data "cloudflare_zero_trust_access_identity_provider" "this" {
  name = "Google"

  account_id = data.cloudflare_zone.this.account_id
}

data "cloudflare_zone" "this" {
  name = "kswb.dev"
}
