# providers.tf
provider "kubernetes" {
  config_path = "~/.kube/config" # Uses your current k3d/OpenShift context
}

provider "aws" {
  region = "us-east-1"
  # No access keys here! Use 'export AWS_ACCESS_KEY_ID=...' in your shell.
}