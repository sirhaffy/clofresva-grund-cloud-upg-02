@description('Base name to use for resources')
param projectName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Admin username for VMs')
param adminUsername string

@description('SSH public key for VMs')
@secure()
param sshPublicKey string

// Naming convention
var vnetName = '${projectName}-vnet'
var bastionName = '${projectName}-bastion'
var appServerName = '${projectName}-appserver'
var reverseProxyName = '${projectName}-proxy'

// Network setup
module network './modules/network.bicep' = {
  name: 'networkDeployment'
  params: {
    location: location
    projectName: projectName
  }
}

// Blob Storage
module blobStorage './modules/blobstorage.bicep' = {
  name: 'blobStorageDeployment'
  params: {
    projectName: projectName
    location: location
  }
}

// Bastion host
module bastionHost './modules/bastion.bicep' = {
  name: 'bastionDeployment'
  params: {
    location: location
    bastionName: bastionName
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'BastionSubnet')
  }
  dependsOn: [
    network
  ]
}

// App server
module appServer './modules/app-server.bicep' = {
  name: 'appServerDeployment'
  params: {
    appServerName: appServerName
    location: location
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AppServerSubnet')
  }
  dependsOn: [
    network
  ]
}

// Reverse proxy
module reverseProxy './modules/reverse-proxy.bicep' = {
  name: 'reverseProxyDeployment'
  params: {
    reverseProxyName: reverseProxyName
    location: location
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'ReverseProxySubnet')
  }
  dependsOn: [
    network
  ]
}

// Output important information
output bastionHostIp string = bastionHost.outputs.publicIp
output reverseProxyIp string = reverseProxy.outputs.publicIp
output appServerPrivateIp string = appServer.outputs.privateIp
output storageAccountName string = blobStorage.outputs.storageAccountName
output blobEndpoint string = blobStorage.outputs.blobEndpoint
