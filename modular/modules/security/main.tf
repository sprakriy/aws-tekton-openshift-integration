resource "kubernetes_namespace_v1" "nginx_dev" {
  metadata {
    name = var.namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

output "namespace_name" {
  value = kubernetes_namespace_v1.nginx_dev.metadata[0].name
}