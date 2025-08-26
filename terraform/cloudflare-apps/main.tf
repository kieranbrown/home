locals {
  account_id = data.cloudflare_zone.this.account_id
  cf_access_state = data.terraform_remote_state.cloudflare_access_settings.outputs

  applications = {
    aiostreams_public = {
      name         = "AIOStreams (Public Rate Limit)"
      logo         = "https://www.stremio.com/website/stremio-logo-small.png"
      hostname     = "aiostreams.kswb.dev"
      service      = "http://aiostreams:3000"
      paths        = ["/*/*/movie/*.json", "/*/*/series/*.json", "/manifest.json", "/*/manifest.json"]
      is_public    = true
      app_launcher = false
    },
    aiostreams = {
      name     = "AIOStreams"
      logo     = "https://www.stremio.com/website/stremio-logo-small.png"
      hostname = "aiostreams.kswb.dev"
      service  = "http://aiostreams:3000"
    },
    home_assistant = {
      name     = "Home Assistant"
      logo     = "https://community-assets.home-assistant.io/original/4X/1/3/8/13882a481a57f91f670def0fc33cf99d09dec293.png"
      hostname = "home.kswb.dev"
      service  = "http://host.docker.internal:8123"
    },
    music_assistant = {
      name     = "Music Assistant"
      logo     = "https://avatars.githubusercontent.com/u/71128003?s=200&v=4"
      hostname = "music.kswb.dev"
      service  = "http://host.docker.internal:8095"
    },
    ssh = {
      name     = "SSH"
      logo     = "https://cdn-icons-png.flaticon.com/512/5261/5261867.png"
      hostname = "ssh.kswb.dev"
      service  = "ssh://host.docker.internal:22"
    },
    z2m = {
      name     = "Zigbee2MQTT"
      logo     = "https://www.zigbee2mqtt.io/logo.png"
      hostname = "z2m.kswb.dev"
      service  = "http://zigbee2mqtt:8080"
    },
  }
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

  lifecycle {
    ignore_changes = [config[0].warp_routing]
  }
}

resource "cloudflare_zero_trust_split_tunnel" "this" {
  account_id = local.account_id

  mode = "include"

  dynamic "tunnels" {
    for_each = distinct(concat(values(local.applications)[*].hostname, ["kieranbrown.cloudflareaccess.com"]))

    content {
      host = tunnels.value
    }
  }
}

resource "cloudflare_zero_trust_access_application" "this" {
  for_each = local.applications

  account_id = local.account_id

  name     = each.value.name
  type     = startswith(each.value.service, "ssh://") ? "ssh" : "self_hosted"
  logo_url = each.value.logo

  dynamic "destinations" {
    for_each = try(each.value.paths, [""])

    content {
      uri = "${each.value.hostname}${destinations.value}"
    }
  }

  policies = try(each.value.is_public, false) ? [local.cf_access_state.app_policy_public_id] : compact([
    local.cf_access_state.app_policy_allow_id,
    startswith(each.value.service, "ssh://") ? null : local.cf_access_state.app_policy_bypass_id,
  ])

  app_launcher_visible = try(each.value.app_launcher, true)

  allowed_idps = [local.cf_access_state.idp_google_id]

  auto_redirect_to_identity = true

  # secure cookie options
  http_only_cookie_attribute = true
  enable_binding_cookie      = true
  same_site_cookie_attribute = "lax"
}

resource "cloudflare_record" "this" {
  for_each = toset([
    for key, app in local.applications : app.hostname
    if endswith(coalesce(app.hostname, "$"), data.cloudflare_zone.this.name)
  ])

  zone_id = data.cloudflare_zone.this.zone_id

  name    = each.key
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.this.cname

  proxied = true

  depends_on = [cloudflare_zero_trust_access_application.this]
}

resource "cloudflare_ruleset" "http_request_firewall_custom" {
  zone_id = data.cloudflare_zone.this.zone_id

  name  = "Custom Firewall Ruleset"
  phase = "http_request_firewall_custom"
  kind  = "zone"

  rules {
    description = "AIOStreams"
    expression  = "(http.host eq \"aiostreams.kswb.dev\") and (\n  (http.request.uri.path contains \"/stream/movie/\" and ends_with(http.request.uri.path, \".json\")) or\n  (http.request.uri.path contains \"/stream/series/\" and ends_with(http.request.uri.path, \".json\")) or\n  ends_with(http.request.uri.path, \"/manifest.json\")\n)"
    action      = "skip"

    action_parameters {
      ruleset = "current" # stop processing further rules
    }

    logging {
      enabled = true
    }
  }

  rules {
    description = "Identity Protected"
    expression  = "http.host in {${ join(" ", distinct([ for app in local.applications : "\"${app.hostname}\"" ])) }}"
    action      = "skip"

    action_parameters {
      phases = ["http_ratelimit"]
    }

    logging {
      enabled = true
    }
  }
}

resource "cloudflare_ruleset" "http_request_cache_settings" {
  zone_id = data.cloudflare_zone.this.zone_id

  name  = "Cache Configuration Ruleset"
  phase = "http_request_cache_settings"
  kind  = "zone"

  rules {
    description = "AIOStreams"
    expression  = "(http.host eq \"aiostreams.kswb.dev\" and (starts_with(http.request.uri.path, \"/_next/static/\") or http.request.uri.path in {\"/assets/logo.png\" \"/icon.ico\"}))"
    action      = "set_cache_settings"

    action_parameters {
      cache = true

      browser_ttl {
        default = 31536000
        mode    = "override_origin"
      }

      cache_key {
        ignore_query_strings_order = true
      }

      edge_ttl {
        default = 31536000
        mode    = "override_origin"
      }

      serve_stale {
        disable_stale_while_updating = true
      }
    }
  }
}

resource "cloudflare_zero_trust_access_short_lived_certificate" "ssh" {
  account_id     = local.account_id
  application_id = cloudflare_zero_trust_access_application.this["ssh"].id

  lifecycle {
    prevent_destroy = true
  }
}
