param location string
param resourceGroupName string // We'll keep this even if unused now

// Virtual network and subnets
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'NordicVNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'ReverseProxySubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsgReverseProxy.id
          }
        }
      }
      {
        name: 'AppServerSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: nsgAppServer.id
          }
        }
      }
      {
        name: 'BastionHostSubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: {
            id: nsgBastionHost.id
          }
        }
      }
      {
        name: 'StorageSubnet'
        properties: {
          addressPrefix: '10.0.4.0/24'
          networkSecurityGroup: {
            id: nsgStorage.id
          }
        }
      }
      {
        name: 'DatabaseSubnet'
        properties: {
          addressPrefix: '10.0.5.0/24'
          networkSecurityGroup: {
            id: nsgDatabase.id
          }
        }
      }
    ]
  }
}

// NSGs
resource nsgReverseProxy 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'NSG-ReverseProxy'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-All'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          description: 'Allow HTTP/S'
        }
      }
      {
        name: 'Allow-SSH-Bastion'
        properties: {
          priority: 1100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.0.3.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SSH from Bastion'
        }
      }
    ]
  }
}

resource nsgAppServer 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'NSG-AppSrv'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-All'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.0.1.0/24'  // From Reverse Proxy subnet
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '5000'
          description: 'Allow HTTP from Reverse Proxy'
        }
      }
      {
        name: 'Allow-SSH-Bastion'
        properties: {
          priority: 1100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.0.3.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SSH from Bastion'
        }
      }
    ]
  }
}

resource nsgBastionHost 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'NSG-BastionHost'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-All'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '2222'
          description: 'Allow SSH'
        }
      }
    ]
  }
}

resource nsgStorage 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'NSG-Storage'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-All'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.0.2.0/24'  // From App Server subnet
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow HTTPS'
        }
      }
    ]
  }
}

resource nsgDatabase 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'NSG-CosmosDB'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-All'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.0.2.0/24'  // From App Server subnet
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow HTTPS'
        }
      }
    ]
  }
}

// Outputs
output vnetId string = vnet.id
output reverseProxySubnetId string = '${vnet.id}/subnets/ReverseProxySubnet'
output appServerSubnetId string = '${vnet.id}/subnets/AppServerSubnet'
output bastionSubnetId string = '${vnet.id}/subnets/BastionHostSubnet'
output storageSubnetId string = '${vnet.id}/subnets/StorageSubnet'
output databaseSubnetId string = '${vnet.id}/subnets/DatabaseSubnet'
