param location string
param projectName string
param vnetName string = '${projectName}-vnet'

// Nätverkskonfiguration
param vnetAddressPrefix string
param bastionSubnetPrefix string
param appServerSubnetPrefix string
param reverseProxySubnetPrefix string

// ASG (Application Security Group)
resource internalAsgSsh 'Microsoft.Network/applicationSecurityGroups@2021-02-01' = {
  name: '${projectName}-asg-internal-ssh'
  location: location
}

// NSG Internal SSH
resource sshNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${projectName}-nsg-ssh'
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
          sourceAddressPrefix: bastionSubnetPrefix // Only allow SSH from the bastion subnet.
          destinationApplicationSecurityGroups: [
            {
              id: internalAsgSsh.id
            }
          ]
        }
      }
    ]
  }
}

// Bastion Subnet NSG
resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${projectName}-bastion-nsg'
  location: location
  properties: {
    securityRules: [
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
resource appServerNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${projectName}-appserver-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAppPortFromReverseProxy'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5000'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Reverse Proxy Subnet NSG
resource reverseProxyNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${projectName}-proxy-nsg'
  location: location
  properties: {
    securityRules: [
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
            id: bastionNsg.id // Connects the NSG to the bastion subnet.
          }
        }
      }
      {
        name: 'AppServerSubnet'
        properties: {
          addressPrefix: appServerSubnetPrefix
          networkSecurityGroup: {
            id: appServerNsg.id // Connects the NSG to the app server subnet.
          }
        }
      }
      {
        name: 'ReverseProxySubnet'
        properties: {
          addressPrefix: reverseProxySubnetPrefix
          networkSecurityGroup: {
            id: reverseProxyNsg.id // Connects the NSG to the reverse proxy subnet.
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
output internalAsgSsh string = internalAsgSsh.id
