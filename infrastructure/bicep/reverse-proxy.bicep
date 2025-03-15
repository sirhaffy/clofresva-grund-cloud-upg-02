param location string
param resourceGroupName string
param adminUsername string
param sshPublicKey string
param subnetId string
param customData string
param privateIpAddress string
param appServerIp string
param appServerPort string

// Public IP for Reverse Proxy
resource reverseProxyPublicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'ReverseProxyIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Network interface for Reverse Proxy
resource reverseProxyNic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'reverseProxyNic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIpAddress
          publicIPAddress: {
            id: reverseProxyPublicIp.id
          }
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

// Reverse Proxy VM
resource reverseProxyVm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: 'ReverseProxyVM'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: 'ReverseProxyVM'
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
          id: reverseProxyNic.id
        }
      ]
    }
  }
}

output publicIp string = reverseProxyPublicIp.properties.ipAddress
output privateIp string = privateIpAddress
