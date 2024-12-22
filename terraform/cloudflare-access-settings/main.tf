locals {
  account_id = one(data.cloudflare_accounts.this.accounts).id
}

resource "cloudflare_zero_trust_device_posture_rule" "gateway" {
  account_id  = local.account_id
  name        = "gateway"
  type        = "gateway"
}

resource "cloudflare_zero_trust_access_policy" "allow" {
  account_id = local.account_id

  name = "allow"
  decision = "allow"

  include {
    email = ["kari96jones@gmail.com", "kswb96@gmail.com"]
  }
}

resource "cloudflare_zero_trust_access_policy" "bypass" {
  account_id = local.account_id

  name = "bypass"
  decision = "bypass"

  include {
    device_posture = [cloudflare_zero_trust_device_posture_rule.gateway.id]
  }
}

resource "cloudflare_zero_trust_gateway_settings" "this" {
  account_id = local.account_id

  logging {
    redact_pii = false

    settings_by_rule_type {
      dns {
        log_all    = false
        log_blocks = false
      }
      http {
        log_all    = false
        log_blocks = false
      }
      l4 {
        log_all    = false
        log_blocks = false
      }
    }
  }

  proxy {
    root_ca    = true
    virtual_ip = false

    disable_for_time = 0

    tcp = true
    udp = true
  }

  lifecycle {
    ignore_changes = [ssh_session_log]
  }
}

resource "cloudflare_zero_trust_device_profiles" "default" {
  account_id = local.account_id

  name        = "Default"
  description = ""
  default     = true

  tunnel_protocol = "masque"
}

resource "cloudflare_zero_trust_access_application" "settings" {
  for_each = toset(["app_launcher", "warp"])

  account_id = local.account_id

  type = each.key

  app_launcher_visible = false

  policies = [
    cloudflare_zero_trust_access_policy.bypass.id,
    cloudflare_zero_trust_access_policy.allow.id,
  ]

  allowed_idps = [data.cloudflare_zero_trust_access_identity_provider.google.id]

  auto_redirect_to_identity = true
}
