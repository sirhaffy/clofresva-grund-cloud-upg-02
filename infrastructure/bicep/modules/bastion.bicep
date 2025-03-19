// Parameters needed from outside the module
param location string = resourceGroup().location
param bastionName string
param subnetId string
param adminUsername string

@secure() // This is a secure parameter that will be encrypted.
param sshPublicKey string

// Create a public IP for the bastion VM
resource publicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${bastionName}-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Create a Network Security Group for the bastion
resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${bastionName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Bastion-Port'
        properties: {
          priority: 101
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '2222'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Create the Network Interface for the bastion VM
resource bastionNic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${bastionName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: bastionNsg.id
    }
  }
}

// Create the bastion VM (this is different from Azure Bastion Service)
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
output publicIp string = publicIp.properties.ipAddress
output vmId string = bastionVM.id
