param location string
param resourceName string
param delay int = 10 // seconds to wait

// Create a managed identity to execute the script
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-wait-${uniqueString(resourceGroup().id, resourceName)}'
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
    azCliVersion: '2.40.0'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
    scriptContent: '''
      #!/bin/bash
      echo "Waiting ${DELAY} seconds for resource to stabilize...";
      sleep ${DELAY};
      echo "Done waiting";
      echo "{\"completed\": true}" > $AZ_SCRIPTS_OUTPUT_PATH
    '''
    environmentVariables: [
      {
        name: 'DELAY'
        value: string(delay)
      }
    ]
    cleanupPreference: 'OnSuccess'
  }
}

output completed bool = true
