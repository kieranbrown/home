resource "cloudflare_access_application" "app_launcher" {
  account_id           = data.cloudflare_zone.this.account_id
  app_launcher_visible = false

  name = "App Launcher"
  type = "app_launcher"
}

resource "cloudflare_access_policy" "app_launcher_bypass" {
  zone_id        = data.cloudflare_zone.this.id
  application_id = cloudflare_access_application.app_launcher.id

  name       = "bypass"
  decision   = "bypass"
  precedence = "1"

  include {
    group = [cloudflare_access_group.bypass.id]
  }
}

resource "cloudflare_access_policy" "app_launcher_allow" {
  zone_id        = data.cloudflare_zone.this.id
  application_id = cloudflare_access_application.app_launcher.id

  name       = "allow"
  decision   = "allow"
  precedence = "2"

  include {
    group = [cloudflare_access_group.allow.id]
  }
}
