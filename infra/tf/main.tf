module "game-platform-services" {

  # Set Source
  source = "./modules/game-platform-services"

  project_id = var.project_id
  region     = var.region
  gke_cluster_name = var.gke_cluster_name
  vpc_name   = var.vpc_name

}

module "data-pipelines-and-processing" {

  # Set Source
  source = "./modules/data-pipelines-and-processing"

  project_id           = var.project_id
  region               = var.region
  game_telemetry_topic = var.game_telemetry_topic
  bigquery_config      = var.bigquery_config

}

module "data-storage" {

  # Set Source
  source = "./modules/data-storage"

  project_id      = var.project_id
  bigquery_config = var.bigquery_config

}

module "machine-learning-operations" {

  # Set Source
  source = "./modules/machine-learning-operations"

  project_id                  = var.project_id
  region                      = var.region
  services_artifact_repo_name = google_artifact_registry_repository.services.repository_id
  cloud_source_repo_name      = var.cloud_source_repo_name
  dataset_id                  = module.data-storage.dataset_id
  dataset_location            = module.data-storage.dataset_location
  table_id                    = module.data-storage.table_id

}