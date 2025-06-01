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

End-to-End CI/CD Pipeline for Java Microservices

This guide provides a comprehensive walkthrough for setting up a complete CI/CD pipeline for Java-based microservices using modern DevOps tools and practices.
Table of Contents

    Infrastructure Setup with Terraform

    EC2 Instance Configuration with Ansible

    Jenkins Setup and Configuration

    Nexus Repository Setup

    SonarQube Setup

    CI Pipeline Implementation

    CD Pipeline Implementation

    Monitoring and Maintenance

1. Infrastructure Setup with Terraform
1.1 Prerequisites

    AWS account with appropriate permissions

    Terraform installed locally

    AWS CLI configured

1.2 Terraform Directory Structure

terraform/
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

1.3 VPC Configuration (vpc/main.tf)
hcl

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

1.4 EKS Cluster Setup (eks/main.tf)
hcl

resource "aws_eks_cluster" "microservices" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.k8s_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
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

1.5 EC2 Instances for Jenkins/Nexus/SonarQube (ec2/main.tf)
hcl

resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  key_name               = var.key_name
  user_data              = file("${path.module}/userdata/jenkins.sh")

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

  tags = {
    Name = "sonarqube-server"
  }
}

1.6 Apply Terraform Configuration
bash

terraform init
terraform plan -out=tfplan
terraform apply tfplan

2. EC2 Instance Configuration with Ansible
2.1 Ansible Directory Structure

ansible/
├── inventory/
│   ├── production
│   └── staging
├── group_vars/
│   ├── all.yml
│   ├── jenkins.yml
│   ├── nexus.yml
│   └── sonarqube.yml
├── roles/
│   ├── common/
│   ├── jenkins/
│   ├── nexus/
│   └── sonarqube/
└── playbooks/
    ├── setup_all.yml
    ├── setup_jenkins.yml
    ├── setup_nexus.yml
    └── setup_sonarqube.yml

2.2 Common Setup (roles/common/tasks/main.yml)
yaml

- name: Update apt package index
  apt:
    update_cache: yes
    cache_valid_time: 3600

- name: Install common packages
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - curl
    - wget
    - unzip
    - git
    - python3-pip
    - openjdk-11-jdk
    - maven
    - docker.io
    - docker-compose

- name: Add current user to docker group
  user:
    name: "{{ ansible_user }}"
    groups: docker
    append: yes

- name: Start and enable Docker service
  service:
    name: docker
    state: started
    enabled: yes

- name: Install AWS CLI
  pip:
    name: awscli
    state: present

- name: Install kubectl
  shell: |
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
  args:
    warn: no

- name: Install helm
  shell: |
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  args:
    warn: no

2.3 Jenkins Setup (roles/jenkins/tasks/main.yml)
yaml

- name: Add Jenkins repository key
  apt_key:
    url: https://pkg.jenkins.io/debian-stable/jenkins.io.key
    state: present

- name: Add Jenkins repository
  apt_repository:
    repo: "deb https://pkg.jenkins.io/debian-stable binary/"
    state: present
    filename: jenkins

- name: Install Jenkins
  apt:
    name: jenkins
    state: present
    update_cache: yes

- name: Start Jenkins service
  service:
    name: jenkins
    state: started
    enabled: yes

- name: Wait for Jenkins to start
  uri:
    url: http://localhost:8080
    status_code: 403
    timeout: 300
  register: result
  until: result.status == 403
  retries: 30
  delay: 10

- name: Get initial admin password
  shell: cat /var/lib/jenkins/secrets/initialAdminPassword
  register: jenkins_initial_password

- debug:
    msg: "Jenkins initial admin password: {{ jenkins_initial_password.stdout }}"

- name: Install Jenkins plugins
  jenkins_plugin:
    name: "{{ item }}"
    state: present
    jenkins_home: /var/lib/jenkins
    url: http://localhost:8080
    timeout: 60
  loop:
    - git
    - workflow-aggregator
    - blueocean
    - pipeline-aws
    - docker-workflow
    - kubernetes
    - sonarqube-scanner
    - nexus-artifact-uploader
    - ansible
    - pipeline-utility-steps

2.4 Nexus Setup (roles/nexus/tasks/main.yml)
yaml

- name: Create nexus user
  user:
    name: nexus
    shell: /bin/bash
    system: yes

- name: Create nexus directories
  file:
    path: "{{ item }}"
    state: directory
    owner: nexus
    group: nexus
  loop:
    - /opt/nexus
    - /opt/sonatype-work

- name: Download Nexus
  get_url:
    url: https://download.sonatype.com/nexus/3/latest-unix.tar.gz
    dest: /tmp/nexus.tar.gz
    mode: 0755

- name: Extract Nexus
  unarchive:
    src: /tmp/nexus.tar.gz
    dest: /opt/
    remote_src: yes
    extra_opts: "--strip-components=1"
    owner: nexus
    group: nexus

- name: Configure Nexus
  template:
    src: nexus.vmoptions.j2
    dest: /opt/nexus/bin/nexus.vmoptions
    owner: nexus
    group: nexus

- name: Create systemd service for Nexus
  template:
    src: nexus.service.j2
    dest: /etc/systemd/system/nexus.service
    owner: root
    group: root
    mode: 0644

- name: Reload systemd and start Nexus
  systemd:
    daemon_reload: yes
    name: nexus.service
    state: started
    enabled: yes

2.5 SonarQube Setup (roles/sonarqube/tasks/main.yml)
yaml

- name: Add SonarQube repository
  apt_repository:
    repo: "deb https://downloads.sonarsource.com/sonarqube-deb/ stable main"
    state: present
    filename: sonarqube
    key_url: https://downloads.sonarsource.com/sonarqube-deb/sonarqube-deb-public-key.asc

- name: Install SonarQube
  apt:
    name: sonarqube
    state: present
    update_cache: yes

- name: Configure SonarQube
  template:
    src: sonar.properties.j2
    dest: /etc/sonarqube/sonar.properties
    owner: sonarqube
    group: sonarqube

- name: Start SonarQube service
  service:
    name: sonarqube
    state: started
    enabled: yes

- name: Wait for SonarQube to start
  uri:
    url: http://localhost:9000
    status_code: 200
    timeout: 300
  register: result
  until: result.status == 200
  retries: 30
  delay: 10

2.6 Running Ansible Playbooks
bash

# Install common packages on all servers
ansible-playbook -i inventory/production playbooks/setup_all.yml

# Setup Jenkins
ansible-playbook -i inventory/production playbooks/setup_jenkins.yml

# Setup Nexus
ansible-playbook -i inventory/production playbooks/setup_nexus.yml

# Setup SonarQube
ansible-playbook -i inventory/production playbooks/setup_sonarqube.yml

3. Jenkins Setup and Configuration
3.1 Initial Jenkins Setup

    Access Jenkins at http://<jenkins-server-ip>:8080

    Unlock Jenkins using the initial admin password (from Ansible output)

    Install suggested plugins

    Create admin user

3.2 Configure System Settings

    Navigate to Manage Jenkins → Configure System

    Configure JDK:

        Name: jdk11

        JAVA_HOME: /usr/lib/jvm/java-11-openjdk-amd64

    Configure Maven:

        Name: maven3

        MAVEN_HOME: /usr/share/maven

3.3 Install Additional Plugins

    Navigate to Manage Jenkins → Manage Plugins → Available

    Install:

        Kubernetes CLI

        Pipeline: AWS Steps

        Docker Pipeline

        Ansible

3.4 Configure Credentials

    Navigate to Manage Jenkins → Manage Credentials

    Add the following credentials:

        AWS IAM credentials (for ECR access)

        Docker Hub credentials (if needed)

        GitHub credentials (for source code access)

        Nexus credentials (admin user)

        SonarQube token

3.5 Configure Kubernetes Cloud

    Navigate to Manage Jenkins → Configure System

    Under Cloud section, add Kubernetes cloud

    Configure with EKS cluster details (kubeconfig from Terraform output)

4. Nexus Repository Setup
4.1 Initial Setup

    Access Nexus at http://<nexus-server-ip>:8081

    Login with default credentials (admin/admin123)

    Change admin password

4.2 Create Repositories

    Navigate to Repository → Repositories

    Create the following repositories:

        maven-releases (hosted, release)

        maven-snapshots (hosted, snapshot)

        maven-central (proxy, https://repo1.maven.org/maven2/)

        maven-public (group, includes the above repositories)

4.3 Create Deployment User

    Navigate to Security → Users → Create user

    Create a user with deployment privileges

    Assign appropriate roles (nx-deploy for deployment)

5. SonarQube Setup
5.1 Initial Setup

    Access SonarQube at http://<sonarqube-server-ip>:9000

    Login with admin/admin

    Change admin password

5.2 Install Plugins

    Navigate to Administration → Marketplace

    Install:

        SonarJava

        SonarJS

        SonarXML

        SonarHTML

5.3 Generate Token

    Navigate to Administration → Security → Users

    Generate token for Jenkins integration

5.4 Configure Quality Gates

    Navigate to Quality Gates

    Create appropriate quality gates for your projects

6. CI Pipeline Implementation
6.1 Jenkinsfile for Java Microservice
groovy

pipeline {
    agent any
    
    environment {
        APP_NAME = "order-service"
        VERSION = "1.0.${BUILD_NUMBER}"
        DOCKER_IMAGE = "123456789012.dkr.ecr.us-east-1.amazonaws.com/${APP_NAME}:${VERSION}"
        NEXUS_URL = "http://nexus-server:8081"
        SONARQUBE_URL = "http://sonarqube-server:9000"
        AWS_REGION = "us-east-1"
        EKS_CLUSTER = "microservices-cluster"
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', 
                    url: 'https://github.com/your-org/order-service.git'
            }
        }
        
        stage('Build with Maven') {
            steps {
                sh 'mvn clean package'
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh 'mvn sonar:sonar'
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        stage('Upload to Nexus') {
            steps {
                nexusArtifactUploader(
                    nexusVersion: 'nexus3',
                    protocol: 'http',
                    nexusUrl: "${NEXUS_URL}",
                    groupId: 'com.yourcompany',
                    version: "${VERSION}",
                    repository: 'maven-releases',
                    credentialsId: 'nexus-credentials',
                    artifacts: [
                        [artifactId: "${APP_NAME}",
                        classifier: '',
                        file: "target/${APP_NAME}-${VERSION}.jar",
                        type: 'jar']
                    ]
                )
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    docker.withRegistry('https://123456789012.dkr.ecr.us-east-1.amazonaws.com', 'ecr:us-east-1:aws-credentials') {
                        def customImage = docker.build("${DOCKER_IMAGE}", "--build-arg JAR_FILE=target/${APP_NAME}-${VERSION}.jar .")
                        customImage.push()
                    }
                }
            }
        }
    }
    
    post {
        success {
            slackSend(color: 'good', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'")
        }
        failure {
            slackSend(color: 'danger', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'")
        }
    }
}

6.2 Dockerfile for Java Microservice
dockerfile

FROM openjdk:11-jre-slim
ARG JAR_FILE
COPY ${JAR_FILE} app.jar
ENTRYPOINT ["java","-jar","/app.jar"]

6.3 SonarQube Properties in pom.xml
xml

<properties>
    <sonar.host.url>http://sonarqube-server:9000</sonar.host.url>
    <sonar.login>${env.SONAR_AUTH_TOKEN}</sonar.login>
    <sonar.projectKey>order-service</sonar.projectKey>
    <sonar.projectName>Order Service</sonar.projectName>
    <sonar.projectVersion>1.0</sonar.projectVersion>
    <sonar.sourceEncoding>UTF-8</sonar.sourceEncoding>
    <sonar.java.binaries>target/classes</sonar.java.binaries>
    <sonar.java.libraries>target/*.jar</sonar.java.libraries>
    <sonar.java.source>11</sonar.java.source>
</properties>

7. CD Pipeline Implementation
7.1 Kubernetes Deployment Files
deployment.yaml
yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  labels:
    app: order-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/order-service:1.0.${BUILD_NUMBER}
        ports:
        - containerPort: 8080
        envFrom:
        - configMapRef:
            name: order-service-config
        - secretRef:
            name: order-service-secrets
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1024Mi"
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 5

service.yaml
yaml

apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  selector:
    app: order-service
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080

ingress.yaml
yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: order-service-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: orders.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: order-service
            port:
              number: 80

7.2 CD Pipeline Extension to Jenkinsfile
groovy

stage('Deploy to EKS') {
    steps {
        script {
            // Configure kubectl
            withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                sh "aws eks --region ${AWS_REGION} update-kubeconfig --name ${EKS_CLUSTER}"
            }
            
            // Deploy to Kubernetes
            sh "sed -i 's/\\\${BUILD_NUMBER}/${BUILD_NUMBER}/g' k8s/deployment.yaml"
            sh "kubectl apply -f k8s/deployment.yaml"
            sh "kubectl apply -f k8s/service.yaml"
            
            // Only apply ingress in production
            if (env.BRANCH_NAME == 'main') {
                sh "kubectl apply -f k8s/ingress.yaml"
            }
            
            // Verify deployment
            sh "kubectl rollout status deployment/order-service --timeout=300s"
        }
    }
}

7.3 Helm Chart Alternative

For more complex deployments, consider using Helm:
Chart Structure

order-service/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── charts/

Helm Deployment Stage
groovy

stage('Helm Deploy') {
    steps {
        script {
            withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                sh "aws eks --region ${AWS_REGION} update-kubeconfig --name ${EKS_CLUSTER}"
                sh "helm upgrade --install order-service ./order-service-chart \
                    --set image.repository=123456789012.dkr.ecr.us-east-1.amazonaws.com/order-service \
                    --set image.tag=1.0.${BUILD_NUMBER} \
                    --namespace ${env.BRANCH_NAME}"
            }
        }
    }
}

8. Monitoring and Maintenance
8.1 Monitoring Setup

    Prometheus & Grafana:

        Deploy monitoring stack using Helm:
        bash

        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm install prometheus prometheus-community/kube-prometheus-stack

    Application Metrics:

        Add Spring Boot Actuator for Java services

        Configure Prometheus to scrape metrics

8.2 Logging Setup

    EFK Stack:

        Deploy Elasticsearch, Fluentd, and Kibana for centralized logging

    CloudWatch:

        Configure AWS CloudWatch logs for EKS clusters

8.3 Maintenance Tasks

    Regular Updates:

        Schedule regular maintenance windows for tool updates

        Keep Terraform modules up-to-date

    Backup Strategies:

        Backup Jenkins configuration regularly

        Implement Nexus blob store backups

        Backup SonarQube database

8.4 Security Considerations

    Network Security:

        Restrict access to Jenkins/Nexus/SonarQube with security groups

        Implement VPC endpoints for AWS services

    Authentication:

        Integrate Jenkins with LDAP/Active Directory

        Configure SSO for Nexus and SonarQube

    Secret Management:

        Use AWS Secrets Manager or HashiCorp Vault for sensitive data

        Implement Kubernetes secrets properly

Conclusion

This comprehensive CI/CD pipeline provides a robust foundation for deploying Java microservices to AWS EKS. The combination of Terraform for infrastructure as code, Ansible for configuration management, Jenkins for orchestration, and Kubernetes for deployment creates a scalable and maintainable system. The pipeline ensures code quality through SonarQube analysis, artifact management through Nexus, and reliable deployments through Kubernetes.

For production environments, consider adding:

    Canary deployments

    Blue-green deployments

    Automated rollback mechanisms

    More sophisticated monitoring and alerting

    Security scanning in the pipeline (e.g., OWASP Dependency Check, Clair for container scanning)

This pipeline can be extended and customized based on specific organizational requirements and the complexity of your microservices architecture.
This response is AI-generated, for reference only.
