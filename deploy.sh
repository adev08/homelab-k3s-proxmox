#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m]'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NoColor='\033[0m' #No Color

echo -e "${GREEN}================================${NoColor}"
echo -e "${GREEN}K3s on Proxmox Deployment Script${NoColor}"
echo -e "${GREEN}================================${NoColor}"

# Check if terraform.tfvars exist
if [ ! - f "terraform/terraform.tfvars" ]; then 
    echo -e "${RED}Error: terraform/terraform.tfvars not found!${NoColor}"
    echo -e "Please copy terraform/terraform.tfvars.example to terraform/terraform.tfvars and fill in your values"
    exit 1
fi

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then 
    echo -e "${YELLOW}Ansible not found. Installing...${NoColor}"
    sudo apt update
    sudo apt install -y ansible
fi

# Step 1: Initialize Terraform
echo -e "\n${GREEN}Step 1: Initializing Terraform...${NoColor}"
cd terraform
terraform init

# Step 2: Validate configuration
echo -e "\n${GREEN}Step 2: Validating Terraform configuration...${NoColor}"
terraform validate

# Step 3: Plan deployment
echo -e "\n${GREEN}Step 3: Planning deployment...${NoColor}"
terraform plan

# Ask for confirmation
echo -e "\n${YELLOW}Do you want to proceed with the deployment? (yes/no)${NoColor}"
read -r response
if [[ ! "$response" =~ ^[Yy[Ee][Ss]]$ ]]; then
    echo -e "${GREEN}Deployment cancelled.${NoColor}"
    exit 0
fi

# Step 4: Apply Terraform
echo -e "\n${GREEN}Step 4: Creating VMs with terraform...${NoColor}"
terraform apply -auto-approve

# Step 5: Get the K3s token
echo -e "\n${GREEN}Step 5: Retrieving K3s token...${NoColor}"
K3S_TOKEN=$(terraform output -raw k3s_token)
export K3S_TOKEN
echo "K3s Token: ${K3S_TOKEN}"

# Step 6: Wait for VMs to be readt
echo -e "\n${GREEN}Step 6: Waiting for VMs to boot (60 seconds)...${NoColor}"
sleep 60

# Step 7: Test SSH connectivity
echo -e "\n${GREEN}Step 7: Testing SSH connectivity...${NoColor}"
CONTROL_PLANE_IP=$(terraform output -json control_plane_ips | jq -r '.[0]')
echo "Testing connection to ${CONTROL_PLANE_IP}..."
cd ..

retries=0
max_retries=30
until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "ubuntu@${CONTROL_PLANE_IP}" "echo 'SSH Ok'" &> /dev/null; do 
    retries=$((retries+1))
    if [ $retries -ge $max_retries ]; then  
        echo -e "\n${RED}Failed to connect via SSH after ${max_retries} attempts${NoColor}"
        exit 1
    fi
    echo -e "Waiting for SSH... (attempt $retries/$max_retries)"
    sleep 10
done

echo -e "\n${GREEN}SSH connectivity confirmed!${NoColor}"

# Step 8: Install system utilities using Ansible
echo -e "\n${GREEN}Step 8: Installing system utilities with Ansible...${NoColor}"
cd ansible
ansible-playbook -i inventory.yml system-utils-install.yml
cd ..

# Step 9: Install K3s using Ansible
echo -e "\n${GREEN}Step 9: Installing K3s cluster with Ansible...${NoColor}"
cd ansible
ansible-playbook -i inventory.yml k3s-install.yml
cd ..

# Step 10: Optional ArgoCD installation
echo -e "\n${YELLOW}Step 10: Do you want to install ArgoCD? (yes/no)${NoColor}"
read -r response
if [[ ! "$response" =~ ^[Yy[Ee][Ss]]$ ]]; then
    echo -e "\n${GREEN}Step 10: Installing ArgoCD with Ansible...${NoColor}"
    cd ansible
    ansible-playbook -i inventory.yml argocd-install.yml
    cd ..
fi

# Step 11: Display cluster info
echo -e "\n${GREEN}================================${NoColor}"
echo -e "${GREEN}Deployment Completed!${NoColor}"
echo -e "${GREEN}================================${NoColor}"

echo -e "\n${GREEN}Cluster Information:${NoColor}"
cd terraform
terraform output cluster_info

echo -e "\n${GREEN}To access your cluster:${NoColor}"
echo "1. Export kubeconfig:"
echo -e "   ${YELLOW}export KUBECONFIG=$(pwd)/kubeconfig${NoColor}"
echo ""
echo "2. Test cluster access:"
echo -e "   ${YELLOW}kubectl get nodes${NoColor}"
echo ""
echo "3. SSH to control plane:"
echo -e      "${YELLOW}$(terraform output -raw ssh_command_control_plane)${NoColor}"
cd ..
echo ""
if [[ ! "$response" =~ ^[Yy[Ee][Ss]]$ ]]; then
    echo -e "\n${GREEN}ArgoCD Information:${NoColor}"
    echo "To access ArgoCD UI:"
    echo -e"    ${YELLOW}kubectl port-forward svc/argocd-server -n argocd 8080:80${NoColor}"
    echo "Then open http://localhost:8080"
    echo "Username: admin"
    echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
fi
echo ""
echo -e "${GREEN}Kubeconfig saved to: $(pwd)/kubeconfig${NoColor}"