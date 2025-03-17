@description('Location for all resources')
param location string = resourceGroup().location

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('SSH public key for VM access')
@secure()
param sshPublicKey string

@description('Storage account name')
param storageAccountName string = 'clofresvaupg02'

@description('CosmosDB account name')
param cosmosDbName string = 'CloFreSvaUpg02'

// Deploy networking resources (VNet, subnets, NSGs, etc)
module networking './bicep/networking.bicep' = {
  name: 'networkingDeployment'
  params: {
    location: location
  }
}

// Deploy storage account
module storage './bicep/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
  dependsOn: [
    networking
  ]
}

// Deploy CosmosDB
module cosmosDb './bicep/cosmos.bicep' = {
  name: 'cosmosDbDeployment'
  params: {
    location: location
    cosmosDbName: cosmosDbName
  }
  dependsOn: [
    networking
  ]
}

// Deploy Bastion Host
module bastion './bicep/bastion.bicep' = {
  name: 'bastionDeployment'
  params: {
    location: location
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
  }
  dependsOn: [
    networking
  ]
}

// Deploy Application Server
module appServer './bicep/app-server.bicep' = {
  name: 'appServerDeployment'
  params: {
    location: location
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    storageAccountName: storageAccountName
    cosmosDbName: cosmosDbName
  }
  dependsOn: [
    networking
    storage
    cosmosDb
  ]
}

// Deploy Reverse Proxy
module reverseProxy './bicep/reverse-proxy.bicep' = {
  name: 'reverseProxyDeployment'
  params: {
    location: location
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    appServerIp: appServer.outputs.appServerPrivateIp
  }
  dependsOn: [
    networking
    appServer
  ]
}

// Output important information
output bastionHostPublicIp string = bastion.outputs.bastionPublicIp
output reverseProxyPublicIp string = reverseProxy.outputs.reverseProxyPublicIp
output connectionStrings object = {
  ssh: {
    bastionHost: 'ssh ${adminUsername}@${bastion.outputs.bastionPublicIp} -p 2222'
    reverseProxy: 'ssh -J ${adminUsername}@${bastion.outputs.bastionPublicIp}:2222 ${adminUsername}@${reverseProxy.outputs.reverseProxyPrivateIp}'
    appServer: 'ssh -J ${adminUsername}@${bastion.outputs.bastionPublicIp}:2222 ${adminUsername}@${appServer.outputs.appServerPrivateIp}'
  }
  webApplication: 'http://${reverseProxy.outputs.reverseProxyPublicIp}'
}
