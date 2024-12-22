locals {
  account_id = data.cloudflare_zone.this.account_id

  applications = [
    {
      name     = "Home Assistant"
      logo     = "https://community-assets.home-assistant.io/original/4X/1/3/8/13882a481a57f91f670def0fc33cf99d09dec293.png"
      hostname = "home.kswb.dev"
      service  = "http://host.docker.internal:8123"
    },
    {
      name     = "Music Assistant"
      logo     = "https://avatars.githubusercontent.com/u/71128003?s=200&v=4"
      hostname = "music.kswb.dev"
      service  = "http://host.docker.internal:8095"
    },
    {
      name     = "Zigbee2MQTT"
      logo     = "https://www.zigbee2mqtt.io/logo.png"
      hostname = "z2m.kswb.dev"
      service  = "http://zigbee2mqtt:8080"
    },
  ]
}

resource "random_bytes" "tunnel_secret" {
  length = 35
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = local.account_id

  name   = "home"
  secret = random_bytes.tunnel_secret.base64
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = local.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config {
    dynamic "ingress_rule" {
      for_each = local.applications

      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service
      }
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_zero_trust_split_tunnel" "this" {
  account_id = local.account_id

  mode = "include"

  dynamic "tunnels" {
    for_each = concat(local.applications[*].hostname, ["kieranbrown.cloudflareaccess.com"])

    content {
      host = tunnels.value
    }
  }
}

resource "cloudflare_zero_trust_access_application" "this" {
  for_each = { for app in local.applications : app.hostname => app }

  account_id = local.account_id

  name     = each.value.name
  domain   = each.value.hostname
  logo_url = each.value.logo

  policies = [
    data.terraform_remote_state.cloudflare_access_settings.outputs.app_policy_allow_id,
    data.terraform_remote_state.cloudflare_access_settings.outputs.app_policy_bypass_id,
  ]

  allowed_idps = [data.terraform_remote_state.cloudflare_access_settings.outputs.idp_google_id]

  auto_redirect_to_identity = true

  # secure cookie options
  http_only_cookie_attribute = true
  enable_binding_cookie      = true
  same_site_cookie_attribute = "lax"
}

resource "cloudflare_record" "this" {
  for_each = {
    for app in local.applications : app.hostname => app
    if endswith(coalesce(app.hostname, "$"), data.cloudflare_zone.this.name)
  }

  zone_id = data.cloudflare_zone.this.zone_id

  name    = each.key
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.this.cname

  proxied = true

  depends_on = [cloudflare_zero_trust_access_application.this]
}
