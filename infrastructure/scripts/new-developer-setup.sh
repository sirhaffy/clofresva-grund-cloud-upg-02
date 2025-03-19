#!/bin/bash
# filepath: /home/haffy/Dev/clofresva-grund-cloud-upg-02/setup.sh

# Check if .env exists
if [ -f .env ]; then
  echo ".env file already exists. Skipping creation."
else
  # Copy sample env
  if [ -f .env.sample ]; then
    cp .env.sample .env
    echo ".env file created from sample. Please edit it with your actual values."
  else
    echo "No .env.sample file found. Creating minimal .env file..."
    cat > .env << EOF
PROJECT_NAME=clofresva-gc-upg02
RESOURCE_GROUP=RGCloFreSvaUpg02
LOCATION=northeurope
SSH_KEY_PATH=~/.ssh/id_clofresvagcupg02
EOF
    echo ".env file created with default values. Please edit it as needed."
  fi
fi

# Check if SSH key exists
SSH_KEY_PATH=$(grep SSH_KEY_PATH .env | cut -d= -f2)
SSH_KEY_PATH=${SSH_KEY_PATH:-"$HOME/.ssh/id_clofresvagcupg02"}

if [ ! -f "$SSH_KEY_PATH" ] || [ ! -f "${SSH_KEY_PATH}.pub" ]; then
  echo "No SSH key found at $SSH_KEY_PATH. Generating new key..."
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
  echo "SSH key generated at $SSH_KEY_PATH"
fi

# Check for Azure CLI
if ! command -v az &> /dev/null; then
  echo "Azure CLI not found. Please install it:"
  echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
fi

# Check for Ansible
if ! command -v ansible &> /dev/null; then
  echo "Ansible not found. Please install it:"
  echo "sudo apt update && sudo apt install -y ansible"
fi

echo "Setup complete! You can now run ./infrastructure/scripts/deploy.sh to deploy the infrastructure."