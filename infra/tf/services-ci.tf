resource "google_artifact_registry_repository" "services" {
  project    = var.project_id
  location      = var.region
  repository_id = "services-images"
  description   = "Managed by Terraform - repo for Images for all services"
  format        = "DOCKER"

  docker_config {
    immutable_tags = false
  }
}

module "ci-triggers-tcp-load" {

  # Set Source
  source = "./modules/ci-triggers"

  # Define Variables
  project                             = var.project_id
  region                              = var.region
  cloud-source-repo-name              = var.cloud_source_repo_name
  artifact-registry-repo-name         = google_artifact_registry_repository.services.repository_id
  source-code-directory-path          = "services/tcp_load"
  trigger-name                        = "tcp-load"
  included-files                      = ["services/tcp_load/**"]
  substitutions                       = {
    _GCP_PROJECT_ID                      = var.project_id
    _ARTIFACT_REPO_NAME                  = google_artifact_registry_repository.services.repository_id
    _ARTIFACT_REPO_REGION                = var.region
    _IMAGE_NAME                          = "tcp-load"
  }

}

module "ci-triggers-event_ingest" {

  # Set Source
  source = "./modules/ci-triggers"

  # Define Variables
  project                             = var.project_id
  region                              = var.region
  cloud-source-repo-name              = var.cloud_source_repo_name
  artifact-registry-repo-name         = google_artifact_registry_repository.services.repository_id
  source-code-directory-path          = "services/event_ingest"
  trigger-name                        = "event-ingest"
  included-files                      = ["services/event_ingest/**", "k8s/templates/event-ingest.example.yaml", "k8s/templates/namespace-wi.example.yaml"]
  substitutions                       = {
    _GCP_PROJECT_ID                      = var.project_id
    _ARTIFACT_REPO_NAME                  = google_artifact_registry_repository.services.repository_id
    _ARTIFACT_REPO_REGION                = var.region
    _IMAGE_NAME                          = "event-ingest"
  }


}

module "ci-triggers-dataflow-streaming-beam" {

  # Set Source
  source = "./modules/ci-triggers"

  # Define Variables
  project                             = var.project_id
  region                              = var.region
  cloud-source-repo-name              = var.cloud_source_repo_name
  artifact-registry-repo-name         = google_artifact_registry_repository.services.repository_id
  source-code-directory-path          = "services/dataflow"
  trigger-name                        = "streaming-beam"
  included-files                      = ["services/dataflow/**"]
  substitutions                       = {
    _GCP_PROJECT_ID                      = var.project_id
    _ARTIFACT_REPO_NAME                  = google_artifact_registry_repository.services.repository_id
    _ARTIFACT_REPO_REGION                = var.region
    _IMAGE_NAME                          = "streaming-beam"
  }

}

module "ci-triggers-ml-serving-spend" {

  # Set Source
  source = "./modules/ci-triggers"

  # Define Variables
  project                             = var.project_id
  region                              = var.region
  cloud-source-repo-name              = var.cloud_source_repo_name
  artifact-registry-repo-name         = google_artifact_registry_repository.services.repository_id
  source-code-directory-path          = "services/ml_serving_spend"
  trigger-name                        = "ml-serving-spend"
  included-files                      = ["services/ml_serving_spend/**", "k8s/templates/ml_serving_spend.example.com"]
  substitutions                       = {
    _GCP_PROJECT_ID                      = var.project_id
    _ARTIFACT_REPO_NAME                  = google_artifact_registry_repository.services.repository_id
    _ARTIFACT_REPO_REGION                = var.region
    _MLOPS_BUCKET_NAME                   = module.machine-learning-operations.mlops-spend-bucket-name
    _MODEL_ID                            = ""
    _MODEL_TIMESTAMP                     = ""
  }

}

module "ci-triggers-churn_lookup" {

  # Set Source
  source = "./modules/ci-triggers"

  # Define Variables
  project                             = var.project_id
  region                              = var.region
  cloud-source-repo-name              = var.cloud_source_repo_name
  artifact-registry-repo-name         = google_artifact_registry_repository.services.repository_id
  source-code-directory-path          = "services/churn_lookup"
  trigger-name                        = "churn-lookup"
  included-files                      = ["services/churn_lookup/**", "k8s/templates/churn_lookup.example.com"]
  substitutions                       = {
    _GCP_PROJECT_ID                      = var.project_id
    _ARTIFACT_REPO_NAME                  = google_artifact_registry_repository.services.repository_id
    _ARTIFACT_REPO_REGION                = var.region
    _BUCKET_NAME                         = module.machine-learning-operations.mlops-churn-bucket-name
    _IMAGE_NAME                          = "churn-lookup"
  }

}