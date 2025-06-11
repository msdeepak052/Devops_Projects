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

# output "eks_admin_instance_ip" {
#   description = "Public IP of SonarQube instance"
#   value       = module.ec2.eks_admin_instance_ip
# }

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.ecr_repository_url
}

output "aws_auth_applied" {
  value = kubectl_manifest.aws_auth.id
}