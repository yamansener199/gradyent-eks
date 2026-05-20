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
    yamlencode({
      cni = {
        exclusive = true
      }
      eni = {
        enabled = true
      }
      ipam = {
        mode = "eni"
      }
      routingMode            = "native"
      kubeProxyReplacement   = true
      k8sServiceHost         = "auto"
      k8sServicePort         = "auto"
      operator = {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
      }
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
          effect   = "NoSchedule"
        },
      ]
    }),
  ]

  lifecycle {
    ignore_changes = [values, version]
  }
}
