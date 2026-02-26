#!/bin/bash
set -e 

GREEN='\033[0;32m'
YELLOW='\0033[1;33m]'
NoColor='\033[0m'

echo -e "${GREEN}==============================${NoColor}"
echo -e "${GREEN}K3s Proxmox Setup Script${NoColor}"
echo -e "${GREEN}==============================${NoColor}"

# Create directory structure
echo -e "\n${GREEN}Creating directory structure...${NoColor}"
mkdir -p ansible terraform

# Create files
echo -e "${GREEN}Creating configuration files...${NoColor}"

# Copy tfvars example to actual file if it doesn't exist
if [ ! -f "terraform/terraform.tfvars" ]; then 
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    echo -e "${YELLOW}Created terraform/terraform.tfvars - Please edit it with your token secrets!${NoColor}"
else
    echo -e "${YELLOW}terraform/terraform.tfvars already exists${NoColor}"
fi

# Make scripts executable
chmod +x deploy.sh 2>/dev/null || true
chmod +x setup.sh 2>/dev/null || true

# Check prerequisites
echo -e "\n${GREEN}Checking prerequisites...${NoColor}"

# Check Terrafrom
if command -v terrafrom &> /dev/null; then
    echo -e "${GREEN} Terraform install: $(terraform version -json | jq -r '.terraform_version')${NoColor}"
else
    echo -e "${YELLOW} Terraform not found. Installing...${NoColor}"
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt udpate && sudo apt install terraform -y
fi

# Check Ansible
if command -v ansible &> /dev/null; then 
    echo -e "${GREEN} Ansible installed: $(ansible --version | head -n1)${NoColor}"
else
    echo -e "${YELLOW} Ansible not found (will be installed during deployment)${NoColor}"
fi

# Check jq
if command -v jq &> /dev/null; then 
    echo -e "${GREEN} jq installed${NoColor}"
else
    echo -e "${YELLOW} jq not found. Installing${NoColor}"
    sudo apt update && sudo apt install jq -y
fi

# Check ssh key
if [ -f "$HOME/.ssh/id_ed25519.pu" ]; then 
    echo -e "${GREEN} SSH key found${NoColor}"
    echo " $(cat "$HOME/.ssh/id_ed25519.pub")"
else
    echo -e "${YELLOW} SSH key not found${NoColor}"
    echo " Generate one with: ssh-keygen -t ed25519 -c 'k3s-cluster'"
fi

# Test Proxmox connectivity
echo -e "\n${GREEN}Testing Proxmox connectivity...${NoColor}"
PVE_IP="10.10.10.10"
if ping -c 1 $PVE_IP &> /dev/null; then 
    echo -e "${GREEN} Proxmox host is reachable${NoColor}"
else 
    echo -e "${YELLOW} Cannot reach Proxmox host at $PVE_IP${NoColor}"
fi

echo -e "\n${GREEN}===================================${NoColor}"
echo -e "${GREEN}Setup summary${NoColor}"
echo -e "${GREEN}===================================${NoColor}"
echo -e ""
echo -e "${YELLOW}Next step:${NoColor}"
echo -e "1. Edit terraform/terraform.tfvars and add your Proxmox API token secret"
echo -e "   nano terraform/terraform.tvars" 
echo -e ""
echo -e "2. Review the configuration:"
echo -e "   cat terraform/terraform.tfvars"
echo -e ""
echo -e "3. Run the deployment:"
echo -e "    ./deploy.sh"
echo -e ""
echo -e "${GREEN}Files created:${NoColor}"
ls -lh ./*.sh terraform/*.tf terraform/terraform.tfvars* ansible/*.yml 2>/dev/null || true


