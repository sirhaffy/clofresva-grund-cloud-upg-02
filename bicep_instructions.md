## Bicep Deployment Instructions

Here's how to deploy the entire infrastructure using Bicep:

```bash
# Login to Azure if not already logged in.
az login

# Set the subscription if not already set.
az account set --subscription <your-subscription-id>

# Create the resource group if it doesn't exist already.
az group create --name <resource-group-name> --location <location>
# Ex:
az group create --name RGCloFreSvaUpg02 --location northeurope

# Generate an SSH key if you don't have one already
ssh-keygen -t rsa -b 4096 -f ~/.ssh/clofresva_gc_upg02_clofresva_gc_upg02_azure_key

# Copy the public key to the clipboard to use in .env and GitHub Secret = SSH_PUBLIC_KEY.
cat ~/.ssh/clofresva_gc_upg02_azure_key.pub

# Create Azure Service Principal 
# Det är en sorts identitet som används av Azure-tjänster för att interagera med resurser i ditt Azure-konto, speciellt vid autentisering och auktorisering vid automatiserade uppgifter.
az ad sp create-for-rbac \
  --name "GitHub-CloFreSvaUpg02" \
  --role contributor \
  --scopes /subscriptions/$(az account show \
  --query id -o tsv)/resourceGroups/RGCloFreSvaUpg02 \
  --sdk-auth

# Copy the output JSON and add to .env and GitHub Secrets named AZURE_CREDENTIALS.

# Validate bicep files before deployment.
az bicep build --file infrastructure/bicep/main.bicep

# Run the deployment script.
./infrastructure/bicep-deploy.sh

# Or for what-if deployment to see changes without applying.
./infrastructure/bicep-deploy.sh --what-if

# Display the deployment outputs
az deployment group show \
  --resource-group RGCloFreSvaUpg02 \
  --name bastionDeployment \
  --query properties.outputs \
  --output json

# Get key information
BASTION_IP=$(az deployment group show \
  --resource-group RGCloFreSvaUpg02 \
  --name bastionDeployment \
  --query properties.outputs.publicIp.value \
  -o tsv)

PROXY_IP=$(az deployment group show \
  --resource-group RGCloFreSvaUpg02 \
  --name reverseProxyDeployment \
  --query properties.outputs.publicIp.value \
  -o tsv)

echo "Bastion Host: $BASTION_IP"
echo "Web Application: http://$PROXY_IP"
echo "SSH to Bastion: ssh azureuser@$BASTION_IP -p 2222"