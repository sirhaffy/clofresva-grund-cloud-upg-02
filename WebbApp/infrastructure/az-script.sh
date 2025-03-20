#!/bin/bash

RESOURCE_GROUP_NAME=clofresva_rg_002
VM_NAME=clofresva_vm_002
PORT=5000

# Skapa en resursgrupp
az group create --name $RESOURCE_GROUP_NAME --location northeurope

# Skapa en virtuell maskin med cloud-init
az vm create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $VM_NAME \
  --image Ubuntu2404 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys

# Öppna port 80 för att tillåta HTTP-trafik
az vm open-port \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $VM_NAME \
  --port $PORT