param location string = resourceGroup().location
param appServerName string
param subnetId string
param adminUsername string
@secure()
param sshPublicKey string

@description('A timestamp to force update the extension')
param deploymentTime string = utcNow('yyyyMMddHHmmss')

// Create a Network Security Group for the app server
resource appNsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${appServerName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-Bastion'
        properties: {
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-App-From-ReverseProxy'
        properties: {
          priority: 110
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5000'
          sourceAddressPrefix: '10.0.3.0/24'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Github-Webhook'
        properties: {
          priority: 120
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Create the Network Interface for the app server
resource appNic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${appServerName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: appNsg.id
    }
  }
}

// Add data disk for GitHub Actions workspace
resource actionsDisk 'Microsoft.Compute/disks@2021-04-01' = {
  name: '${appServerName}-data-disk'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 50
  }
}

// Create the app server VM
resource appServerVM 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: appServerName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        diskSizeGB: 40
      }
      dataDisks: [
        {
          createOption: 'Attach'
          lun: 0
          managedDisk: {
            id: actionsDisk.id
          }
        }
      ]
    }
    osProfile: {
      computerName: appServerName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: appNic.id
        }
      ]
    }
  }
}

// Use a setup script with a timestamp in the name to make it idempotent
resource setupExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: appServerVM
  name: 'SetupScript${deploymentTime}'  // Add timestamp to make name unique each deployment
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {  // Using settings instead of protectedSettings for better error messages
      timestamp: deploymentTime  // Add timestamp to force update
      commandToExecute: 'bash -c "wget -O /tmp/setup.sh https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/demos/vm-custom-script-windows/scripts/empty.sh && chmod +x /tmp/setup.sh && /tmp/setup.sh"'
      fileUris: [
        'https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/demos/vm-custom-script-windows/scripts/empty.sh'
      ]
    }
    protectedSettings: {
      commandToExecute: '''#!/bin/bash
set -e
echo "Running setup script at $(date)" > /tmp/setup.log

# Check if setup was already completed
if [ -f "/tmp/setup_completed" ]; then
  echo "Setup was already completed. Skipping." >> /tmp/setup.log
  exit 0
fi

# Format and mount the data disk if not already mounted
if [ -e /dev/sdc ]; then
  echo "Data disk found at /dev/sdc" >> /tmp/setup.log

  if ! grep -q /dev/sdc /etc/fstab && ! grep -q /actions-runner /etc/fstab; then
    echo "Formatting disk" >> /tmp/setup.log
    parted /dev/sdc --script mklabel gpt mkpart primary ext4 0% 100%
    sleep 10
    mkfs.ext4 -F /dev/sdc1
    mkdir -p /actions-runner
    UUID=$(lsblk -no UUID /dev/sdc1)
    echo "UUID=$UUID /actions-runner ext4 defaults 0 2" >> /etc/fstab
    mount -a
    chown -R ${adminUsername}:${adminUsername} /actions-runner
  else
    echo "Disk already mounted" >> /tmp/setup.log
  fi
else
  echo "No data disk found at /dev/sdc" >> /tmp/setup.log
fi

# Install dependencies if not already installed
if ! command -v jq &> /dev/null; then
  echo "Installing dependencies" >> /tmp/setup.log
  apt-get update
  apt-get install -y curl jq build-essential libssl-dev libffi-dev python3 python3-venv python3-dev git unzip wget
else
  echo "Dependencies already installed" >> /tmp/setup.log
fi

# Install .NET SDK if not already installed
if ! command -v dotnet &> /dev/null; then
  echo "Installing .NET SDK" >> /tmp/setup.log
  wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  dpkg -i packages-microsoft-prod.deb
  apt-get update
  apt-get install -y dotnet-sdk-8.0
else
  echo ".NET SDK already installed" >> /tmp/setup.log
fi

# Mark setup as completed
touch /tmp/setup_completed
echo "Setup completed at $(date)" >> /tmp/setup.log
'''
    }
  }
}

// Outputs
output privateIp string = appNic.properties.ipConfigurations[0].properties.privateIPAddress
output vmId string = appServerVM.id
