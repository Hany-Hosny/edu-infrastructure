output "ec2_public_ip" {
  description = "Public IPv4 address of the application EC2 instance"
  value       = aws_instance.app.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the application EC2 instance"
  value       = aws_instance.app.public_dns
}

output "application_url" {
  description = "Public application URL"
  value       = "http://${aws_instance.app.public_ip}"
}

output "rds_endpoint" {
  description = "PostgreSQL RDS endpoint"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "PostgreSQL RDS port"
  value       = aws_db_instance.postgres.port
}

output "rds_master_secret_arn" {
  description = "ARN of the RDS master password secret"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "backend_ecr_repository_url" {
  description = "Backend ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "github_actions_role_arn" {
  description = "IAM role used by GitHub Actions through OIDC"
  value       = aws_iam_role.github_actions.arn
}