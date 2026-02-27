terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}
/*
provider "kubernetes" {
  host                   = "https://127.0.0.1:36409"
  insecure               = true  # <--- Add this line
}

provider "helm" {
  kubernetes {
    host     = "https://127.0.0.1:36409"
    insecure = true  # <--- Add this line
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "k3d-mycluster"
}
*/
# We keep these empty just to satisfy Terraform's requirement for the 
# kubernetes_annotations resource.
provider "kubernetes" {
  config_path = "~/.kube/config"
}
resource "helm_release" "test" {
  name       = "nginx"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  namespace  = "default"
}

provider "helm" {}

# Use the exact same logic that worked for Tekton
resource "null_resource" "install_prometheus" {
  provisioner "local-exec" {
    # This uses your system's Helm, which already has the credentials
    command = <<EOT
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
      helm repo update
      helm install prometheus prometheus-community/kube-prometheus-stack \
        --set grafana.enabled=true \
        --set prometheus.enabled=true \
        --kubeconfig ~/.kube/config
    EOT
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true

# CHANGE THIS BACK TO BLOCKS
  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.enabled"
    value = "true"
  }
}
# This pulls the official Tekton Pipelines from GitHub
resource "null_resource" "install_tekton" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml"
  }
}

# This pulls the EventListeners and Triggers
resource "null_resource" "install_tekton_triggers" {
  depends_on = [null_resource.install_tekton]
  provisioner "local-exec" {
    command = "kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml"
  }
}
resource "kubernetes_annotations" "tekton_sa_aws" {
  api_version = "v1"
  kind        = "ServiceAccount"
  metadata {
    name      = "tekton-pipelines-controller" # Or the specific SA from the public repo
    namespace = "tekton-pipelines"
  }
  annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::319310747432:role/GitHubAction-AssumeRoleWithAction"
  }
}