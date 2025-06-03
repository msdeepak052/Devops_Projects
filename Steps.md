# Devops_Projects

## 1. End-to-End CI/CD Pipeline with Java Microservices

### Objective

Build a CI/CD pipeline for a Java-based microservice using:
- Maven
- SonarQube
- Nexus
- Jenkins
- Docker
- Kubernetes (EKS)
- Terraform

---

### Steps

#### Infrastructure Setup

- Use Terraform to provision AWS EKS, EC2 (for Jenkins/Nexus), and VPC.
- Deploy Nexus (for artifact storage) and SonarQube (for code quality) on EC2.

#### CI Pipeline (Jenkins)

- Checkout code → Maven build → SonarQube scan → Push JAR to Nexus.
- Build Docker image and push to ECR (AWS Container Registry).

#### CD Pipeline (Jenkins + Kubernetes)

- Deploy Docker image to EKS using kubectl/Helm.
- Use Ansible for configuration management (if needed).

---

## Project File Structure

```
Terraform-Infra/
├── aws-auth.tf
├── main.tf
├── provider.tf
├── variables.tf
├── outputs.tf
├── eks/
│   ├── main.tf
│   └── variables.tf
├── ec2/
│   ├── main.tf
│   └── variables.tf
├── vpc/
│   ├── main.tf
│   └── variables.tf
└── userdata/
    ├── jenkins.sh
    ├── nexus.sh
    ├── sonarqube.sh
    └── eks-admin.sh
```


### Root module files

#### a. main.tf

```hcl
module "vpc" {
  source = "./vpc"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = var.availability_zones
}

module "eks" {
  source = "./eks"

  cluster_name  = var.cluster_name
  k8s_version   = var.k8s_version
  subnet_ids    = module.vpc.public_subnet_ids
  desired_nodes = var.desired_nodes
  max_nodes     = var.max_nodes
  min_nodes     = var.min_nodes
  instance_type = var.eks_instance_type
    providers = {
    kubectl = kubectl
  }
}

module "ec2" {
  source = "./ec2"

  ami_id                    = var.ami_id
  instance_type             = var.ec2_instance_type
  subnet_ids                = module.vpc.public_subnet_ids
  key_name                  = var.key_name
  vpc_id                    = module.vpc.vpc_id
  eks_instance_profile_name = module.eks.eks_admin_instance_profile_name
  security_group_id_jenkins = module.vpc.jenkins_sg_id
  security_group_id_nexus   = module.vpc.nexus_sg_id
  security_group_id_sonarqube = module.vpc.sonarqube_sg_id
  security_group_id_eks_admin = module.vpc.eks_admin_sg_id

  eks_cluster_name          = var.cluster_name
  aws_region                = var.aws_region

  depends_on = [module.eks,kubectl_manifest.aws_auth]
}
```

#### b. variables.tf

```hcl
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "deepak-project1-cluster"
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "desired_nodes" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 2
}

variable "min_nodes" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "eks_instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t2.medium"
}

variable "ec2_instance_type" {
  description = "Instance type for EC2 instances"
  type        = string
  default     = "t2.medium"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0e35ddab05955cf57" # Ubuntu Machine
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
  default     = "lappynewawss"
}
```

#### c.outputs.tf

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "jenkins_instance_ip" {
  description = "Public IP of Jenkins instance"
  value       = module.ec2.jenkins_instance_ip
}

output "nexus_instance_ip" {
  description = "Public IP of Nexus instance"
  value       = module.ec2.nexus_instance_ip
}

output "sonarqube_instance_ip" {
  description = "Public IP of SonarQube instance"
  value       = module.ec2.sonarqube_instance_ip
}

output "eks_admin_instance_ip" {
  description = "Public IP of SonarQube instance"
  value       = module.ec2.eks_admin_instance_ip
}

output "aws_auth_applied" {
  value = kubectl_manifest.aws_auth.id
}
```

#### d. providers.tf

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"  # Stable version known to work
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region,
      "--output", "json"  # Explicitly request JSON output
    ]
  }
}

```

#### e. aws-auth.tf

```hcl
resource "kubectl_manifest" "aws_auth" {
  depends_on = [
    module.eks
  ]

  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${module.eks.node_role_arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${module.eks.eks_admin_ec2_role_arn}
      username: admin
      groups:
        - system:masters
YAML
}


```

### vpc modules

#### a. main.tf

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "deepak-project1-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-gw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nexus" {
  name        = "nexus-sg"
  description = "Security group for Nexus server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sonarqube" {
  name        = "sonarqube-sg"
  description = "Security group for SonarQube server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "eks-admin" {
  name        = "eks-admin-sg"
  description = "Security group for eks-admin server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


```
#### b. variables.tf

```hcl
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}
```

#### c. outputs.tf

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "jenkins_sg_id" {
  value = aws_security_group.jenkins.id
}

output "nexus_sg_id" {
  value = aws_security_group.nexus.id
}

output "sonarqube_sg_id" {
  value = aws_security_group.sonarqube.id
}

output "eks_admin_sg_id" {
  value = aws_security_group.eks-admin.id
}
```

### EKS Module Files

#### a. main.tf

```hcl
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role" "eks_admin_ec2_role" {
  name = "${var.cluster_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_instance_profile" "eks_admin_instance_profile" {
  name = "${var.cluster_name}-ec2-profile"
  role = aws_iam_role.eks_admin_ec2_role.name
}

resource "aws_iam_role_policy_attachment" "eks_admin_ec2_policy" {
  role       = aws_iam_role.eks_admin_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_eks_cluster" "deepak-eks-cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.k8s_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }

    enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

    tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
}

resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.deepak-eks-cluster.name
  node_group_name = "deepak-project1-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.desired_nodes
    max_size     = var.max_nodes
    min_size     = var.min_nodes
  }

  instance_types = [var.instance_type]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
  ]
}
```

#### b.variables.tf

```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "desired_nodes" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "max_nodes" {
  description = "Maximum number of worker nodes"
  type        = number
}

variable "min_nodes" {
  description = "Minimum number of worker nodes"
  type        = number
}

variable "instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
}

variable "tags" {
  description = "Common tags for AWS resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "eks-project"
    Owner       = "Deepak"
  }
}
```

#### c.outputs.tf

```hcl
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.deepak-eks-cluster.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = aws_eks_cluster.deepak-eks-cluster.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64 encoded certificate data for the cluster"
  value       = aws_eks_cluster.deepak-eks-cluster.certificate_authority[0].data
}

output "eks_admin_instance_profile_name" {
  value = aws_iam_instance_profile.eks_admin_instance_profile.name
}

output "node_role_arn" {
  value = aws_iam_role.eks_nodes.arn
}

output "eks_admin_ec2_role_arn" {
  value = aws_iam_role.eks_admin_ec2_role.arn
}
```

#### d.versions.tf

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
  }
}

```

#### ec2-modules

### a. main.tf

```hcl
resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.security_group_id_jenkins]
  key_name               = var.key_name
  user_data              = file("${path.module}/userdata/jenkins.sh")

  root_block_device {
    volume_size = 15
    volume_type = "gp2"
  }

  tags = {
    Name = "jenkins-server"
  }
}

resource "aws_instance" "nexus" {
  ami                    = var.ami_id
  instance_type          = "t2.medium" # Nexus requires more resources
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.security_group_id_nexus]
  key_name               = var.key_name
  user_data              = file("${path.module}/userdata/nexus.sh")

  root_block_device {
    volume_size = 10
    volume_type = "gp2"
  }

  tags = {
    Name = "nexus-server"
  }
}

resource "aws_instance" "sonarqube" {
  ami                    = var.ami_id
  instance_type          = "t2.medium" # SonarQube requires moderate resources
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.security_group_id_sonarqube]
  key_name               = var.key_name
  user_data              = file("${path.module}/userdata/sonarqube.sh")

  root_block_device {
    volume_size = 10
    volume_type = "gp2"
  }

  tags = {
    Name = "sonarqube-server"
  }
}

resource "aws_instance" "eks_admin" {
  ami                    = var.ami_id
  instance_type          = "t2.medium" # Or a larger instance type if needed
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.security_group_id_eks_admin]
  key_name               = var.key_name
  user_data = templatefile("${path.module}/userdata/eks-admin.sh", {
                eks_cluster_name = var.eks_cluster_name
                aws_region       = var.aws_region
  })
  iam_instance_profile = var.eks_instance_profile_name != null ? var.eks_instance_profile_name : null

  root_block_device {
    volume_size = 10
    volume_type = "gp2"
  }

  tags = {
    Name = "eks-admin"
  }
}

resource "aws_eip" "eks_admin" {
  instance = aws_instance.eks_admin.id
  vpc      = true
}

resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  vpc      = true
}

resource "aws_eip" "nexus" {
  instance = aws_instance.nexus.id
  vpc      = true
}

resource "aws_eip" "sonarqube" {
  instance = aws_instance.sonarqube.id
  vpc      = true
}
```

#### b. variables.tf

```hcl
variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "Instance type for EC2 instances"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "eks_instance_profile_name" {
  description = "IAM instance profile name for EKS admin EC2"
  type        = string
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "security_group_id_jenkins" {
  description = "The ID of the security group for Jenkins"
  type        = string
}

variable "security_group_id_nexus" {
  description = "The ID of the security group for Nexus"
  type        = string
}

variable "security_group_id_sonarqube" {
  description = "The ID of the security group for SonarQube"
  type        = string
}

variable "security_group_id_eks_admin" {
  description = "The ID of the security group for EKS Admin"
  type        = string
}
```

#### c.outputs.tf

```hcl
output "jenkins_instance_ip" {
  description = "Public IP of Jenkins instance"
  value       = aws_eip.jenkins.public_ip
}

output "nexus_instance_ip" {
  description = "Public IP of Nexus instance"
  value       = aws_eip.nexus.public_ip
}

output "sonarqube_instance_ip" {
  description = "Public IP of SonarQube instance"
  value       = aws_eip.sonarqube.public_ip
}

output "eks_admin_instance_ip" {
  description = "Public IP of SonarQube instance"
  value       = aws_eip.eks_admin.public_ip
}


```

#### d.userdata

#### i - jenkins.sh

```bash
#!/bin/bash

# Exit immediately if any command fails
set -e

# set -euxo pipefail   #The set -euxo pipefail in scripts helps catch such issues early
# # Install Jenkins
# sudo yum update -y
# sudo yum install wget unzip -y

# # Install Java 21 (for RHEL 10)
# sudo dnf install -y java-21-openjdk-devel

# # Configure alternatives if needed
# sudo alternatives --set java /usr/lib/jvm/java-21-openjdk-*/bin/java
# sudo alternatives --set javac /usr/lib/jvm/java-21-openjdk-*/bin/javac

# sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
# sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
# # sudo yum install jenkins java-11-openjdk-devel -y
# sudo systemctl daemon-reload
# sudo systemctl start jenkins
# sudo systemctl enable jenkins

# # Install Docker
# sudo yum install docker.io -y
# sudo systemctl start docker
# sudo systemctl enable docker
# sudo usermod -aG docker jenkins
# sudo usermod -aG docker ec2-user

# # Install other tools
# sudo yum install -y git maven

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


# Git and maven install

sudo apt install git maven -y

# Verify installations

echo "=== INSTALLATION VERIFICATION ==="
docker --version
java --version
mvn --version
git --version


# Get Jenkins initial admin password
echo "=== JENKINS SETUP ==="
echo "Initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Could not find Jenkins password"

echo "All packages installed successfully!"
echo "NOTE: Log out and back in for Docker group changes to take effect."
```

#### ii-nexus.sh

```bash
#!/bin/bash
set -e

# Variables
NEXUS_VERSION="3.80.0-06"
NEXUS_TAR="nexus-${NEXUS_VERSION}-linux-x86_64.tar.gz"
NEXUS_URL="https://download.sonatype.com/nexus/3/${NEXUS_TAR}"
INSTALL_DIR="/opt/nexus"
DATA_DIR="/opt/sonatype-work"
NEXUS_USER="nexus"

# Install dependencies
sudo apt update
sudo apt install -y openjdk-17-jdk wget tar curl

# Create nexus user
sudo useradd -m -d /home/${NEXUS_USER} -s /bin/bash ${NEXUS_USER}

# Download and extract Nexus
cd /opt
sudo wget ${NEXUS_URL}
sudo tar -xvzf ${NEXUS_TAR}
sudo mv nexus-${NEXUS_VERSION} nexus
sudo rm -f ${NEXUS_TAR}
sudo chown -R ${NEXUS_USER}:${NEXUS_USER} nexus sonatype-work || true

# Configure Nexus to run as nexus user
echo "run_as_user=${NEXUS_USER}" | sudo tee ${INSTALL_DIR}/bin/nexus.rc

# Set permissions
sudo chown -R ${NEXUS_USER}:${NEXUS_USER} ${INSTALL_DIR} ${DATA_DIR}

# Create systemd service
sudo tee /etc/systemd/system/nexus.service > /dev/null <<EOF
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
User=${NEXUS_USER}
Group=${NEXUS_USER}
ExecStart=${INSTALL_DIR}/bin/nexus start
ExecStop=${INSTALL_DIR}/bin/nexus stop
Restart=on-abort
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start Nexus
sudo systemctl daemon-reload
sudo systemctl enable nexus
sudo systemctl start nexus

# Get IPs from AWS Metadata
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "NoPublicIP")
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || echo "NoPrivateIP")

echo ""
echo "🎉 Nexus Repository installed successfully!"

PUBLIC_IP=$(curl -s ifconfig.me)
echo "🌍 Public access URL: http://${PUBLIC_IP}:8081"
echo ""
echo "⏳ Waiting for Nexus to generate the admin password..."

ADMIN_PASSWORD_FILE="/opt/sonatype-work/nexus3/admin.password"
TIMEOUT=120   # 2 minutes
WAIT=0

while [ ! -f "$ADMIN_PASSWORD_FILE" ] && [ $WAIT -lt $TIMEOUT ]; do
    sleep 5
    WAIT=$((WAIT + 5))
done

if [ -f "$ADMIN_PASSWORD_FILE" ]; then
    ADMIN_PASSWORD=$(sudo cat $ADMIN_PASSWORD_FILE)
else
    ADMIN_PASSWORD="(File not found after $TIMEOUT seconds - please check Nexus logs)"
fi

echo "🔑 Default credentials:"
echo "   Username: admin"
echo "   Password: $ADMIN_PASSWORD"

```

#### iii - sonarqube.sh

```bash
#!/bin/bash

# Exit on any error
set -e

# Variables
SONAR_USER="sonar"
SONAR_VERSION="10.5.1.90531"
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_DIR="/opt/sonarqube"
DB_NAME="sonarqube"
DB_USER="sonar"
DB_PASSWORD="StrongSonarPass123"

# Update system
sudo apt update && sudo apt install -y openjdk-17-jdk unzip wget postgresql

# Create sonar user
sudo useradd -m -d /home/$SONAR_USER -s /bin/bash $SONAR_USER

# Configure PostgreSQL
sudo -u postgres psql <<EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
EOF

# Download and extract SonarQube
cd /opt
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}
sudo unzip ${SONAR_ZIP}
sudo mv sonarqube-${SONAR_VERSION} sonarqube
sudo chown -R $SONAR_USER:$SONAR_USER $SONAR_DIR
sudo rm -f ${SONAR_ZIP}

# Configure SonarQube DB credentials
sudo sed -i "s|^#sonar.jdbc.username=.*|sonar.jdbc.username=${DB_USER}|" ${SONAR_DIR}/conf/sonar.properties
sudo sed -i "s|^#sonar.jdbc.password=.*|sonar.jdbc.password=${DB_PASSWORD}|" ${SONAR_DIR}/conf/sonar.properties
sudo sed -i "s|^#sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://localhost/${DB_NAME}|" ${SONAR_DIR}/conf/sonar.properties

# Create systemd service
sudo tee /etc/systemd/system/sonarqube.service > /dev/null <<EOF
[Unit]
Description=SonarQube service
After=network.target postgresql.service

[Service]
Type=simple
User=${SONAR_USER}
Group=${SONAR_USER}
ExecStart=${SONAR_DIR}/bin/linux-x86-64/sonar.sh start
ExecStop=${SONAR_DIR}/bin/linux-x86-64/sonar.sh stop
RemainAfterExit=yes
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Reload and start service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

echo "🎉 SonarQube installation complete!"
PUBLIC_IP=$(curl -s ifconfig.me)
echo "🌍 Public access URL: http://${PUBLIC_IP}:9000"
```

#### d.eks-admin.sh

```bash
#!/bin/bash

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install required packages
sudo apt-get install -y curl unzip jq

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

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

# Configure AWS CLI
aws configure set region ${aws_region}

# Wait for cluster to be active
for i in {1..30}; do
  if aws eks describe-cluster --name ${eks_cluster_name} --query "cluster.status" | grep -q "ACTIVE"; then
    break
  fi
  sleep 10
done



# Update kubeconfig
aws eks update-kubeconfig --region ${aws_region} --name ${eks_cluster_name}

# Copy kubeconfig to ubuntu user's home

sudo mkdir -p /home/ubuntu/.kube
sudo cp -i /root/.kube/config /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Optional: verify
sudo -u ubuntu kubectl get nodes

```
