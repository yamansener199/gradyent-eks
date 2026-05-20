locals {
  platform_appproject = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "platform"
      namespace = kubernetes_namespace_v1.argocd.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      description = "CNCF platform stack reconciled from gitops/ (Cilium, Karpenter, observability, security, mesh)."
      sourceRepos = [var.gitops_repo_url]
      destinations = [
        {
          namespace = "*"
          server    = "https://kubernetes.default.svc"
        },
      ]
      clusterResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        },
      ]
      namespaceResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        },
      ]
    }
  }
}

# AppProject CRD is created by the Argo CD Helm chart; apply via kubectl after CRDs exist.
resource "null_resource" "platform_appproject" {
  depends_on = [
    helm_release.argocd,
    time_sleep.wait_argocd_crds,
  ]

  triggers = {
    manifest_sha = sha256(jsonencode(local.platform_appproject))
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name "${var.cluster_name}" --region "${var.aws_region}" >/dev/null
      kubectl wait --for=condition=Established crd/appprojects.argoproj.io --timeout=300s
      kubectl apply -f - <<'EOF'
${yamlencode(local.platform_appproject)}
EOF
    EOT
  }
}
