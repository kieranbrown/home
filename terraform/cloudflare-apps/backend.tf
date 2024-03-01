terraform {
  backend "remote" {
    organization = "kieranbrown"

    workspaces {
      name = "nas-apps"
    }
  }
}
