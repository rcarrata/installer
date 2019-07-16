resource "google_storage_bucket" "ignition" {
  name = "${var.cluster_id}-bootstrap-ignition"
}

resource "google_storage_bucket_object" "ignition" {
  bucket  = "${google_storage_bucket.ignition.name}"
  name    = "bootstrap.ign"
  content = var.ignition
}

data "google_storage_object_signed_url" "ignition_url" {
  bucket   = "${google_storage_bucket.ignition.name}"
  path     = "bootstrap.ign"
  duration = "1h"
}

data "ignition_config" "redirect" {
  replace {
    source = "${data.google_storage_object_signed_url.ignition_url.signed_url}"
  }
}

resource "google_compute_firewall" "bootstrap_ingress_ssh" {
  name    = "${var.cluster_id}-bootstrap-ingress-ssh"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.cluster_id}-bootstrap"]
}

resource "google_compute_instance" "bootstrap" {
  count = var.bootstrap_enabled ? 1 : 0

  name         = "${var.cluster_id}-bootstrap"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      type  = var.root_volume_type
      size  = var.root_volume_size
      image = var.image_name
    }
  }

  network_interface {
    subnetwork = var.subnet

    access_config {
    }
  }

  metadata = {
    user-data = data.ignition_config.redirect.rendered
  }

  tags = ["${var.cluster_id}-master", "${var.cluster_id}-bootstrap"]

  labels = var.labels
}

resource "google_compute_instance_group" "bootstrap" {
  count = var.bootstrap_enabled ? 1 : 0

  name    = "${var.cluster_id}-bootstrap"
  network = var.network
  zone    = var.zone

  named_port {
    name = "ignition"
    port = "22623"
  }

  named_port {
    name = "https"
    port = "6443"
  }

  instances = google_compute_instance.bootstrap.*.self_link
}
