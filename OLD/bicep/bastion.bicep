param location string
param resourceGroupName string
param adminUsername string
param sshPublicKey string
param subnetId string
param customData string
param configHash string = '' // Default empty if not provided
param deploymentTimestamp string = utcNow()

// Add other parameters needed by the VM extension
param githubOrg string = ''
param githubRepoName string = ''
param appServerPort string = ''
param githubToken string = ''

// Use current time for forcing updates to VM extensions
var vmName = empty(configHash) ? 'BastionHostVM' : 'BastionHostVM-${take(configHash, 8)}'

// Public IP for Bastion Host
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'BastionPublicIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Network interface for Bastion Host
resource bastionNic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'bastionNic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPublicIp.id
          }
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

// Bastion Host VM
resource bastionVm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: 'BastionHostVM'
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
          id: bastionNic.id
        }
      ]
    }
  }
}

// Configure VM to update on every deployment
resource configureVm 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: '${bastionVm.name}/ConfigureApp'
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
      commandToExecute: !empty(githubOrg) && !empty(githubRepoName) ? 'curl -s https://raw.githubusercontent.com/${githubOrg}/${githubRepoName}/main/scripts/configure.sh | bash -s -- ${appServerPort} ${githubToken}' : 'echo "No configuration required"'
    }
  }
}

output publicIp string = bastionPublicIp.properties.ipAddress
output privateIp string = bastionNic.properties.ipConfigurations[0].properties.privateIPAddress
output vmName string = bastionVm.name
