# Define Terraform Backend Remote State
terraform {
  backend "gcs" {}
  required_providers {
    google-beta = {
      source = "hashicorp/google-beta"
      version = "5.7.0"
    }
  }
}