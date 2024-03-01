resource "cloudflare_access_group" "allow" {
  name    = "allow"
  zone_id = data.cloudflare_zone.this.id

  include {
    email = var.allowed_emails
  }

  require {
    geo = ["GB"]
  }
}

resource "cloudflare_access_group" "bypass" {
  name    = "bypass"
  zone_id = data.cloudflare_zone.this.id

  include {
    ip = var.trusted_ips
  }
}
