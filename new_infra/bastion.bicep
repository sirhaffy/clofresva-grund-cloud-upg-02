param location string = resourceGroup().location
param bastionHostName string = 'BastionHostVM'
param vnetName string = 'NordicVNet'
param bastionSubnetName string = 'BastionHostSubnet'
param adminUsername string = 'azureuser'
param sshPublicKey string

// Create a static public IP for the Bastion Host
resource bastionPublicIP 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: 'BastionPublicIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Create a network interface for the Bastion Host VM
resource bastionNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${bastionHostName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, bastionSubnetName)
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPublicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: resourceId('Microsoft.Network/networkSecurityGroups', 'NSG-BastionHost')
    }
  }
}

// Create the Bastion Host VM
resource bastionVM 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: bastionHostName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
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
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: bastionHostName
      adminUsername: adminUsername
      customData: loadFileAsBase64('cloud_init_bastion.yaml')
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

output bastionPublicIp string = bastionPublicIP.properties.ipAddress
