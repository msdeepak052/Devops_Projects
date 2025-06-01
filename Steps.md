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
