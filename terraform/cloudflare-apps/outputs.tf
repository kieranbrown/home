output "tunnel_token" {
  value     = cloudflare_tunnel.this.tunnel_token
  sensitive = true
}
