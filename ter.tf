# Initialize the provider
provider "google" {
  project = "your-google-cloud-project-id"
  region  = "us-central1"
  zone    = "us-central1-a"
}

# Create a network
resource "google_compute_network" "vpc_network" {
  name = "example-vpc-network"
}

# Create a firewall rule to allow HTTP traffic
resource "google_compute_firewall" "firewall_rule" {
  name    = "allow-http"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Create two compute instances
resource "google_compute_instance" "instance" {
  count        = 2
  name         = "example-instance-${count.index}"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name

    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y apache2
    sudo systemctl start apache2
    sudo bash -c 'echo Hello, world! > /var/www/html/index.html'
  EOF
}

# Create a health check for the load balancer
resource "google_compute_http_health_check" "default" {
  name               = "example-health-check"
  request_path       = "/"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 2
}

# Create a backend service including the instance group
resource "google_compute_backend_service" "default" {
  name       = "example-backend-service"
  port_name  = "http"
  protocol   = "HTTP"
  timeout_sec = 10
  health_checks = [google_compute_http_health_check.default.id]

  backend {
    group = google_compute_instance.instance.self_link
  }
}

# Create a URL map to route requests to the backend service
resource "google_compute_url_map" "default" {
  name            = "example-url-map"
  default_service = google_compute_backend_service.default.id
}

# Create a target HTTP proxy to route requests to the URL map
resource "google_compute_target_http_proxy" "default" {
  name   = "example-http-proxy"
  url_map = google_compute_url_map.default.id
}

# Create a global forwarding rule to route traffic to the target HTTP proxy
resource "google_compute_global_forwarding_rule" "default" {
  name       = "example-forwarding-rule"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
}

output "load_balancer_ip" {
  value = google_compute_global_forwarding_rule.default.ip_address
}
