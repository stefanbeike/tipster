locals {
  name     = "tipster-${var.environment}"
  services = toset(["frontend", "user-service", "payment-service"])
  zones    = { a = "eu-central-1a", b = "eu-central-1b" }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  for_each          = local.zones
  vpc_id            = aws_vpc.main.id
  availability_zone = each.value
  cidr_block        = each.key == "a" ? "10.42.0.0/24" : "10.42.1.0/24"
  tags              = { Name = "${local.name}-public-${each.key}" }
}

resource "aws_subnet" "private" {
  for_each          = local.zones
  vpc_id            = aws_vpc.main.id
  availability_zone = each.value
  cidr_block        = each.key == "a" ? "10.42.10.0/24" : "10.42.11.0/24"
  tags              = { Name = "${local.name}-private-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  for_each       = local.zones
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

# One NAT gateway per AZ: Stripe, SMTP and image pulls need outbound access.
resource "aws_eip" "nat" {
  for_each = local.zones
  domain   = "vpc"
}

resource "aws_nat_gateway" "main" {
  for_each      = local.zones
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  for_each = local.zones
  vpc_id   = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }
}

resource "aws_route_table_association" "private" {
  for_each       = local.zones
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-alb-"
  description = "Public HTTP redirect and HTTPS entry point"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "app" {
  name_prefix = "${local.name}-app-"
  description = "Fargate tasks: frontend accessible only from ALB"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "db" {
  name_prefix = "${local.name}-db-"
  description = "PostgreSQL accessible only from application tasks"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "app_internet" {
  for_each          = toset(["443", "587"])
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
}

resource "aws_vpc_security_group_egress_rule" "app_db" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "db" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_db_subnet_group" "main" {
  name       = local.name
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]
}

resource "aws_db_instance" "main" {
  identifier                      = local.name
  engine                          = "postgres"
  engine_version                  = "15"
  instance_class                  = var.db_instance_class
  allocated_storage               = 20
  max_allocated_storage           = 100
  storage_type                    = "gp3"
  storage_encrypted               = true
  db_name                         = "tipsterdb"
  username                        = "tipster_admin"
  manage_master_user_password     = true
  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  publicly_accessible             = false
  multi_az                        = var.db_multi_az
  backup_retention_period         = 14
  copy_tags_to_snapshot           = true
  deletion_protection             = true
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${local.name}-final"
  auto_minor_version_upgrade      = true
  apply_immediately               = false
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  lifecycle {
    prevent_destroy = true
  }
}

# Only the empty secret container is managed. Values are entered outside Terraform.
resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name}/application"
  recovery_window_in_days = 30
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository" "app" {
  for_each             = local.services
  name                 = "${local.name}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}"
  retention_in_days = 30
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name}-iac"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_lb" "main" {
  name                       = local.name
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for subnet in aws_subnet.public : subnet.id]
  enable_deletion_protection = true
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "app" {
  name        = local.name
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
