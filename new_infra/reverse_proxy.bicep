param location string = resourceGroup().location
param reverseProxyName string = 'ReverseProxyVM'
param vnetName string = 'NordicVNet'
param proxySubnetName string = 'ReverseProxySubnet'
param adminUsername string = 'azureuser'
param sshPublicKey string
param privateIpAddress string = '10.0.1.10'
param appServerIp string
param appServerPort string = '5000'

// Create a static public IP for the Reverse Proxy
resource reverseProxyIP 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: 'ReverseProxyIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Create a network interface for the Reverse Proxy VM
resource reverseProxyNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${reverseProxyName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, proxySubnetName)
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIpAddress
          publicIPAddress: {
            id: reverseProxyIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: resourceId('Microsoft.Network/networkSecurityGroups', 'NSG-ReverseProxy')
    }
  }
}

// Prepare cloud-init data with the app server IP inserted
var cloudInitTemplate = loadTextContent('../cloud_init_templates/reverse_proxy.yaml')
var cloudInitData = replace(replace(cloudInitTemplate, '${app_server_ip}', appServerIp), '${app_server_port}', appServerPort)

// Create the Reverse Proxy VM
resource reverseProxyVM 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: reverseProxyName
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
      computerName: reverseProxyName
      adminUsername: adminUsername
      customData: base64(cloudInitData)
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
          id: reverseProxyNic.id
        }
      ]
    }
  }
}

output reverseProxyPublicIp string = reverseProxyIP.properties.ipAddress
output reverseProxyPrivateIp string = privateIpAddress
