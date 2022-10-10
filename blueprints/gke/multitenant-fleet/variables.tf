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

variable "billing_account_id" {
  description = "Billing account id."
  type        = string
}

variable "clusters" {
  description = "Cluster configuration, keys will be used for cluster names."
  type = map(object({
    cluster_autoscaling = optional(object({
      auto_provisioning_defaults = optional(object({
        boot_disk_kms_key = optional(string)
        image_type        = optional(string)
        oauth_scopes      = optional(list(string))
        service_account   = optional(string)
      }))
      cpu_limits = optional(object({
        min = number
        max = number
      }))
      mem_limits = optional(object({
        min = number
        max = number
      }))
    }))
    enable_addons = optional(
      object({
        cloudrun                       = optional(bool, false)
        config_connector               = optional(bool, false)
        dns_cache                      = optional(bool, false)
        gce_persistent_disk_csi_driver = optional(bool, false)
        gcp_filestore_csi_driver       = optional(bool, false)
        gke_backup_agent               = optional(bool, false)
        horizontal_pod_autoscaling     = optional(bool, false)
        http_load_balancing            = optional(bool, false)
        istio = optional(object({
          enable_tls = bool
        }))
        kalm           = optional(bool, false)
        network_policy = optional(bool, false)
      }),
      {
        horizontal_pod_autoscaling = true
        http_load_balancing        = true
      }
    )
    enable_features = optional(
      object({
        autopilot            = optional(bool, false)
        binary_authorization = optional(bool, false)
        cloud_dns = optional(object({
          provider = optional(string)
          scope    = optional(string)
          domain   = optional(string)
        }))
        database_encryption = optional(object({
          state    = string
          key_name = string
        }))
        dataplane_v2         = optional(bool, false)
        groups_for_rbac      = optional(string)
        intranode_visibility = optional(bool, false)
        l4_ilb_subsetting    = optional(bool, false)
        pod_security_policy  = optional(bool, false)
        resource_usage_export = optional(object({
          dataset                              = string
          enable_network_egress_metering       = optional(bool)
          enable_resource_consumption_metering = optional(bool)
        }))
        shielded_nodes = optional(bool, false)
        tpu            = optional(bool, false)
        upgrade_notifications = optional(object({
          topic_id = optional(string)
        }))
        vertical_pod_autoscaling = optional(bool, false)
        workload_identity        = optional(bool, false)
      }),
      {
        workload_identity = true
      }
    )
    issue_client_certificate = optional(bool, false)
    labels                   = optional(map(string))
    location                 = string
    logging_config           = optional(list(string), ["SYSTEM_COMPONENTS"])
    maintenance_config = optional(
      object({
        daily_window_start_time = optional(string)
        recurring_window = optional(object({
          start_time = string
          end_time   = string
          recurrence = string
        }))
        maintenance_exclusions = optional(list(object({
          name       = string
          start_time = string
          end_time   = string
          scope      = optional(string)
        })))
      }),
      {
        daily_window_start_time = "03:00"
        recurring_window        = null
        maintenance_exclusion   = []
      }
    )
    max_pods_per_node  = optional(number, 110)
    min_master_version = optional(string)
    monitoring_config  = optional(list(string), ["SYSTEM_COMPONENTS"])
    node_locations     = optional(list(string))
    release_channel    = optional(string)
    vpc_config = object({
      network                  = string
      subnetwork               = string
      master_authorized_ranges = optional(map(string))
      master_ipv4_cidr_block   = optional(string)
      secondary_range_blocks = optional(object({
        pods     = string
        services = string
      }), )
      secondary_range_names = optional(object({
        pods     = string
        services = string
      }), { pods = "pods", services = "services" })
    })
  }))
}

variable "fleet_configmanagement_clusters" {
  description = "Config management features enabled on specific sets of member clusters, in config name => [cluster name] format."
  type        = map(list(string))
  default     = {}
  nullable    = false
}

variable "fleet_configmanagement_templates" {
  description = "Sets of config management configurations that can be applied to member clusters, in config name => {options} format."
  type = map(object({
    binauthz = bool
    config_sync = object({
      git = object({
        gcp_service_account_email = string
        https_proxy               = string
        policy_dir                = string
        secret_type               = string
        sync_branch               = string
        sync_repo                 = string
        sync_rev                  = string
        sync_wait_secs            = number
      })
      prevent_drift = string
      source_format = string
    })
    hierarchy_controller = object({
      enable_hierarchical_resource_quota = bool
      enable_pod_tree_labels             = bool
    })
    policy_controller = object({
      audit_interval_seconds     = number
      exemptable_namespaces      = list(string)
      log_denies_enabled         = bool
      referential_rules_enabled  = bool
      template_library_installed = bool
    })
    version = string
  }))
  default  = {}
  nullable = false
}

variable "fleet_features" {
  description = "Enable and configue fleet features. Set to null to disable GKE Hub if fleet workload identity is not used."
  type = object({
    appdevexperience             = bool
    configmanagement             = bool
    identityservice              = bool
    multiclusteringress          = string
    multiclusterservicediscovery = bool
    servicemesh                  = bool
  })
  default = null
}

variable "fleet_workload_identity" {
  description = "Use Fleet Workload Identity for clusters. Enables GKE Hub if set to true."
  type        = bool
  default     = false
  nullable    = false
}

variable "folder_id" {
  description = "Folder used for the GKE project in folders/nnnnnnnnnnn format."
  type        = string
}

variable "group_iam" {
  description = "Project-level IAM bindings for groups. Use group emails as keys, list of roles as values."
  type        = map(list(string))
  default     = {}
  nullable    = false
}

variable "iam" {
  description = "Project-level authoritative IAM bindings for users and service accounts in  {ROLE => [MEMBERS]} format."
  type        = map(list(string))
  default     = {}
  nullable    = false
}

variable "labels" {
  description = "Project-level labels."
  type        = map(string)
  default     = {}
}

variable "nodepool_defaults" {
  description = ""
  type = object({
    image_type        = string
    max_pods_per_node = number
    node_locations    = list(string)
    node_tags         = list(string)
    node_taints       = list(string)
  })
  default = {
    image_type        = "COS_CONTAINERD"
    max_pods_per_node = 110
    node_locations    = null
    node_tags         = null
    node_taints       = []
  }
}

variable "nodepools" {
  description = ""
  type = map(map(object({
    node_count         = number
    node_type          = string
    initial_node_count = number
    overrides = object({
      image_type        = string
      max_pods_per_node = number
      node_locations    = list(string)
      node_tags         = list(string)
      node_taints       = list(string)
    })
    spot = bool
  })))
}

variable "prefix" {
  description = "Prefix used for resources that need unique names."
  type        = string
}

variable "private_cluster_config" {
  description = "Private cluster configuration, applied to all clusters."
  type = object({
    enable_private_endpoint = optional(bool)
    master_global_access    = optional(bool)
    peering_config = optional(object({
      export_routes = optional(bool)
      import_routes = optional(bool)
      project_id    = optional(string)
    }))
  })
  default = null
}

variable "project_id" {
  description = "ID of the project that will contain all the clusters."
  type        = string
}

variable "project_services" {
  description = "Additional project services to enable."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "vpc_config" {
  description = "VPC-level configuration."
  type = object({
    host_project_id = string
  })
}
