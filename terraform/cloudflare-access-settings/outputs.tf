output "app_policy_allow_id" {
  value = cloudflare_zero_trust_access_policy.allow.id
}

output "app_policy_bypass_id" {
  value = cloudflare_zero_trust_access_policy.bypass.id
}

output "app_policy_public_id" {
  value = cloudflare_zero_trust_access_policy.public.id
}

output "idp_google_id" {
  value = data.cloudflare_zero_trust_access_identity_provider.google.id
}
