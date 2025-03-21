param projectName string
param location string = resourceGroup().location
param databaseName string = 'cloudsoft'
param collectionName string = 'subscribers'

// Generate a unique Cosmos DB account name
var cosmosDbAccountName = '${toLower(replace(projectName, '-', ''))}mongo${uniqueString(resourceGroup().id, projectName)}'

// Create a Cosmos DB account if it doesn't already exist.
resource existingCosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' existing = {
  name: cosmosDbAccountName
  scope: resourceGroup()
}

// Create a Cosmos DB account
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
    publicNetworkAccess: 'Enabled'
  }
}

// Wait for Cosmos DB account to be fully provisioned
module waitForAccount 'deploymentScripts.bicep' = {
  name: 'waitForAccount-${uniqueString(deployment().name)}'
  params: {
    location: location
    resourceName: cosmosDbAccountName
    delay: 15 // wait 15 seconds for account to stabilize
  }
  dependsOn: [
    cosmosDbAccount
  ]
}

// Create a database in the Cosmos DB account
resource mongoDatabase 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2022-05-15' = {
  parent: cosmosDbAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
    options: {}
  }
  dependsOn: [
    waitForAccount
  ]
}

// Wait for database to be fully provisioned
module waitForDatabase 'deploymentScripts.bicep' = {
  name: 'waitForDatabase-${uniqueString(deployment().name)}'
  params: {
    location: location
    resourceName: '${cosmosDbAccountName}-${databaseName}'
    delay: 10 // wait 10 seconds for database to stabilize
  }
  dependsOn: [
    mongoDatabase
  ]
}

// Create a collection in the database
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
            keys: ['email']
          }
        }
      ]
    }
    options: {}
  }
  dependsOn: [
    waitForDatabase
  ]
}

// Output the names of the Cosmos DB account, database, and collection
output cosmosDbAccountName string = cosmosDbAccount.name
output cosmosDbDatabaseName string = mongoDatabase.name
output cosmosDbCollectionName string = mongoCollection.name

// Secret output that contains the connection string for the MongoDB API
#disable-next-line outputs-should-not-contain-secrets
output dotNetMongoConnectionString string = cosmosDbAccount.listConnectionStrings().connectionStrings[0].connectionString

// Output the IDs of the Cosmos DB account, database, and collection
output cosmosDbAccountId string = cosmosDbAccount.id
output mongoDbDatabaseId string = mongoDatabase.id
output mongoDbCollectionId string = mongoCollection.id
