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

resource "google_compute_instance" "default" {
  for_each     = toset([for i in range(2) : tostring(i)])
  project      = var.project_id
  name         = "test-${each.key}" # test-0 test-1
  machine_type = "e2-small"
  zone         = "${var.region}-b"
  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-93-lts"
    }
  }
  metadata = {
    user-data = templatefile("cloud-config.yaml", { host = each.key })
  }
  network_interface {
    network    = var.vpc
    subnetwork = var.subnet
  }
  tags = ["ssh", "test-echo"]
}

resource "google_compute_instance_group" "default" {
  project     = var.project_id
  name        = "test-default"
  zone        = "${var.region}-b"
  description = "Default nginx group."
  instances   = [for k, v in google_compute_instance.default : v.self_link]
  named_port {
    name = "echo"
    port = 7
  }
}

resource "google_compute_instance_group" "failover" {
  project     = var.project_id
  name        = "test-failover"
  zone        = "${var.region}-b"
  description = "Failover nginx group."
  instances   = []
  named_port {
    name = "echo"
    port = 7
  }
}
