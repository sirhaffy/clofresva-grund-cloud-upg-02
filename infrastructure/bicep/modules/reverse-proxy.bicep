param location string = resourceGroup().location
param appServerName string
param subnetId string
param adminUsername string
param asgId string
@secure()
param sshPublicKey string

// Create public IP address for App Server
resource publicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${appServerName}-public-ip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower(appServerName)
    }
  }
}

// Create network interface for App Server
resource appNic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${appServerName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
          applicationSecurityGroups: [
            {
              id: asgId
            }
          ]
        }
      }
    ]
  }
}

// Create the app server VM
resource appServerVM 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: appServerName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
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
    osProfile: {
      computerName: appServerName
      adminUsername: adminUsername
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
    networkProfile: {
      networkInterfaces: [
        {
          id: appNic.id
        }
      ]
    }
  }
}

// Outputs
output vmId string = appServerVM.id
output privateIp string = appNic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIpAddress string = publicIp.properties.ipAddress
