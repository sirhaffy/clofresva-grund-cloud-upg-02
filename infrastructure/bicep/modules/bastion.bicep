param location string = resourceGroup().location
param bastionName string
param subnetId string
param adminUsername string
@secure() // Secure parameter.
param sshPublicKey string

// Create public IP for bastion host.
resource publicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${bastionName}-ip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Create network interface for bastion
resource bastionNic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${bastionName}-nic'
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
        }
      }
    ]
  }
}

// Create the VM
resource bastionVM 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: bastionName
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
      computerName: bastionName
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
          id: bastionNic.id
        }
      ]
    }
  }
}

// Outputs
output vmId string = bastionVM.id
output publicIpAddress string = publicIp.properties.ipAddress
