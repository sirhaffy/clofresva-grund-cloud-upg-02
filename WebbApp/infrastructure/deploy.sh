#!/bin/bash

# Enable error handling
set -e
set -o pipefail

# Set variables
RESOURCE_GROUP="MVC_TestApp"
LOCATION="northeurope"
STORAGE_ACCOUNT="clofresvastorage12345"
CONTAINER_NAME="mycontainer"
ZIP_FILE="mvc_app.zip"
APP_FOLDER="MVC_TestApp"
VM_NAME="MVCTestAppVM"
SUBSCRIPTION_ID="831a771a-003a-4263-b2cf-fe3ef338dbca"
CLOUD_INIT_FILE="cloud-init.yaml"
LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"
SSH_KEY_PATH="$HOME/.ssh/azure_vm_key"

# Logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    local line_number=$1
    local error_message=$2
    log "Error on line $line_number: $error_message"
    exit 1
}

trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# Check for required tools
if ! command -v zip &> /dev/null; then
    log "Installing zip package..."
    sudo apt-get update && sudo apt-get install -y zip
fi

# Find the MVC_TestApp directory
log "Looking for application directory..."
CURRENT_DIR=$(pwd)
PARENT_DIR=$(dirname "$CURRENT_DIR")
BASE_DIR=$(basename "$PARENT_DIR")

if [ "$BASE_DIR" = "$APP_FOLDER" ]; then
    APP_PATH="$PARENT_DIR"
    log "Found application in parent directory: $APP_PATH"
else
    log "ERROR: Current directory structure is incorrect."
    log "Expected to be in $APP_FOLDER/infrastructure"
    log "Current path: $CURRENT_DIR"
    log "Parent directory: $PARENT_DIR"
    exit 1
fi

# Build the .NET application
log "Building .NET application..."
log "Using application path: $APP_PATH"
cd "$APP_PATH"
dotnet publish -c Release
BUILD_RESULT=$?
if [ $BUILD_RESULT -ne 0 ]; then
    log "ERROR: Build failed with exit code $BUILD_RESULT"
    exit 1
fi
ORIGINAL_DIR=$(pwd)
cd - > /dev/null # Return to original directory

# Verify the published output
PUBLISH_DIR="$APP_PATH/bin/Release/net9.0/publish"
if [ ! -d "$PUBLISH_DIR" ]; then
    log "ERROR: Published directory not found at $PUBLISH_DIR"
    exit 1
fi

# List the contents of publish directory for verification
log "Published application contents:"
ls -la "$PUBLISH_DIR"

# Verify the DLL exists
if [ ! -f "$PUBLISH_DIR/MVC_TestApp.dll" ]; then
    log "ERROR: MVC_TestApp.dll not found in publish directory"
    exit 1
fi

# Create ZIP file first
log "Creating application package..."
log "Zipping application from: $PUBLISH_DIR"
cd "$PUBLISH_DIR"
if ! zip -r "$CURRENT_DIR/$ZIP_FILE" ./*; then
    log "ERROR: Failed to create ZIP file"
    exit 1
fi

# Verify ZIP file
if [ ! -f "$CURRENT_DIR/$ZIP_FILE" ]; then
    log "ERROR: ZIP file was not created"
    exit 1
fi

if [ ! -s "$CURRENT_DIR/$ZIP_FILE" ]; then
    log "ERROR: ZIP file is empty"
    exit 1
fi

log "ZIP file created successfully:"
ls -lh "$CURRENT_DIR/$ZIP_FILE"
cd "$CURRENT_DIR"

# Delete existing VM and its resources if they exist
log "Checking for existing VM resources..."
if az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &>/dev/null; then
    log "Existing VM found. Deleting VM and associated resources..."

    # Get a list of all disks associated with the VM
    DISK_IDS=$(az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME" --query "storageProfile.[osDisk.managedDisk.id, dataDisks[].managedDisk.id]" -o tsv)

    # Delete the VM and wait for completion
    log "Deleting VM..."
    az vm delete --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --yes

    # Delete all associated disks and wait for each deletion
    if [ ! -z "$DISK_IDS" ]; then
        log "Deleting associated disks..."
        for DISK_ID in $DISK_IDS; do
            log "Deleting disk: $DISK_ID"
            az disk delete --ids "$DISK_ID" --yes

            # Wait until disk is completely deleted
            while az disk show --ids "$DISK_ID" &>/dev/null; do
                log "Waiting for disk deletion to complete..."
                sleep 10
            done
            log "Disk deleted successfully: $DISK_ID"
        done
    fi

    # Double check that all VM-related resources are gone
    log "Verifying all VM resources are deleted..."
    REMAINING_DISKS=$(az disk list -g "$RESOURCE_GROUP" --query "[?contains(name, '$VM_NAME')].id" -o tsv)
    if [ ! -z "$REMAINING_DISKS" ]; then
        log "Cleaning up remaining disks..."
        for DISK_ID in $REMAINING_DISKS; do
            log "Deleting remaining disk: $DISK_ID"
            az disk delete --ids "$DISK_ID" --yes
            while az disk show --ids "$DISK_ID" &>/dev/null; do
                log "Waiting for disk deletion to complete..."
                sleep 10
            done
        done
    fi

    log "All VM resources deleted successfully"
fi

# Create resource group if it doesn't exist
log "Creating/checking resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# Set subscription
log "Setting subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

# Generate SSH key if it doesn't exist
if [ ! -f "$SSH_KEY_PATH" ]; then
    log "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
fi

# Deploy the VM
log "Deploying VM with cloud-init configuration..."
az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --image Ubuntu2404 \
    --admin-username azureuser \
    --ssh-key-value "$SSH_KEY_PATH.pub" \
    --custom-data "$CLOUD_INIT_FILE"

# Get VM's public IP
VM_IP=$(az vm show -d -g "$RESOURCE_GROUP" -n "$VM_NAME" --query publicIps -o tsv)
log "VM Public IP: $VM_IP"

# Wait for VM to be ready
log "Waiting for VM to be ready..."
while ! nc -z "$VM_IP" 22 2>/dev/null; do
    log "Waiting for SSH port to be available..."
    sleep 10
done

# Create SSH connection string
SSH_CONNECT="ssh -i $SSH_KEY_PATH azureuser@$VM_IP"
log "SSH Connection string: $SSH_CONNECT"

# Upload ZIP file to Azure VM
log "Uploading application package..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY_PATH" "$ZIP_FILE" "azureuser@$VM_IP:/tmp"

# Verify upload
log "Verifying uploaded file..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY_PATH" "azureuser@$VM_IP" "ls -lh /tmp/$ZIP_FILE"

# wait for 2 minutes
log "Waiting for 2 minutes..."
sleep 120

# Run setup script
log "Running setup script..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY_PATH" "azureuser@$VM_IP" "sudo /tmp/setup.sh"


# Add service status checks
log "Checking service statuses..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY_PATH" "azureuser@$VM_IP" "
    echo 'Checking nginx status...'
    sudo systemctl status nginx
    echo 'Checking application service status...'
    sudo systemctl status mywebapp
    echo 'Checking nginx configuration...'
    sudo nginx -t
    echo 'Checking application logs...'
    sudo journalctl -u mywebapp --no-pager -n 50
"

# Open port 80 for web traffic
log "Opening HTTP port..."
az vm open-port --port 80 --resource-group "$RESOURCE_GROUP" --name "$VM_NAME"

# Health check function
check_health() {
    local retries=30
    local wait_seconds=10
    local count=0
    log "Performing health check..."

    while [ $count -lt $retries ]; do
        if curl -s -f "http://$VM_IP" >/dev/null; then
            log "Application is running successfully!"
            return 0
        fi
        count=$((count + 1))
        log "Health check attempt $count of $retries failed. Waiting $wait_seconds seconds..."
        sleep $wait_seconds
    done

    log "ERROR: Health check failed after $retries attempts"
    return 1
}

# Perform health check
check_health

# Print final connection information
echo ""
log "Deployment completed successfully!"
log "-----------------------------------"
log "VM Public IP: $VM_IP"
log "SSH Connection: $SSH_CONNECT"
log "Web Application: http://$VM_IP"
log "Deployment log: $LOG_FILE"