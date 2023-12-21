resource "google_compute_network" "vpc_network" {
  project                 = var.project_id
  name                    = "default"
  auto_create_subnetworks = true
  mtu                     = 1460
  routing_mode            = "REGIONAL"
}

resource "google_compute_firewall" "default-allow-internal" {
  name    = "default-allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.128.0.0/9"]
  
}

resource "google_compute_firewall" "default-allow-ssh" {
  name    = "default-allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  
}

resource "google_compute_firewall" "default-allow-icmp" {
  name    = "default-allow-icmp"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  
}