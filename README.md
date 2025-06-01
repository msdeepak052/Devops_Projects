# Devops_Projects

### **1. End-to-End CI/CD Pipeline with Java Microservices**
**Objective:**  
Build a CI/CD pipeline for a Java-based microservice using Maven, SonarQube, Nexus, Jenkins, Docker, Kubernetes (EKS), and Terraform.  

**Steps:**  
- **Infrastructure Setup:**  
  - Use **Terraform** to provision AWS EKS, EC2 (for Jenkins/Nexus), and VPC.  
  - Deploy **Nexus** (for artifact storage) and **SonarQube** (for code quality) on EC2.  
- **CI Pipeline (Jenkins):**  
  - Checkout code → **Maven build** → **SonarQube scan** → Push JAR to **Nexus**.  
  - Build **Docker image** and push to **ECR (AWS Container Registry)**.  
- **CD Pipeline (Jenkins + Kubernetes):**  
  - Deploy Docker image to **EKS** using **kubectl/Helm**.  
  - Use **Ansible** for configuration management (if needed).  

---

### **2. Infrastructure as Code (IaC) with Terraform & Ansible**  
**Objective:**  
Automate AWS infrastructure provisioning and configuration using Terraform and Ansible.  

**Steps:**  
- **Terraform:**  
  - Provision **EKS cluster, VPC, IAM roles, EC2 (Jenkins/Nexus/SonarQube)**.  
- **Ansible:**  
  - Configure Jenkins, Nexus, SonarQube on EC2.  
  - Install Docker, kubectl, Maven, and other tools.  

---

### **3. Kubernetes Blue-Green Deployment on EKS**  
**Objective:**  
Implement **Blue-Green deployment** for a Spring Boot app on **EKS** using Jenkins.  

**Steps:**  
- Use **Terraform** to set up EKS.  
- Jenkins pipeline:  
  - Build → Test → Deploy **v1 (Blue)** → Test → Switch traffic to **v2 (Green)**.  
- Use **kubectl/Helm** for deployment.  

---

### **4. Automated Security Scanning in CI/CD**  
**Objective:**  
Integrate **SonarQube + Trivy (for Docker) + OWASP Dependency-Check** in Jenkins.  

**Steps:**  
- Jenkins pipeline:  
  - **Maven build** → **SonarQube scan** → **Dependency-Check** → **Trivy scan (Docker image)** → Deploy to EKS.  

---

### **5. Self-Healing Kubernetes Cluster on AWS**  
**Objective:**  
Deploy a **self-healing** app on EKS using Jenkins, Prometheus, and Terraform.  

**Steps:**  
- **Terraform** provisions EKS + Auto Scaling.  
- Jenkins deploys a **Flask/Python app** with **liveness/readiness probes**.  
- Use **Prometheus + Grafana** for monitoring.  

---

### **6. Multi-Branch Pipeline for GitOps**  
**Objective:**  
Implement **GitOps** using Jenkins multi-branch pipelines and Kubernetes.  

**Steps:**  
- Jenkins detects **Git branches** → Builds & deploys to **different EKS namespaces** (dev/stage/prod).  
- Use **Helm charts** for Kubernetes deployments.  

---

### **7. Serverless CI/CD with Jenkins on EKS (Jenkins in Kubernetes)**  
**Objective:**  
Run **Jenkins inside EKS** (instead of EC2) for a cloud-native CI/CD.  

**Steps:**  
- **Terraform** provisions EKS.  
- Deploy **Jenkins in Kubernetes** using Helm.  
- Pipeline: Build → Scan → Deploy to EKS.  

---

### **8. Immutable Infrastructure with Packer + Ansible + Terraform**  
**Objective:**  
Build **immutable infrastructure** using Packer (for AMI), Ansible, and Terraform.  

**Steps:**  
- **Packer + Ansible** → Create a custom AMI with Jenkins/Docker.  
- **Terraform** → Deploy infrastructure using the AMI.  

---

### **9. Canary Deployments on EKS using Istio**  
**Objective:**  
Implement **Canary deployments** on EKS using **Istio (Service Mesh)**.  

**Steps:**  
- **Terraform** provisions EKS.  
- Jenkins deploys **v1 (90% traffic)** → **v2 (10% traffic)** → Gradually shift traffic.  

---

### **10. Disaster Recovery Setup for Kubernetes**  
**Objective:**  
Automate **backup & recovery** of Kubernetes resources.  

**Steps:**  
- Use **Velero** to backup EKS cluster.  
- **Jenkins pipeline** triggers backups periodically.  
- **Terraform** recreates EKS if needed.  

---

### **Common Tools Used Across Projects:**  
| **Tool**         | **Purpose**                          |
|------------------|-------------------------------------|
| **Linux**        | Base OS for Jenkins/Nexus/SonarQube |
| **Maven**        | Java project build tool             |
| **SonarQube**    | Static code analysis                |
| **Nexus**        | Artifact repository                |
| **AWS**          | Cloud provider (EKS, EC2, ECR, etc.) |
| **Jenkins**      | CI/CD automation                   |
| **Kubernetes (EKS)** | Container orchestration          |
| **Terraform**    | Infrastructure as Code (IaC)       |
| **Ansible**      | Configuration management           |
| **Docker**       | Containerization                   |

---
