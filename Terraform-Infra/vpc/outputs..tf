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