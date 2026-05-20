output "argocd_namespace" {
  value = kubernetes_namespace_v1.argocd.metadata[0].name
}

output "irsa_configmap_name" {
  value = kubernetes_config_map_v1.irsa_roles.metadata[0].name
}

output "platform_root_application" {
  value = "platform-root"
}

output "platform_bootstrap_enabled" {
  value = var.bootstrap_platform_on_apply
}

output "platform_applications" {
  description = "Argo CD Applications managed under the platform AppProject"
  value = [
    "metrics-server",
    "karpenter",
    "cert-manager",
    "cilium",
    "kyverno",
    "kyverno-policies",
    "falco",
    "istio-base",
    "istiod",
    "fluentd",
    "kube-prometheus-stack",
    "jaeger",
  ]
}
