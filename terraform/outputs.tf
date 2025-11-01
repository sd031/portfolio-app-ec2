output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.frontend_alb.dns_name
}

output "alb_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.frontend_alb.dns_name}"
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "frontend_instance_ids" {
  description = "Frontend EC2 instance IDs"
  value       = aws_instance.frontend[*].id
}

output "backend_instance_ids" {
  description = "Backend EC2 instance IDs"
  value       = aws_instance.backend[*].id
}

output "nat_gateway_ips" {
  description = "Elastic IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}
