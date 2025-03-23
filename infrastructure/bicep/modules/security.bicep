param vnetName string
// param bastionSubnetName string = 'BastionSubnet'
// param appServerSubnetName string = 'AppServerSubnet'
// param reverseProxySubnetName string = 'ReverseProxySubnet'
// param cosmosDbSubnetName string = 'CosmosDbSubnet'

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${vnetName}-nsg'
  location: resourceGroup().location
  properties: {
    securityRules: [
      // {
      //   name: 'AllowBastionSSH'
      //   properties: {
      //     priority: 100
      //     protocol: 'Tcp'
      //     sourcePortRange: '*'
      //     destinationPortRange: '22'
      //     sourceAddressPrefix: '*'
      //     destinationAddressPrefix: '*'
      //     access: 'Allow'
      //     direction: 'Inbound'
      //   }
      // }
      {
        name: 'AllowBastion2222'
        properties: {
          priority: 110
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '2222'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowReverseProxyHTTP'
        properties: {
          priority: 120
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
        name: 'AllowAppServerHTTP'
        properties: {
          priority: 130
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5000'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAppServerSSH'
        properties: {
          priority: 140
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowReverseProxySSH'
        properties: {
          priority: 150
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource asg 'Microsoft.Network/applicationSecurityGroups@2021-02-01' = {
  name: '${vnetName}-asg'
  location: resourceGroup().location
  properties: {}
}

output nsgId string = nsg.id
output asgId string = asg.id
