# Copyright 2023 Google LLC All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Project Variables
variable "project_id" {
  type        = string
  description = "GCP Project Name"
}

variable "region" {
  type        = string
  description = "GCP region"
}

# VPC Variables
variable "gke_cluster_name" {
  type        = string
  description = "The name of the GKE cluster"
}

# VPC Variables
variable "vpc_name" {
  type        = string
  description = "VPC Name"
}