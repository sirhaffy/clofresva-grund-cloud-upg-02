#!/bin/bash
set -e  # Exit on any error

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
else
  echo "No .env file found. Using default values where possible."
fi

# Variables
export RESOURCE_GROUP=${RESOURCE_GROUP:-"RGCloFreSvaUpg02"}
export LOCATION=${LOCATION:-"northeurope"}
export APP_SERVER_IP=${APP_SERVER_IP:-"10.0.2.10"}
export APP_SERVER_PORT=${APP_SERVER_PORT:-"5000"}
export REVERSE_PROXY_IP=${REVERSE_PROXY_IP:-"10.0.1.10"}
export GITHUB_ORG=${GITHUB_ORG:-"Campus-Molndal-CLOH24"}
export GITHUB_REPO_NAME=${GITHUB_REPO_NAME:-"CloFreSvaUpg02App"}
export APP_NAME=${APP_NAME:-"CloFreSvaUpg02App"}

# Use environment variables for sensitive data
export ADMIN_EMAIL=${ADMIN_EMAIL:-"default_email@example.com"}
export ADMIN_USERNAME=${ADMIN_USERNAME:-"azureuser"}
export GITHUB_TOKEN=${GITHUB_TOKEN:-""}

# Validate required secrets are set
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GitHub token is not set."
  echo "Create a .env file with GITHUB_TOKEN=your_token or set it as an environment variable."
  exit 1
fi

# Create resource group if it doesn't exist
echo "Creating resource group..."
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Generate SSH key if not exists
if [ ! -f ~/.ssh/clofresva_gc_upg02_azure_key ]; then
  echo "Generating SSH key..."
  ssh-keygen -t ed25519 -C "$ADMIN_EMAIL" -f ~/.ssh/clofresva_gc_upg02_azure_key -N ""
fi

# Read SSH public key and export it
export SSH_PUBLIC_KEY=$(cat ~/.ssh/clofresva_gc_upg02_azure_key.pub)

# Process cloud-init templates with environment variables
echo "Processing cloud-init templates..."
mkdir -p temp
envsubst < cloud-init/reverse-proxy.yaml.template > temp/reverse-proxy.yaml
envsubst < cloud-init/app-server.yaml.template > temp/app-server.yaml
cp cloud-init/bastion.yaml temp/bastion.yaml

# Calculate config hashes for idempotency
export BASTION_HASH=$(sha256sum temp/bastion.yaml | cut -d' ' -f1)
export PROXY_HASH=$(sha256sum temp/reverse-proxy.yaml | cut -d' ' -f1)
export APP_HASH=$(sha256sum temp/app-server.yaml | cut -d' ' -f1)

echo "Config hashes:"
echo "  Bastion: ${BASTION_HASH:0:8}..."
echo "  Reverse Proxy: ${PROXY_HASH:0:8}..."
echo "  App Server: ${APP_HASH:0:8}..."

# Process parameters.json template with environment variables
echo "Processing parameters.json template..."
envsubst < parameters.json.template > temp/parameters.json

# Deploy infrastructure using Bicep with parameters file
echo "Deploying infrastructure..."
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file bicep/main.bicep \
  --parameters @temp/parameters.json

# Get deployment outputs
echo "Getting deployment outputs..."
bastion_host_ip=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name bastionDeployment \
  --query properties.outputs.publicIp.value \
  -o tsv)

reverse_proxy_ip=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name reverseProxyDeployment \
  --query properties.outputs.publicIp.value \
  -o tsv)

# Clean up temporary files with sensitive information
echo "Cleaning up temporary files..."
rm -rf temp

# Output important information
echo "=================================================="
echo "Deployment completed successfully!"
echo "=================================================="
echo "Bastion Host IP: $bastion_host_ip"
echo "Reverse Proxy IP: $reverse_proxy_ip"
echo "App Server Internal IP: $APP_SERVER_IP"
echo ""
echo "Web Application URL: http://$reverse_proxy_ip"
echo ""
echo "SSH to Bastion: ssh $ADMIN_USERNAME@$bastion_host_ip -p 2222"