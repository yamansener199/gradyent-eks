# EKS does not publish kube-public/cluster-info (unlike kubeadm), so k8sServiceHost=auto
# cannot resolve during Helm render. Provide the API endpoint explicitly and publish
# cluster-info for GitOps (Argo CD) Helm lookups.
locals {
  k8s_service_host = trimsuffix(trimprefix(var.cluster_endpoint, "https://"), ":443")
}

resource "kubernetes_config_map_v1" "cluster_info" {
  metadata {
    name      = "cluster-info"
    namespace = "kube-public"
  }

  data = {
    kubeconfig = <<-EOT
      apiVersion: v1
      kind: Config
      clusters:
      - cluster:
          server: ${var.cluster_endpoint}
        name: ""
      contexts:
      - context:
          cluster: ""
          user: ""
        name: ""
      current-context: ""
      users:
      - name: ""
        user:
          token: ""
    EOT
  }
}

# Cilium must exist before Argo CD when the EKS vpc-cni add-on is omitted (Cilium-only).
# Argo CD (sync wave 1) upgrades this release with full values from gitops/apps/cilium.
resource "helm_release" "cilium_bootstrap" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_chart_version
  namespace  = "kube-system"

  wait    = true
  timeout = 900

  values = [
    yamlencode(local.cilium_platform_values),
  ]

  depends_on = [kubernetes_config_map_v1.cluster_info]
}
