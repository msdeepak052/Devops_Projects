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
variable "name_ecr" {
  description = "Name of the ECR repository"
  type        = string
  default     = "app/tour-travels-webapp"
}
variable "enable_immutable_tags" {
  description = "Enable immutable tags for ECR repository"
  type        = bool
  default     = false
}

variable "ecr_tags" {
  description = "Tags for the ECR repository"
  type        = map(string)
  default = {
    Environment = "Production"
    Project     = "Tour Travels Web App"
  }
}

variable "eks_admin_instance_profile_name" {
  description = "Name of the EKS admin instance profile"
  type        = string
  default     = "eks-admin-instance-profile"
}