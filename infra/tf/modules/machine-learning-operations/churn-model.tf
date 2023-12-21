####################################
# TRAINING PIPELINE INFRASTRUCTURE #
####################################

# Create the PubSub subscription for the bigquery updates topic
resource "google_pubsub_subscription" "cloudrun-run-dataform" {
  project = var.project_id
  name  = "cloudrun-run-churn-dataform"
  topic = google_pubsub_topic.training-model-build-trigger-topic.name
  push_config {
    push_endpoint = google_cloud_run_v2_service.churn-run-dataform.uri
    oidc_token {
      service_account_email = google_service_account.pipeline-triggers-service-account.email
    }
    attributes = {
      x-goog-version = "v1"
    }
  }
  depends_on = [google_cloud_run_v2_service.churn-run-dataform]
}

# Allow the Pipeline Triggers SA to invoke the churn-run-dataform Cloud Run service
resource "google_cloud_run_service_iam_member" "churn-run-dataform-trigger-service-account-iam-member" {
  project = var.project_id
  location = var.region
  service  = google_cloud_run_v2_service.churn-run-dataform.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pipeline-triggers-service-account.email}"
}

# Cloud Build Service placeholder image to be updated by build trigger
resource "google_cloud_run_v2_service" "churn-run-dataform" {
  project = var.project_id
  name     = "churn-run-dataform"
  location = var.region
  template {
    labels = {
      managed-by = "terraform"
    } 
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      env {
        name  = "PROJECT"
        value = var.project_id
      }
      env {
        name  = "LOCATION"
        value = var.region
      }
      env {
        name  = "DATAFORM_REPO_NAME"
        value = google_dataform_repository.churn_respository.name
      }
      env {
        name  = "DATAFORM_RELEASE_NAME"
        value = google_dataform_repository_release_config.churn_release_config.name
      }
    }
    service_account = google_service_account.pipeline-triggers-service-account.email
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image
    ]
  }
  
  depends_on = [google_project_service.cloud-run-api-enable]
}

# Create the Cloud Build trigger for building the Cloud Run service that's used to run dataform (replaces image above)
resource "google_cloudbuild_trigger" "churn-run-dataform-trigger" {

  name        = "ml-training-churn-cloudrun-run-dataform"
  description = "(Managed by Terraform - Do not manually edit). ml-training-churn-cloudrun-run-dataform"
  project     = var.project_id
  location    = var.region

  trigger_template {
    project_id  = var.project_id
    branch_name = "^main$"
    repo_name   = var.cloud_source_repo_name
  }

  included_files = ["ml_training/player_churn/cloudrun_run_dataform/**"]

  substitutions = {
    _GCP_PROJECT_ID                      = var.project_id
    _ARTIFACT_REPO_NAME                  = google_artifact_registry_repository.mlops-images.repository_id
    _ARTIFACT_REPO_REGION                = var.region
    _IMAGE_NAME                          = "churn-cloudrun-run-dataform"
  }
   
  filename = "ml_training/player_churn/cloudrun_run_dataform/cloudbuild.yaml"

}

# Grant the pipeline triggers SA dataform admin
resource "google_project_iam_member" "pipeline-trigger-service-account-dataform-admin" {
  project = var.project_id
  role     = "roles/dataform.admin"
  member  = "serviceAccount:${google_service_account.pipeline-triggers-service-account.email}"
}

# Enable Dataform API
resource "google_project_service" "dataform-api-enable" {
  project = var.project_id
  service = "dataform.googleapis.com"
}

resource "google_dataform_repository" "churn_respository" {
  project      = var.project_id
  region       = var.region
  provider     = google-beta
  name         = "churn_repository"

  depends_on     = [google_project_service.dataform-api-enable]

}

resource "google_dataform_repository_release_config" "churn_release_config" {
  provider = google-beta

  project    = google_dataform_repository.churn_respository.project
  region     = google_dataform_repository.churn_respository.region
  repository = google_dataform_repository.churn_respository.name

  name          = "churn_release"
  git_commitish = "main"
  cron_schedule = "0 1 * * *"
  time_zone     = "America/New_York"

  code_compilation_config {
    default_database = var.project_id
    default_schema   = var.dataset_id
    default_location = var.dataset_location
    assertion_schema = var.dataset_id
    vars = {
      bucket_name = google_storage_bucket.mlops-churn-bucket.name
    }
  }
}

resource "google_dataform_repository_workflow_config" "churn_workflow" {
  provider = google-beta

  project        = google_dataform_repository.churn_respository.project
  region         = google_dataform_repository.churn_respository.region
  repository     = google_dataform_repository.churn_respository.name
  name           = "churn_workflow"
  release_config = google_dataform_repository_release_config.churn_release_config.id

  invocation_config {
    transitive_dependencies_included         = true
    transitive_dependents_included           = true
    fully_refresh_incremental_tables_enabled = true
  }

  cron_schedule   = "0 7 * * *"
  time_zone       = "America/New_York"
}

# Grant the Datafrom default SA with permissions to access Bigquery
resource "google_project_iam_member" "dataform-bigquery-editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

# Grant the Datafrom default SA with permissions to access Bigquery
resource "google_project_iam_member" "dataform-bigquery-viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

# Grant the Datafrom default SA with permissions to access Bigquery
resource "google_project_iam_member" "dataform-bigquery-job-user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

# Grant the Datafrom default SA with permissions to use GCS objects
resource "google_project_iam_member" "dataform-storage-object-user" {
  project = var.project_id
  role    = "roles/storage.objectUser"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

# Create the MLOps Bucket where the training job will output the model
resource "google_storage_bucket" "mlops-churn-bucket" {
  project       = var.project_id
  name          = "${var.project_id}-mlops-churn"
  location      = var.region

  uniform_bucket_level_access = true
  public_access_prevention = "enforced"
  versioning {
    enabled = true
  }
  
}

###################################
# SERVING PIPELINE INFRASTRUCTURE #
###################################

# Create a Pub/Sub Topic used for notifications on new object changes in the mlops-bucket
resource "google_pubsub_topic" "churn-model-artifacts-update-notifications-topic" {
  project     = var.project_id
  name     = "churn-model-artifacts-update-notifications"
  provider = google-beta
}

# Enable notifications by giving the correct IAM permission to the unique service account.
resource "google_pubsub_topic_iam_member" "churn-iam-member" {
  provider = google-beta
  topic    = google_pubsub_topic.churn-model-artifacts-update-notifications-topic.id
  role     = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

// Create a Pub/Sub notification for the mlops-churn bucket
resource "google_storage_notification" "churn-notification" {
  provider       = google-beta
  bucket         = google_storage_bucket.mlops-churn-bucket.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.churn-model-artifacts-update-notifications-topic.id
  event_types    = ["OBJECT_FINALIZE"]
  object_name_prefix = "churn-batch-predictions"
  depends_on     = [google_pubsub_topic_iam_member.churn-iam-member]
}


// Create the Cloud Build trigger that is triggered by the PubSub notification topic
resource "google_cloudbuild_trigger" "ml-serving-churn" {

  name        = "churn-lookup-batch-predictions-update"
  description = "(Managed by Terraform - Do not manually edit). ml-serving-churn-batch-predictions-update"
  project     = var.project_id
  location    = var.region

  pubsub_config {
      topic = google_pubsub_topic.churn-model-artifacts-update-notifications-topic.id
  }

  source_to_build {
    uri       = "https://source.developers.google.com/p/${var.project_id}/r/${var.cloud_source_repo_name}"
    ref       = "refs/heads/main"
    repo_type = "CLOUD_SOURCE_REPOSITORIES"
  }

  git_file_source {
    path      = "services/churn_lookup/cloudbuild.yaml"
    uri       = "https://source.developers.google.com/p/${var.project_id}/r/${var.cloud_source_repo_name}"
    revision  = "refs/heads/main"
    repo_type = "CLOUD_SOURCE_REPOSITORIES"
  }

  substitutions = {
    _GCP_PROJECT_ID                      = var.project_id
    _BUCKET_NAME                         = google_storage_bucket.mlops-churn-bucket.name
    _ARTIFACT_REPO_NAME                  = var.services_artifact_repo_name
    _ARTIFACT_REPO_REGION                = var.region
    _IMAGE_NAME                          = "churn-lookup"
  }

}