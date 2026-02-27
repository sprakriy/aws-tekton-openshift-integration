variable "target_namespace" {
  description = "The namespace for our hardened Nginx"
  type        = string
  default     = "nginx-dev"
}

variable "cluster_monitoring_namespace" {
  description = "Where the existing Prometheus and 9113 service live"
  type        = string
  default     = "monitoring"
}