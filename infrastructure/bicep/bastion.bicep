param location string
param resourceGroupName string
param adminUsername string
param sshPublicKey string
param subnetId string
param customData string

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
  name: 'BastionHostVM'
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
          id: bastionNic.id
        }
      ]
    }
  }
}

output publicIp string = bastionPublicIp.properties.ipAddress
