param location string
param resourceName string
param delay int = 10 // seconds to wait

// Create a managed identity to execute the script
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${uniqueString(resourceGroup().id, resourceName)}'
  location: location
}

// Create a deployment script that waits
resource waitScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'wait-for-${resourceName}-${uniqueString(deployment().name)}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.26.0'
    scriptContent: 'echo "Waiting ${delay} seconds for resource to stabilize..."; sleep ${delay}; echo "Done waiting"'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
  }
}

output completed bool = true
