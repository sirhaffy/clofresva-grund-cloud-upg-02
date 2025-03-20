param projectName string
param location string = resourceGroup().location
param databaseName string = 'myDatabase'
param collectionName string = 'myCollection'

// Generera ett unikt namn för Cosmos DB-kontot (måste vara globalt unikt)
var cosmosDbAccountName = '${toLower(replace(projectName, '-', ''))}mongo${uniqueString(resourceGroup().id)}'

// Skapa ett Cosmos DB-konto med MongoDB API
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'MongoDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    capabilities: [
      {
        name: 'EnableMongo'
      }
      {
        name: 'EnableServerless'
      }
    ]
    apiProperties: {
      serverVersion: '4.2'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
  }
}

// Skapa en MongoDB-databas
resource mongoDatabase 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2022-05-15' = {
  parent: cosmosDbAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

// Skapa en collection i databasen (motsvarar en tabell)
resource mongoCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2022-05-15' = {
  parent: mongoDatabase
  name: collectionName
  properties: {
    resource: {
      id: collectionName
      shardKey: {
        _id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: ['_id']
          }
        }
        {
          key: {
            keys: ['name']
          }
        }
      ]
    }
  }
}

// Outputs för anslutningsinformation
output cosmosDbAccountName string = cosmosDbAccount.name
output cosmosDbDatabaseName string = mongoDatabase.name
output cosmosDbCollectionName string = mongoCollection.name

// Connection string för MongoDB-anslutning (standard format)
output mongoDbConnectionString string = 'mongodb://${cosmosDbAccount.name}:${listKeys(cosmosDbAccount.id, cosmosDbAccount.apiVersion).primaryMasterKey}@${cosmosDbAccount.name}.mongo.cosmos.azure.com:10255/${databaseName}?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@${cosmosDbAccount.name}@'

// Connection string för .NET Core app (använder C# MongoDB-driver)
output dotNetMongoConnectionString string = 'mongodb://${cosmosDbAccount.name}:${listKeys(cosmosDbAccount.id, cosmosDbAccount.apiVersion).primaryMasterKey}@${cosmosDbAccount.name}.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@${cosmosDbAccount.name}@'
