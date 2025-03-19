#!/bin/bash
# filepath: /home/haffy/Dev/clofresva-grund-cloud-upg-02/infrastructure/scripts/deploy.sh

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

# Check for required tools
if ! command -v jq &> /dev/null; then
  echo "jq is required for parsing deployment outputs. Installing..."
  sudo apt-get update && sudo apt-get install -y jq
fi

# Create resource group if it doesn't exist
echo "Creating/updating resource group $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# Check if VM exists and remove existing extensions
if az vm show --resource-group "$RESOURCE_GROUP" --name "${PROJECT_NAME}-app-server" &>/dev/null; then
  echo "VM exists, removing any existing CustomScript extensions..."
  # List all extensions
  extensions=$(az vm extension list --resource-group "$RESOURCE_GROUP" --vm-name "${PROJECT_NAME}-app-server" --query "[?extensionType=='CustomScript'].name" -o tsv)

  # Delete each extension
  for ext in $extensions; do
    echo "Removing extension: $ext"
    az vm extension delete --resource-group "$RESOURCE_GROUP" --vm-name "${PROJECT_NAME}-app-server" --name "$ext"
  done

  echo "Waiting for extension deletion to complete..."
  sleep 30
fi

# Deploy Bicep template
echo "Deploying infrastructure with Bicep..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "main" \
  --template-file ./infrastructure/bicep/main.bicep \
  --parameters projectName="$PROJECT_NAME" \
  --parameters adminUsername=azureuser \
  --parameters "sshPublicKey=$SSH_PUBLIC_KEY" \
  --parameters location="$LOCATION"

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
APP_IP=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.appServerPrivateIp.value')
STORAGE_ACCOUNT=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.storageAccountName.value')
BLOB_ENDPOINT=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.blobEndpoint.value')

# Update .env file with these values
sed -i "s/^BASTION_IP=.*/BASTION_IP=$BASTION_IP/" .env
sed -i "s/^PROXY_IP=.*/PROXY_IP=$PROXY_IP/" .env
sed -i "s/^APP_IP=.*/APP_IP=$APP_IP/" .env
sed -i "s/^STORAGE_ACCOUNT=.*/STORAGE_ACCOUNT=$STORAGE_ACCOUNT/" .env
sed -i "s|^BLOB_ENDPOINT=.*|BLOB_ENDPOINT=$BLOB_ENDPOINT|" .env

# Display deployment information
echo "=============================================="
echo "Deployment complete! Access information:"
echo "Bastion host: $BASTION_IP (SSH port 22)"
echo "Web application: http://$PROXY_IP/"
echo "SSH to bastion: ssh -i $SSH_KEY_PATH azureuser@$BASTION_IP"
echo "=============================================="

# Create dynamic inventory file for Ansible
mkdir -p ./ansible/inventories
cat > ./ansible/inventories/azure_rm.yml << EOF
all:
  hosts:
    bastion:
      ansible_host: "${BASTION_IP}"
      ansible_user: azureuser
      ansible_ssh_private_key_file: ${SSH_KEY_PATH}
    reverse_proxy:
      ansible_host: "${PROXY_IP}"
      ansible_user: azureuser
      ansible_ssh_private_key_file: ${SSH_KEY_PATH}
    app_server:
      ansible_host: "${APP_IP}"
      ansible_user: azureuser
      ansible_ssh_private_key_file: ${SSH_KEY_PATH}
      ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -i ${SSH_KEY_PATH} azureuser@${BASTION_IP}"'
  vars:
    project_name: "${PROJECT_NAME}"
    storage_account: "${STORAGE_ACCOUNT}"
    blob_endpoint: "${BLOB_ENDPOINT}"
EOF

# Ask to run Ansible playbooks
read -p "Run Ansible playbooks now? (y/n) " RUN_ANSIBLE

if [[ $RUN_ANSIBLE == "y" ]]; then
  echo "Running Ansible playbooks"

  # Wait for SSH to be ready
  echo "Waiting for SSH connections to be ready..."
  sleep 30

  # Run the playbooks
  ansible-playbook -i ./ansible/inventories/azure_rm.yml ./ansible/playbooks/site.yml
else
  echo "Skipping Ansible playbooks. You can run them later with:"
  echo "ansible-playbook -i ./ansible/inventories/azure_rm.yml ./ansible/playbooks/site.yml"
fi

echo "Deployment process complete!"