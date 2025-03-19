param location string
param projectName string
param vnetName string = '${projectName}-vnet'

// Nätverkskonfiguration
param vnetAddressPrefix string
param bastionSubnetPrefix string
param appServerSubnetPrefix string
param reverseProxySubnetPrefix string

// Application Security Groups
resource bastionASG 'Microsoft.Network/applicationSecurityGroups@2021-05-01' = {
  name: '${projectName}-bastion-asg'
  location: location
}

resource appServerASG 'Microsoft.Network/applicationSecurityGroups@2021-05-01' = {
  name: '${projectName}-appserver-asg'
  location: location
}

resource reverseProxyASG 'Microsoft.Network/applicationSecurityGroups@2021-05-01' = {
  name: '${projectName}-proxy-asg'
  location: location
}

// Bastion Subnet NSG
resource bastionNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${projectName}-bastion-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSHInbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowBastionPort'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '2222'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// App Server Subnet NSG
resource appServerNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${projectName}-appserver-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSHFromBastion'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceApplicationSecurityGroups: [
            {
              id: bastionASG.id
            }
          ]
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAppPortFromReverseProxy'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5000'
          sourceApplicationSecurityGroups: [
            {
              id: reverseProxyASG.id
            }
          ]
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Reverse Proxy Subnet NSG
resource reverseProxyNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${projectName}-proxy-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSHFromBastion'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceApplicationSecurityGroups: [
            {
              id: bastionASG.id
            }
          ]
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHTTPInbound'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Create the Virtual Network with subnets
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'BastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
          networkSecurityGroup: {
            id: bastionNSG.id
          }
        }
      }
      {
        name: 'AppServerSubnet'
        properties: {
          addressPrefix: appServerSubnetPrefix
          networkSecurityGroup: {
            id: appServerNSG.id
          }
        }
      }
      {
        name: 'ReverseProxySubnet'
        properties: {
          addressPrefix: reverseProxySubnetPrefix
          networkSecurityGroup: {
            id: reverseProxyNSG.id
          }
        }
      }
    ]
  }
}

// Output the IDs
output vnetName string = vnet.name
output vnetId string = vnet.id
output bastionSubnetId string = '${vnet.id}/subnets/BastionSubnet'
output appServerSubnetId string = '${vnet.id}/subnets/AppServerSubnet'
output reverseProxySubnetId string = '${vnet.id}/subnets/ReverseProxySubnet'
output bastionASGId string = bastionASG.id
output appServerASGId string = appServerASG.id
output reverseProxyASGId string = reverseProxyASG.id
