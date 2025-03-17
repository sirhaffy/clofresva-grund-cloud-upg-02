name: Deploy Azure Infrastructure

on:
  push:
    branches:
      - main
    paths:
      - 'bicep/**'
      - '.github/workflows/deploy-infrastructure.yml'
  workflow_dispatch:

jobs:
  deploy-infrastructure:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Login to Azure
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Bicep template
        uses: azure/arm-deploy@v1
        with:
          resourceGroupName: RGCloFreSvaUpg02
          template: ./main.bicep
          parameters: 'sshPublicKey="${{ secrets.SSH_PUBLIC_KEY }}"'
          deploymentName: github-workflow-${{ github.run_number }}
          failOnStdErr: false
      
      - name: Show deployment outputs
        run: |
          outputs=$(az deployment group show \
            --resource-group RGCloFreSvaUpg02 \
            --name github-workflow-${{ github.run_number }} \
            --query properties.outputs \
            --output json)
          echo "::set-output name=deployment_outputs::$outputs"
          echo "$outputs" | jq