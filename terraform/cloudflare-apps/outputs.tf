output "tunnel_token" {
  value = cloudflare_zero_trust_tunnel_cloudflared.this.tunnel_token

  sensitive = true
}
