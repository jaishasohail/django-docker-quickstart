# AWS Configuration
aws_region = "us-east-1"

# Project Configuration
project_name = "django-app"
environment  = "dev"

# Network Configuration
vpc_cidr              = "10.0.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
database_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

# NAT Gateway Configuration
enable_nat_gateway = true
single_nat_gateway = true

# RDS Configuration
db_instance_class     = "db.t3.micro"
db_allocated_storage  = 20
db_engine_version     = ""
db_name               = "django_app_db"
db_username           = "dbadmin"
db_password           = "luffyandsa123"  # Use AWS Secrets Manager in production

# EKS Configuration
# EKS Configuration
eks_cluster_version      = "1.28"
eks_node_instance_types  = ["t3.medium"]
eks_desired_size         = 2
eks_min_size             = 1
eks_max_size             = 4
