locals {
  platform_root_application = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "platform-root"
      namespace = kubernetes_namespace_v1.argocd.metadata[0].name
      annotations = {
        "argocd.argoproj.io/sync-wave" = "0"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_revision
        path           = var.gitops_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace_v1.argocd.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune      = false
          selfHeal   = true
          allowEmpty = false
        }
        syncOptions = [
          "CreateNamespace=true",
        ]
        retry = {
          limit     = 5
          backoff = {
            duration    = "30s"
            factor      = 2
            maxDuration = "5m"
          }
        }
      }
    }
  }
}

# ArgoCD Application CRD is installed by the Helm chart; apply root app after CRDs exist.
resource "time_sleep" "wait_argocd_crds" {
  depends_on = [helm_release.argocd]

  create_duration = "90s"
}

resource "null_resource" "platform_root_app" {
  depends_on = [
    time_sleep.wait_argocd_crds,
    kubernetes_config_map_v1.irsa_roles,
    kubernetes_manifest.platform_appproject,
  ]

  triggers = {
    manifest_sha = sha256(jsonencode(local.platform_root_application))
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name "${var.cluster_name}" --region "${var.aws_region}" >/dev/null
      kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=300s
      kubectl apply -f - <<'EOF'
${yamlencode(local.platform_root_application)}
EOF
    EOT
  }
}
