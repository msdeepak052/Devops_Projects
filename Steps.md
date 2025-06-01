### 1. End-to-End CI/CD Pipeline with Java Microservices

Objective:
Build a CI/CD pipeline for a Java-based microservice using Maven, SonarQube, Nexus, Jenkins, Docker, Kubernetes (EKS), and Terraform.

Steps:

    Infrastructure Setup:
        Use Terraform to provision AWS EKS, EC2 (for Jenkins/Nexus), and VPC.
        Deploy Nexus (for artifact storage) and SonarQube (for code quality) on EC2.
    CI Pipeline (Jenkins):
        Checkout code → Maven build → SonarQube scan → Push JAR to Nexus.
        Build Docker image and push to ECR (AWS Container Registry).
    CD Pipeline (Jenkins + Kubernetes):
        Deploy Docker image to EKS using kubectl/Helm.
        Use Ansible for configuration management (if needed).

#### Folder structure

```bash
Project 1 - terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── eks/
│   ├── main.tf
│   └── variables.tf
├── ec2/
│   ├── main.tf
│   └── variables.tf
└── vpc/
    ├── main.tf
    └── variables.tf
```

### Root module files

#### a. main.tf

```hcl
provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./vpc"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = var.availability_zones
}

module "eks" {
  source = "./eks"

  cluster_name    = var.cluster_name
  k8s_version     = var.k8s_version
  subnet_ids      = module.vpc.public_subnet_ids
  desired_nodes   = var.desired_nodes
  max_nodes       = var.max_nodes
  min_nodes       = var.min_nodes
  instance_type   = var.eks_instance_type
}

module "ec2" {
  source = "./ec2"

  ami_id         = var.ami_id
  instance_type  = var.ec2_instance_type
  subnet_ids     = module.vpc.public_subnet_ids
  key_name       = var.key_name
  vpc_id         = module.vpc.vpc_id
}
```

#### b. variables.tf

```hcl
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
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
  default     = ["us-east-1a", "us-east-1b"]
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "microservices-cluster"
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.24"
}

variable "desired_nodes" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "min_nodes" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "eks_instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "ec2_instance_type" {
  description = "Instance type for EC2 instances"
  type        = string
  default     = "t3.large"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Amazon Linux 2
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
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
```

### vpc modules

#### a. main.tf

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "microservices-vpc"
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

resource "aws_eks_cluster" "microservices" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.k8s_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }

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
  cluster_name    = aws_eks_cluster.microservices.name
  node_group_name = "microservices-nodes"
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
```

#### c.variables.tf

```hcl
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.microservices.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = aws_eks_cluster.microservices.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64 encoded certificate data for the cluster"
  value       = aws_eks_cluster.microservices.certificate_authority[0].data
}
```

#### ec2-modules

### a. main.tf

```hcl
resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  key_name               = var.key_name
  user_data              = file("${path.module}/userdata/jenkins.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }

  tags = {
    Name = "jenkins-server"
  }
}

resource "aws_instance" "nexus" {
  ami                    = var.ami_id
  instance_type          = "t3.xlarge" # Nexus requires more resources
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.nexus.id]
  key_name               = var.key_name
  user_data              = file("${path.module}/userdata/nexus.sh")

  root_block_device {
    volume_size = 50
    volume_type = "gp2"
  }

  tags = {
    Name = "nexus-server"
  }
}

resource "aws_instance" "sonarqube" {
  ami                    = var.ami_id
  instance_type          = "t3.medium" # SonarQube requires moderate resources
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.sonarqube.id]
  key_name               = var.key_name
  user_data              = file("${path.module}/userdata/sonarqube.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }

  tags = {
    Name = "sonarqube-server"
  }
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
```

#### d.userdata

#### i - jenkins.sh

```bash
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
```

#### ii-nexus.sh

```bash
#!/bin/bash
# Install Nexus
sudo yum update -y
sudo yum install java-11-openjdk-devel -y

NEXUS_VERSION="3.37.3-02"
sudo mkdir -p /opt/nexus
sudo wget https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz -P /tmp
sudo tar xzf /tmp/nexus-${NEXUS_VERSION}-unix.tar.gz -C /opt/nexus --strip-components=1
sudo rm /tmp/nexus-${NEXUS_VERSION}-unix.tar.gz

# Create nexus user
sudo useradd nexus
sudo chown -R nexus:nexus /opt/nexus

# Configure Nexus
sudo sed -i 's|#run_as_user=""|run_as_user="nexus"|g' /opt/nexus/bin/nexus.rc
sudo sed -i 's|-Xms2703m|-Xms2g|g' /opt/nexus/bin/nexus.vmoptions
sudo sed -i 's|-Xmx2703m|-Xmx4g|g' /opt/nexus/bin/nexus.vmoptions

# Create systemd service
cat <<EOF | sudo tee /etc/systemd/system/nexus.service
[Unit]
Description=nexus service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start nexus
sudo systemctl enable nexus
```

#### iii - sonarqube.sh

```bash
#!/bin/bash
# Install SonarQube
sudo yum update -y
sudo yum install java-11-openjdk-devel -y

# Install PostgreSQL
sudo amazon-linux-extras install postgresql10 -y
sudo yum install postgresql-server postgresql-devel -y
sudo postgresql-setup initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Configure PostgreSQL
sudo -u postgres psql -c "CREATE USER sonarqube WITH PASSWORD 'sonarqube';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonarqube;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;"

# Download and install SonarQube
SONAR_VERSION="9.4.0.54424"
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip -P /tmp
sudo unzip /tmp/sonarqube-${SONAR_VERSION}.zip -d /opt
sudo mv /opt/sonarqube-${SONAR_VERSION} /opt/sonarqube
sudo rm /tmp/sonarqube-${SONAR_VERSION}.zip

# Configure SonarQube
sudo sed -i 's|#sonar.jdbc.username=|sonar.jdbc.username=sonarqube|g' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's|#sonar.jdbc.password=|sonar.jdbc.password=sonarqube|g' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's|#sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube|sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube|g' /opt/sonarqube/conf/sonar.properties

# Create sonarqube user
sudo useradd sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Create systemd service
cat <<EOF | sudo tee /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start sonarqube
sudo systemctl enable sonarqube
```
