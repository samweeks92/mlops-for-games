// Copyright 2023 Google LLC All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

locals {
    table_schema = file("${path.module}/resources/bigquery-events-schema.json")
}

# Get Project ID
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_bigquery_dataset" "default" {
  project       = var.project_id
  dataset_id    = var.bigquery_config.dataset
  friendly_name = var.bigquery_config.dataset
  description   = "Unified Data - created by Terraform"
  location      = var.bigquery_config.location
}

resource "google_bigquery_table" "default" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.default.dataset_id
  table_id   = var.bigquery_config.table

  schema = local.table_schema

  time_partitioning {
    type = "DAY"
    field = "event_date"
  }

  depends_on = [
    google_bigquery_dataset.default
  ]

}

resource "google_service_account" "service_account" {
  project = var.project_id
  account_id   = "bigquery-sa"
  display_name = "BigQuery Service Account - managed through terraform"
}

# Grant the BQ service account the bigquery data editor role
resource "google_project_iam_member" "bq-sa-bq-data-editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

# Grant the BQ service account the bigquery user role
resource "google_project_iam_member" "bq-sa-bq-user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_service_account_iam_member" "terraform-runner-actas" {
  service_account_id = google_service_account.service_account.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_service_account_iam_member" "data-transfer-act-as" {
  service_account_id = google_service_account.service_account.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com"
}

# Copy data from the source table to the new partitioned table
resource "google_bigquery_data_transfer_config" "copy_data" {
  depends_on = [
    google_service_account.service_account,
    google_project_iam_member.bq-sa-bq-data-editor,
    google_project_iam_member.bq-sa-bq-user,
    google_service_account_iam_member.terraform-runner-actas,
    google_bigquery_table.default
  ]

  project                 = var.project_id
  display_name            = "Copy Data"
  data_source_id          = "scheduled_query"
  location                = var.bigquery_config.location
  destination_dataset_id  = google_bigquery_table.default.dataset_id
  service_account_name    = google_service_account.service_account.email

  params = {
    query                 = "INSERT INTO `${var.project_id}.${google_bigquery_table.default.dataset_id}.${google_bigquery_table.default.table_id}` SELECT PARSE_DATE('%Y%m%d', event_date) AS event_date, * EXCEPT(event_date), FROM `firebase-public-project.analytics_153293282.events_*`",
  }

  schedule_options {
    end_time = "${formatdate("YYYY-MM-DD", timeadd(timestamp(), "12h"))}T${formatdate("hh:mm:ss", timeadd(timestamp(), "12h"))}+00:00"
  }

  lifecycle {
    ignore_changes = [schedule_options["end_time"]]
  }

}