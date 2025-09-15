
# Terraform GCP Website Deployment

This project uses **Terraform** to deploy a static website on **Google Cloud Platform (GCP)** with the following features:

- Google Cloud Storage bucket for static website hosting
- Public read access for website content
- Global static IP address
- Google Cloud CDN for caching and performance
- HTTP Load Balancer
- Cloud DNS integration with A and CNAME records
- Fully automated Terraform workflow

---

## Prerequisites

- A **GCP project**
- `gcloud` CLI installed and authenticated
- `terraform` installed on your machine

---

## 1. Configure GCP Project

Set your project:

```bash
gcloud config set project PROJECT_ID
```

Verify configuration:

```bash
gcloud config list
```

---

## 2. Enable Required APIs

Enable the following APIs:

```bash

# Cloud DNS

gcloud services enable dns.googleapis.com --project PROJECT_ID

# Compute Engine (for load balancer & CDN)

gcloud services enable compute.googleapis.com --project PROJECT_ID

# IAM

gcloud services enable iam.googleapis.com --project PROJECT_ID
```

---

## 3. Create Service Account for Terraform

Create a service account:

```bash
gcloud iam service-accounts create utom-terraform \
 --display-name="utom-terraform"
```

Assign the necessary roles:

```bash

# Cloud DNS

gcloud projects add-iam-policy-binding PROJECT_ID \
 --member="serviceAccount:utom-terraform@PROJECT_ID.iam.gserviceaccount.com" \
 --role="roles/dns.admin"

# Load Balancer

gcloud projects add-iam-policy-binding PROJECT_ID \
 --member="serviceAccount:utom-terraform@PROJECT_ID.iam.gserviceaccount.com" \
 --role="roles/compute.loadBalancerAdmin"

# Storage

gcloud projects add-iam-policy-binding PROJECT_ID \
 --member="serviceAccount:utom-terraform@PROJECT_ID.iam.gserviceaccount.com" \
 --role="roles/storage.admin"
```

> **Tip:** Download the service account JSON key from GCP Console (IAM → Service Accounts → `utom-terraform` → Keys → Create Key). Store it safely and use it with Terraform.

---

## 4. Create Infrastructure with Terraform

Now navigate to infra folder

```bash
cd infra
```

1. Initialize Terraform:

```bash
terraform init
```

2. Review the execution plan:

```bash
terraform plan
```

3. Apply the plan:

```bash
terraform apply
```

---

## 5. Terraform Components

### Storage Bucket

- Hosts the static website
- Publicly readable via IAM binding
- Automatically uploads all files from project root (excluding `infra` & hidden directories)

### Global Static IP

- Reserved for the load balancer

### Backend Bucket & CDN

- Storage bucket is added as a backend for Google Cloud CDN

### Load Balancer

- URL map points all traffic to the backend bucket
- HTTP proxy and global forwarding rule listen on port 80

### DNS Records

- Apex domain (`example.com`) → **A record** pointing to static IP
- Subdomain (`www.example.com`) → **CNAME** pointing to apex domain

---

## 6. Example Commands

### Create DNS Managed Zone

```bash
gcloud dns managed-zones create utom-zone \
 --dns-name="example.dev" \
 --description="Managed zone for example.dev" \
 --visibility=public \
 --project=PROJECT_ID
```
