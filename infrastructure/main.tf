# -------------------------------------------------------------------
# AWS & HELM PROVIDERS - Target: India (Mumbai)
# -------------------------------------------------------------------
provider "aws" {
  region = "ap-south-1" 
}

# -------------------------------------------------------------------
# 1. NETWORKING (VPC)
# -------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name = "lwlabs-production-vpc"
  cidr = "10.0.0.0/16"

  azs              = ["ap-south-1a", "ap-south-1b"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24"]

  create_database_subnet_group = true
  enable_nat_gateway           = true
  single_nat_gateway           = true 
}

# -------------------------------------------------------------------
# 2. CONTAINER REGISTRY (ECR)
# -------------------------------------------------------------------
resource "aws_ecr_repository" "lwlabs_app" {
  name                 = "lwlabs-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# -------------------------------------------------------------------
# 3. DATABASE (RDS MySQL)
# -------------------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = "lwlabs-rds-sg"
  description = "Allow EKS nodes to access MySQL"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = module.vpc.private_subnets_cidr_blocks
  }
}

resource "aws_db_instance" "lwlabs_db" {
  identifier             = "lwlabs-production-db"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "lwlabs_report"
  username               = "dbadmin"
  password               = "<ADD_YOUR_SECURE_DATABASE_PASSWORD_HERE>"
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
}

# -------------------------------------------------------------------
# 4. KUBERNETES CLUSTER (EKS)
# -------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "lwlabs-eks-cluster"
  cluster_version = "1.29"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    lwlabs_nodes = {
      min_size       = 2
      max_size       = 5
      desired_size   = 2
      instance_types = ["t3.medium"]
    }
  }
}

# -------------------------------------------------------------------
# 5. AUTO-SCALING ENGINE (Metrics Server via Helm)
# -------------------------------------------------------------------
# Get cluster authentication details to configure the Helm provider
data "aws_eks_cluster" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Install the Metrics Server automatically
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  depends_on = [module.eks]

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}

# -------------------------------------------------------------------
# OUTPUTS
# -------------------------------------------------------------------
output "ecr_repository_url" {
  value = aws_ecr_repository.lwlabs_app.repository_url
}
output "rds_endpoint" {
  value = aws_db_instance.lwlabs_db.endpoint
}
output "eks_cluster_name" {
  value = module.eks.cluster_name
}