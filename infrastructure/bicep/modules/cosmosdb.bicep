param projectName string
param location string = resourceGroup().location
param databaseName string = 'myDatabase'
param collectionName string = 'myCollection'

// Generera ett unikt namn för Cosmos DB-kontot (måste vara globalt unikt)
// Använder ett beständigt mönster som inte ändras mellan deployments
var cosmosDbAccountName = '${toLower(replace(projectName, '-', ''))}mongo${uniqueString(resourceGroup().id, projectName)}'

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
      serverVersion: '4.2' // MongoDB server version
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
    options: {}
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
    options: {} // Tom options för att göra deployments idempotenta
  }
}

// Outputs för anslutningsinformation
output cosmosDbAccountName string = cosmosDbAccount.name
output cosmosDbDatabaseName string = mongoDatabase.name
output cosmosDbCollectionName string = mongoCollection.name

// Säker output för connection strings
#disable-next-line outputs-should-not-contain-secrets use-resource-symbol-reference
output mongoDbConnectionString string = 'mongodb://${cosmosDbAccount.name}:${listKeys(cosmosDbAccount.id, cosmosDbAccount.apiVersion).primaryMasterKey}@${cosmosDbAccount.name}.mongo.cosmos.azure.com:10255/${databaseName}?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@${cosmosDbAccount.name}@'

#disable-next-line outputs-should-not-contain-secrets use-resource-symbol-reference
output dotNetMongoConnectionString string = 'mongodb://${cosmosDbAccount.name}:${listKeys(cosmosDbAccount.id, cosmosDbAccount.apiVersion).primaryMasterKey}@${cosmosDbAccount.name}.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@${cosmosDbAccount.name}@'

// Output som gör det möjligt att referera till dessa resurser från andra Bicep-moduler
output cosmosDbAccountId string = cosmosDbAccount.id
output mongoDbDatabaseId string = mongoDatabase.id
output mongoDbCollectionId string = mongoCollection.id
