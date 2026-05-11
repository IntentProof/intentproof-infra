# Route 53 + ACM — RUNTIME_DECISION.md § 3 + § 8 DNS provisioning substeps.
# Per-subdomain cert only (no wildcard) — DNS_HYGIENE.md rule 1.
#
# IMPORTANT: After `terraform apply` creates the hosted zone, update the registrar's
# nameservers to match the four NS records output below. ACM validation will not
# complete until NS delegation is live. Use:
#   dig NS intentproof.io @8.8.8.8
# to verify propagation before expecting the cert to validate.

resource "aws_route53_zone" "intentproof_io" {
  name    = "intentproof.io"
  comment = "IntentProof public hosted zone — managed by Terraform"

  tags = { Name = "intentproof.io" }
}

# ── DNS hygiene baseline at apex (DNS_HYGIENE.md § baseline) ─────────────────

resource "aws_route53_record" "spf" {
  zone_id = aws_route53_zone.intentproof_io.zone_id
  name    = "intentproof.io"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

resource "aws_route53_record" "dmarc" {
  zone_id = aws_route53_zone.intentproof_io.zone_id
  name    = "_dmarc.intentproof.io"
  type    = "TXT"
  ttl     = 300
  # p=quarantine initially; promote to p=reject once no legitimate mail is failing DMARC
  records = ["v=DMARC1; p=quarantine; rua=mailto:ops@intentproof.io"]
}

resource "aws_route53_record" "caa" {
  zone_id = aws_route53_zone.intentproof_io.zone_id
  name    = "intentproof.io"
  type    = "CAA"
  ttl     = 300
  # Restrict cert issuance to ACM/Amazon CA only — DNS_HYGIENE.md rule 1
  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \";\"", # explicitly deny wildcard issuance
  ]
}

# ── ACM certificate for api.intentproof.io ───────────────────────────────────

resource "aws_acm_certificate" "api" {
  domain_name       = "api.intentproof.io"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "api.intentproof.io" }
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.intentproof_io.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

# ── A-record alias api.intentproof.io → ALB ──────────────────────────────────

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.intentproof_io.zone_id
  name    = "api.intentproof.io"
  type    = "A"

  alias {
    name                   = aws_lb.api.dns_name
    zone_id                = aws_lb.api.zone_id
    evaluate_target_health = true
  }
}
