resource "google_storage_bucket" "utom_skill_connect_bucket" {
  name     = "utom-skill-connect-bucket-1"
  location = var.gcp_region

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  force_destroy = true
}

locals {
  website_root_dir = abspath("${path.module}/..")

  // Gather all files under the project root, excluding the infra directory itself and common hidden dirs
  all_site_files = [for f in fileset(local.website_root_dir, "**/*") : f
    if !startswith(f, "infra/") &&
    !startswith(f, ".terraform/") &&
  !endswith(f, "/")]

  // Basic content type mapping by extension
  content_types_by_ext = {
    ".html"  = "text/html; charset=utf-8"
    ".htm"   = "text/html; charset=utf-8"
    ".css"   = "text/css; charset=utf-8"
    ".js"    = "application/javascript; charset=utf-8"
    ".json"  = "application/json; charset=utf-8"
    ".svg"   = "image/svg+xml"
    ".png"   = "image/png"
    ".jpg"   = "image/jpeg"
    ".jpeg"  = "image/jpeg"
    ".gif"   = "image/gif"
    ".webp"  = "image/webp"
    ".ico"   = "image/x-icon"
    ".woff"  = "font/woff"
    ".woff2" = "font/woff2"
    ".ttf"   = "font/ttf"
    ".eot"   = "application/vnd.ms-fontobject"
    ".pdf"   = "application/pdf"
    ".txt"   = "text/plain; charset=utf-8"
  }
}


// Public read access for all objects in the bucket
resource "google_storage_bucket_iam_binding" "public_read" {
  bucket = google_storage_bucket.utom_skill_connect_bucket.name
  role   = "roles/storage.objectViewer"
  members = [
    "allUsers",
  ]
}



// Upload every file from the site preserving folder structure
resource "google_storage_bucket_object" "site_files" {
  for_each = toset(local.all_site_files)

  name   = each.value
  bucket = google_storage_bucket.utom_skill_connect_bucket.name
  source = "${local.website_root_dir}/${each.value}"

  // Derive content type from file extension when possible
  content_type = lookup(
    local.content_types_by_ext,
    lower(try(regexall("\\.[^.]+$", each.value)[0], "")),
    "application/octet-stream"
  )

  #   cache_control = contains(each.value, "/assets/") || contains(each.value, "/js/") || contains(each.value, "/css/") ? "public, max-age=31536000, immutable" : "public, max-age=300"
}

# Reserver a static ip address for the bucket
resource "google_compute_global_address" "static_ip" {
  name = "utom-lb-ip"
}

# Get the managed DNS zone
data "google_dns_managed_zone" "utom_zone" {
  name = "utom-zone"
}


# Add IP to the DNS
resource "google_dns_record_set" "apex_a" {
  name         = "${var.domain}."
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.utom_zone.name
  rrdatas      = [google_compute_global_address.static_ip.address]
}

# CNAME for www
resource "google_dns_record_set" "utom_cname" {
  name         = "www.${var.domain}."
  type         = "CNAME"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.utom_zone.name
  rrdatas      = ["${var.domain}."]
}


# Add the bucket as a CDN backend 
resource "google_compute_backend_bucket" "utom-backend" {
  name        = "utom-backend"
  bucket_name = google_storage_bucket.utom_skill_connect_bucket.name
  enable_cdn  = true
}


# Create a URL map
resource "google_compute_url_map" "utom-url-map" {
  name            = "utom-url-map"
  default_service = google_compute_backend_bucket.utom-backend.self_link
  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"

  }
  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_bucket.utom-backend.self_link
  }
}

# HTTP proxy
resource "google_compute_target_http_proxy" "utom-proxy" {
  name    = "utom-target-proxy"
  url_map = google_compute_url_map.utom-url-map.self_link
}

# Forwarding rule 
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "utom-forwarding-rule"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.static_ip.address
  ip_protocol           = "TCP"
  port_range            = "80"
  target = google_compute_target_http_proxy.utom-proxy.self_link
}
