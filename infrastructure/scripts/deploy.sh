#!/bin/bash

# Create .env file if it doesn't exist or load if it does
if [ ! -f .env ]; then
  echo "Creating new .env file with default values..."
  cat > .env << EOF
PROJECT_NAME=${PROJECT_NAME:-"clofresva-gc-upg02"}
RESOURCE_GROUP=${RESOURCE_GROUP:-"RGCloFreSvaUpg02"}
LOCATION=${LOCATION:-"northeurope"}
REPO_NAME=${REPO_NAME:-"sirhaffy/clofresva-grund-cloud-upg-02"}
SSH_KEY_PATH=${SSH_KEY_PATH:-"$HOME/.ssh/clofresva_gc_upg02_azure_key"}
EOF
else
  echo "Loading existing .env file..."
  source .env
fi

# Set default values if not provided in .env
PROJECT_NAME=${PROJECT_NAME:-"clofresva-gc-upg02"}
LOCATION=${LOCATION:-"northeurope"}
RESOURCE_GROUP=${RESOURCE_GROUP:-"RGCloFreSvaUpg02"}
SSH_KEY_PATH=${SSH_KEY_PATH:-"$HOME/.ssh/id_rsa"}

# Check for required tools
if ! command -v jq &> /dev/null; then
  echo "jq is required for parsing deployment outputs. Installing..."
  sudo apt-get update && sudo apt-get install -y jq
fi

# Check if SSH key exists, if not, create one
if [ ! -f "$SSH_KEY_PATH" ] || [ ! -f "${SSH_KEY_PATH}.pub" ]; then
  echo "No SSH key found at $SSH_KEY_PATH. Generating new key..."
  mkdir -p "$(dirname "$SSH_KEY_PATH")"
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
fi

# Read SSH public key
SSH_PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")

# Create resource group if it doesn't exist
echo "Creating/updating resource group $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# Visa vad som kommer göras, men utan disk-checks
echo "Checking what changes would be made to infrastructure..."
az deployment group what-if \
  --resource-group "$RESOURCE_GROUP" \
  --name "main" \
  --template-file ./infrastructure/bicep/main.bicep \
  --parameters projectName="$PROJECT_NAME" \
  --parameters adminUsername=azureuser \
  --parameters "sshPublicKey=$SSH_PUBLIC_KEY" \
  --parameters location="$LOCATION"

read -p "Do you want to apply these changes? (y/n) " APPLY_CHANGES

if [[ $APPLY_CHANGES == "y" ]]; then
  echo "Deploying infrastructure with Bicep (incremental mode)..."
  az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "main" \
    --template-file ./infrastructure/bicep/main.bicep \
    --parameters projectName="$PROJECT_NAME" \
    --parameters adminUsername=azureuser \
    --parameters "sshPublicKey=$SSH_PUBLIC_KEY" \
    --parameters location="$LOCATION" \
    --mode Incremental
else
  echo "Deployment cancelled."
  exit 0
fi

# Check if deployment succeeded
if [ "$?" -ne 0 ]; then
  echo "Deployment failed. Check the error messages above."
  exit 1
fi

# Get deployment outputs
echo "Getting deployment outputs..."
DEPLOYMENT_OUTPUTS=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "main" \
  --query properties.outputs -o json)

if [ $? -ne 0 ]; then
  echo "Failed to get deployment outputs."
  exit 1
fi

# Create a function to update .env variables
update_env_var() {
  local var_name=$1
  local var_value=$2

  if grep -q "^${var_name}=" .env; then
    sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" .env
  else
    echo "${var_name}=${var_value}" >> .env
  fi
}

# Use the function for all variables
update_env_var "BASTION_IP" "$BASTION_IP"
update_env_var "PROXY_IP" "$PROXY_IP"
update_env_var "STORAGE_ACCOUNT" "$STORAGE_ACCOUNT"
update_env_var "BLOB_ENDPOINT" "$BLOB_ENDPOINT"
update_env_var "APP_PRIVATE_IP" "$APP_PRIVATE_IP"
update_env_var "PROXY_PRIVATE_IP" "$PROXY_PRIVATE_IP"

# Setup SSH config with Ansible
if command -v ansible-playbook &> /dev/null; then
  echo "Setting up SSH configuration with Ansible..."
  ansible-playbook -i ./ansible/inventories/azure_rm.yaml ./ansible/playbooks/ssh_config.yaml
else
  echo "Ansible not found. Manual SSH configuration may be required."
fi

# Display deployment information
echo "=============================================="
echo "Deployment complete! Access information:"
echo "Bastion host: $BASTION_IP (SSH port 22)"
echo "Web application: http://$PROXY_IP/"
echo "SSH to bastion: ssh -i $SSH_KEY_PATH azureuser@$BASTION_IP"
echo "=============================================="

# Create dynamic inventory file for Ansible
# Detta är bara det relevanta avsnittet i deploy.sh

# Create dynamic inventory file for Ansible
mkdir -p ./ansible/inventories
cat > ./ansible/inventories/azure_rm.yaml << EOF
all:
  hosts:
    bastion:
      ansible_host: "${BASTION_IP}"
      ansible_user: azureuser
      ansible_ssh_private_key_file: ${SSH_KEY_PATH}
      ansible_ssh_common_args: '-o StrictHostKeyChecking=accept-new'
    reverse_proxy:
      ansible_host: "${PROXY_IP}"
      ansible_user: azureuser
      ansible_ssh_private_key_file: ${SSH_KEY_PATH}
      ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=accept-new -i ${SSH_KEY_PATH} azureuser@${BASTION_IP}"'
    app_server:
      ansible_host: "${APP_PRIVATE_IP}"
      ansible_user: azureuser
      ansible_ssh_private_key_file: ${SSH_KEY_PATH}
      ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=accept-new -i ${SSH_KEY_PATH} azureuser@${BASTION_IP}"'
  vars:
    project_name: "${PROJECT_NAME}"
    storage_account: "${STORAGE_ACCOUNT}"
    blob_endpoint: "${BLOB_ENDPOINT}"
    REPO_NAME: "${REPO_NAME}"
    github_runner_token: "${RUNNER_TOKEN}"
EOF

# Ask to run Ansible playbooks
read -p "Run Ansible playbooks now? (y/n) " RUN_ANSIBLE

if [[ $RUN_ANSIBLE == "y" ]]; then
  echo "Running Ansible playbooks"

  # Förbered SSH-anslutningar för att undvika host key-verifieringsproblem
  prepare_ssh_connections "$BASTION_IP" "$APP_PRIVATE_IP" "$PROXY_PRIVATE_IP"

  # Vänta på att SSH ska vara tillgängligt innan Ansible körs
  if ! wait_for_ssh "$BASTION_IP"; then
    echo "ERROR: Could not establish SSH connection to bastion host."
    echo "Please check your deployment and try running Ansible manually."
    exit 1
  fi

  # Kontrollera om ansible-playbook finns tillgängligt
  if ! command -v ansible-playbook &> /dev/null; then
    echo "ansible-playbook not found. Please install Ansible and try again."
    echo "You can install it with: sudo apt install -y ansible"
    echo "Then run Ansible manually with: ansible-playbook -i ./ansible/inventories/azure_rm.yaml ./ansible/playbooks/site.yaml"
    exit 1
  fi

  # Skapa eller uppdatera ansible.cfg
  cat > ./ansible/ansible.cfg << EOF
[defaults]
host_key_checking = False
EOF

  # Säkerställ att GitHub-variabler är exporterade för Ansible
  # Läs in .env-filen igen för att säkerställa att eventuella manuella ändringar finns med
  source .env
  export REPO_NAME RUNNER_TOKEN

  # Run the playbooks
  ANSIBLE_CONFIG=./ansible/ansible.cfg ansible-playbook -i ./ansible/inventories/azure_rm.yaml ./ansible/playbooks/site.yaml
else
  echo "Skipping Ansible playbooks. You can run them later with:"
  echo "source .env && export REPO_NAME RUNNER_TOKEN && ansible-playbook -i ./ansible/inventories/azure_rm.yaml ./ansible/playbooks/site.yaml"
fi

echo "Deployment process complete!"