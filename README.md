# Azure Infrastructure Project
- **Student**: Johan Nilsson
- **Kurs**: Cloud Basics
- **Institution**: Campus Mölndal YH
- **Handledare**: Lars Larsson
- 

## Detaljer
- **Projekt**: Azure Infrastructure Project
- **GitHub Repo**: sirhaffy/
- **Webbapplikation URL**: [WebbApp](https://webbapp.johannilsson.se)

## Lösningsbeskrivning och Tankar
Jag hade först byggt en lösning via den gamla tutorial-metoden med Azure CLI och hade som plan att göra ett gitrepo med Bicep och Cloud-Init som komplement. Men efter kursen med Ansible gjorde jag om hela lösningen, för jag vill ha det idempotent. 

Jag fastnade ganska länge i deploy.sh skripet, som är det initiala skripet som sätter upp grunden för både infrastruktur (bicep) och configuration (ansible).

Fastnade en stund med att få till så den använde en nyare version för Ubuntu. Tillslut förstod jag att det var olika "offer" för olika "sku" och att jag behövde en annan offer för att få en nyare version.

Hade problem med att GH Actions väntade på att runnern skulle startas, vilket ger aningar om att allt kanske inte gick rätt i Ansible processen till, speciellt med Runnern. Fick tips av Lars om att det kanske var fel användare som används. Det var nog inte hela problemet. Jag SSH:ade in i app-servern och kollade lite, den verkar inte ha slutfört installationen, många saker saknades. Så började felsöka där. Skapade lite debugs och en log output med hjälp av AI, det ledde mig till att prova att skapa en PAT (Personal Access Token) med rättigheter för att låta Workflow hantera och skapa Runner Token. Lägger in den i GH Secrets för att sen kunna skapa RUNNER_TOKEN dynamiskt i GitHub Workflow. Det löste problemet med att Runnern inte startade mm.

<!-- Jag har också lagt in en Azure Dynamic Inventory som hämtar information om hostar från Azure. Detta är en stor fördel för att slippa hålla koll på IP-adresser och annat. -->



## Folder Structure
```bash
.
├── .github/               # Directory containing GitHub Actions workflows
│   └── workflows/         # Directory containing workflow files
│       └── main.yml       # Main workflow file
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
│   ├── site.yml           # Main playbook that includes other playbooks
│   ├── app-server.yml     # Playbook for app server setup
│   └── reverse-proxy.yml  # Playbook for reverse proxy setup
├── roles/                 # Directory containing role definitions
│   ├── common/            # Common role applied to all servers
│   │   ├── tasks/         # Tasks for common role
│   │   │   └── main.yml   # Main tasks file
│   │   ├── handlers/      # Handlers for common role
│   │   │   └── main.yml   # Main handlers file
│   │   ├── templates/     # Jinja2 templates for common role
│   │   ├── files/         # Static files for common role
│   │   ├── vars/          # Variables for common role
│   │   │   └── main.yml   # Main variables file
│   │   └── defaults/      # Default variables for common role
│   │       └── main.yml   # Main defaults file
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

// TODO: Frågor till Lars: Hur gör man när man är fler användare som ska kunna köra Azure Bicep?
5. Konfigurera dina Azure-autentiseringsuppgifter och prenumeration.
6. Kör deployment-skripten för att konfigurera infrastrukturen och applikationen.

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





