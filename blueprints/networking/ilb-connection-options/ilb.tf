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

resource "google_compute_firewall" "echo" {
  name          = "test-ingress-echo"
  description   = "Allow HTTP to 'test-echo' tag."
  project       = "tf-playground-svpc-net"
  network       = "shared-vpc"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["test-echo"]
  allow {
    protocol = "tcp"
    ports    = [7, 7000]
  }
}

resource "google_compute_health_check" "echo" {
  project             = var.project_id
  name                = "test-echo"
  timeout_sec         = 2
  check_interval_sec  = 5
  healthy_threshold   = 1
  unhealthy_threshold = 1
  tcp_health_check {
    port = 7000
  }
}

resource "google_compute_forwarding_rule" "default" {
  provider              = google-beta
  project               = var.project_id
  name                  = "test"
  load_balancing_scheme = "INTERNAL"
  region                = var.region
  network               = var.vpc
  subnetwork            = var.subnet
  ip_protocol           = "TCP"
  ports                 = [7]
  allow_global_access   = true
  backend_service       = google_compute_region_backend_service.default.id
}

resource "google_compute_region_backend_service" "default" {
  provider                        = google-beta
  project                         = var.project_id
  name                            = "test-default"
  load_balancing_scheme           = "INTERNAL"
  region                          = var.region
  network                         = var.vpc
  health_checks                   = [google_compute_health_check.echo.self_link]
  protocol                        = "TCP"
  session_affinity                = null
  connection_draining_timeout_sec = 10
  backend {
    balancing_mode = "CONNECTION"
    group          = google_compute_instance_group.default.id
  }
  dynamic "backend" {
    for_each = var.enable_failover ? { 1 = 1 } : {}
    content {
      balancing_mode = "CONNECTION"
      group          = google_compute_instance_group.failover.id
      failover       = true
    }
  }
  # connection_tracking_policy {
  #   connection_persistence_on_unhealthy_backends = "DEFAULT_FOR_PROTOCOL"
  #   idle_timeout_sec                             = 600
  #   tracking_mode                                = "PER_CONNECTION"
  # }
  failover_policy {
    disable_connection_drain_on_failover = true
    drop_traffic_if_unhealthy            = true
  }
}
