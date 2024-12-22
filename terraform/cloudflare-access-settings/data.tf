data "cloudflare_accounts" "this" {
  name = "Kieran Brown"
}

data "cloudflare_zero_trust_access_identity_provider" "google" {
  account_id = local.account_id

  name = "Google"
}
