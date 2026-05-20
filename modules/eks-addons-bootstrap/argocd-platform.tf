resource "kubernetes_manifest" "platform_appproject" {
  manifest = {
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

  depends_on = [
    helm_release.argocd,
    time_sleep.wait_argocd_crds,
  ]
}
