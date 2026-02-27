module "security" {
  source    = "./modules/security"
  namespace = "nginx-dev"
#   namespace = namespace_name
}

module "workload" {
  source    = "./modules/workload"
  namespace = module.security.namespace_name
}

module "monitoring" {
  source    = "./modules/monitoring"
  app_namespace        = module.security.ns_name
  monitoring_namespace = var.cluster_monitoring_namespace
}