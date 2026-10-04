locals {
  assume_task_role = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow", Action = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.aws_account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:ecs:eu-central-1:${var.aws_account_id}:*" }
      }
    }]
  })
  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.app.name
      awslogs-region        = "eu-central-1"
      awslogs-stream-prefix = "app"
    }
  }
  common_environment = {
    MICRONAUT_ENVIRONMENTS  = "prd"
    FRONTEND_BASE_URL       = "https://${var.domain_name}"
    DATASOURCES_DEFAULT_URL = "jdbc:postgresql://${aws_db_instance.main.endpoint}/tipsterdb?sslmode=require"
    JAVA_TOOL_OPTIONS       = "-XX:MaxRAMPercentage=70.0"
  }
  common_secrets = {
    JWT_SECRET       = "jwt_secret"
    INTERNAL_API_KEY = "internal_api_key"
  }
  backend = {
    user-service = {
      port = 8081
      environment = {
        DATASOURCES_DEFAULT_USERNAME                                 = "tipster_user"
        APP_NAME                                                     = "Gratilo"
        MAIL_FROM_NAME                                               = "Gratilo"
        MAIL_FROM_EMAIL                                              = local.ses_from_email
        MAIL_HOST                                                    = local.ses_smtp_host
        MAIL_PORT                                                    = "587"
        MICRONAUT_SERVER_CORS_CONFIGURATIONS_DEFAULT_ALLOWED_ORIGINS = "https://${var.domain_name}"
        MAIL_SMTP_AUTH                                               = "true"
        MAIL_SMTP_STARTTLS_ENABLE                                    = "true"
        JAVAMAIL_PROPERTIES_MAIL_SMTP_STARTTLS_REQUIRED              = "true"
      }
      secrets = {
        DATASOURCES_DEFAULT_PASSWORD     = "user_db_password"
        JAVAMAIL_AUTHENTICATION_USERNAME = "smtp_username"
        JAVAMAIL_AUTHENTICATION_PASSWORD = "smtp_password"
      }
    }
    payment-service = {
      port = 8082
      environment = {
        DATASOURCES_DEFAULT_USERNAME = "tipster_payment"
        USER_SERVICE_URL             = "http://127.0.0.1:8081"
        STRIPE_SUCCESS_URL           = "https://${var.domain_name}/pay/success?session_id={CHECKOUT_SESSION_ID}"
        STRIPE_CANCEL_URL            = "https://${var.domain_name}/pay/cancelled"
      }
      secrets = {
        DATASOURCES_DEFAULT_PASSWORD = "payment_db_password"
        STRIPE_SECRET_KEY            = "stripe_secret_key"
        STRIPE_WEBHOOK_SECRET        = "stripe_webhook_secret"
      }
    }
  }
}

resource "aws_iam_role" "execution" {
  for_each           = toset(["app", "bootstrap"])
  name               = "${local.name}-${each.key}-execution"
  assume_role_policy = local.assume_task_role
}

resource "aws_iam_role_policy" "execution" {
  for_each = aws_iam_role.execution
  role     = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
        Resource = [for repo in aws_ecr_repository.app : repo.arn]
      },
      {
        Effect   = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.app.arn}:*"
      },
      {
        Effect   = "Allow", Action = ["secretsmanager:GetSecretValue"]
        Resource = concat([aws_secretsmanager_secret.app.arn], each.key == "bootstrap" ? [aws_db_instance.main.master_user_secret[0].secret_arn] : [])
      }
    ]
  })
}

# Application containers need no AWS API permissions. ECS injects their secrets.
resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = local.assume_task_role
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "3072"
  execution_role_arn       = aws_iam_role.execution["app"].arn
  task_role_arn            = aws_iam_role.task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode(concat([
    {
      name         = "frontend"
      image        = "${aws_ecr_repository.app["frontend"].repository_url}:${var.image_tag}"
      essential    = true
      memory       = 256
      portMappings = [{ containerPort = 80, protocol = "tcp" }]
      environment = [
        { name = "USER_SERVICE_HOST", value = "127.0.0.1" },
        { name = "PAYMENT_SERVICE_HOST", value = "127.0.0.1" }
      ]
      dependsOn        = [for service in keys(local.backend) : { containerName = service, condition = "HEALTHY" }]
      logConfiguration = local.log_configuration
      healthCheck = {
        command  = ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost/ || exit 1"]
        interval = 30, timeout = 5, retries = 3, startPeriod = 30
      }
    }
    ], [for name, config in local.backend : {
      name         = name
      image        = "${aws_ecr_repository.app[name].repository_url}:${var.image_tag}"
      essential    = true
      memory       = 1280
      startTimeout = 120
      portMappings = [{ containerPort = config.port, protocol = "tcp" }]
      environment  = [for key, value in merge(local.common_environment, config.environment) : { name = key, value = value }]
      secrets = [for key, json_key in merge(local.common_secrets, config.secrets) : {
        name = key, valueFrom = "${aws_secretsmanager_secret.app.arn}:${json_key}::"
      }]
      logConfiguration = local.log_configuration
      healthCheck = {
        command  = ["CMD-SHELL", "curl --fail --silent http://localhost:${config.port}/health || exit 1"]
        interval = 30, timeout = 5, retries = 3, startPeriod = 120
      }
  }]))
}

resource "aws_ecs_service" "app" {
  name                               = "${local.name}-app"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  health_check_grace_period_seconds  = 180
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  wait_for_steady_state              = true
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "frontend"
    container_port   = 80
  }
  depends_on = [aws_lb_listener.https, aws_iam_role_policy.execution, aws_route_table_association.private]
}

# Registers a definition only. Terraform never runs this task or executes SQL.
resource "aws_ecs_task_definition" "db_bootstrap" {
  family                   = "${local.name}-db-bootstrap"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution["bootstrap"].arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions = jsonencode([{
    name       = "db-bootstrap"
    image      = "public.ecr.aws/docker/library/postgres:15"
    essential  = true
    entryPoint = ["/bin/sh", "-ec"]
    command    = ["psql -X --set=ON_ERROR_STOP=1 <<'SQL'\n${file("${path.module}/bootstrap.sql")}\nSQL"]
    environment = [
      { name = "PGHOST", value = aws_db_instance.main.address },
      { name = "PGDATABASE", value = "tipsterdb" },
      { name = "PGUSER", value = aws_db_instance.main.username },
      { name = "PGSSLMODE", value = "require" }
    ]
    secrets = [
      { name = "PGPASSWORD", valueFrom = "${aws_db_instance.main.master_user_secret[0].secret_arn}:password::" },
      { name = "USER_DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.app.arn}:user_db_password::" },
      { name = "PAYMENT_DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.app.arn}:payment_db_password::" }
    ]
    logConfiguration = local.log_configuration
  }])
}
