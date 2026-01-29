# Blackstone VPC MySQL Database Solution

# Provider Configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC Configuration
resource "aws_vpc" "blackstone_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Blackstone_vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "blackstone_igw" {
  vpc_id = aws_vpc.blackstone_vpc.id

  tags = {
    Name = "Blackstone_IGW"
  }
}

# Public Subnets (for bastion host or application tier)
resource "aws_subnet" "blackstone_public_subnet_1" {
  vpc_id                  = aws_vpc.blackstone_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Blackstone_Public_Subnet_1"
  }
}

resource "aws_subnet" "blackstone_public_subnet_2" {
  vpc_id                  = aws_vpc.blackstone_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Blackstone_Public_Subnet_2"
  }
}

# Private Subnets (for RDS MySQL)
resource "aws_subnet" "blackstone_private_subnet_1" {
  vpc_id            = aws_vpc.blackstone_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Blackstone_Private_Subnet_1"
  }
}

resource "aws_subnet" "blackstone_private_subnet_2" {
  vpc_id            = aws_vpc.blackstone_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Blackstone_Private_Subnet_2"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "blackstone_public_rt" {
  vpc_id = aws_vpc.blackstone_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.blackstone_igw.id
  }

  tags = {
    Name = "Blackstone_Public_RT"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.blackstone_public_subnet_1.id
  route_table_id = aws_route_table.blackstone_public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.blackstone_public_subnet_2.id
  route_table_id = aws_route_table.blackstone_public_rt.id
}

# Security Group for RDS MySQL
resource "aws_security_group" "blackstone_rds_sg" {
  name        = "blackstone_rds_sg"
  description = "Security group for Blackstone RDS MySQL instance"
  vpc_id      = aws_vpc.blackstone_vpc.id

  ingress {
    description = "MySQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.blackstone_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Blackstone_RDS_SG"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "blackstone_db_subnet_group" {
  name       = "blackstone-db-subnet-group"
  subnet_ids = [
    aws_subnet.blackstone_private_subnet_1.id,
    aws_subnet.blackstone_private_subnet_2.id
  ]

  tags = {
    Name = "Blackstone_DB_Subnet_Group"
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "blackstone_mysql" {
  identifier             = "blackstone-mysql-db"
  engine                 = "mysql"
  engine_version         = "8.0.39"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = "blackstonedb"
  username               = "admin"
  password               = "ChangeMe123!"  # Change this to a secure password
  db_subnet_group_name   = aws_db_subnet_group.blackstone_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.blackstone_rds_sg.id]
  
  # Backup and Maintenance
  backup_retention_period = 0  # 0 for free tier, 1-35 for paid
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  # Multi-AZ for high availability
  multi_az = false  # Set to true for production
  
  # Deletion protection
  skip_final_snapshot       = true  # Set to false for production
  deletion_protection       = false # Set to true for production
  
  # Enable automated minor version upgrades
  auto_minor_version_upgrade = true
  
  # Storage autoscaling
  max_allocated_storage = 100

  tags = {
    Name = "Blackstone_MySQL_DB"
  }
}

# Outputs
output "blackstone_vpc_id" {
  description = "Blackstone VPC ID"
  value       = aws_vpc.blackstone_vpc.id
}

output "blackstone_rds_endpoint" {
  description = "Blackstone RDS MySQL endpoint"
  value       = aws_db_instance.blackstone_mysql.endpoint
}

output "blackstone_rds_port" {
  description = "Blackstone RDS MySQL port"
  value       = aws_db_instance.blackstone_mysql.port
}

output "blackstone_database_name" {
  description = "Blackstone Database name"
  value       = aws_db_instance.blackstone_mysql.db_name
}
