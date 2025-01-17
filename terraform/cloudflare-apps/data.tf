data "cloudflare_zone" "this" {
  name = "kswb.dev"
}

data "terraform_remote_state" "cloudflare_access_settings" {
  backend = "s3"

  config = {
    bucket = "terraform-tfstate"
    key    = "home/cloudflare-access-settings/terraform.tfstate"
    region = "auto"

    access_key = var.cloudflare_s3_access_key
    secret_key = var.cloudflare_s3_secret_key

    skip_s3_checksum            = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true

    endpoints = {
      s3 = "https://5289841818760c6a5b9a9f73d990001f.r2.cloudflarestorage.com/terraform-tfstate"
    }
  }
}
