param location string
param resourceGroupName string
param adminUsername string
param sshPublicKey string
param subnetId string
param customData string
param privateIpAddress string
param appServerPort string
param githubOrg string
param githubRepoName string
param githubToken string
param appName string
param configHash string = '' // Add this parameter
param deploymentTimestamp string = utcNow()

// Use hash in VM name to force recreation when config changes significantly
var vmName = empty(configHash) ? 'AppServerVM' : 'AppServerVM-${take(configHash, 8)}'

// Network interface for App Server
resource appServerNic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'appServerNic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIpAddress
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

// App Server VM
resource appServerVm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: 'AppServerVM'
      adminUsername: adminUsername
      customData: customData
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: appServerNic.id
        }
      ]
    }
  }
}

// Configure App Server to update the app on every deployment
resource configureVm 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: '${appServerVm.name}/ConfigureApp'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      timestamp: deploymentTimestamp  // Forces the extension to run on every deployment
    }
    protectedSettings: {
      commandToExecute: !empty(githubOrg) && !empty(githubRepoName) ? 'curl -s https://raw.githubusercontent.com/${githubOrg}/${githubRepoName}/main/scripts/configure-app.sh | bash -s -- ${appServerPort} ${githubToken} ${appName}' : 'echo "No app configuration required"'
    }
  }
}

output privateIp string = appServerNic.properties.ipConfigurations[0].properties.privateIPAddress
