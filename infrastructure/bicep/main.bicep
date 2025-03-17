@description('Location for all resources')
param location string = resourceGroup().location
param resourceGroupName string
param adminEmail string // kept for future use
param adminUsername string = 'azureuser'
param sshPublicKey string
param appServerIp string
param appServerPort string
param reverseProxyIp string
param githubOrg string
param githubRepoName string
param githubToken string
param appName string
param bastionConfigHash string = ''
param reverseProxyConfigHash string = ''
param appServerConfigHash string = ''

// Read cloud-init files - adjust paths as needed
var bastionCloudInit = loadFileAsBase64('../cloud-init/bastion.yaml')
var reverseProxyCloudInit = loadFileAsBase64('../cloud-init/reverse-proxy.yaml')
var appServerCloudInit = loadFileAsBase64('../cloud-init/app-server.yaml')

// Deploy network resources (VNet, subnets, NSGs, etc)
module networking 'networking.bicep' = {
  name: 'networkDeployment'
  params: {
    location: location
    resourceGroupName: resourceGroupName
  }
}

// Deploy storage account
module storage 'storage.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    vnetId: networking.outputs.vnetId
    storageSubnetId: networking.outputs.storageSubnetId
  }
}

// Deploy Cosmos DB
module cosmos 'cosmos.bicep' = {
  name: 'cosmosDeployment'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    vnetId: networking.outputs.vnetId
    databaseSubnetId: networking.outputs.databaseSubnetId
  }
}

// Deploy Bastion Host VM
module bastion 'bastion.bicep' = {
  name: 'bastionDeployment'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    subnetId: networking.outputs.bastionSubnetId
    customData: bastionCloudInit
    configHash: bastionConfigHash
    githubOrg: githubOrg
    githubRepoName: githubRepoName
    githubToken: githubToken
    appServerPort: appServerPort
  }
}

// Deploy Reverse Proxy VM
module reverseProxy 'reverse-proxy.bicep' = {
  name: 'reverseProxyDeployment'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    subnetId: networking.outputs.reverseProxySubnetId
    customData: reverseProxyCloudInit
    privateIpAddress: reverseProxyIp
    appServerIp: appServerIp
    appServerPort: appServerPort
    configHash: reverseProxyConfigHash  // Add this line
  }
}

// Deploy App Server VM
module appServer 'app-server.bicep' = {
  name: 'appServerDeployment'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    subnetId: networking.outputs.appServerSubnetId
    customData: appServerCloudInit
    privateIpAddress: appServerIp
    appServerPort: appServerPort
    githubOrg: githubOrg
    githubRepoName: githubRepoName
    githubToken: githubToken
    appName: appName
    configHash: appServerConfigHash  // Add this line
  }
}

// Outputs for the deployment
output bastionHostIp string = bastion.outputs.publicIp
output reverseProxyIp string = reverseProxy.outputs.publicIp
output appServerIp string = appServer.outputs.privateIp

output connectionStrings object = {
  ssh: {
    // SSH to Bastion Host
    bastionHost: 'ssh ${adminUsername}@${bastion.outputs.publicIp} -p 2222'

    // SSH to Reverse Proxy via Bastion Host
    reverseProxy: 'ssh -J ${adminUsername}@${bastion.outputs.publicIp}:2222 ${adminUsername}@${reverseProxy.outputs.privateIp}'

    // SSH to App Server via Reverse Proxy
    appServer: 'ssh -J ${adminUsername}@${bastion.outputs.publicIp}:2222 ${adminUsername}@${appServer.outputs.privateIp}'
  }

  // Web application URL
  webApplication: 'http://${reverseProxy.outputs.publicIp}'
}
