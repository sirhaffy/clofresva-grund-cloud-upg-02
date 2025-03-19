#!/bin/bash
echo "Setting up development environment..."

# Check for .env file
if [ -f .env ]; then
  echo ".env file exists, using existing configuration."
else
  echo "Creating .env file with default settings."
  cat > .env << EOF
# Project settings
PROJECT_NAME=clofresva-gc-upg02
RESOURCE_GROUP=RGCloFreSvaUpg02
LOCATION=northeurope
ADMIN_USERNAME=azureuser

# SSH settings (for local deployment)
SSH_KEY_PATH=~/.ssh/id_rsa

# Optional: For manual testing with Azure CLI
AZURE_SUBSCRIPTION_ID=your_subscription_id

# These will be populated by the deploy script after deployment
BASTION_IP=
PROXY_IP=
APP_PRIVATE_IP=
STORAGE_ACCOUNT=
BLOB_ENDPOINT=
EOF
  echo ".env file created."
fi

# Check for Azure CLI
if ! command -v az &> /dev/null; then
  echo "Azure CLI not found. You'll need to install it to deploy to Azure."
  echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
else
  echo "Azure CLI found."

  # Check if logged in
  az account show &> /dev/null
  if [ $? -ne 0 ]; then
    echo "Not logged in to Azure. Please login:"
    az login
  fi

  # Get subscription ID
  AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
  echo "Using Azure subscription ID: $AZURE_SUBSCRIPTION_ID"

  # Update .env with subscription ID
  sed -i "s/AZURE_SUBSCRIPTION_ID=your_subscription_id/AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID/" .env
fi

# Check for SSH keys
SSH_KEY_PATH=$(grep SSH_KEY_PATH .env | cut -d= -f2)
if [ -z "$SSH_KEY_PATH" ]; then
  SSH_KEY_PATH="$HOME/.ssh/id_rsa"
fi

if [ ! -f "$SSH_KEY_PATH" ] || [ ! -f "${SSH_KEY_PATH}.pub" ]; then
  echo "No SSH key found at $SSH_KEY_PATH. Generating new key..."
  mkdir -p "$(dirname "$SSH_KEY_PATH")"
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "azureuser@clofresva-deployment"
  echo "SSH key generated at $SSH_KEY_PATH"
else
  echo "SSH keys found at $SSH_KEY_PATH"
fi

# Check for required tools
echo "Checking for required tools..."

# Check for Ansible
if ! command -v ansible &> /dev/null; then
  echo "Ansible not found. You'll need to install it to configure servers."
  echo "Run: sudo apt update && sudo apt install -y ansible"
else
  echo "Ansible found: $(ansible --version | head -n1)"
fi

# Check for Bicep
if ! command -v bicep &> /dev/null; then
  echo "Bicep not found. You'll need it to deploy infrastructure."
  echo "It's part of Azure CLI. Make sure your Azure CLI is up to date."
else
  echo "Bicep found: $(bicep --version)"
fi

echo "Setup complete! You can now run './infrastructure/scripts/deploy.sh' to deploy your infrastructure."