output "region" {
  value = "eu-central-1"
}
output "ecr_repository_urls" {
  value = { for name, repo in aws_ecr_repository.app : name => repo.repository_url }
}
output "application_url" {
  value = "https://${var.domain_name}"
}
output "load_balancer_dns_name" {
  description = "DNS target; DNS is intentionally not modified by this configuration."
  value       = aws_lb.main.dns_name
}
output "load_balancer_zone_id" {
  value = aws_lb.main.zone_id
}
output "cluster_name" {
  value = aws_ecs_cluster.main.name
}
output "service_name" {
  value = aws_ecs_service.app.name
}
output "application_secret_arn" {
  description = "Reference only; no secret value is read or emitted by Terraform."
  value       = aws_secretsmanager_secret.app.arn
}
output "database_admin_secret_arn" {
  value = aws_db_instance.main.master_user_secret[0].secret_arn
}
output "database_endpoint" {
  value = aws_db_instance.main.endpoint
}
output "bootstrap_task_definition_arn" {
  value = aws_ecs_task_definition.db_bootstrap.arn
}
output "bootstrap_network_configuration" {
  value = {
    awsvpcConfiguration = {
      subnets        = [for subnet in aws_subnet.private : subnet.id]
      securityGroups = [aws_security_group.app.id]
      assignPublicIp = "DISABLED"
    }
  }
}
