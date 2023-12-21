# Get Project ID
data "google_project" "project" {
  project_id = var.project_id
}

# Enable PubSub API
resource "google_project_service" "pubsub-api-enable" {
  project = var.project_id
  service = "pubsub.googleapis.com"
}

# Create PubSub Topic for streaming data
resource "google_pubsub_topic" "game-telemetry" {
  project = var.project_id
  name    = var.game_telemetry_topic
  depends_on = [
    google_project_service.pubsub-api-enable
  ]
}

# Enable Dataflow API
resource "google_project_service" "dataflow-api-enable" {
  project = var.project_id
  service = "dataflow.googleapis.com"
}

# Grant the Dataflow service account the storage object admin role
resource "google_project_iam_member" "dataflow-sa-object-admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# Grant the Dataflow service account the viewer role
resource "google_project_iam_member" "dataflow-sa-viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# Grant the Dataflow service account the dataflow worker role
resource "google_project_iam_member" "dataflow-sa-dataflow-worker" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# Grant the Dataflow service account the pubsub admin role
resource "google_project_iam_member" "dataflow-sa-pubsub-admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# Grant the Dataflow service account the bigquery data editor role
resource "google_project_iam_member" "dataflow-sa-bq-data-editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_storage_bucket" "dataflow-config-bucket" {
  project                     = var.project_id
  name                        = "${var.project_id}-dataflow"
  location                    = var.region
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

resource "local_file" "config" {
  content = templatefile("${path.module}/resources/streaming-beam.tftpl", { project_id = var.project_id, region = var.region })
  filename = "${path.module}/resources/streaming-beam.json"  
}

# Add the dataflow template config file to the dataflow-config Bucket
resource "google_storage_bucket_object" "config" {
  name   = "templates/streaming-beam-tf.json"
  source = local_file.config.filename
  bucket = google_storage_bucket.dataflow-config-bucket.name

  depends_on = [
    local_file.config
  ]
}

# Upload the config file used to define the Dataflow Template streaming job.
resource "google_dataflow_flex_template_job" "streaming-job" {
  provider                = google-beta
  project                 = var.project_id
  region                  = var.region
  name                    = "dataflow-streaming-job-tf"
  container_spec_gcs_path = "gs://${google_storage_bucket.dataflow-config-bucket.name}/templates/streaming-beam-tf.json"
  parameters = {
    input_topic = "projects/${var.project_id}/topics/${var.game_telemetry_topic}",
    output_table= "${var.project_id}:${var.bigquery_config.dataset}.${var.bigquery_config.table}"
  }

  depends_on = [
    google_project_service.dataflow-api-enable,
    google_project_iam_member.dataflow-sa-object-admin,
    google_project_iam_member.dataflow-sa-dataflow-worker,
    google_project_iam_member.dataflow-sa-pubsub-admin,
    google_project_iam_member.dataflow-sa-bq-data-editor,
    google_storage_bucket_object.config
  ]

}