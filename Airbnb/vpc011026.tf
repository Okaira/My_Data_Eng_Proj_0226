# VPC Configuration for Relational Database
resource "aws_vpc" "db_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "db-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "db_igw" {
  vpc_id = aws_vpc.db_vpc.id

  tags = {
    Name = "db-igw"
  }
}

# Public Subnets (for NAT Gateway and Bastion)
resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.db_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "db-public-subnet-az1"
  }
}

resource "aws_subnet" "public_subnet_az2" {
  vpc_id                  = aws_vpc.db_vpc.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "db-public-subnet-az2"
  }
}

# Private Subnets (for Database)
resource "aws_subnet" "private_subnet_az1" {
  vpc_id            = aws_vpc.db_vpc.id
  cidr_block        = "10.1.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "db-private-subnet-az1"
  }
}

resource "aws_subnet" "private_subnet_az2" {
  vpc_id            = aws_vpc.db_vpc.id
  cidr_block        = "10.1.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "db-private-subnet-az2"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "db-nat-eip"
  }

  depends_on = [aws_internet_gateway.db_igw]
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_az1.id

  tags = {
    Name = "db-nat-gateway"
  }

  depends_on = [aws_internet_gateway.db_igw]
}

# Public Route Table
resource "aws_route_table" "db_public_rtb" {
  vpc_id = aws_vpc.db_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.db_igw.id
  }

  tags = {
    Name = "db-public-rtb"
  }
}

# Private Route Table
resource "aws_route_table" "db_private_rtb" {
  vpc_id = aws_vpc.db_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "db-private-rtb"
  }
}

# Route Table Associations - Public
resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.db_public_rtb.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.db_public_rtb.id
}

# Route Table Associations - Private
resource "aws_route_table_association" "private_az1" {
  subnet_id      = aws_subnet.private_subnet_az1.id
  route_table_id = aws_route_table.db_private_rtb.id
}

resource "aws_route_table_association" "private_az2" {
  subnet_id      = aws_subnet.private_subnet_az2.id
  route_table_id = aws_route_table.db_private_rtb.id
}

# DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_az1.id, aws_subnet.private_subnet_az2.id]

  tags = {
    Name = "db-subnet-group"
  }
}

# Security Group for Database
resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.db_vpc.id

  ingress {
    description = "MySQL/Aurora from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.db_vpc.cidr_block]
  }

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.db_vpc.cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-security-group"
  }
}

# Security Group for Application/Bastion
resource "aws_security_group" "app_sg" {
  name        = "app-security-group"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.db_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP in production
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-security-group"
  }
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.db_vpc.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = [aws_subnet.private_subnet_az1.id, aws_subnet.private_subnet_az2.id]
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.db_subnet_group.name
}

output "db_security_group_id" {
  description = "Database security group ID"
  value       = aws_security_group.db_sg.id
}

output "app_security_group_id" {
  description = "Application security group ID"
  value       = aws_security_group.app_sg.id
}

# RDS Instance
resource "aws_db_instance" "main_db" {
  identifier     = "main-database"
  engine         = "mysql"
  engine_version = "8.0"  # Use latest 8.0 version
  instance_class = "db.t3.micro"  # Free tier eligible

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "appdb"
  username = "dbadmin"
  password = "ChangeMeInProduction123!" # Use AWS Secrets Manager in production

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  multi_az               = false  # Set to false for free tier
  publicly_accessible    = false
  backup_retention_period = 1  # Free tier limit
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  
  skip_final_snapshot       = true  # Skip snapshot for cleanup
  deletion_protection       = false  # Allow deletion

  auto_minor_version_upgrade = true
  copy_tags_to_snapshot     = true

  tags = {
    Name        = "main-database"
    Environment = "production"
  }
}

# RDS Output
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main_db.endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main_db.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.main_db.username
  sensitive   = true
}
