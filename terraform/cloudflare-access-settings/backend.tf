terraform {
  backend "s3" {
    bucket = "terraform-tfstate"
    key    = "home/cloudflare-access-settings/terraform.tfstate"

    region = "auto"

    skip_s3_checksum            = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true

    endpoints = {
      s3 = "https://5289841818760c6a5b9a9f73d990001f.r2.cloudflarestorage.com/terraform-tfstate"
    }

    use_lockfile = true
  }
}
