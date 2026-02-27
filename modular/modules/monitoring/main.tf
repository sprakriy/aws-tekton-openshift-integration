resource "kubernetes_manifest" "nginx_servicemonitor" {
  manifest = {
    "apiVersion" = "monitoring.coreos.com/v1"
    "kind"       = "ServiceMonitor"
    "metadata" = {
      "name"      = "nginx-service-monitor"
      "namespace" = var.monitoring_namespace # The monitoring namespace
      "labels"    = { "release" = "prometheus-stack" }
    }
    "spec" = {
      "selector" = {
        "matchLabels" = { "app" = "nginx" }
      }
      "endpoints" = [
        { "port" = "9113-tcp", "interval" = "30s" }
      ]
    }
  }
}