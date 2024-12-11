resource "random_bytes" "tunnel_secret" {
  length = 35
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = data.cloudflare_zone.this.account_id

  name   = "home"
  secret = random_bytes.tunnel_secret.base64
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = cloudflare_zero_trust_tunnel_cloudflared.this.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config {
    ingress_rule {
      hostname = "home.kswb.dev"
      service  = "http://host.docker.internal:8123"
    }

    ingress_rule {
      hostname = "music.kswb.dev"
      service  = "http://host.docker.internal:8095"
    }

    ingress_rule {
      hostname = "z2m.kswb.dev"
      service  = "http://zigbee2mqtt:8080"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_zero_trust_access_policy" "allow" {
  account_id = data.cloudflare_zone.this.account_id

  name = "allow"
  decision = "allow"

  include {
    email = ["kari96jones@gmail.com", "kswb96@gmail.com"]
  }
}

locals {
  applications = {
    for ingress_rule in cloudflare_zero_trust_tunnel_cloudflared_config.this.config[0].ingress_rule : ingress_rule.hostname => ingress_rule
    if endswith(coalesce(ingress_rule.hostname, "$"), data.cloudflare_zone.this.name)
  }
}

resource "cloudflare_zero_trust_access_application" "this" {
  for_each = local.applications

  account_id = data.cloudflare_zone.this.account_id

  name   = each.key
  domain = each.key
  policies = [cloudflare_zero_trust_access_policy.allow.id]

  allowed_idps = [data.cloudflare_zero_trust_access_identity_provider.this.id]

  auto_redirect_to_identity = true
}

resource "cloudflare_record" "this" {
  for_each = local.applications

  zone_id = data.cloudflare_zone.this.zone_id

  name    = each.key
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.this.cname

  proxied = true

  depends_on = [cloudflare_zero_trust_access_application.this]
}
