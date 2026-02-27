provider "aws" {
  region = "us-east-1"
}

# 1. The Landing Zone (PVC) - This replaces the ImageStream's role of holding data
resource "kubernetes_persistent_volume_claim_v1" "onboarding_pvc" {
  metadata {
    name      = "${var.app_name}-pvc"
    #namespace = var.namespace
    namespace = "my-onboarding-project" # k3d's default namespace, since we're not creating one here
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    # FORCE it to use k3d's default storage provider
    storage_class_name = "local-path"
  }
}

resource "kubernetes_manifest" "git_clone_task" {
  manifest = {
    apiVersion = "tekton.dev/v1beta1"
    kind       = "Task"
    metadata = {
      name      = "git-clone"
      namespace = "my-onboarding-project"
    }
    spec = {
      workspaces = [{ name = "output" }]
      params = [
        { name = "url", type = "string", description = "Repository URL" },
        { name = "revision", type = "string", default = "main" }
      ]
      steps = [{
        name    = "clone"
        image   = "alpine/git:latest"
        env = [
          { name = "GIT_TERMINAL_PROMPT", value = "0" }
      ]
        # Added logic to clear the directory if it exists
        script = <<-EOT
          if [ -d "$(workspaces.output.path)/.git" ]; then
            echo "Found existing repo, cleaning up..."
            rm -rf $(workspaces.output.path)/* $(workspaces.output.path)/.[!.]*
          fi
          git clone $(params.url) $(workspaces.output.path)
        EOT
      }]
      # ... (Standard Tekton Hub git-clone spec goes here)
      # Or use a remote data source / raw YAML
    }
  }
}
resource "kubernetes_manifest" "terraform_executor_task" {
  manifest = {
    "apiVersion" = "tekton.dev/v1beta1"
    "kind"       = "Task"
    "metadata" = {
      "name"      = "terraform-executor"
      "namespace" = var.namespace
    }
    "spec" = {
      "stepTemplate" = {
        "name" = ""
        "securityContext" = {
          "runAsUser" = 0
        }
      }
      "workspaces" = [{ "name" = "source" }]
      "steps" = [
        {
          "name"       = "terraform-init-apply"
          "image"      = "hashicorp/terraform:latest"
          "workingDir" = "$(workspaces.source.path)"
          
          # 1. Mount the credentials from your 'aws-creds' secret
          "volumeMounts" = [{
            "name"      = "aws-creds-vol"
            "mountPath" = "/etc/aws-creds"
            "readOnly"  = true
          }]

          "script" = <<-EOT
            #!/bin/sh
            # 1. Locate the directory that actually contains the Terraform files
            TF_DIR=$(find $(workspaces.source.path) -name "main.tf" -exec dirname {} \;)
            if [ -z "$TF_DIR" ]; then
              echo "Error: Could not find main.tf in $(workspaces.source.path)"
              exit 1
            fi
            # 2. Change into that directory
            cd "$TF_DIR"
  
            # 3. Print where we are so we can verify
            echo "Terraform is running in: $(pwd)"
            # Load credentials for S3 Backend and AWS access
            export AWS_ACCESS_KEY_ID=$(cat /etc/aws-creds/aws_access_key_id | tr -d '\n')
            export AWS_SECRET_ACCESS_KEY=$(cat /etc/aws-creds/aws_secret_access_key | tr -d '\n')
            #export AWS_SESSION_TOKEN=$(cat /etc/aws-creds/aws_session_token | tr -d '\n')
            export AWS_REGION="us-east-1"

            echo "Initializing Terraform with S3 Backend..."
            terraform init
            
            echo "Executing Operation..."
            terraform apply -auto-approve
          EOT
        }
      ]
      # 2. Key change: Use the Secret instead of the Projected Token
      "volumes" = [{
        "name" = "aws-creds-vol"
        "secret" = {
          "secretName" = "aws-creds"
          "items" = [
            { "key" = "AWS_ACCESS_KEY_ID", "path" = "aws_access_key_id" },
            { "key" = "AWS_SECRET_ACCESS_KEY", "path" = "aws_secret_access_key" },
            { "key" = "AWS_SESSION_TOKEN", "path" = "aws_session_token" }
          ]
        }
      }]
    }
  }
}
/*
resource "kubernetes_manifest" "terraform_executor_task" {
  manifest = {
    "apiVersion" = "tekton.dev/v1beta1"
    "kind"       = "Task"
    "metadata" = {
      "name"      = "terraform-executor" # Name it what it actually does
      "namespace" = var.namespace
    }
    "spec" = {
      "workspaces" = [{ "name" = "source" }]
      "steps" = [
        {
          "name"  = "terraform-init-apply"
          "image" = "hashicorp/terraform:latest" # The tool you actually need
          "workingDir" = "$(workspaces.source.path)" # Where the git-clone put your code
          # 1. These ENV vars tell Terraform WHERE the token is
          env = [
            { name = "AWS_ROLE_ARN", value = "arn:aws:iam::319310747432:role/GitHubAction-AssumeRoleWithAction" },
            { name = "AWS_WEB_IDENTITY_TOKEN_FILE", value = "/var/run/secrets/eks.amazonaws.com/serviceaccount/token" },
            { name = "AWS_REGION", value = "us-east-1" }
          ]   

        # 2. This mounts the "freaking location" into the container
          volumeMounts = [{
            name      = "aws-token"
            mountPath = "/var/run/secrets/eks.amazonaws.com/serviceaccount"
            readOnly  = true
          }]
          "script" = <<-EOT
            #!/bin/sh
            echo "Initializing Terraform for EC2..."
            terraform init
            
            echo "Applying EC2 Configuration..."
            terraform apply -auto-approve
          EOT
        }
      ]
      # 3. THIS IS THE KEY: This "projected" volume creates the token file for you
      volumes = [{
        name = "aws-token"
        projected = {
          sources = [{
            serviceAccountToken = {
              audience          = "sts.amazonaws.com"
              expirationSeconds = 86400
              path              = "token" # This creates the file named 'token'
            }
          }]
        }
      }]
    }
  }
}
*/
/*
# 2. The Task (The new "BuildConfig")
resource "kubernetes_manifest" "python_build_task" {
  manifest = {
    "apiVersion" = "tekton.dev/v1beta1"
    "kind"       = "Task"
    "metadata" = {
      "name"      = "${var.app_name}-build"
      "namespace" = var.namespace
    }
    "spec" = {
      "workspaces" = [{ "name" = "source" }]
      "steps" = [
        {
          "name"  = "build-and-push"
          "image" = "quay.io/buildah/stable:latest"
          "script" = "buildah bud -t ${var.app_name}:latest $(workspaces.source.path)"
        }
      ]
    }
  }
}
*/
# 3. The Standard Deployment (Replaces DeploymentConfig for k3d compatibility)
resource "kubernetes_deployment_v1" "python_app" {
  metadata {
    name      = var.app_name
    namespace = "my-onboarding-project"
  }
  spec {
    replicas = 2
    selector {
      match_labels = { app = "hello-python" }
    }
    template {
      metadata {
        labels = { app = "hello-python" }
      }
      spec {
        container {
          name  = "hello-python"
          #image = "${var.app_name}:latest"
          image = "python:3.9-slim"
          port { container_port = 8080 }
          # This keeps the container awake so it doesn't crash!
          command = ["/bin/sh", "-c", "while true; do sleep 30; done"]
    
          volume_mount {
            name       = "storage"
            mount_path = "/data"
          }
        }
        volume {
          name = "storage"
          persistent_volume_claim {
            #claim_name = kubernetes_persistent_volume_claim_v1.onboarding_pvc.metadata[0].name
            claim_name = "hello-python-pvc"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_account_v1" "tekton_aws_sa" {
  metadata {
    name      = "tekton-aws-sa"
    namespace = "my-onboarding-project"
    annotations = {
      # This is where your ARN Role goes
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::319310747432:role/GitHubAction-AssumeRoleWithAction"
    }
  }
}
resource "kubernetes_manifest" "onboarding_pipeline" {
  manifest = {
    apiVersion = "tekton.dev/v1beta1"
    kind       = "Pipeline"
    metadata = {
      name      = "github-refresh-pipeline"
      namespace = "my-onboarding-project"
    }
    spec = {
      workspaces = [{ name = "shared-data" }] # This connects to your PVC
      tasks = [
        {
          name = "fetch-repository"
          taskRef = { name = "git-clone" }
          workspaces = [{ name = "output", workspace = "shared-data" }]
          params = [
            { name = "url", value = "https://github.com/sprakriy/ci-cd-testing.git" },
            { name = "revision", value = "main" }
          ]
        },
        {
          name = "deploy-ec2"
          runAfter = ["fetch-repository"]
          taskRef = { name = "terraform-executor" } # The task we saw earlier
          workspaces = [{ name = "source", workspace = "shared-data" }]
          # Injecting the Secrets as Environment Variables
       }
      ]
    }
  }
}
resource "kubernetes_manifest" "onboarding_trigger_template" {
  manifest = {
    apiVersion = "triggers.tekton.dev/v1alpha1"
    kind       = "TriggerTemplate"
    metadata = {
      name      = "refresh-trigger-template"
      namespace = "my-onboarding-project"
    }
    spec = {
      resourcetemplates = [{
        apiVersion = "tekton.dev/v1beta1"
        kind       = "PipelineRun"
        metadata = {
          name = "github-run-$(uid)" # Unique name for each run
          namespace    = "my-onboarding-project"
        }
        spec = {
          pipelineRef = { 
            name = "github-refresh-pipeline" 
            namespace = "my-onboarding-project"
          }
          serviceAccountName = "tekton-aws-sa" # <--- Connects the Identity
          workspaces = [{
            name = "shared-data"
            persistentVolumeClaim = { claimName = "hello-python-pvc" }
          }]
        }
      }]
    }
  }
}
resource "kubernetes_manifest" "github_listener" {
  manifest = {
    apiVersion = "triggers.tekton.dev/v1alpha1"
    kind       = "EventListener"
    metadata = {
      name      = "github-listener"
      namespace = "my-onboarding-project"
    }
    spec = {
      serviceAccountName = "tekton-aws-sa" # The identity with OIDC ARN
      triggers = [{
        template = {
          ref = "refresh-trigger-template" # Links to your TriggerTemplate
        }
        # Optional: Add an Interceptor here later to validate GitHub Secrets
      }]
    }
  }
  # ADD THIS BLOCK to resolve the conflict
  field_manager {
    force_conflicts = true
  }
}
resource "kubernetes_manifest" "listener_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "el-github-listener"
      namespace = "my-onboarding-project"
    }
    spec = {
      rules = [{
        http = {
          paths = [{
            path = "/"
            pathType = "Prefix"
            backend = {
              service = {
                name = "el-github-listener"
                port = { number = 8080 }
              }
            }
          }]
        }
      }]
    }
  }
}
resource "kubernetes_role_binding_v1" "tekton_triggers_binding" {
  metadata {
    name      = "tekton-triggers-eventlistener-binding"
    namespace = "my-onboarding-project"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind       = "ClusterRole"
    # This is a standard role created when you installed Tekton Triggers
    name       = "tekton-triggers-eventlistener-roles" 
  }
  subject {
    kind      = "ServiceAccount"
    name      = "tekton-aws-sa"
    namespace = "my-onboarding-project"
  }
}

resource "kubernetes_role_binding_v1" "tekton_triggers_admin_binding" {
  metadata {
    name      = "tekton-triggers-eventlistener-clusteraccess"
    namespace = "my-onboarding-project"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind       = "ClusterRole"
    name       = "tekton-triggers-eventlistener-clusterroles"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "tekton-aws-sa"
    namespace = "my-onboarding-project"
  }
}
# This allows the SA to see ClusterTriggerBindings and ClusterInterceptors
resource "kubernetes_cluster_role_binding_v1" "tekton_listener_cluster_access" {
  metadata {
    name = "tekton-listener-cluster-access-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind       = "ClusterRole"
    name       = "tekton-triggers-eventlistener-clusterroles"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "tekton-aws-sa"
    namespace = "my-onboarding-project"
  }
}

# This allows the SA to manage the actual Trigger logic at cluster level
resource "kubernetes_cluster_role_binding_v1" "tekton_listener_roles_access" {
  metadata {
    name = "tekton-listener-roles-access-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind       = "ClusterRole"
    name       = "tekton-triggers-eventlistener-roles"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "tekton-aws-sa"
    namespace = "my-onboarding-project"
  }
}
/*
resource "aws_iam_openid_connect_provider" "k3d_provider" {
  url             = "https://myokld.click"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["946E24DA38A41BD708C5384DE40F235C256C0722"]
}
*/