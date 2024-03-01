resource "cloudflare_access_application" "warp" {
  account_id           = data.cloudflare_zone.this.account_id
  app_launcher_visible = false

  name = "Warp Login App"
  type = "warp"
}

resource "cloudflare_access_policy" "warp_bypass" {
  zone_id        = data.cloudflare_zone.this.id
  application_id = cloudflare_access_application.warp.id

  name       = "bypass"
  decision   = "bypass"
  precedence = "1"

  include {
    group = [cloudflare_access_group.bypass.id]
  }
}

resource "cloudflare_access_policy" "warp_allow" {
  zone_id        = data.cloudflare_zone.this.id
  application_id = cloudflare_access_application.warp.id

  name       = "allow"
  decision   = "allow"
  precedence = "2"

  include {
    group = [cloudflare_access_group.allow.id]
  }
}
