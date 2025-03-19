param location string = resourceGroup().location
param reverseProxyName string
param subnetId string
param adminUsername string
@secure()
param sshPublicKey string

// Create a public IP for the reverse proxy
resource publicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${reverseProxyName}-ip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Create a Network Security Group for the reverse proxy
resource proxyNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${reverseProxyName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-SSH-From-Bastion'
        properties: {
          priority: 110
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Create the Network Interface for the reverse proxy
resource proxyNic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${reverseProxyName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: proxyNsg.id
    }
  }
}

// Create the reverse proxy VM
resource proxyVM 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: reverseProxyName
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
      computerName: reverseProxyName
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
          id: proxyNic.id
        }
      ]
    }
  }
}

// Output the public IP address for access
output publicIp string = publicIp.properties.ipAddress
output privateIp string = proxyNic.properties.ipConfigurations[0].properties.privateIPAddress
output vmId string = proxyVM.id
