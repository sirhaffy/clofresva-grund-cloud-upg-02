# Inlämningsuppgift 02 för Cloud Grund, Campus Mölndal, YH-utbildning.
av: Fredrik
datum: 2022-03-06

## Uppgiftsbeskrivning
Uppgiften ... skyddar oss mot hot, speciellt från hackergruppen 'Cloud Just Means Rain' som är på oss som flugor redan från start.

Jag beskriver nedan det manuella flödet för att sätta upp denna lösningen. Sen har jag också satt upp lösningen med Bicep, som funns i GitHub Repot. För att Bicep har något väldigt bra som inte bash har och det är idempotens.

Det blev för rörigt att ha allt i samma fil, så jag gjorde såhär denna gången. Nästa gång kommer jag fokusera på att skapa automatiseringen och hur den ser ut. Jag ville bara visa att jag förstår det manuella flödet innan jag automatiserar det. Så inte jag bara kört AI på allt.

## Uppgifter:
Github Repo:
IP Adress för lösningsförslaget:
SSH sträng för att komma in i Bastion Host: `ssh `
SSH sträng för att komma in i Reverse Proxy: `ssh `
SSH sträng för att komma in i App Server: `ssh `

## Att göra:

1. Gör hela det manuella flödet och se så det fungerar.
2. Gör en ARM-mall för att sätta upp allt.
3. Gör en CloudInit för att sätta upp allt.
4. Gör en GitHub Workflow för att sätta upp allt.
5. Gör en README.md för att beskriva allt.

## 1. Resource Group
Vi behöver skapa en resursgrupp för att kunna skapa resurser i Azure.

```bash
# Create resource group
az group create --name RGCloFreSvaUpg02 --location northeurope
```


## 2. Network

### vNet (Virtual Network)
Ett virtuellt nät delas in i ett eller flera subnät och kan ha en eller flera nätverksgränssnitt.

```bash
# Create vNet
az network vnet create \
--resource-group RGCloFreSvaUpg02 \
--name NordicVNet \
--address-prefix 10.0.0.0/16 
```

### Subnet
Ett subnet är en del av ett nätverk som innehåller en grupp av enheter som kan kommunicera med varandra.   

```bash
# 1. Skapa subnet för lagring
az network vnet subnet create \
  --resource-group RGCloFreSvaUpg02 \
  --vnet-name NordicVNet \
  --name StorageSubnet \
  --address-prefix 10.0.4.0/8

# 2. Skapa subnet för databas
az network vnet subnet create \
  --resource-group RGCloFreSvaUpg02 \
  --vnet-name NordicVNet \
  --name DatabaseSubnet \
  --address-prefix 10.0.5.0/8

# 3. Skapa Private Endpoint för Blob Storage
az network private-endpoint create \
  --resource-group RGCloFreSvaUpg02 \
  --name BlobStorageEndpoint \
  --vnet-name NordicVNet \
  --subnet StorageSubnet \
  --private-connection-resource-id $(az storage account show -g RGCloFreSvaUpg02 -n clofresvaupg02 --query id -o tsv) \
  --group-id blob \
  --connection-name BlobStorageConnection

# 4. Skapa Private Endpoint för Cosmos DB
az network private-endpoint create \
  --resource-group RGCloFreSvaUpg02 \
  --name CosmosDBEndpoint \
  --vnet-name NordicVNet \
  --subnet DatabaseSubnet \
  --private-connection-resource-id $(az cosmosdb show -g RGCloFreSvaUpg02 -n CloFreSvaUpg02 --query id -o tsv) \ 
  --group-id Sql \
  --connection-name CosmosDBConnection

# 5. Skapa subnet för Reverse Proxy
az network vnet subnet create \
  --resource-group RGCloFreSvaUpg02 \
  --vnet-name NordicVNet \
  --name ReverseProxySubnet \
  --address-prefix 10.0.1.0/8

# 6. Skapa subnet för Application Server
az network vnet subnet create \
  --resource-group RGCloFreSvaUpg02 \
  --vnet-name NordicVNet \
  --name AppServerSubnet \
  --address-prefix 10.0.2.0/8

# 7. Skapa subnet för Bastion Host
az network vnet subnet create \
  --resource-group RGCloFreSvaUpg02 \
  --vnet-name NordicVNet \
  --name BastionHostSubnet \
  --address-prefix 10.0.3.0/8
```


#### ServiceTags - En samling av IP-adresser som representerar Azure-tjänster, som kan användas i NSG:er och ASG:er.
Service Tags är en grupp av IP-adresser som representerar specifika Azure-tjänster.
Istället för att manuellt ange IP-adresser för Azure-tjänster som ASG:er eller NSG:er, så använder man Service Tags. Speciellt lämpligt då IP-adresserna för Azure-tjänster kan ändras (Dynamic IP).
Man tilldelar en Service Tag till ett subnet eller på en VMs nätverkskort (NIC) och kan sedan använda den i NSG:er och ASG:er.

Vi kommer använda följande:
- BastionHostSubnet > ST-BH.
- ReverseProxySubnet > ST-RP.
- AppServerSubnet > ST-AS.
- BlobStorageEndpoint > ST-BS.
- CosmosDBEndpoint > ST-CDB.

   
#### NSG - Network Security Group, säkerhetsregler som tillämpas på nätverksnivå.
En Network Security Group (NSG) innehåller regler för att tillåta eller blockera trafik till och från målet.
NSG:er kan tillämpas på subnät eller nätverkskort (NIC) för att filtrera trafik.

Vi kommer skapa följande NSGer:
- NSG-ReverseProxy, tillåter bara HTTP/S-trafik (80 och 443/TCP) till Reverse Proxy Subnet (ST-RP) från hela internet.
- NSG-AppSrv, tillåter bara HTTP-trafik (5000/TCP) till App Server Subnet (ST-AS) från Reverse Proxy Subnet (ST-RP).
- NSG-BastionHost, tillåter bara SSH-trafik (2222/TCP) till Bastion Host Subnet (ST-BH) från hela internet.
- NSG-InternalAccess, tillåter bara SSH-trafik (22/TCP) till virtuella maskiner från Bastion Host Subnet (ST-BH).
- NSG-Storage, tillåter bara Blob Storage-trafik (443/TCP) från Application Server Subnet (ST-AS).
- NSG-CosmosDB, tillåter bara Cosmos DB-trafik (443/TCP) från Application Server Subnet (ST-AS).

```bash	
# Create NSG
az network nsg create --resource-group RGCloFreSvaUpg02 --name NSG-ReverseProxy
az network nsg create --resource-group RGCloFreSvaUpg02 --name NSG-AppSrv
az network nsg create --resource-group RGCloFreSvaUpg02 --name NSG-BastionHost
az network nsg create --resource-group RGCloFreSvaUpg02 --name NSG-InternalAccess
az network nsg create --resource-group RGCloFreSvaUpg02 --name NSG-Storage
az network nsg create --resource-group RGCloFreSvaUpg02 --name NSG-CosmosDB
```

```bash
# Create NSG rule for Blob Storage
az network nsg rule create \
--resource-group RGCloFreSvaUpg02 \
--nsg-name NSG-Storage \
--name Allow-HTTPS-All \
--direction Inbound \
--priority 1000 \
--source-address-prefixes ST-AS \
--source-port-ranges '*' \
--destination-address-prefixes '*' \
--destination-port-ranges 443 \
--access Allow \
--protocol Tcp \
--description "Allow HTTPS"

# Create NSG rule for Cosmos DB
az network nsg rule create \
--resource-group RGCloFreSvaUpg02 \
--nsg-name NSG-CosmosDB \
--name Allow-HTTPS-All \
--direction Inbound \
--priority 1000 \
--source-address-prefixes ST-AS \
--source-port-ranges '*' \
--destination-address-prefixes '*' \
--destination-port-ranges 443 \
--access Allow \
--protocol Tcp \
--description "Allow HTTPS"

# Create NSG for Reverse Proxy
az network nsg rule create \
--resource-group RGCloFreSvaUpg02 \
--nsg-name NSG-ReverseProxy \
--name Allow-HTTP-All \
--direction Inbound \
--priority 1000 \
--source-address-prefixes Internet \
--source-port-ranges '*' \
--destination-address-prefixes '*' \
--destination-port-ranges 80 443 \
--access Allow \
--protocol Tcp \
--description "Allow HTTP/S"

# Create NSG for App Server
az network nsg rule create \
--resource-group RGCloFreSvaUpg02 \
--nsg-name NSG-AppSrv \
--name Allow-HTTP-All \
--direction Inbound \                 
--priority 1000 \
--source-address-prefixes ST-RP \
--source-port-ranges '*' \
--destination-address-prefixes '*' \
--destination-port-ranges 5000 \
--access Allow \
--protocol Tcp \
--description "Allow HTTP"

# Create NSG for Bastion Host
az network nsg rule create \
--resource-group RGCloFreSvaUpg02 \
--nsg-name NSG-BastionHost \
--name Allow-SSH-All \
--direction Inbound \
--priority 1000 \
--source-address-prefixes Internet \
--source-port-ranges '*' \
--destination-address-prefixes '*' \
--destination-port-ranges 2222 \
--access Allow \
--protocol Tcp \
--description "Allow SSH"

# Create NSG for Internal Access
az network nsg rule create \
--resource-group RGCloFreSvaUpg02 \
--nsg-name NSG-InternalAccess \
--name Allow-SSH-All \
--direction Inbound \
--priority 1000 \
--source-address-prefixes ST-BH \
--source-port-ranges '*' \
--destination-address-prefixes '*' \
--destination-port-ranges 22 \
--access Allow \
--protocol Tcp \
--description "Allow SSH"
```

Nu ska vi koppla dom mot respektive subnet.

```bash
# Associate NSG with Storage subnet
az network vnet subnet update \
--resource-group RGCloFreSvaUpg02 \
--vnet-name NordicVNet \
--name StorageSubnet \
--network-security-group NSG-Storage

# Associate NSG with Database subnet
az network vnet subnet update \
--resource-group RGCloFreSvaUpg02 \
--vnet-name NordicVNet \
--name DatabaseSubnet \
--network-security-group NSG-CosmosDB

# Associate NSG with Reverse Proxy subnet
az network vnet subnet update \
--resource-group RGCloFreSvaUpg02 \
--vnet-name NordicVNet \
--name ReverseProxySubnet \
--network-security-group NSG-ReverseProxy

# Associate NSG with Application Server subnet
az network vnet subnet update \
--resource-group RGCloFreSvaUpg02 \
--vnet-name NordicVNet \
--name AppServerSubnet \
--network-security-group NSG-AppSrv

# Associate NSG with Bastion Host subnet
az network vnet subnet update \
--resource-group RGCloFreSvaUpg02 \
--vnet-name NordicVNet \
--name BastionHostSubnet \
--network-security-group NSG-BastionHost

# Associate NSG with Internal Access subnet
az network vnet subnet update \
--resource-group RGCloFreSvaUpg02 \
--vnet-name NordicVNet \
--name InternalAccessSubnet \
--network-security-group NSG-AppSrv, NSG-ReverseProxy
```


#### ASG - Application Security Group, säkerhetsregler som tillämpas på applikationsnivå.
En Application Security Group (ASG) låter oss gruppera virtuella maskiner och applicera säkerhetsregler baserat på grupper istället för enskilda IP-adresser eller NICs.

Vi behöver inga ASG:er för denna lösningen i nuläget. Vi skulle kunna gjort det istället för att peka InternalAccessSubnet på ett Subnät bara för att via hur man gör.

Exempel:
```bash
# Create ASG
az network asg create --resource-group RGCloFreSvaUpg02 --name ASG-InternalSshAccess

# ** Add ReverseProxyVM to ASG **

# Get the NIC of the VM
REVERSEPROXY_NIC=$(az vm show --resource-group RGCloFreSvaUpg02 --name ReverseProxyVM --query 'networkProfile.networkInterfaces[0].id' -o tsv | xargs -n 1 basename)

# Associate Reverse Proxy VMs NIC with ASG.
az network nic update \
  --resource-group RGCloFreSvaUpg02 \
  --name $REVERSEPROXY_NIC \
  --add applicationSecurityGroups ASG-InternalSshAccess
```

Denna lösningen ser till att NICen är kopplad direkt till ASG, så även om IP adressen byts (dynamiskt ip) så kommer ASG att fungera.










## 3. Sätt upp Blob Storage
```bash
az storage account create \
--name clofresvaupg02 \
--resource-group RGCloFreSvaUpg02 \
--location northeurope \
--sku Standard_LRS

# Get the connection string
az storage account show-connection-string \
--name clofresvaupg02 \
--resource-group RGCloFreSvaUpg02 \
--query connectionString -o tsv

# Create a container
az storage container create \
--name clofresvaupg02 \
--connection-string "<connection-string>"

# Upload a file
az storage blob upload \
--container-name clofresvaupg02 \
--file <file-path> \
--name <file-name> \
--connection-string "<connection-string>"

# List blobs
az storage blob list \
--container-name clofresvaupg02 \
--connection-string "<connection-string>"

# Get the URL of the image
az storage blob url \
--container-name clofresvaupg02 \
--name <file-name> \
--connection-string "<connection-string>"
```

## 4. Sätt upp Azure Cosmos DB
```bash
az cosmosdb create \
--name CloFreSvaUpg02 \
--resource-group RGCloFreSvaUpg02 \
--locations regionName="North Europe" failoverPriority=0 isZoneRedundant=False \
--locations regionName="West Europe" failoverPriority=1 isZoneRedundant=False \
--default-consistency-level "Session" \
--enable-multiple-write-locations true

# Get the connection string
az cosmosdb keys list \
--name CloFreSvaUpg02 \
--resource-group RGCloFreSvaUpg02 \
--type connection-strings \
--query connectionStrings[0].connectionString -o tsv

# Create a mongo db database
az cosmosdb mongodb database create \
--account-name CloFreSvaUpg02 \
--name CloFreSvaUpg02DB \
--resource-group RGCloFreSvaUpg02

# Create a mongo db collection
az cosmosdb mongodb collection create \
--account-name CloFreSvaUpg02 \
--database-name CloFreSvaUpg02DB \
--name CloFreSvaUpg02Collection \
--resource-group RGCloFreSvaUpg02

# Get the connection string for the mongo db to use in C# .Net core application
az cosmosdb keys list \
--name CloFreSvaUpg02 \
--resource-group RGCloFreSvaUpg02 \
--type connection-strings \
--query connectionStrings[1].connectionString -o tsv

# Get the URL of the mongo db
az cosmosdb show \
--name CloFreSvaUpg02 \
--resource-group RGCloFreSvaUpg02 \
--query documentEndpoint -o tsv

# Get the primary key of the mongo db
az cosmosdb keys list \
--name CloFreSvaUpg02 \
--resource-group RGCloFreSvaUpg02 \
--query primaryMasterKey -o tsv
```

## 5. Bastion Host
Har till uppgift att skydda interna nätverk från attacker utifrån. Bastion hosten är en server som är placerad i ett DMZ (Demilitarized Zone) och används för att ansluta till interna servrar. 

_Notering: Jag skulle velat lägga in Port Knocking, Fail2Ban också. Men det är utanför kursen så jag får nöja mig med att byta porten och sätta upp SSH nyckel istället för lösenord. För att skydda oss från hackergruppen._

```bash	
# Skapa en statisk offentlig IP
az network public-ip create \
--resource-group RGCloFreSvaUpg02 \
--name BastionPublicIP \
--allocation-method Static \
--sku Standard

# Create virtual machine
az vm create \
--resource-group RGCloFreSvaUpg02 \
--vnets NordicVNet \
--subnet AppServerSubnet \
--name BastionHostVM \
--image Ubuntu2204 \
--size Standard_B1s \
--public-ip-address BastionPublicIP \
--admin-username azureuser \
--service-tags ST-BH \
--ssh-key-values "$ssh_public_key" \ // TODO
--custom-data cloud_init_bastion.yaml

# Skriv ut det statiska offentliga IP-adressen
az vm show \
--detail \
--resource-group RGCloFreSvaUpg02 \
--name BastionHostVM \
--query publicIps \
-o tsv
```

### Skapa en cloud-init fil för att konfigurera Bastion Host.
```bash
# Skapa en cloud-init fil
touch cloud_init_bastion.yaml

# Öppna filen
nano cloud_init_bastion.yaml
```

```yaml
#cloud-config bastion host
package_update: true
package_upgrade: true

# Installera önskade paket
packages:
  - openssh-server
  - fail2ban

write_files:
  - path: /etc/ssh/sshd_config
    content: |
      Port 2222
      PasswordAuthentication no
      PermitRootLogin no
      PubkeyAuthentication yes
      ChallengeResponseAuthentication no
      UsePAM yes
      X11Forwarding no
      PrintMotd no
      AcceptEnv LANG LC_*
      Subsystem sftp /usr/lib/openssh/sftp-server
      AllowUsers azureuser

  # Fail2ban configuration to protect SSH
  - path: /etc/fail2ban/jail.local
    content: |
      [sshd]
      enabled = true
      port = 2222
      filter = sshd
      logpath = /var/log/auth.log
      maxretry = 5
      bantime = 3600

runcmd:
  # Set proper permissions for SSH directory (even though Azure handles the keys)
  - mkdir -p /home/azureuser/.ssh
  - chmod 700 /home/azureuser/.ssh
  - touch /home/azureuser/.ssh/authorized_keys
  - chmod 600 /home/azureuser/.ssh/authorized_keys
  - chown -R azureuser:azureuser /home/azureuser/.ssh

  # Start and restart services
  - systemctl restart ssh
  - systemctl enable fail2ban
  - systemctl start fail2ban

  # Configure firewall
  - ufw allow 2222/tcp
  - ufw --force enable

  # Log completion
  - echo "Security hardening complete" >> /var/log/cloud-init-output.log
```

```bash
# Spara och stäng filen.
'ctrl + x' > y > enter
```

## 6. Reverse Proxy
En reverse proxy är en server som tar emot förfrågningar från klienter och skickar dem vidare till en eller flera servrar. Den är till för att skydda och lastbalansera servrarna som finns bakom. 

Vi kommer skapa en VM och installera och konfigurera Nginx på den, som kommer att fungera som en reverse proxy.

```bash
# Skapa en statisk offentlig IP
az network public-ip create \
--resource-group RGCloFreSvaUpg02 \
--name ReverseProxyIP \
--allocation-method Static \
--sku Standard

# Skapa en virtuell maskin för Reverse Proxy
az vm create \
--resource-group RGCloFreSvaUpg02 \
--vnets NordicVNet \
--subnet AppServerSubnet \
--name ReverseProxyVM \
--image Ubuntu2204 \
--size Standard_B1s \
--public-ip-address ReverseProxyIP \
--admin-username azureuser \
--service-tags ST-RP \
--private-ip-address 10.0.1.10 \ # Sätt en statisk intern IP-adress.
--private-ip-address-allocation static 

# Hämta den publika IP-adressen
az vm show \
--detail \
--resource-group RGCloFreSvaUpg02 \
--name ReverseProxyVM \
--query publicIps \
-o tsv
```

### Skapa en cloud-init fil för att konfigurera Reverse Proxy.
```bash
# Skapa en cloud-init fil
touch cloud_init_reverse_proxy.yaml

# Öppna filen
nano cloud_init_reverse_proxy.yaml
```

### 
```yaml
#cloud-config reverse proxy
package_update: true
package_upgrade: true

packages:
- nginx
- openssh-server

write_files:
- path: /etc/nginx/sites-available/reverse-proxy.conf
    content: |
    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://${app_server_ip}:${app_server_port};
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }

# SSH configuration
- path: /etc/ssh/sshd_config
    content: |
    Port 22
    PasswordAuthentication no
    PubkeyAuthentication yes
    PermitRootLogin no
    ChallengeResponseAuthentication no
    UsePAM yes
    X11Forwarding no
    PrintMotd no
    AcceptEnv LANG LC_*
    Subsystem sftp /usr/lib/openssh/sftp-server
    AllowUsers azureuser

runcmd:
# Configure SSH
- systemctl restart ssh

# Configure Nginx reverse proxy
- ln -sf /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/
- rm -f /etc/nginx/sites-enabled/default
- nginx -t && systemctl restart nginx
- systemctl enable nginx

# Configure firewall
- ufw allow 80/tcp
- ufw allow 22/tcp
- ufw --force enable
```

## 7. Application Server
En applikationsserver är en server som är utformad för att hantera och köra applikationer. Den är till för att hantera och köra applikationer som är skrivna i olika programmeringsspråk.

Vi kommer att skapa en VM och installera och konfigurera Dotnet Core på den, som kommer att fungera som en applikationsserver.

```bash
# Create virtual machine
az vm create \
--resource-group $resource_group \
--vnet-name $vnet_name \
--subnet AppServerSubnet \
--name $app_server_name \
--image Ubuntu2204 \
--size Standard_B1s \
--admin-username azureuser \
--service-tags ST-AS \
--ssh-key-values "$ssh_public_key" \
--private-ip-address $app_server_ip \
--private-ip-address-allocation static \
--custom-data cloud_init_app_server.yaml

# Hämta den interna IP-adressen för SSH-anslutning via ProxyJump.
reverse_proxy_public_ip=$(az vm show \
--detail \
--resource-group $resource_group \
--name $reverse_proxy_name \
--query publicIps \
-o tsv)
```

### Installera och konfigurera SSH

```bash
# Installera OpenSSH
sudo apt update
sudo apt install openssh-server -y

# Öppna filen för SSH-konfiguration:
sudo nano /etc/ssh/sshd_config

# Ändra/Lägg till:
Port 22

# Spara och stäng filen.
'ctrl + x' > y > enter

# Starta om tjänsten:
sudo systemctl restart ssh
```

### Installera och konfigurera Dotnet Core på VM:en. 

```bash
# Installera Dotnet Core
add-apt-repository ppa:dotnet/backports -y
apt-get update
apt-get install -y aspnetcore-runtime-9.0

# Kolla versionen
dotnet --version
```

## 8. Setup SSH för att ansluta till VMs.
Vi har tidigare skapat en SSH-nyckel för att ansluta till Bastion Host. Vi kommer använda samma nyckel för att ansluta till App Server och Reverse Proxy.

```bash
# ** CLIENT SIDE  **

# Lägg till nyckeln i config.
nano ~/.ssh/config

# Lägg till:
Host bastionvm
    HostName <BastionHost_Public_IP>
    User azureuser
    Port 2222
    IdentityFile ~/.ssh/clofresva_gc_upg02_azure_key

Host appserver
    HostName 10.0.2.10  # Använd det statiska IP:t direkt istället för variabel
    User azureuser
    ProxyJump bastionvm
    IdentityFile ~/.ssh/clofresva_gc_upg02_azure_key

Host reverseproxy
    HostName 10.0.1.10  # Använd det statiska IP:t direkt istället för variabel
    User azureuser
    ProxyJump bastionvm
    IdentityFile ~/.ssh/clofresva_gc_upg02_azure_key

# Spara och stäng filen.
'ctrl + x' > y > enter

# Nu kan man ssha in såhär:
ssh bastionvm       # Bastion Host.
ssh appserver       # App Server, via Bastion Host.
ssh reverseproxy    # Reverse Proxy, via Bastion Host.

# Nu kan man också skicka och hämta filer med scp:
scp /path/to/file azureuser@appserver:/path/to/destination
scp azureuser@appserver:/path/to/file /path/to/destination

```


### Github Repo med Actions Workflow och Artifacts.

Lokalt på utvecklingsdatorn.

```bash
# Gå in i mappen för applikationen.
cd ~/app/CloFreSvaUpg02App

# Skapa först en .gitignore fil
dotnet new gitignore

# Initiera ett nytt git-repo
git init

# Lägg till alla filer
git add .

# Commit
git commit -m "First commit"    

# Installera GitHub CLI
gh auth login

# Skapa ett nytt repo
gh repo create Campus-Molndal-CLOH24/<namnet-på-repot> --public --source=. --remote=origin --push

# Pusha till GitHub
git push origin main
```

### Installera Github Runner

1. Logga in på GitHub och gå till ditt repo
2. Navigera till repository-inställningarna
3. Klicka på "Settings" i den övre delen av ditt repository
4. I sidomenyn, scrolla ner och klicka på "Actions"
5. Klicka på "Runners"
6. Klicka på "New self-hosted runner"

7. Välj runner-konfiguration
    Välj "Linux" som operativsystem
    Välj "x64" som arkitektur

8. Du kommer nu se instruktioner för att ladda ner och konfigurera runnern, exempel lösning.

Anslut till din AppServerVM via SSH. 
// TODO
```bash
ssh -i ~/.ssh/clofresva_gc_upg02_azure_key azureuser@<AppServer_Public_IP>
```

Kör följande kommandon för att installera och konfigurera runner på din AppServerVM.
```bash
# Gå till hemkatalogen
cd ~/

# Create a folder
$ mkdir actions-runner && cd actions-runner

# Download the latest runner package
$ curl -o actions-runner-linux-x64-2.322.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-linux-x64-2.322.0.tar.gz

# Optional: Validate the hash
$ echo "b13b784808359f31bc79b08a191f5f83757852957dd8fe3dbfcc38202ccf5768  actions-runner-linux-x64-2.322.0.tar.gz" | shasum -a 256 -c

# Extract the installer
$ tar xzf ./actions-runner-linux-x64-2.322.0.tar.gz

# ** Konfigurera runnern **
# Create the runner and start the configuration experience
./config.sh --url https://github.com/Campus-Molndal-CLOH24/CloFreSvaUpg02App --token ACMKOYEG54SS7G5RYOKLCWDH2V3VI

# Last step, run it!
$ ./run.sh

# Starta runnern som en tjänst
$ ./svc.sh install
$ ./svc.sh start

# Kolla status
$ ./svc.sh status
```

### Actions Workflow

```yaml
# .github/workflows/dotnet-core.yml
name: GithubActionsCloFreSvarUpg2

on:
  push:
    branches:
    - "main"
  workflow_dispatch:

jobs:

  build:
    runs-on: ubuntu-latest
    steps:

    - name: Install .NET SDK
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '9.0.x'

    - name: Check out this repo
      uses: actions/checkout@v4

    - name: Restore dependencies (install Nuget packages)
      run: dotnet restore

    - name: Build and publish the app
      run: |
        dotnet build --no-restore
        dotnet publish -c Release -o ./publish

    - name: Upload app artifacts to Github
      uses: actions/upload-artifact@v4
      with:
        name: app-artifacts
        path: ./publish

  deploy:
    runs-on: self-hosted # The runner on the AppServerVM.
    needs: build

    steps:
    - name: Download the artifacts from Github (from the build job)
      uses: actions/download-artifact@v4
      with:
        name: app-artifacts

    - name: Stop the application service
      run: |
        sudo systemctl stop GithubActionsCloFreSvarUpg2.service

    - name: Deploy the the application
      run: |
        sudo rm -Rf /opt/GithubActionsCloFreSvarUpg2 || true
        sudo cp -r /home/azureuser/actions-runner/_work/CloFreSvaUpg02App/CloFreSvaUpg02App /opt/GithubActionsCloFreSvarUpg2

    - name: Start the application service
      run: |
        sudo systemctl start GithubActionsCloFreSvarUpg2.service
```





## 9. Skapa DotNet Core applikation
```bash
# Skapa en ny mapp för applikationen
mkdir ~/app

# Gå in i mappen
cd ~/app

# Skapa en ny DotNet Core applikation
dotnet new webapi -n CloFreSvaUpg02App

# Gå in i mappen för den nya applikationen
cd CloFreSvaUpg02App

# Starta applikationen
dotnet run
```

### Koppla upp mot Cosmos DB
```csharp
// Installera MongoDB.Driver
dotnet add package MongoDB.Driver

// Skapa en ny instans av MongoClient
var client = new MongoClient("<connection-string>");

// Hämta en referens till databasen
var database = client.GetDatabase("CloFreSvaUpg02DB");

// Hämta en referens till collection
var collection = database.GetCollection<BsonDocument>("CloFreSvaUpg02Collection");

// Skapa ett nytt dokument
var document = new BsonDocument
{
    { "name", "Azure Cosmos DB" },
    { "type", "Database" },
    { "account", "CloFreSvaUpg02" }
};

// Lägg till dokumentet i collection
collection.InsertOne(document);
```

### Koppla upp mot Blob Storage
```csharp
// Installera Azure.Storage.Blobs
dotnet add package Azure.Storage.Blobs

// Skapa en ny instans av BlobServiceClient
var blobServiceClient = new BlobServiceClient("<connection-string>");

// Hämta en referens till containern
var containerClient = blobServiceClient.GetBlobContainerClient
("clofresvaupg02");

// Hämta en referens till blob
var blobClient = containerClient.GetBlobClient("file-name");

// Ladda ner blob
var download = await blobClient.DownloadAsync();

// Läs innehållet
var content = await new StreamReader(download.Value.Content).ReadToEndAsync();
```




## 10. Testa lösningen
Nu ska vi testa att ansluta till applikationsservern via reverse proxy.

```bash
# Testa att ansluta till App Server via Reverse Proxy
curl http://<ReverseProxy_Public_IP>
```