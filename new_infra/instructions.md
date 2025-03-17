// ...existing code...

## 11. Bicep Deployment Instructions

Here's how to deploy the entire infrastructure using Bicep:

```bash
# Login to Azure
az login

# Set the subscription
az account set --subscription <your-subscription-id>

# Create the resource group if it doesn't exist
az group create --name RGCloFreSvaUpg02 --location northeurope

# Generate an SSH key if you don't have one already
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_key

# Deploy the Bicep template with the SSH public key
az deployment group create \
  --resource-group RGCloFreSvaUpg02 \
  --template-file main.bicep \
  --parameters sshPublicKey="$(cat ~/.ssh/azure_key.pub)"

# Display the deployment outputs
az deployment group show \
  --resource-group RGCloFreSvaUpg02 \
  --name mainDeployment \
  --query properties.outputs \
  --output json