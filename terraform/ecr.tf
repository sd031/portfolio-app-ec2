# Reference existing ECR repositories created by build-and-push.sh
# These repositories are created outside of Terraform by the deployment script

# Data source for Frontend ECR Repository
data "aws_ecr_repository" "frontend" {
  name = "${var.project_name}-frontend"
}

# Data source for Backend ECR Repository
data "aws_ecr_repository" "backend" {
  name = "${var.project_name}-backend"
}

# Output ECR repository URLs
output "ecr_frontend_repository_url" {
  description = "Frontend ECR repository URL"
  value       = data.aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_repository_url" {
  description = "Backend ECR repository URL"
  value       = data.aws_ecr_repository.backend.repository_url
}
