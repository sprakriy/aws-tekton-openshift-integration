output "ns_name" {
  value = kubernetes_namespace_v1.nginx_dev.metadata[0].name
}