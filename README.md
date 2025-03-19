# Azure Infrastructure Project

This project automates the deployment of an Azure infrastructure using Bicep and Ansible. It sets up a virtual network with subnets for a bastion host, application server, reverse proxy, and Cosmos DB. The project also includes the necessary configurations for security groups and virtual machines.

## Project Structure

cloud-solution/
├── .github/
│   └── workflows/
│       └── deploy.yml          # Single workflow for infrastructure and app deployment
├── bicep/
│   ├── main.bicep              # Main bicep template that orchestrates everything
│   ├── modules/
│   │   ├── network.bicep       # VNet and subnet definitions
│   │   ├── bastion.bicep       # Bastion host VM
│   │   ├── app-server.bicep    # App server VM with .NET 9
│   │   └── reverse-proxy.bicep # Reverse proxy with nginx
│   └── parameters.json         # Single parameters file for all resources
├── ansible/
│   ├── inventory.yml           # Single inventory file
│   ├── site.yml                # Main playbook that runs everything
│   └── roles/
│       ├── common/             # Common configurations
│       ├── bastion/            # Bastion-specific setup
│       ├── app-server/         # App server setup with .NET 9
│       └── reverse-proxy/      # Nginx reverse proxy configuration
├── scripts/
│   └── deploy.sh               # Single deployment script
├── .env.sample                 # Template for your .env file
└── README.md                   # Documentation

Parameter file will get updated from environment variable.


## Basic ansible folder structure
ansible/
├── ansible.cfg            # Configuration settings for Ansible, global parameters.
├── inventories/           # Directory containing inventory files, define target hosts and groups.

|   ├── azure_rm.yaml      # Dynamic inventory that uses environment variables to get host information.

│   ├── production/        # Production environment inventory
│   │   ├── hosts          # Production hosts file
│   │   └── group_vars/    # Variables specific to production groups
│   └── staging/           # Staging environment inventory
│       ├── hosts          # Staging hosts file
│       └── group_vars/    # Variables specific to staging groups
├── playbooks/             # Directory containing playbook files.

Playbook files are yaml files that ddefine a set of tasks to be executed on the target hosts.

│   ├── site.yml           # Main playbook that includes other playbooks
│   ├── app-server.yml     # Playbook for app server setup
│   └── reverse-proxy.yml  # Playbook for reverse proxy setup

Roles provide a way to organize playbooks into reusable components. Each role has a standardized directory structure:

- tasks: Main tasks the role executes
- handlers: Handlers triggered by tasks
- templates: Jinja2 templates, used to generate files and works with variables.
- files: Static files
- vars: Role-specific variables
- defaults: Default variables (lowest precedence)
- meta: Role metadata and dependencies

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
└── library/               # Custom Ansible modules



- **.env.sample**: Sample environment variable configuration for the project.

- **README.md**: Documentation for the project, including setup instructions and usage.

- **.gitignore**: Specifies files and directories to be ignored by Git.

## Setup Instructions

1. Clone the repository to your local machine.
2. Navigate to the project directory.
3. Configure the `.env` file based on the `.env.sample` file.
4. Set up your Azure credentials and subscription.
5. Run the deployment scripts to set up the infrastructure and application.

## Usage

- Use the provided Ansible playbooks to deploy individual components or the entire infrastructure.
- Utilize GitHub Actions for CI/CD workflows to automate deployments.

This project provides a comprehensive solution for deploying a secure and scalable Azure infrastructure using modern tools and practices.




Fas 1: Grundläggande infrastruktur (körs en gång)
Denna fas skapar alla Azure-resurser inklusive VMs, nätverksresurser, etc.
Körs i början av projektet för att sätta upp grundläggande infrastruktur

Fas 2: Konfigurationshantering (körs vid behov)
Ansible hanterar konfiguration och applikationsdistribution
Kan köras när som helst för att uppdatera konfiguration utan att röra infrastrukturen


1. När du ska köra deploy.sh
Deploy.sh shall jag bara köra när jag gör förändringar i infrastrukturen va?

Ja, exakt! Du kör deploy.sh när du behöver:

Skapa nya Azure-resurser
Ändra befintliga resurser (t.ex. storleksjusteringar, nya nätverk)
Återskapa miljön från grunden
2. Ansible-konfigurationsändringar
Om jag gör ändringar i config (ansible) så skall jag köra ett annat komando va?

Rätt! För att bara applicera Ansible-konfigurationsändringar (utan att röra Azure-infrastrukturen):

Detta kör bara Ansible-delen för att konfigurera mjukvara och inställningar på de befintliga VM:arna.


Jag hade först byggt en lösning via den gamla tutorial-metoden med Azure CLI och hade som plan att göra ett gitrepo med Bicep och Cloud-Init som komplement. Men efter kursen med Ansible gjorde jag om hela lösningen, för jag vill ha det idempotent. 
Jag fastnade ganska länge i deploy.sh skripet, som är det initiala skripet som sätter upp grunden för både infrastruktur (bicep) och configuration (ansible).
Hade problem med att GH Actions väntade på att runnern skulle startas, men fick tips av Lars om att det kanske var fel användare. Det var nog inte hela problemet. Jag SSH:ade in i app-servern och kollade lite, den verkar inte ha slutfört installationen.
