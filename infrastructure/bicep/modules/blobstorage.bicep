param location string
param projectName string

// Create a unique storage account name by removing hyphens and using lowercase
var storageAccountName = replace(toLower('${projectName}storage'), '-', '')

// Create a storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // You might want to set this to 'Deny' for better security and explicitly allow specific networks
    }
  }
}

// Create a blob service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Create a container
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  parent: blobService
  name: 'appdata'
  properties: {
    publicAccess: 'None'
  }
}

// Outputs
output storageAccountName string = storageAccount.name
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
