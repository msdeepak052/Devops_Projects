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

# output "eks_admin_instance_ip" {
#   description = "Public IP of SonarQube instance"
#   value       = aws_eip.eks_admin.public_ip
# }

output "jenkins_role_arn" {
  value = aws_iam_role.jenkins_combined_role.arn
}


