param location string = resourceGroup().location
param appServerName string = 'AppServerVM'
param vnetName string = 'NordicVNet'
param appSubnetName string = 'AppServerSubnet'
param adminUsername string = 'azureuser'
param sshPublicKey string
param privateIpAddress string = '10.0.2.10'
param storageAccountName string = 'clofresvaupg02'
param cosmosDbName string = 'CloFreSvaUpg02'

// Create a network interface for the App Server VM
resource appServerNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${appServerName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, appSubnetName)
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIpAddress
        }
      }
    ]
    networkSecurityGroup: {
      id: resourceId('Microsoft.Network/networkSecurityGroups', 'NSG-AppSrv')
    }
  }
}

// Get storage account connection string
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}

// Get CosmosDB connection string
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: cosmosDbName
}

// Prepare cloud-init data with the connection strings inserted
var cloudInitTemplate = loadTextContent('../cloud_init_templates/app_server.yaml')
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'

resource cosmosDbListConnectionStrings 'Microsoft.DocumentDB/databaseAccounts/listConnectionStrings@2023-04-15' = {
  name: 'listConnectionStrings'
  parent: cosmosDbAccount
}

var cosmosDbConnectionString = cosmosDbListConnectionStrings.connectionStrings[1].connectionString
var cloudInitData = replace(replace(cloudInitTemplate, '${storage_connection_string}', storageConnectionString), '${cosmos_connection_string}', cosmosDbConnectionString)

// Create the App Server VM
resource appServerVM 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: appServerName
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
      computerName: appServerName
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
          id: appServerNic.id
        }
      ]
    }
  }
}

output appServerPrivateIp string = privateIpAddress
