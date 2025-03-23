param projectName string
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure() // Secure the SSH public key
param sshPublicKey string

// Nätverkskonfiguration - definiera allt centralt
param vnetAddressPrefix string = '10.0.0.0/16'
param bastionSubnetPrefix string = '10.0.1.0/24'
param appServerSubnetPrefix string = '10.0.2.0/24'
param reverseProxySubnetPrefix string = '10.0.3.0/24'

// Network Module
module networkModule './modules/network.bicep' = {
  name: 'networkDeployment'
  params: {
    location: location
    projectName: projectName
    vnetName: '${projectName}-vnet'
    vnetAddressPrefix: vnetAddressPrefix
    bastionSubnetPrefix: bastionSubnetPrefix
    appServerSubnetPrefix: appServerSubnetPrefix
    reverseProxySubnetPrefix: reverseProxySubnetPrefix
  }
}

// Bastion host module
module bastionHost './modules/bastion.bicep' = {
  name: 'bastionHostDeployment'
  params: {
    location: location
    bastionName: '${projectName}-bastion'
    subnetId: networkModule.outputs.bastionSubnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
  }
}

// App Server Module
module appServer './modules/app-server.bicep' = {
  name: 'appServerDeployment'
  params: {
    location: location
    appServerName: '${projectName}-appserver'
    subnetId: networkModule.outputs.appServerSubnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    asgId: networkModule.outputs.internalAsgSsh
  }
}

// Reverse Proxy Module
module reverseProxy './modules/reverse-proxy.bicep' = {
  name: 'reverseProxyDeployment'
  params: {
    location: location
    appServerName: '${projectName}-reverse-proxy'
    subnetId: networkModule.outputs.reverseProxySubnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    asgId: networkModule.outputs.internalAsgSsh
  }
}

// Cosmos DB Module
module cosmosDb 'modules/cosmosdb.bicep' = {
  name: 'cosmosDbDeploy'
  params: {
    projectName: projectName
    location: location
    databaseName: 'myAppDb'
    collectionName: 'items'
  }
}

// Blob Storage Module
module storageModule './modules/blobstorage.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    projectName: projectName
  }
}

// Outputs

// Bastion Host Public IP
output bastionHostIp string = bastionHost.outputs.publicIpAddress

// App Server Public IP
output reverseProxyIp string = reverseProxy.outputs.publicIpAddress

// App Server Private IP
output appServerPrivateIp string = appServer.outputs.privateIp

// Reverse Proxy Private IP
output reverseProxyPrivateIp string = reverseProxy.outputs.privateIp

// MongoDB Connection String
output mongoDbConnectionString string = cosmosDb.outputs.dotNetMongoConnectionString

// Cosmos DB Account Name
output storageAccountName string = storageModule.outputs.storageAccountName

// Blob Storage Connection String
output blobEndpoint string = storageModule.outputs.blobEndpoint
