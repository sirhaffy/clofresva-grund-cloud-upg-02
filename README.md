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



### ???
Deploy.sh shall jag bara köra när jag gör förändringar i infrastrukturen, men jag har försökt göra den så idempotens jag kunnat. Så den inte ställer till med stora saker när den behöver köras. 

1. Infrastrukturändringar
Om det är infrastrukturändringar så skall Bicep köras.

2. Ansible-konfigurationsändringar
Om det är rena konfigurationsändringar så skall ansible köras.

### Ansible
1. Ansible-konfigurationsändringar
Om det är rena konfigurationsändringar så skall ansible köras. Detta steget har jag också bakat in i GH Workflow, den kollar om det är några ändringar som behöver köras. Annars hoppar den över det och gör bara ändringar i Appen.


## Lösningsbeskrivning och Tankar
Jag hade först byggt en lösning via den gamla tutorial-metoden med Azure CLI och hade som plan att göra ett gitrepo med Bicep och Cloud-Init som komplement. Men efter kursen med Ansible gjorde jag om hela lösningen, för jag vill ha det idempotent. 

Jag fastnade ganska länge i deploy.sh skripet, som är det initiala skripet som sätter upp grunden för både infrastruktur (bicep) och configuration (ansible).

Hade problem med att GH Actions väntade på att runnern skulle startas, vilket ger aningar om att allt kanske inte gick rätt i Ansible processen till, speciellt med Runnern. Fick tips av Lars om att det kanske var fel användare som används. Det var nog inte hela problemet. Jag SSH:ade in i app-servern och kollade lite, den verkar inte ha slutfört installationen, många saker saknades. Så började felsöka där. Skapade lite debugs och en log output med hjälp av AI, det ledde mig till att prova att skapa en PAT (Personal Access Token) med rättigheter för att låta Workflow hantera och skapa Runner Token. Lägger in den i GH Secrets för att sen kunna skapa RUNNER_TOKEN dynamiskt i GitHub Workflow.
