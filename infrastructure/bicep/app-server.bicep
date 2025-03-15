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
  name: 'AppServerVM'
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
        sku: '22_04-lts-gen2'
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

output privateIp string = privateIpAddress
