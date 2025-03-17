# Inlämningsuppgift 02 för Cloud Grund, Campus Mölndal, YH-utbildning.
av: Fredrik
datum: 2022-03-06

## Uppgiftsbeskrivning
Uppgiften ... skyddar oss mot hot, speciellt från hackergruppen 'Cloud Just Means Rain' som är på oss som flugor redan från start.

Jag beskriver nedan flödet för att sätta upp denna lösningen med Bicep. Bicep har något väldigt bra som inte bash har och det är idempotens, så vi kan köra deployments flera gånger utan problem.

## Uppgifter:
Github Repo:
IP Adress för lösningsförslaget:
SSH sträng för att komma in i Bastion Host: `ssh `
SSH sträng för att komma in i Reverse Proxy: `ssh `
SSH sträng för att komma in i App Server: `ssh `

## Att göra:

1. Skapa Bicep-filer för infrastrukturen
2. Deploya infrastrukturen
3. Konfigurera VMs med cloud-init
4. Sätta upp GitHub Actions för CI/CD
5. Skapa och köra applikationen

## 1. Resource Group och Bicep-filer

Först skapar vi en resursgrupp där vi ska deploya vår lösning:

```bash
# Skapa resursgrupp
az group create --name RGCloFreSvaUpg02 --location northeurope
```

Sedan behöver vi skapa vår Bicep-filstruktur. Vi kommer att organisera våra Bicep-filer enligt följande:

```
/
├── main.bicep             # Huvudfil som orkestrerar alla resurser
├── modules/
│   ├── network.bicep      # Nätverk, subnät, NSG, etc.
│   ├── storage.bicep      # Blob Storage
│   ├── database.bicep     # CosmosDB
│   └── compute.bicep      # Virtuella maskiner
├── configs/
│   ├── cloud-init-bastion.yaml
│   ├── cloud-init-reverseproxy.yaml
│   └── cloud-init-appserver.yaml
└── deploy.sh              # Deployment-skript
```

### main.bicep

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
  }
}

module databaseModule 'modules/database.bicep' = {
  name: 'databaseDeployment'
  params: {
    location: location
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
    blobConnectionString: storageModule.outputs.blobConnectionString
    cosmosDbConnectionString: databaseModule.outputs.cosmosDbConnectionString
  }
}

// Outputs
output bastionPublicIp string = computeModule.outputs.bastionPublicIp
output reverseProxyPublicIp string = computeModule.outputs.reverseProxyPublicIp
output appServerPrivateIp string = computeModule.outputs.appServerPrivateIp
output reverseProxyPrivateIp string = computeModule.outputs.reverseProxyPrivateIp
```

## 2. Network

Här skapar vi modulen för nätverk och säkerhet:

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

## 3. Sätt upp Blob Storage med Bicep

```bicep
// modules/storage.bicep
@description('Plats för Blob Storage')
param location string

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
      virtualNetworkRules: []
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

// Hämta connection string
var storageAccountKey = storageAccount.listKeys().keys[0].value
var blobConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net'

// Output
output blobConnectionString string = blobConnectionString
output storageAccountId string = storageAccount.id
```

## 4. Sätt upp Azure Cosmos DB med Bicep

```bicep
// modules/database.bicep
@description('Plats för Cosmos DB')
param location string

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
resource mongoDbDatabase 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2022-05-15' = {
  name: '${cosmosDbAccount.name}/CloFreSvaUpg02DB'
  properties: {
    resource: {
      id: 'CloFreSvaUpg02DB'
    }
  }
}

// Collection
resource mongoDbCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2022-05-15' = {
  name: '${mongoDbDatabase.name}/CloFreSvaUpg02Collection'
  properties: {
    resource: {
      id: 'CloFreSvaUpg02Collection'
      shardKey: {
        id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
      ]
    }
  }
}

// Output
output cosmosDbConnectionString string = 'mongodb://${cosmosDbAccount.name}:${listKeys(cosmosDbAccount.id, cosmosDbAccount.apiVersion).primaryMasterKey}@${cosmosDbAccount.name}.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@${cosmosDbAccount.name}@'
output cosmosDb