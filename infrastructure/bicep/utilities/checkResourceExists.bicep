param location string
param resourceType string
param resourceName string

// Create a managed identity to execute the script
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${uniqueString(resourceGroup().id, resourceName)}'
  location: location
}

// Deploy a script that checks if the resource exists and output the result
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'checkResourceExists-${resourceName}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.40.0'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
      #!/bin/bash
      echo "Checking if resource exists: $RESOURCE_NAME of type $RESOURCE_TYPE"
      EXISTS=$(az resource show --resource-type "$RESOURCE_TYPE" --name "$RESOURCE_NAME" --resource-group "$RESOURCE_GROUP" --query "id" --output tsv 2>/dev/null || echo "NotFound")

      if [ "$EXISTS" != "NotFound" ]; then
        echo "Resource $RESOURCE_NAME exists"
        echo "{\"exists\": true}" > $AZ_SCRIPTS_OUTPUT_PATH
      else
        echo "Resource $RESOURCE_NAME does not exist"
        echo "{\"exists\": false}" > $AZ_SCRIPTS_OUTPUT_PATH
      fi
    '''
    environmentVariables: [
      {
        name: 'RESOURCE_NAME'
        value: resourceName
      }
      {
        name: 'RESOURCE_TYPE'
        value: resourceType
      }
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
    ]
  }
}

output exists bool = bool(deploymentScript.properties.outputs.exists)
