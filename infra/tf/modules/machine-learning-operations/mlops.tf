# Get Project ID
data "google_project" "project" {
  project_id = var.project_id
}

data "google_storage_project_service_account" "gcs_account" {
  project     = var.project_id
  provider = google-beta
}

########################################################################################################################
# INFRASTRUCTURE TO SETUP AUTOMATED NOTIFICATIONS TO ALLOW MODEL TRAINING PIPELINES TO REACT TO CHANGES IN SOURCE DATA #
########################################################################################################################

resource "google_monitoring_alert_policy" "alert_policy" {
    project = var.project_id
    display_name = "BigQuery Updates Alert"
    user_labels = {}
    combiner     = "OR"
    conditions {
        display_name = "Dataflow Job - BigQueryIO.Write Requests"
        condition_threshold {
            filter     = "resource.type = \"dataflow_job\" AND metric.type=\"dataflow.googleapis.com/job/bigquery/write_count\""
            aggregations {
                alignment_period   = "300s"
                per_series_aligner = "ALIGN_DELTA"
                cross_series_reducer = "REDUCE_SUM"
                group_by_fields = ["metric.label.bigquery_table_or_view_id"]
            }
            comparison = "COMPARISON_GT"
            duration   = "0s"
            trigger {
                count = 1
            }
            threshold_value = 1000
        }
    }
    alert_strategy {
        auto_close  = "1800s"
    }
    enabled = true
    notification_channels = [google_monitoring_notification_channel.bigquery-update-notifications-pubsub.name]
}

resource "google_monitoring_notification_channel" "bigquery-update-notifications-pubsub" {
  project = var.project_id
  display_name = "BigQuery Updates Notification Channel"
  type         = "pubsub"
  labels = {
    topic = google_pubsub_topic.training-model-build-trigger-topic.id
  }
}

# Grant the pubsub default service account the storage object admin role
resource "google_project_iam_member" "pubsub-monitoring-sa-pubsub-publisher" {
  project = var.project_id
  role     = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-monitoring-notification.iam.gserviceaccount.com"
}

# Create a Pub/Sub Topic used for notifications on bigquery updates
resource "google_pubsub_topic" "training-model-build-trigger-topic" {
  project     = var.project_id
  name     = "bigquery-update-notifications"
  provider = google-beta
}

#################################################################
# INFRASTRUCTURE SHARED BY MLOPS PIPELINES AND DIFFERENT MODELS #
#################################################################

# Create the Google Artifact Repo registry used for interim images used in the MLOps pipelines
resource "google_artifact_registry_repository" "mlops-images" {
  project    = var.project_id
  location      = var.region
  repository_id = "mlops-images"
  description   = "Managed by Terraform - repo for Images for all MLOps images"
  format        = "DOCKER"

  docker_config {
    immutable_tags = false
  }
}

# Create the Service Account to use with the Cloud Run services and the pubsub triggers
resource "google_service_account" "pipeline-triggers-service-account" {
  project = var.project_id
  account_id   = "pipeline-triggers-sa"
  display_name = "Pipeline Triggers SA"
  description  = "Service Account for the pipeline triggers"
}

# Allow the PubSub agent to create tokens
resource "google_project_service_identity" "pubsub_agent" {
  provider = google-beta
  project  = var.project_id
  service  = "pubsub.googleapis.com"
}

resource "google_project_iam_member" "project_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_project_service_identity.pubsub_agent.email}"
}

# Enable Cloud Run API
resource "google_project_service" "cloud-run-api-enable" {
  project = var.project_id
  service = "run.googleapis.com"
}