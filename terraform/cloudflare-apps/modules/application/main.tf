data "cloudflare_access_identity_provider" "this" {
  name = "Google"

  zone_id = var.zone_id
}

resource "cloudflare_access_application" "this" {
  zone_id = var.zone_id
  name    = var.name

  logo_url = var.logo_url

  domain = "${var.name}.${var.zone_name}${var.path}"

  allowed_idps              = data.cloudflare_access_identity_provider.this[*].id
  auto_redirect_to_identity = true
}

resource "cloudflare_access_policy" "bypass" {
  zone_id        = var.zone_id
  application_id = cloudflare_access_application.this.id

  name       = "bypass"
  decision   = "bypass"
  precedence = "1"

  include {
    group = var.cloudflare_access_groups.bypass
  }
}

resource "cloudflare_access_policy" "allow" {
  zone_id        = var.zone_id
  application_id = cloudflare_access_application.this.id

  name       = "allow"
  decision   = "allow"
  precedence = "2"

  include {
    group = var.cloudflare_access_groups.allow
  }
}

resource "cloudflare_record" "this" {
  zone_id = var.zone_id
  name    = var.name
  value   = var.tunnel_cname
  type    = "CNAME"
  proxied = true

  allow_overwrite = true
}
