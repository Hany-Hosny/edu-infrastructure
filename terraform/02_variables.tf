variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "name of the project"
  type        = string
  default     = "edu-app"

}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "assessment"

}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_db_subnet_a_cidr" {
  description = "CIDR block for the first private database subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_db_subnet_b_cidr" {
  description = "CIDR block for the second private database subnet"
  type        = string
  default     = "10.0.3.0/24"
}


variable "github_owner" {
  description = "GitHub org or user owning the repository"
  type        = string
  default     = "Hany-Hosny"
}

variable "github_repository" {
  description = "GitHub repository name used for GitHub Actions OIDC trust"
  type        = string
  default     = "edu-app"
}

variable "db_name" {
  description = "Application PostgreSQL database name"
  type        = string
  default     = "edu"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "eduadmin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = "hanyhosny01@gmail.com"
}