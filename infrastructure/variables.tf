variable "aws_account_id" {
  description = "Expected AWS account ID; prevents planning/applying against another account. Not a credential."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Supply the expected 12-digit AWS account ID."
  }
}

variable "environment" {
  type    = string
  default = "prd"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}$", var.environment))
    error_message = "Use 2-11 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "domain_name" {
  description = "Public hostname; DNS and an issued ACM certificate must already be prepared."
  type        = string
  default     = "gratilo.com"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+\\.[a-z]{2,}$", var.domain_name))
    error_message = "Supply a hostname without scheme, port or path."
  }
}

variable "certificate_arn" {
  description = "Existing, issued ACM certificate in eu-central-1 covering domain_name."
  type        = string
  validation {
    condition     = can(regex("^arn:aws:acm:eu-central-1:[0-9]{12}:certificate/", var.certificate_arn))
    error_message = "An ACM certificate ARN in eu-central-1 is required."
  }
}

variable "image_tag" {
  description = "Unique immutable release tag shared by all three ECR images. Populate images before enabling the service."
  type        = string
  default     = "initial"
  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", var.image_tag)) && var.image_tag != "latest"
    error_message = "Use a release tag, not latest."
  }
}

variable "desired_count" {
  description = "Keep at zero until images, secret values and database schemas are ready."
  type        = number
  default     = 0
  validation {
    condition     = var.desired_count >= 0 && var.desired_count <= 4 && floor(var.desired_count) == var.desired_count
    error_message = "Use an integer between zero and four."
  }
}

variable "mail_from_email" {
  description = "Sender in the SES-verified domain; default is noreply@<domain_name>."
  type        = string
  default     = null
  validation {
    condition     = var.mail_from_email == null ? true : can(regex("^[^@\\s]+@${replace(var.domain_name, ".", "\\.")}$", var.mail_from_email))
    error_message = "The sender must belong to domain_name."
  }
}

variable "db_instance_class" {
  description = "Small starting size: Graviton db.t4g.micro (2 vCPUs, 1 GiB RAM)."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Start with Single-AZ to minimize cost; enable Multi-AZ when failover is required."
  type        = bool
  default     = false
}
