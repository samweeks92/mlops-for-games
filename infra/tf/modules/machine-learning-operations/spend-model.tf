####################################
# TRAINING PIPELINE INFRASTRUCTURE #
####################################

# Upload the default spend model pipeline configuration to the Bucket. Include ignore_changes = [all] to enable Data Scientists to make any updates to this object.
resource "local_file" "pipeline-config" {
  content = templatefile("${path.module}/resources/spend_pipeline.tftpl", { bucket_name = google_storage_bucket.mlops-spend-bucket.name, region = var.region })
  filename = "${path.module}/resources/spend_pipeline.yaml"
}

resource "google_storage_bucket_object" "object" {
  name   = "spend_pipeline.yaml"
  bucket = google_storage_bucket.mlops-spend-bucket.name
  source = local_file.pipeline-config.filename

  depends_on = [
    local_file.pipeline-config
  ]

  lifecycle {
    ignore_changes = all
  }
}

# Create the PubSub subscription for the bigquery updates topic
resource "google_pubsub_subscription" "cloudrun-run-pipeline" {
  project = var.project_id
  name  = "cloudrun-run-spend-pipeline"
  topic = google_pubsub_topic.training-model-build-trigger-topic.name
  push_config {
    push_endpoint = google_cloud_run_v2_service.spend-run-pipeline.uri
    oidc_token {
      service_account_email = google_service_account.pipeline-triggers-service-account.email
    }
    attributes = {
      x-goog-version = "v1"
    }
  }
  depends_on = [google_cloud_run_v2_service.spend-run-pipeline]
}

# Allow the Pipeline Triggers SA to invoke the spend-run-pipeline Cloud Run service
resource "google_cloud_run_service_iam_member" "spend-run-pipeline-trigger-service-account-iam-member" {
  project = var.project_id
  location = var.region
  service  = google_cloud_run_v2_service.spend-run-pipeline.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pipeline-triggers-service-account.email}"
}

# Cloud Build Service placeholder image to be updated by build trigger
resource "google_cloud_run_v2_service" "spend-run-pipeline" {
  project = var.project_id
  name     = "spend-run-pipeline"
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
        name  = "PIPELINE_ROOT"
        value = google_storage_bucket.mlops-spend-bucket.url
      }
      env {
        name  = "SERVICE_ACCOUNT"
        value = google_service_account.pipeline_service_account.email
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

# Create the Cloud Build trigger for building the Cloud Run service that's used to run the pipeline (replaces image above)
resource "google_cloudbuild_trigger" "spend-run-pipeline-trigger" {

  name        = "ml-training-spend-cloudrun-run-pipeline"
  description = "(Managed by Terraform - Do not manually edit). ml-training-spend-cloudrun-run-pipeline"
  project     = var.project_id
  location    = var.region

  trigger_template {
    project_id  = var.project_id
    branch_name = "^main$"
    repo_name   = var.cloud_source_repo_name
  }

  included_files = ["ml_training/predict_spend/cloudrun_run_pipeline/**"]

  substitutions = {
    _GCP_PROJECT_ID                      = var.project_id
    _ARTIFACT_REPO_NAME                  = google_artifact_registry_repository.mlops-images.repository_id
    _ARTIFACT_REPO_REGION                = var.region
    _IMAGE_NAME                          = "spend-cloudrun-run-pipeline"
  }
   
  filename = "ml_training/predict_spend/cloudrun_run_pipeline/cloudbuild.yaml"

}

# Grant the pipeline triggers SA AI Platform User
resource "google_project_iam_member" "pipeline-trigger-service-account-ai-platform-user" {
  project = var.project_id
  role     = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.pipeline-triggers-service-account.email}"
}

# Grant the pipeline triggers GCS Storage Object admin
resource "google_project_iam_member" "pipeline-trigger-service-account-storage-object-admin" {
  project = var.project_id
  role     = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.pipeline-triggers-service-account.email}"
}

# Create the Pipeline SA
resource "google_service_account" "pipeline_service_account" {
  project = var.project_id
  account_id   = "pipeline-sa"
  display_name = "Vertex AI Pipeline SA - managed through terraform"
}

resource "google_project_service_identity" "ai_platform_sa" {
  provider = google-beta
  project = var.project_id
  service = "aiplatform.googleapis.com"
}

# Grant the Vertex AI Service Agent SA with permissions to create Service Account tokens (for the Pipeline SA)
resource "google_project_iam_member" "vertex-serivice-agent-token-creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_project_service_identity.ai_platform_sa.email}"
}

# Grant the Pipeline Triggers SA permissions to act as the Pipeline SA
resource "google_service_account_iam_member" "pipeline-triggers-sa-actas-pipeline-triggers-sa" {
  service_account_id = google_service_account.pipeline_service_account.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.pipeline-triggers-service-account.email}"
}

# Grant the Cloud Build Service Account permissions to act as the Pipeline SA
resource "google_service_account_iam_member" "pipeline-sa-actas" {
  service_account_id = google_service_account.pipeline_service_account.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Grant the Cloud Build Service Account permissions to act as the Pipeline Triggers SA
resource "google_service_account_iam_member" "gcb-sa-actas-pipeline-triggers-sa" {
  service_account_id = google_service_account.pipeline-triggers-service-account.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Grant the Pipeline SA AI Platform User
resource "google_project_iam_member" "pipeline-sa-aiplatform-user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}

# Grant the Pipeline SA the artifact registry admin
resource "google_project_iam_member" "pipeline-sa-gar-admin" {
  project = var.project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}

# Grant the Pipeline SA Storage Admin
resource "google_project_iam_member" "pipeline-sa-storage-object-admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"

}

# Grant the Pipeline SA Bigquery data editor on the dataset
resource "google_bigquery_dataset_iam_member" "editor" {
  project    = var.project_id
  dataset_id = var.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}

# Grant the Pipeline SA Bigquery data editor on the dataset
resource "google_project_iam_member" "bigquery-jobs-user" {
  project    = var.project_id
  role       = "roles/bigquery.jobUser"
  member     = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}


# Create the Pipeline Bucket where the training job will output the model
resource "google_storage_bucket" "mlops-spend-bucket" {
  project       = var.project_id
  name          = "${var.project_id}-mlops-spend"
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

# Create a Pub/Sub Topic used for notifications on new object changes in the mlops-spend bucket
resource "google_pubsub_topic" "spend-model-artifacts-update-notifications-topic" {
  project     = var.project_id
  name     = "spend-model-artifacts-update-notifications"
  provider = google-beta
}

# Enable notifications by giving the correct IAM permission to the unique service account.
resource "google_pubsub_topic_iam_member" "spend-iam-member" {
  project = var.project_id
  topic    = google_pubsub_topic.spend-model-artifacts-update-notifications-topic.id
  role     = "roles/pubsub.publisher"
  member   = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# Create a Pub/Sub notification for the mlops-spend bucket
resource "google_storage_notification" "spend-model-artifacts-update-pubsub-notification" {
  provider       = google-beta
  bucket         = google_storage_bucket.mlops-spend-bucket.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.spend-model-artifacts-update-notifications-topic.id
  event_types    = ["OBJECT_FINALIZE"]
  object_name_prefix = "model-"
  depends_on     = [google_pubsub_topic_iam_member.spend-iam-member]
}

# Allow the Spend Pipeline Triggers SA to invoke Cloud Run
resource "google_cloud_run_service_iam_member" "spend-build-image-pipeline-trigger-service-account-iam-member" {
  project = var.project_id
  location = var.region
  service  = google_cloud_run_v2_service.spend-build-serving-image.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pipeline-triggers-service-account.email}"
}

# Create the PubSub subscription for the model object updates notifications
resource "google_pubsub_subscription" "cloudrun-build-image" {
  project = var.project_id
  name  = "cloudrun-build-image-spend"
  topic = google_pubsub_topic.spend-model-artifacts-update-notifications-topic.name
  push_config {
    push_endpoint = google_cloud_run_v2_service.spend-build-serving-image.uri
    oidc_token {
      service_account_email = google_service_account.pipeline-triggers-service-account.email
    }
    attributes = {
      x-goog-version = "v1"
    }
  }
  depends_on = [google_cloud_run_v2_service.spend-build-serving-image]
}

# Cloud Run Service (placeholder image to be updated by build trigger)
resource "google_cloud_run_v2_service" "spend-build-serving-image" {
  project = var.project_id
  name     = "spend-build-serving-image"
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
        name  = "REPO_NAME"
        value = var.cloud_source_repo_name
      }
      env {
        name  = "TRIGGER_NAME"
        value = "ml-serving-spend"
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

# Cloud Build trigger to run Cloud Run service to trigger the training pipeline
resource "google_cloudbuild_trigger" "spend-build-serving-image-trigger" {

  name        = "ml-training-spend-cloudrun-build-serving-image"
  description = "(Managed by Terraform - Do not manually edit). ml-training-spend-cloudrun-build-serving-image"
  project     = var.project_id
  location    = var.region

  trigger_template {
    project_id  = var.project_id
    branch_name = "^main$"
    repo_name   = var.cloud_source_repo_name
  }

  included_files = ["ml_training/predict_spend/cloudrun_build_serving_image/**"]

  substitutions = {
    _GCP_PROJECT_ID                      = var.project_id
    _ARTIFACT_REPO_NAME                  = google_artifact_registry_repository.mlops-images.repository_id
    _ARTIFACT_REPO_REGION                = var.region
    _IMAGE_NAME                          = "spend-cloudrun-build-serving-pipeline"
  }
   
  filename = "ml_training/predict_spend/cloudrun_build_serving_image/cloudbuild.yaml"

}

# Grant the pipeline triggers SA Cloud Builds Editor
resource "google_project_iam_member" "pipeline-trigger-service-account-builds-editor" {
  project = var.project_id
  role     = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.pipeline-triggers-service-account.email}"
}

