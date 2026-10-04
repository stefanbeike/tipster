locals {
  ses_smtp_host  = "email-smtp.eu-central-1.amazonaws.com"
  ses_from_email = coalesce(var.mail_from_email, "noreply@${var.domain_name}")
  ses_mail_from  = "bounce.${var.domain_name}"
}

# Reuse the existing public DNS zone; do not create a second hosted zone.
# If there are duplicate public zones, resolve the intended delegation before apply.
data "aws_route53_zone" "mail" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_ses_domain_identity" "app" {
  domain = var.domain_name
}

resource "aws_route53_record" "ses_verification" {
  zone_id         = data.aws_route53_zone.mail.zone_id
  name            = "_amazonses.${var.domain_name}"
  type            = "TXT"
  ttl             = 300
  records         = [aws_ses_domain_identity.app.verification_token]
  allow_overwrite = false
}

resource "aws_ses_domain_identity_verification" "app" {
  domain     = aws_ses_domain_identity.app.domain
  depends_on = [aws_route53_record.ses_verification]
}

resource "aws_ses_domain_dkim" "app" {
  domain = aws_ses_domain_identity.app.domain
}

resource "aws_route53_record" "ses_dkim" {
  count           = 3
  zone_id         = data.aws_route53_zone.mail.zone_id
  name            = "${aws_ses_domain_dkim.app.dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type            = "CNAME"
  ttl             = 300
  records         = ["${aws_ses_domain_dkim.app.dkim_tokens[count.index]}.dkim.amazonses.com"]
  allow_overwrite = false
}

resource "aws_ses_domain_mail_from" "app" {
  domain                 = aws_ses_domain_identity.app.domain
  mail_from_domain       = local.ses_mail_from
  behavior_on_mx_failure = "RejectMessage"
  depends_on             = [aws_ses_domain_identity_verification.app]
}

# These apply only to the dedicated bounce subdomain, not to incoming domain mail.
resource "aws_route53_record" "ses_mail_from_mx" {
  zone_id         = data.aws_route53_zone.mail.zone_id
  name            = local.ses_mail_from
  type            = "MX"
  ttl             = 300
  records         = ["10 feedback-smtp.eu-central-1.amazonses.com"]
  allow_overwrite = false
}

resource "aws_route53_record" "ses_mail_from_spf" {
  zone_id         = data.aws_route53_zone.mail.zone_id
  name            = local.ses_mail_from
  type            = "TXT"
  ttl             = 300
  records         = ["v=spf1 include:amazonses.com ~all"]
  allow_overwrite = false
}

# Create the principal and its least-privilege policy, but NEVER an access key.
# aws_iam_access_key would put the secret into Terraform state.
resource "aws_iam_user" "ses_smtp" {
  name          = "gratilo-${var.environment}-ses-smtp"
  force_destroy = false
}

resource "aws_iam_user_policy" "ses_smtp" {
  name = "send-application-mail"
  user = aws_iam_user.ses_smtp.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendRawEmail"]
      Resource = aws_ses_domain_identity.app.arn
      Condition = {
        StringEquals = { "ses:FromAddress" = local.ses_from_email }
      }
    }]
  })
}
