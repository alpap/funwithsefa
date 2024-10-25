provider "google" {
  project = "YOUR_PROJECT_ID"
  region  = "us-central1"
}

resource "google_compute_instance" "app-instance-1" {
  name         = "app-instance-1"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOT
              #! /bin/bash
              sudo apt-get update
              sudo apt-get install -y python3-pip
              sudo python3 -m http.server 300
              sudo python3 -m http.server 5000
              EOT
}

resource "google_compute_instance" "app-instance-2" {
  name         = "app-instance-2"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOT
              #! /bin/bash
              sudo apt-get update
              sudo apt-get install -y python3-pip
              sudo python3 -m http.server 300
              sudo python3 -m http.server 5000
              EOT
}

resource "google_compute_health_check" "http-health-check-300" {
  name                = "http-health-check-300"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 300
  }
}

resource "google_compute_health_check" "http-health-check-5000" {
  name                = "http-health-check-5000"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 5000
  }
}

resource "google_compute_instance_group" "app-instance-group" {
  name        = "app-instance-group"
  zone        = "us-central1-a"
  instances   = [google_compute_instance.app-instance-1.id, google_compute_instance.app-instance-2.id]
  named_port {
    name = "port300"
    port = 300
  }
  named_port {
    name = "port5000"
    port = 5000
  }
}

resource "google_compute_firewall" "default" {
  name    = "default-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["300", "5000"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_backend_service" "default" {
  name                  = "backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.http-health-check-300.id, google_compute_health_check.http-health-check-5000.id]

  backend {
    group = google_compute_instance_group.app-instance-group.self_link
  }
}

resource "google_compute_url_map" "default" {
  name            = "url-map"
  default_service = google_compute_backend_service.default.self_link
}

resource "google_compute_target_http_proxy" "default" {
  name    = "http-lb-proxy"
  url_map = google_compute_url_map.default.self_link
}

resource "google_compute_global_forwarding_rule" "default" {
  name        = "http-content-rule"
  target      = google_compute_target_http_proxy.default.self_link
  port_range  = "80"
  ip_protocol = "TCP"
}

output "instance_1_name" {
  value = google_compute_instance.app-instance-1.name
}

output "instance_2_name" {
  value = google_compute_instance.app-instance-2.name
}

output "backend_service_name" {
  value = google_compute_backend_service.default.name
}

output "load_balancer_ip" {
  value = google_compute_global_forwarding_rule.default.ip_address
}