locals {
  services_config = {
    "homarr" = {
      # logo_url = ""
      port = 7575
    },
    "home-assistant" = {
      logo_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6e/Home_Assistant_Logo.svg/1200px-Home_Assistant_Logo.svg.png"
      port     = 8123
    },
    "overseerr" = {
      logo_url = "https://overseerr.dev/_next/image?url=%2Fos_logo_filled.svg&w=96&q=100"
      port     = 5055
    },
    "pihole" = {
      logo_url = "https://wp-cdn.pi-hole.net/wp-content/uploads/2016/12/cropped-Vortex-R-1-192x192.png"
      path     = "/admin"
      port     = 80
      service  = "192.168.1.2"
    },
    "pihole-02" = {
      logo_url = "https://wp-cdn.pi-hole.net/wp-content/uploads/2016/12/cropped-Vortex-R-1-192x192.png"
      path     = "/admin"
      port     = 80
      service  = "pihole"
    },
    "plex" = {
      logo_url = "https://www.plex.tv/wp-content/themes/plex/assets/img/favicons/plex-192.png"
      port     = 32400
    },
    "prowlarr" = {
      logo_url = "https://prowlarr.com/logo/256.png"
      port     = 9696
      service  = "gluetun"
    },
    "pyload" = {
      logo_url = "https://raw.githubusercontent.com/pyload/pyload/main/media/logo.png"
      port     = 8000
    },
    "qbittorrent" = {
      logo_url = "https://upload.wikimedia.org/wikipedia/commons/6/66/New_qBittorrent_Logo.svg"
      port     = 8080
      service  = "gluetun"
    },
    "radarr" = {
      logo_url = "https://avatars.githubusercontent.com/u/25025331?s=280&v=4"
      port     = 7878
    },
    "rdtclient" = {
      # logo_url = ""
      port = 6500
    }
    "sonarr" = {
      logo_url = "https://avatars.githubusercontent.com/u/1082903?s=280&v=4"
      port     = 8988
    },
    "tautulli" = {
      logo_url = "https://tautulli.com/images/logo-circle.png"
      port     = 8181
    },
    "uisp" = {
      logo_url      = "https://upload.wikimedia.org/wikipedia/en/6/6d/Ubiquiti-Networks-Logo-2023.png"
      port          = 443
      protocol      = "https"
      no_tls_verify = true # todo: this has to be set in the console as cloudflare-terraform provider does not support it
    },
    "unifi" = {
      logo_url      = "https://assets-global.website-files.com/622b70d8906c7ab0c03f77f8/63b40a92093c6b2f3767e4e6_tMCv8T-y_400x400.png"
      port          = 8443
      protocol      = "https"
      no_tls_verify = true # todo: this has to be set in the console as cloudflare-terraform provider does not support it
    },
  }

  services = { for key, config in local.services_config : key => {
    name     = key
    port     = config.port
    protocol = try(config.protocol, config.port == 443 ? "https" : "http")
    logo_url = try(config.logo_url, null)
    path     = try(config.path, "")
  } }

  zone_name = "kswb.uk"
}

data "cloudflare_zone" "this" {
  name = local.zone_name
}

resource "random_id" "tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_tunnel" "this" {
  account_id = data.cloudflare_zone.this.account_id
  name       = "NAS"
  secret     = sensitive(random_id.tunnel_secret.b64_std)
}

resource "cloudflare_tunnel_config" "this" {
  account_id = data.cloudflare_zone.this.account_id
  tunnel_id  = cloudflare_tunnel.this.id

  config {
    dynamic "ingress_rule" {
      for_each = local.services

      content {
        hostname = try(local.services_config[ingress_rule.key].hostname, "${ingress_rule.value.name}.${data.cloudflare_zone.this.name}")
        service  = "${ingress_rule.value.protocol}://${try(local.services_config[ingress_rule.key].service, ingress_rule.value.name)}:${ingress_rule.value.port}"
      }
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

module "applications" {
  source   = "./modules/application"
  for_each = local.services

  cloudflare_access_groups = {
    bypass = [cloudflare_access_group.bypass.id]
    allow  = [cloudflare_access_group.allow.id]
  }

  logo_url = each.value.logo_url

  name = each.value.name
  path = each.value.path

  tunnel_cname = cloudflare_tunnel.this.cname
  zone_id      = data.cloudflare_zone.this.id
  zone_name    = data.cloudflare_zone.this.name
}
