# modules/monitoring/service_monitor.tf
resource "kubernetes_manifest" "nginx_monitor" {
  manifest = {
    "apiVersion" = "monitoring.coreos.com/v1"
    "kind"       = "ServiceMonitor"
    "metadata" = {
      "name"      = "nginx-service-monitor"
      "namespace" = "nginx-dev"
      "labels"    = {
        "release" = "prometheus-stack" # MUST match your 'oc get prometheus' label
      }
    }
    "spec" = {
      "selector" = {
        "matchLabels" = { "app" = "nginx" }
      }
      "endpoints" = [
        {
          "port"     = "metrics"
          "interval" = "30s"
        }
      ]
    }
  }
}