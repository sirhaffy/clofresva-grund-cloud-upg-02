#!/bin/bash

# Variables
resource_group="RGCloFreSvaUpg02"
location="northeurope"
admin_email="haffy@icloud.com"
admin_username="azureuser"
app_server_ip="10.0.2.10"
app_server_port="5000"
reverse_proxy_ip="10.0.1.10"
github_org="Campus-Molndal-CLOH24"
github_repo_name="CloFreSvaUpg02App"
github_token="ACMKOYEG54SS7G5RYOKLCWDH2V3VI" # Should be secured
app_name="CloFreSvaUpg02App"

# Create resource group if it doesn't exist
echo "Creating resource group..."
az group create \
  --name $resource_group \
  --location $location

# Generate SSH key if not exists
if [ ! -f ~/.ssh/azure_key ]; then
  echo "Generating SSH key..."
  ssh-keygen -t ed25519 -C "$admin_email" -f ~/.ssh/azure_key -N ""
fi

# Read SSH public key
ssh_public_key=$(cat ~/.ssh/azure_key.pub)

# Process cloud-init templates with environment variables
echo "Processing cloud-init templates..."
mkdir -p temp
envsubst < cloud-init/reverse-proxy.yaml.template > temp/reverse-proxy.yaml
envsubst < cloud-init/app-server.yaml.template > temp/app-server.yaml
cp cloud-init/bastion.yaml temp/bastion.yaml

# Deploy infrastructure using Bicep
echo "Deploying infrastructure..."
az deployment group create \
  --resource-group $resource_group \
  --template-file bicep/main.bicep \
  --parameters location=$location \
  --parameters resourceGroupName=$resource_group \
  --parameters adminEmail=$admin_email \
  --parameters adminUsername=$admin_username \
  --parameters sshPublicKey="$ssh_public_key" \
  --parameters appServerIp=$app_server_ip \
  --parameters appServerPort=$app_server_port \
  --parameters reverseProxyIp=$reverse_proxy_ip \
  --parameters githubOrg=$github_org \
  --parameters githubRepoName=$github_repo_name \
  --parameters githubToken=$github_token \
  --parameters appName=$app_name

# Get deployment outputs
echo "Getting deployment outputs..."
bastion_host_ip=$(az deployment group show \
  --resource-group $resource_group \
  --name bastionDeployment \
  --query properties.outputs.publicIp.value \
  -o tsv)

reverse_proxy_ip=$(az deployment group show \
  --resource-group $resource_group \
  --name reverseProxyDeployment \
  --query properties.outputs.publicIp.value \
  -o tsv)

# Clean up temporary files
rm -rf temp

# Output important information
echo "Deployment completed successfully!"
echo "Bastion Host IP: $bastion_host_ip"
echo "Reverse Proxy IP: $reverse_proxy_ip"
echo "App Server Internal IP: $app_server_ip"