variable "cloudflare_api_token" {
  type      = string
  sensitive = true
  ephemeral = true
}

variable "cloudflare_s3_access_key" {
  type      = string
  sensitive = true
}

variable "cloudflare_s3_secret_key" {
  type      = string
  sensitive = true
}
