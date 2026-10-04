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
  description = "Web DNS target; only SES DNS records are managed by this configuration."
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

output "ses_identity_arn" {
  value = aws_ses_domain_identity.app.arn
}
output "ses_smtp_endpoint" {
  value = local.ses_smtp_host
}
output "ses_from_email" {
  value = local.ses_from_email
}
output "ses_smtp_iam_user" {
  description = "IAM user only; SMTP credentials must be created outside Terraform and stored in Secrets Manager."
  value       = aws_iam_user.ses_smtp.name
}
output "ses_route53_zone_id" {
  value = data.aws_route53_zone.mail.zone_id
}
