param cosmosDbName string
param location string = resourceGroup().location

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' = {
  name: cosmosDbName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

output cosmosDbEndpoint string = cosmosDb.properties.documentEndpoint
output cosmosDbPrimaryKey string = listKeys(cosmosDb.id, '2021-03-15').primaryMasterKey