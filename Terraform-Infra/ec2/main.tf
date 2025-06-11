resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.security_group_id_jenkins]
  key_name               = var.key_name
  //user_data              = file("${path.module}/userdata/jenkins.sh")

    user_data = templatefile("${path.module}/userdata/jenkins.sh", {
                eks_cluster_name = var.cluster_name
                aws_region       = var.aws_region
  })

  
  # Use the instance profile for ECR access
  iam_instance_profile   = aws_iam_instance_profile.jenkins_instance_profile.name


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

# resource "aws_instance" "eks_admin" {
#   ami                    = var.ami_id
#   instance_type          = "t2.medium" # Or a larger instance type if needed
#   subnet_id              = var.subnet_ids[0]
#   vpc_security_group_ids = [var.security_group_id_eks_admin]
#   key_name               = var.key_name
#   user_data = templatefile("${path.module}/userdata/eks-admin.sh", {
#                 eks_cluster_name = var.eks_cluster_name
#                 aws_region       = var.aws_region
#   })
#   iam_instance_profile = var.eks_instance_profile_name != null ? var.eks_instance_profile_name : null

#   root_block_device {
#     volume_size = 10
#     volume_type = "gp2"
#   }

#   tags = {
#     Name = "eks-admin"
#   }
# }

# resource "aws_eip" "eks_admin" {
#   instance = aws_instance.eks_admin.id
#   vpc      = true
# }

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