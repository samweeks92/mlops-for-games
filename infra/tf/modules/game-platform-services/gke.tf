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

resource "google_container_cluster" "unified-data-cluster" {
  project  = var.project_id
  name     = var.gke_cluster_name
  location = var.region
  network  = google_compute_network.vpc_network.name

  ip_allocation_policy {}

  # Enabling Autopilot for this cluster
  enable_autopilot = true
}

resource "google_service_account" "udp_sa_service_account" {
  project      = var.project_id
  account_id   = "udp-sa"
  display_name = "Terraform-managed SA for gke cluster workloads"
}

resource "google_project_iam_member" "udp_sa_project_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.udp_sa_service_account.email}"
}

resource "google_service_account_iam_member" "udp_sa_wi" {
  
  service_account_id = google_service_account.udp_sa_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[game-event-ns/udp-k8s-sa]"

  depends_on = [
    google_container_cluster.unified-data-cluster,
    google_service_account.udp_sa_service_account
  ]
}