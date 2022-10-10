/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


module "gke-cluster" {
  source                   = "../../../modules/gke-cluster"
  for_each                 = var.clusters
  name                     = each.key
  project_id               = module.gke-project-0.project_id
  description              = each.value.description
  location                 = each.value.location
  cluster_autoscaling      = each.value.cluster_autoscaling
  enable_addons            = each.value.enable_addons
  enable_features          = each.value.enable_features
  issue_client_certificate = each.value.issue_client_certificate
  labels                   = each.value.labels
  logging_config           = each.value.logging_config
  maintenance_config       = each.value.maintenance_config
  max_pods_per_node        = each.value.max_pods_per_node
  min_master_version       = each.value.min_master_version
  monitoring_config        = each.value.monitoring_config
  node_locations           = each.value.node_locations
  private_cluster_config = var.private_cluster_config == null ? null : merge(
    var.private_cluster_config,
    {
      master_ipv4_cidr_block = each.value.vpc_config.master_ipv4_cidr_block
    }
  )
  release_channel = each.value.release_channel
  vpc_config      = each.value.vpc_config
}
