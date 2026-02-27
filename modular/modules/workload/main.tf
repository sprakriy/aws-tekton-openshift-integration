resource "kubernetes_deployment_v1" "nginx" {
  metadata {
    name      = "nginx-sre-final"
    namespace = var.namespace
  }
  spec {
    selector { match_labels = { app = "nginx" } }
    template {
      metadata { labels = { app = "nginx" } }
      spec {
        security_context {
          run_as_non_root = true
          seccomp_profile { type = "RuntimeDefault" }
        }
        container {
          name  = "nginx"
          image = "nginxinc/nginx-unprivileged:latest"
          port { container_port = 8080 }

          security_context  {
            run_as_non_root = true
            capabilities { drop = ["ALL"] }
            allow_privilege_escalation = false
          }
        }
        container {
          name  = "exporter"
          image = "nginx/nginx-prometheus-exporter:latest"
          args  = ["-nginx.scrape-uri=http://localhost:8080/stub_status"]
          port { container_port = 9113 }

          security_context  {
            run_as_non_root = true
            capabilities { drop = ["ALL"] }
            allow_privilege_escalation = false
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "nginx_service" {
  metadata {
    name      = "nginx-service"
    namespace = var.namespace
    labels = {
      app = "nginx"
    }
  }
  spec {
    selector = {
      app = "nginx" # This MUST match the label in your deployment
    }
    port {
      name        = "http"
      port        = 80
      target_port = 8080 # Matches Nginx container port
    }
    port {
      name        = "metrics"
      port        = 9113
      target_port = 9113 # Matches Exporter container port
    }
    type = "ClusterIP"
  }
}