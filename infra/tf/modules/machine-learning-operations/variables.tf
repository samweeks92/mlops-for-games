variable "project_id" {
  type        = string
  description = "GCP Project Name"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "services_artifact_repo_name" {
  type        = string
  description = "Name of the Artifact Repo repository containing the Services images"
}

variable "cloud_source_repo_name" {
  type        = string
  description = "The name of the Cloud Source Repository containing this code"
}

variable "dataset_id" {
  type        = string
  description = "The name of the dataset containing the game telemetry data"
}

variable "dataset_location" {
  type        = string
  description = "The location of the dataset containing the game telemetry data"
}

variable "table_id" {
  type        = string
  description = "The name of the table containing the game telemetry data"
}