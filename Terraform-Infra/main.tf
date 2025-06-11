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

module "ecr" {
  source = "./ecr"

  name_ecr              = var.name_ecr
  enable_immutable_tags = var.enable_immutable_tags
  ecr_tags              = var.ecr_tags

}


module "ec2" {
  source = "./ec2"

  ami_id                      = var.ami_id
  instance_type               = var.ec2_instance_type
  subnet_ids                  = module.vpc.public_subnet_ids
  key_name                    = var.key_name
  vpc_id                      = module.vpc.vpc_id
  security_group_id_jenkins   = module.vpc.jenkins_sg_id
  security_group_id_nexus     = module.vpc.nexus_sg_id
  security_group_id_sonarqube = module.vpc.sonarqube_sg_id
  security_group_id_eks_admin = module.vpc.eks_admin_sg_id

  cluster_name = var.cluster_name
  aws_region   = var.aws_region

  depends_on = [module.eks, module.ecr]
}