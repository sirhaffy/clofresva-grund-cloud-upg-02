param location string
param resourceGroupName string
param vnetId string
param databaseSubnetId string

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: 'CloFreSvaUpg02'
  location: location
  kind: 'MongoDB'
  properties: {
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
    enableMultipleWriteLocations: true
    networkAclBypass: 'AzureServices'
    virtualNetworkRules: [
      {
        id: databaseSubnetId
        ignoreMissingVNetServiceEndpoint: false
      }
    ]
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2022-05-15' = {
  parent: cosmosDbAccount
  name: 'CloFreSvaUpg02DB'
  properties: {
    resource: {
      id: 'CloFreSvaUpg02DB'
    }
  }
}

resource collection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2022-05-15' = {
  parent: database
  name: 'CloFreSvaUpg02Collection'
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

output cosmosDbId string = cosmosDbAccount.id
output cosmosDbName string = cosmosDbAccount.name
output connectionString string = listConnectionStrings(cosmosDbAccount.id, cosmosDbAccount.apiVersion).connectionStrings[0].connectionString
