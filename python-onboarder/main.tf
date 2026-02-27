provider "kubernetes" {
  # This tells Terraform to look at your local k3d credentials
  config_path    = "~/.kube/config"
  config_context = "k3d-mycluster" # Change this to your actual k3d context name
}

resource "kubernetes_namespace_v1" "app_ns" {
  metadata {
    name = "my-onboarding-project"
  }
}

module "onboarding" {
  source    = "./modules/app_onboarding"
  namespace = kubernetes_namespace_v1.app_ns.metadata[0].name # Pass the real name
  app_name  = "hello-python"
  # ... other variables
}
