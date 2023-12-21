/**
 * Copyright 2021 Google LLC
 */


resource "google_cloudbuild_trigger" "apply" {

  name        = var.trigger-name
  description = "(Managed by Terraform - Do not manually edit). ${var.trigger-name}"
  project     = var.project
  location    = var.region

  trigger_template {
    project_id  = var.project
    branch_name = "^main$"
    repo_name   = var.cloud-source-repo-name
  }

  included_files = var.included-files

  substitutions = var.substitutions
   
  filename = "${var.source-code-directory-path}/cloudbuild.yaml"

}