#!/bin/bash

# Exit immediately if any command fails
set -e

export DEBIAN_FRONTEND=noninteractive

sudo apt update -y
sudo apt install wget -y
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update -y
sudo apt install openjdk-17-jdk -y
sudo apt-get install jenkins -y

# ---------------------------------------------------------------------------------
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins


# Install Docker

sudo apt install docker.io -y
# sudo chmod 777 /var/run/docker.sock

# Create dedicated docker user (optional)
if ! id "dockeruser" &>/dev/null; then
  sudo useradd -m -s /bin/bash dockeruser
  echo "Created 'dockeruser' account"
fi

# Add users to docker group
sudo groupadd docker 2>/dev/null || true  # Ignore if group exists
for user in "$USER" jenkins dockeruser; do
  if id "$user" &>/dev/null; then
    sudo usermod -aG docker "$user"
    echo "Added $user to docker group"
  fi
done

sudo usermod -aG docker ubuntu
# Restart Docker service
sudo systemctl restart docker
# ---------------------------------------------------------------------------------


# Git and maven install

sudo apt install git maven -y

# Install required packages
sudo apt-get install -y curl unzip jq

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

echo "AWS CLI installed successfully"

echo "Installing kubectl..."

# Install kubectl (official method)
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Cleanup
rm -rf aws awscliv2.zip kubectl


# Configure AWS CLI for root user (automated)
mkdir -p /root/.aws

cat <<EOF > /root/.aws/config
[default]
region = ${aws_region}
output = json
EOF

# Verify AWS CLI installation
aws --version || { echo "AWS CLI installation failed"; exit 1; }  

# Configure AWS CLI
aws configure set region ${aws_region}

# Trivy installation

echo "Installing Trivy..."

sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update -y
sudo apt-get install trivy -y

# Argocd CLI installation
echo "Installing ArgoCD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

echo "Waiting for Argocd to warmup..."
sleep 30  # Adjust as necessary for your environment

# ---------------------------------------------------------------------------------


echo "Waiting for Jenkins to start..."
sleep 30  # Adjust as necessary for your environment
# ---------------------------------------------------------------------------------
# Verify Jenkins installation
jenkins_status=$(systemctl is-active jenkins)
if [ "$jenkins_status" = "active" ]; then
  echo "Jenkins is running"
else
  echo "Jenkins is not running. Status: $jenkins_status"
  exit 1
fi
# ---------------------------------------------------------------------------------
# Wait for EKS cluster to be active
for i in {1..30}; do
  if aws eks describe-cluster --name ${eks_cluster_name} --query "cluster.status" | grep -q "ACTIVE"; then
    echo "EKS cluster is active"
    break
  fi
  echo "Waiting for EKS cluster to become active..."
  sleep 10
done
# Verify Docker installation
docker_status=$(systemctl is-active docker)
if [ "$docker_status" = "active" ]; then
  echo "Docker is running"
else
  echo "Docker is not running. Status: $docker_status"
  exit 1
fi

# Verify AWS CLI installation
aws_status=$(aws sts get-caller-identity 2>&1)
if [[ $aws_status == *"AccessDenied"* ]]; then
  echo "AWS CLI is not configured correctly. Status: $aws_status"
  exit 1
else
  echo "AWS CLI is configured correctly"
fi

# Verify kubectl installation
kubectl_status=$(kubectl version --client 2>&1)
if [[ $kubectl_status == *"Client Version"* ]]; then
  echo "kubectl is installed correctly"
else
  echo "kubectl installation failed. Status: $kubectl_status"
  exit 1
fi

# Verify Trivy installation
trivy_status=$(trivy --version 2>&1)
if [[ $trivy_status == *"Version"* ]]; then
  echo "Trivy is installed correctly"
else
  echo "Trivy installation failed. Status: $trivy_status"
  exit 1
fi

# Install Helm
echo "Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

# Configure Helm for jenkins user
sudo mkdir -p /var/lib/jenkins/.config/helm
sudo cp -r /root/.config/helm /var/lib/jenkins/.config/
sudo chown -R jenkins:jenkins /var/lib/jenkins/.config/helm

# Configure Helm for ubuntu user
sudo mkdir -p /home/ubuntu/.config/helm
sudo cp -r /root/.config/helm /home/ubuntu/.config/
sudo chown -R ubuntu:ubuntu /home/ubuntu/.config/helm
# ---------------------------------------------------------------------------------

# Update kubeconfig
aws eks update-kubeconfig --region ${aws_region} --name ${eks_cluster_name}

# Copy kubeconfig to ubuntu user's home

sudo mkdir -p /home/ubuntu/.kube
sudo cp -i /root/.kube/config /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Create .kube directory for jenkins user
sudo mkdir -p /var/lib/jenkins/.kube

# Copy kubeconfig from root to jenkins home
sudo cp -i /root/.kube/config /var/lib/jenkins/.kube/config

# Set ownership to jenkins user
sudo chown jenkins:jenkins /var/lib/jenkins/.kube/config

# (Optional) Test as jenkins user
sudo -u jenkins kubectl get nodes

# Optional: verify
sudo -u ubuntu kubectl get nodes

sudo -u jenkins kubectl get nodes
# ---------------------------------------------------------------------------------
# Wait for Jenkins to be ready
echo "Waiting for Jenkins to start..."
sleep 30  # Adjust as necessary for your environment

sudo systemctl restart jenkins
# Verify Jenkins installation
jenkins_status=$(systemctl is-active jenkins)
if [ "$jenkins_status" = "active" ]; then
  echo "Jenkins is running"
else
  echo "Jenkins is not running. Status: $jenkins_status"
  exit 1
fi
# ---------------------------------------------------------------------------------

# Verify installations

echo "=== 🚀 INSTALLATION VERIFICATION ==="

echo "🐳 Docker Version:"
docker --version || echo "❌ Docker not found"

echo "☕ Java Version:"
java --version || echo "❌ Java not found"

echo "📦 Maven Version:"
mvn --version || echo "❌ Maven not found"

echo "🌿 Git Version:"
git --version || echo "❌ Git not found"

echo "🛠️ AWS CLI Version:"
aws --version || echo "❌ AWS CLI not found"

echo "☸️ kubectl Version:"
kubectl version --client || echo "❌ kubectl not found"

echo "🔍 Trivy Version:"
trivy --version || echo "❌ Trivy not found"

echo "🔍 Argocd Version"
argocd version --client || echo "❌ argocd not found"

echo "⛵ Helm Version:"
helm version --short || echo "❌ Helm not found"


# Get Jenkins initial admin password
echo "=== JENKINS SETUP ==="
echo "Initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Could not find Jenkins password"

echo "All packages installed successfully!"
