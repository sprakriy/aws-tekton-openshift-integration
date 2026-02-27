variable "app_namespace" {
  description = "The namespace where Nginx is running (nginx-dev)"
  type        = string
}

variable "monitoring_namespace" {
  description = "The namespace where Prometheus lives (monitoring)"
  type        = string
}