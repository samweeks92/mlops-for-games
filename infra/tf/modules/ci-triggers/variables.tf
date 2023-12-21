/**
 * Copyright 2021 Google LLC
 */


variable "project" {
  type        = string
  description = "The project that contains the Cloud Source Repositories repo"
}

variable "region" {
  type        = string
  description = "GCP Region to deploy resources"
}

variable "cloud-source-repo-name" {
  type        = string
  description = "The name of the Cloud Source Repository containing this code"
}

variable "included-files" {
  type        = list
  description = "List of file paths to watch for changes against"
}

variable "source-code-directory-path" {
  type        = string
  description = "The directory path to the source files for this service"
}

variable "trigger-name" {
  type        = string
  description = "The name of the Trigger for the service"
}

variable "artifact-registry-repo-name" {
  type        = string
  description = "The name of the Artifact Registry repo to store service Images"
}

variable "substitutions" {
  type        = map(string)
  description = "The object of substitutions to send through to the Cloud Build Trigger template"
}
