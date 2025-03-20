Azure Infrastructure Project
Detta projekt automatiserar deployment av Azure-infrastruktur med hjälp av Bicep och Ansible. Det konfigurerar ett virtuellt nätverk med subnät för bastion-värd, applikationsserver, reverse proxy och Cosmos DB. Projektet innehåller även nödvändiga konfigurationer för säkerhetsgrupper och virtuella maskiner.

Parameterfilen uppdateras från miljövariabler.

Grundläggande Ansible-mappstruktur
Playbook-filer är yaml-filer som definierar uppgifter som ska utföras på målvärdarna.

Roller ger ett sätt att organisera playbooks i återanvändbara komponenter. Varje roll har en standardiserad katalogstruktur:

tasks: Huvuduppgifter som rollen utför
handlers: Hanterare som utlöses av uppgifter
templates: Jinja2-mallar, används för att generera filer och fungerar med variabler
files: Statiska filer
vars: Rollspecifika variabler
defaults: Standardvariabler (lägst prioritet)
meta: Rollmetadata och beroenden
.env.sample: Exempel på miljövariabelkonfiguration för projektet.
README.md: Dokumentation för projektet, inklusive instruktioner för installation och användning.
.gitignore: Specificerar filer och kataloger som ska ignoreras av Git.
Installationsanvisningar
Klona projektet till din lokala maskin.
Navigera till projektkatalogen.
Konfigurera en .env-fil med följande secrets/variabler:
PROJECT_NAME
RESOURCE_GROUP
LOCATION
ADMIN_USERNAME
REPO_NAME
PAT_TOKEN (GitHub Personal Access Token med repo och workflow-rättigheter)
SSH_KEY_PATH
VNET_NAME
BASTION_SSH_PORT
APP_SERVER_PORT
DOTNET_VERSION
VM_SIZE
Konfigurera dina Azure-autentiseringsuppgifter och prenumeration.
Kör deployment-skripten för att konfigurera infrastrukturen och applikationen.
GitHub Actions Secrets
För att GitHub Actions workflow ska fungera korrekt behöver följande secrets vara konfigurerade i ditt GitHub-repository:

PROJECT_NAME: Projektets namn (samma som i .env)
RESOURCE_GROUP: Azure resursgruppens namn (samma som i .env)
REPO_NAME: GitHub repository i formatet användarnamn/repo (samma som REPO_NAME i .env)
PAT_TOKEN: GitHub Personal Access Token med repo-scope för att kunna generera runner-tokens
SSH_PRIVATE_KEY: Privat SSH-nyckel för att ansluta till servrarna
SSH_PUBLIC_KEY: Offentlig SSH-nyckel som installeras på servrarna
AZURE_CREDENTIALS: JSON-output från az ad sp create-for-rbac kommandot
Användning
Använd de tillhandahållna Ansible-playbooks för att distribuera enskilda komponenter eller hela infrastrukturen.
Använd GitHub Actions för CI/CD-arbetsflöden för att automatisera deployments.
Detta projekt ger en heltäckande lösning för att distribuera en säker och skalbar Azure-infrastruktur med moderna verktyg och metoder.

Deployment-strategi
Deploy.sh ska bara köras när du gör förändringar i infrastrukturen, men jag har försökt göra den så idempotent som möjligt. Så den inte ställer till med stora saker när den behöver köras.

Infrastrukturändringar
Om det är infrastrukturändringar så ska Bicep köras.

Ansible-konfigurationsändringar
Om det är rena konfigurationsändringar så ska ansible köras.

Ansible
Ansible-konfigurationsändringar
Om det är rena konfigurationsändringar så ska ansible köras. Detta steget har jag också bakat in i GH Workflow, den kollar om det är några ändringar som behöver köras. Annars hoppar den över det och gör bara ändringar i Appen.
Lösningsbeskrivning och Tankar
Jag hade först byggt en lösning via den gamla tutorial-metoden med Azure CLI och hade som plan att göra ett gitrepo med Bicep och Cloud-Init som komplement. Men efter kursen med Ansible gjorde jag om hela lösningen, för jag vill ha det idempotent.

Jag fastnade ganska länge i deploy.sh skripet, som är det initiala skripet som sätter upp grunden för både infrastruktur (bicep) och configuration (ansible).

Hade problem med att GH Actions väntade på att runnern skulle startas, vilket ger aningar om att allt kanske inte gick rätt i Ansible processen till, speciellt med Runnern. Fick tips av Lars om att det kanske var fel användare som används. Det var nog inte hela problemet. Jag SSH:ade in i app-servern och kollade lite, den verkar inte ha slutfört installationen, många saker saknades. Så började felsöka där. Skapade lite debugs och en log output med hjälp av AI, det ledde mig till att prova att skapa en PAT (Personal Access Token) med rättigheter för att låta Workflow hantera och skapa Runner Token. Lägger in den i GH Secrets för att sen kunna skapa RUNNER_TOKEN dynamiskt i GitHub Workflow.