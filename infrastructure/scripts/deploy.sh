#!/bin/bash
# filepath: d:\Dev\CloudDeveloper\06_Grund_Cloud\Inlamningsuppgift_02\infrastructure\scripts\deploy.sh

# Source .env file if it exists
if [ -f .env ]; then
  source .env
else
  echo "No .env file found. Creating from .env.sample..."
  if [ -f .env.sample ]; then
    cp .env.sample .env
    echo "Please edit the .env file with your actual values, then run this script again."
    exit 1
  else
    echo "No .env.sample file found. Cannot continue."
    exit 1
  fi
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

# Extract values from outputs
BASTION_IP=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.bastionHostIp.value')
PROXY_IP=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.reverseProxyIp.value')
STORAGE_ACCOUNT=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.storageAccountName.value')
BLOB_ENDPOINT=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.blobEndpoint.value')
APP_PRIVATE_IP=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.appServerPrivateIp.value')
PROXY_PRIVATE_IP=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.reverseProxyPrivateIp.value')

# Update .env file with these values
sed -i "s/^BASTION_IP=.*/BASTION_IP=$BASTION_IP/" .env
sed -i "s/^PROXY_IP=.*/PROXY_IP=$PROXY_IP/" .env
sed -i "s/^STORAGE_ACCOUNT=.*/STORAGE_ACCOUNT=$STORAGE_ACCOUNT/" .env
sed -i "s|^BLOB_ENDPOINT=.*|BLOB_ENDPOINT=$BLOB_ENDPOINT|" .env
sed -i "s/^APP_PRIVATE_IP=.*/APP_PRIVATE_IP=$APP_PRIVATE_IP/" .env
sed -i "s/^PROXY_PRIVATE_IP=.*/PROXY_PRIVATE_IP=$PROXY_PRIVATE_IP/" .env

# Funktion för att rensa SSH known_hosts och hantera nya nycklar
prepare_ssh_connections() {
  local bastion_ip="$1"
  local app_ip="$2"
  local proxy_ip="$3"

  echo "Preparing SSH connections by cleaning known hosts..."

  # Ta bort eventuella tidigare SSH-nycklar för VM-IP-adresser
  ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$bastion_ip" 2>/dev/null || true
  ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$app_ip" 2>/dev/null || true
  ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$proxy_ip" 2>/dev/null || true

  # Lägg till StrictHostKeyChecking=no i SSH-konfigurationen för dessa hosts
  mkdir -p "$HOME/.ssh"
  cat > "$HOME/.ssh/config" << EOF
Host $bastion_ip
  StrictHostKeyChecking accept-new

Host $app_ip
  StrictHostKeyChecking accept-new
  ProxyCommand ssh -W %h:%p $bastion_ip

Host $proxy_ip
  StrictHostKeyChecking accept-new
  ProxyCommand ssh -W %h:%p $bastion_ip
EOF

  chmod 600 "$HOME/.ssh/config"

  echo "SSH configuration updated."
}

# Funktion för att vänta på SSH-tillgänglighet
wait_for_ssh() {
  local host=$1
  local max_attempts=30
  local attempt=0

  echo "Waiting for SSH on $host..."

  while [ $attempt -lt $max_attempts ]; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o BatchMode=yes -i "$SSH_KEY_PATH" azureuser@"$host" exit 2>/dev/null; then
      echo "SSH connection to $host established."
      return 0
    fi

    attempt=$((attempt+1))
    echo "Attempt $attempt/$max_attempts failed. Waiting 10 seconds..."
    sleep 10
  done

  echo "Failed to connect to $host after $max_attempts attempts."
  return 1
}

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
cat > ./ansible/inventories/azure_rm.yml << EOF
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
    github_repo: "${GITHUB_REPO}"
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
    echo "Then run Ansible manually with: ansible-playbook -i ./ansible/inventories/azure_rm.yml ./ansible/playbooks/site.yml"
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
  export REPO_GITHUB RUNNER_TOKEN

  # Run the playbooks
  ANSIBLE_CONFIG=./ansible/ansible.cfg ansible-playbook -i ./ansible/inventories/azure_rm.yml ./ansible/playbooks/site.yml
else
  echo "Skipping Ansible playbooks. You can run them later with:"
  echo "source .env && export REPO_GITHUB RUNNER_TOKEN && ansible-playbook -i ./ansible/inventories/azure_rm.yml ./ansible/playbooks/site.yml"
fi

echo "Deployment process complete!"