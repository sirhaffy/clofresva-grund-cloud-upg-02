# Inlämningsuppgift 02 för Cloud Grund, Campus Mölndal, YH-utbildning.
av: Fredrik
datum: 2022-03-06

## Uppgiftsbeskrivning
Uppgiften ... skyddar oss mot hot, speciellt från hackergruppen 'Cloud Just Means Rain' som är på oss som flugor redan från start.

Jag beskriver nedan flödet för att sätta upp denna lösningen med Bicep. Bicep har något väldigt bra som inte bash har och det är idempotens, så vi kan köra deployments flera gånger utan problem.

## Uppgifter:
Github Repo:
IP Adress för lösningsförslaget:
SSH sträng för att komma in i Bastion Host: `ssh azureuser@<bastionPublicIP> -p 2222 -i ~/.ssh/azure_key`
SSH sträng för att komma in i Reverse Proxy: `ssh -J azureuser@<bastionPublicIP>:2222 azureuser@10.0.1.10 -i ~/.ssh/azure_key`
SSH sträng för att komma in i App Server: `ssh -J azureuser@<bastionPublicIP>:2222 azureuser@10.0.2.10 -i ~/.ssh/azure_key`

## Filstruktur

För den här lösningen använder vi en strukturerad approach med separata filer:

```
/
├── main.bicep                       # Huvudfil som orkestrerar alla resurser
├── modules/
│   ├── network.bicep                # Nätverk, subnät, NSG, etc.
│   ├── storage.bicep                # Blob Storage
│   ├── database.bicep               # CosmosDB
│   └── compute.bicep                # Virtuella maskiner
├── configs/
│   ├── cloud-init-bastion.yaml      # Cloud-init för Bastion Host
│   ├── cloud-init-reverseproxy.yaml # Cloud-init för Reverse Proxy
│   └── cloud-init-appserver.yaml    # Cloud-init för App Server
├── .github/
│   └── workflows/
│       └── deploy.yml               # GitHub Actions workflow
├── src/                             # Källkod för .NET-applikationen
└── deploy.sh                        # Deployment-skript
```

## Steg-för-steg guide

### 1. Resource Group

Först skapar vi en resursgrupp där vi ska deploya vår lösning:

```bash
# Skapa resursgrupp
az group create --name RGCloFreSvaUpg02 --location northeurope
```

### 2. Skapa Bicep-filer

#### main.bicep
```bicep
// main.bicep
@description('Plats för alla resurser')
param location string = resourceGroup().location

@description('SSH public key för VM-autentisering')
@secure()
param sshPublicKey string

@description('Admin användarnamn för VMs')
param adminUsername string = 'azureuser'

// Moduler
module networkModule 'modules/network.bicep' = {
  name: 'networkDeployment'
  params: {
    location: location
  }
}

module storageModule 'modules/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    vnetId: networkModule.outputs.virtualNetworkId
    storageSubnetId: networkModule.outputs.storageSubnetId
  }
}

module databaseModule 'modules/database.bicep' = {
  name: 'databaseDeployment'
  params: {
    location: location
    vnetId: networkModule.outputs.virtualNetworkId
    databaseSubnetId: networkModule.outputs.databaseSubnetId
  }
}

module computeModule 'modules/compute.bicep' = {
  name: 'computeDeployment'
  params: {
    location: location
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    virtualNetworkId: networkModule.outputs.virtualNetworkId
    bastionSubnetId: networkModule.outputs.bastionSubnetId
    reverseProxySubnetId: networkModule.outputs.reverseProxySubnetId
    appServerSubnetId: networkModule.outputs.appServerSubnetId
    storageAccountName: storageModule.outputs.storageAccountName
    cosmosDbAccountName: databaseModule.outputs.cosmosDbAccountName
  }
}

// Outputs
output bastionPublicIp string = computeModule.outputs.bastionPublicIp
output reverseProxyPublicIp string = computeModule.outputs.reverseProxyPublicIp
output appServerPrivateIp string = computeModule.outputs.appServerPrivateIp
output reverseProxyPrivateIp string = computeModule.outputs.reverseProxyPrivateIp
output storageAccountName string = storageModule.outputs.storageAccountName
output cosmosDbAccountName string = databaseModule.outputs.cosmosDbAccountName
```

#### modules/network.bicep
```bicep
// modules/network.bicep
@description('Plats för alla nätverksresurser')
param location string

// Resurser
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'NordicVNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

// NSG för Storage
resource storageNsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'NSG-Storage'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-All'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AppServerSubnet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
          description: 'Allow HTTPS'
        }
      }
    ]
  }
}

// NSG for Cosmos DB
resource cosmosDbNsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'NSG-CosmosDB'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-All'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AppServerSubnet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
          description: 'Allow HTTPS'
        }
      }
    ]
  }
}

// NSG för Reverse Proxy
resource reverseProxyNsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'NSG-ReverseProxy'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-All'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
          description: 'Allow HTTP/S'
        }
      }
    ]
  }
}

// NSG för App Server
resource appServerNsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'NSG-AppSrv'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-All'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5000'
          sourceAddressPrefix: 'ReverseProxySubnet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
          description: 'Allow HTTP'
        }
      }
    ]
  }
}

// NSG för Bastion Host
resource bastionHostNsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'NSG-BastionHost'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-All'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '2222'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
          description: 'Allow SSH'
        }
      }
    ]
  }
}

// NSG för Internal Access
resource internalAccessNsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'NSG-InternalAccess'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-All'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'BastionHostSubnet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
          description: 'Allow SSH'
        }
      }
    ]
  }
}

// Subnät
resource storageSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  parent: virtualNetwork
  name: 'StorageSubnet'
  properties: {
    addressPrefix: '10.0.4.0/24'
    networkSecurityGroup: {
      id: storageNsg.id
    }
  }
}

resource databaseSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  parent: virtualNetwork
  name: 'DatabaseSubnet'
  properties: {
    addressPrefix: '10.0.5.0/24'
    networkSecurityGroup: {
      id: cosmosDbNsg.id
    }
  }
  dependsOn: [
    storageSubnet
  ]
}

resource reverseProxySubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  parent: virtualNetwork
  name: 'ReverseProxySubnet'
  properties: {
    addressPrefix: '10.0.1.0/24'
    networkSecurityGroup: {
      id: reverseProxyNsg.id
    }
  }
  dependsOn: [
    databaseSubnet
  ]
}

resource appServerSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  parent: virtualNetwork
  name: 'AppServerSubnet'
  properties: {
    addressPrefix: '10.0.2.0/24'
    networkSecurityGroup: {
      id: appServerNsg.id
    }
  }
  dependsOn: [
    reverseProxySubnet
  ]
}

resource bastionHostSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  parent: virtualNetwork
  name: 'BastionHostSubnet'
  properties: {
    addressPrefix: '10.0.3.0/24'
    networkSecurityGroup: {
      id: bastionHostNsg.id
    }
  }
  dependsOn: [
    appServerSubnet
  ]
}

// Outputs
output virtualNetworkId string = virtualNetwork.id
output bastionSubnetId string = bastionHostSubnet.id
output reverseProxySubnetId string = reverseProxySubnet.id
output appServerSubnetId string = appServerSubnet.id
output storageSubnetId string = storageSubnet.id
output databaseSubnetId string = databaseSubnet.id
```

#### modules/storage.bicep
```bicep
// modules/storage.bicep
@description('Plats för Blob Storage')
param location string

@description('VNet ID')
param vnetId string

@description('Storage Subnet ID')
param storageSubnetId string

// Blob Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'clofresvaupg02'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: storageSubnetId  
          action: 'Allow'
        }
      ]
      ipRules: []
    }
  }
}

// Container
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: '${storageAccount.name}/default/clofresvaupg02'
  properties: {
    publicAccess: 'None'
  }
}

// Private Endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'BlobStorageEndpoint'
  location: location
  properties: {
    subnet: {
      id: storageSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'BlobStorageConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

// Outputs
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
```

#### modules/database.bicep
```bicep
// modules/database.bicep
@description('Plats för Cosmos DB')
param location string

@description('VNet ID')
param vnetId string

@description('Database Subnet ID')
param databaseSubnetId string

// Cosmos DB Account
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: 'CloFreSvaUpg02'
  location: location
  properties: {
    enableFreeTier: false
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: 'North Europe'
        failoverPriority: 0
        isZoneRedundant: false
      }
      {
        locationName: 'West Europe'
        failoverPriority: 1
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableMongo'
      }
    ]
  }
}

// Mongo DB
resource mongoDbDatabase 'Microsoft.DocumentDB/databaseAccounts/mongodb