# Azure Infrastructure Project
- **Student**: Johan Nilsson
- **Kurs**: Cloud Basics
- **Institution**: Campus Mölndal YH
- **Lärare**: Lars Appel

## Detaljer
- **Projekt**: Azure Infrastructure Project
- **GitHub Repo**: sirhaffy/
- **Webbapplikation URL**: [WebbApp](https://webbapp.johannilsson.se)

## Lösningsbeskrivning och Tankar
Jag hade först byggt en lösning via den gamla tutorial-metoden med Azure CLI och hade som plan att göra ett gitrepo med Bicep och Cloud-Init som komplement. Men efter kursen med Ansible gjorde jag om hela lösningen, för jag vill ha det idempotent. 

Jag kan omöjligt förklara allt jag gjort för denna lösning, men jag skall försöka så gott jag kan. Jag har försökt att använda mig av Bicep för att skapa infrastrukturen och Ansible för att konfigurera servrarna. Jag har också använt mig av GitHub Actions för att automatisera deploymenten. Det krävde att jag skapade en PAT (Personal Access Token) för att kunna skapa en Runner Token dynamiskt i GitHub Workflow. //TODO: Har jag?? Jag har också använt mig av Azure Dynamic Inventory för att hämta information om hostar från Azure.

Infrastrukturen hos Azure:
- vNet (Virtual Network) 

- Subnät
  - Bastion Subnet
  - App Subnet
  - Reverse Proxy Subnet
  - Blob Storage Subnet
  - Cosmos DB Subnet

- NSG (Network Security Group)
  - Bastion NSG
  - App NSG
  - Reverse Proxy NSG
  - Blob Storage NSG
  - Cosmos DB NSG

- VM (Virtual Machine)
  - Bastion Server 
    - Ubuntu Server - 24.2.0-LTS
    - Publikt IP
    - Öppen för SSH (22 och 2222)
    - NSG (Network Security Group) som tillåter inkommande trafik från Internet.
    - NSG som tillåter inkommande trafik från Bastion till App Server.
    - NSG som tillåter inkommande trafik från Bastion till Reverse Proxy Server.
    - NSG som tillåter inkommande trafik från Bastion till Blob Storage. ??
    - NSG som tillåter inkommande trafik från Bastion till Cosmos DB. ??
    - TODO: Fail2ban
    - TODO: PortKnocking 
- App Server
  - 
- Reverse Proxy Server

- Azure Tjänster
  - En Blob Storage
    - Container för att lagra bilder
    - Publik åtkomst
  - En Cosmos DB
    - MongoDB API
    - Databas och Collection

- Ansible 
  - Konfigurerar servrarna
  - App Server
    - .NET Core
    - Nginx
    - Reverse Proxy
    - WebbApp
  - Reverse Proxy
    - Nginx
    - Reverse Proxy
    - WebbApp
  - Bastion
    - Fail2ban
    - PortKnocking
  - Blob Storage
    - Container för att lagra bilder
  - Cosmos DB
    - MongoDB API
    - Databas och Collection
  - 


- GitHub Actions

Jag fastnade ganska länge i deploy.sh skripet, som är det initiala skripet som sätter upp grunden för både infrastruktur (bicep) och configuration (ansible).

Fastnade en stund med att få till så den använde en nyare version för Ubuntu. Tillslut förstod jag att det var olika "offer" för olika "sku" och att jag behövde en annan offer för att få en nyare version.

Hade problem med att GH Actions väntade på att runnern skulle startas, vilket ger aningar om att allt kanske inte gick rätt i Ansible processen till, speciellt med Runnern. Fick tips av Lars om att det kanske var fel användare som används. Det var nog inte hela problemet. Jag SSH:ade in i app-servern och kollade lite, den verkar inte ha slutfört installationen, många saker saknades. Så började felsöka där. Skapade lite debugs och en log output med hjälp av AI, det ledde mig till att prova att skapa en PAT (Personal Access Token) med rättigheter för att låta Workflow hantera och skapa Runner Token. Lägger in den i GH Secrets för att sen kunna skapa RUNNER_TOKEN dynamiskt i GitHub Workflow. Det löste problemet med att Runnern inte startade mm.

<!-- Jag har också lagt in en Azure Dynamic Inventory som hämtar information om hostar från Azure. Detta är en stor fördel för att slippa hålla koll på IP-adresser och annat. -->

När jag skapar alla resurser i Azure så har jag lagt in dem i en Resource Group. Azure skapar då en NetworkWatcherRG automatiskt för att hantera nätverksövervakning, separat från min egen resursgrupp. Det är nytt för mig och något jag behöver djupdyka i en dag för att greppa.

Jag skulle gärna koppla på Azure Keyvaults för att spara mina hemligheter, får kolla på det längre fram.

Jag skapade först en ny dotnet app och städade den från bootstrap mm och la in SCSS. Men insåg att jag sparar en massa tid på att återavnända MVC appen vi skapat i kursen. Så jag tog den och la in den i mitt repo.

Fick problem med identation när jag använde HEREDOC, så gick till ECHO per rad istället.

Provade att dela upp stegen i deploy.yaml i flera steg: 'Check Changed files', 'Deploy Azure Infrastructure', 'Configure servers with Ansible', 'Deploy Application as Artifact' och 'Deploy Artifact to App-Server' . Men det blev för mycket fuduplicerad kod (DRY) så jag la tillbaka det i ett tre steg istället: 'Check Changed files', 'Deploy Infrastructure', 'Deploy Ansible'. Gillar egentligen att ha fler steg för detta. Ska kolla om man kan skapa metoder eller något som man kan återanvända

Brottades med connectionstring en stund i appsettings template, ddfick det att fungea tillslut. Men tyckte det var smidigar ee

Made dubbla steg och felplacerat.. Rensade bort ett.

Hade glömt öppna upp blobstorage för public, så fick ändra på det i Biceps filen.

Fick också ändra lite så den hämtade från rätt container i BlobStorage. Och använder faöllback till local storage /image mappen, med en flagga.

Har problem med att sajten tas ner om flödet inte fungerar.. La in 'continue-on-error: true' och en flagga om det failar. Då använder den förra versionen av appen i stället och i .Net så finns det en timestamp så man vet vilken version som körs.

Blob storage gick relativt lätt att lösa, men Cosmos DB kontot råkade jag slänga då jag hade två. Och jag råkade slänga fel. Då upptäckte jag att jag inte hade checks på om den fanns eller inte, så la in det.

Blob Storage-implementeringen var relativt okomplicerad. Jag konfigurerade en Bicep-modul med rätt Storage Account-inställningar, säkerställde publik åtkomst genom allowBlobPublicAccess: true och publicAccess: 'Container' för appens bildhantering.

Cosmos DB-implementeringen blev mer utmanande. Efter att oavsiktligt ha raderat fel Cosmos DB-konto upptäckte jag brister i min infrastruktur-som-kod-hantering. Jag förbättrade Bicep-modulen genom att:

Lägga till kontroll för existerande resurser med existing-syntax
Implementera transient state-hantering med deploymentScripts.bicep för att pausera deployments
Konfigurera optimala index för MongoDB och lägga till databas/collection-skapande
Implementera en failover-strategi i applikationen som växlar mellan cosmos och inmemory repository baserat på tillgänglighet

GLÖM INTE SÄKERHETEN..





## TODO
MongoDB
Blobstorage
Fail2ban
PortKnocking



## Folder Structure
```bash
.
├── .github/               # Directory containing GitHub Actions workflows
│   └── workflows/         # Directory containing workflow files
│       └── main.yaml       # Main workflow file
│
│
├── ansible/               # Directory containing Ansible configuration
│   ├── ansible.cfg        # Ansible configuration file
│
├── inventories/           # Directory containing inventory files, define target hosts and groups.
│   ├── azure_rm.yaml      # Dynamic inventory that uses environment variables to get host information.
│   ├── production/        # Production environment inventory
│   │   ├── hosts          # Production hosts file
│   │   └── group_vars/    # Variables specific to production groups
│   └── staging/           # Staging environment inventory
│       ├── hosts          # Staging hosts file
│       └── group_vars/    # Variables specific to staging groups
├── playbooks/             # Directory containing playbook files.
│   ├── site.yaml           # Main playbook that includes other playbooks
│   ├── app-server.yaml     # Playbook for app server setup
│   └── reverse-proxy.yaml  # Playbook for reverse proxy setup
├── roles/                 # Directory containing role definitions
│   ├── common/            # Common role applied to all servers
│   │   ├── tasks/         # Tasks for common role
│   │   │   └── main.yaml   # Main tasks file
│   │   ├── handlers/      # Handlers for common role
│   │   │   └── main.yaml   # Main handlers file
│   │   ├── templates/     # Jinja2 templates for common role
│   │   ├── files/         # Static files for common role
│   │   ├── vars/          # Variables for common role
│   │   │   └── main.yaml   # Main variables file
│   │   └── defaults/      # Default variables for common role
│   │       └── main.yaml   # Main defaults file
│   └── app-server/        # Role specific to app servers
│       ├── tasks/
│       ├── handlers/
│       └── ...
│
│
├── infrastructure/         # Directory containing Bicep files for Azure infrastructure
│   ├── main.bicep          # Main Bicep file for infrastructure deployment
│   └── main.json           # Compiled JSON file from main.bicep
│
├── modules/                # 
│   ├── app-server.bicep    # Skapar en VM och returnerar vmId, publicIp och privateIp.
│   ├── bastion.bicep       # Skapar en VM och returnerar vmId och publicIp.
│   ├── blobstorage.bicep   # Skapar Storage Account, Service och Container. Returnerar storageAccountName och blobEndpoint.
│   ├── cosmosdb.bicep      # Skapar CosmosDB Account och Database. Returnerar cosmosDbAccountName och cosmosDbDatabaseName.
│   ├── network.bicep       # 
│   ├── reverse-proxy.bicep # 
│   └── security.bicep      # 

├── scripts/                # Directory containing shell scripts for deployment
│   ├── deploy.sh           # Main deployment script
│   ├── ansible.sh          # Ansible deployment script
│   └── bicep.sh            # Bicep deployment script

│
├── WebbApp/               # Directory containing the web application
│   ├── WebbApp.csproj     # Web application project file
│   ├── Program.cs         # Main program file
│
├── .env.sample            # Sample environment variable configuration
├── README.md              # Documentation for the project
├── .gitignore             # Specifies files and directories to be ignored by Git
└── setup.sh               # Setup script for the project
```

## Installationsanvisningar
1. Klona projektet till din lokala maskin.
2. Be mig lägga in din användare i GitHub-repot.
3. Navigera till projektkatalogen.
4. Skapa en .env-fil med följande bash komando:

```bash
cat > .env << 'EOF'
PROJECT_NAME=clofresva-gc-upg02
RESOURCE_GROUP=RGCloFreSvaUpg02
LOCATION=northeurope
REPO_NAME=sirhaffy/clofresva-grund-cloud-upg-02
PAT_TOKEN=<Skapa en GitHub PAT och lägg in den här.>
SSH_KEY_PATH=~/.ssh/clofresva_gc_upg02_azure_key
EOF
```

* PAT behöver Administration, Action och Metadata rättigheter.

1. Konfigurera dina Azure-autentiseringsuppgifter och prenumeration.
2. Kör deployment-skripten för att konfigurera infrastrukturen och applikationen.

### GitHub Actions Secrets
Vi har också dessa GitHub Secrets variabler:

```env
PROJECT_NAME=clofresva-gc-upg02
RESOURCE_GROUP=RGCloFreSvaUpg02
LOCATION=northeurope
REPO_NAME=sirhaffy/clofresva-grund-cloud-upg-02
PAT_TOKEN=<GitHub PAT>
SSH_PRIVATE_KEY=<SSH private key>
SSH_PUBLIC_KEY=<SSH public key>
AZURE_CREDENTIALS=<Azure Service Principal credentials json>
```

## Deployment strategy
Deploy.sh ska bara köras när du gör förändringar i infrastrukturen, men jag har försökt göra den så idempotent som möjligt. Så den inte ställer till med stora saker när den behöver köras.

- Infrastrukturändringar
Om det är infrastrukturändringar så ska Bicep köras.

- Ansible-konfigurationsändringar
Om det är rena konfigurationsändringar så ska ansible köras.


### Ansible
1. Ansible-konfigurationsändringar
Om det är rena konfigurationsändringar så skall ansible köras. Detta steget har jag också bakat in i GH Workflow, den kollar om det är några ändringar som behöver köras. Annars hoppar den över det och gör bara ändringar i Appen.





