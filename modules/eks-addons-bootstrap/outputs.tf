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
  description = "Argo CD Applications registered for manual sync (ingress/DNS stack excluded when installed by Terraform)"
  value = [
    "metrics-server",
    "karpenter",
    "karpenter-provisioner",
    "cilium",
    "cilium-servicemonitors",
    "falco-servicemonitors",
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

output "argocd_url" {
  description = "Public Argo CD URL when bootstrap_ingress_dns_before_argocd is true"
  value       = var.bootstrap_ingress_dns_before_argocd ? "https://argocd.${var.platform_domain}" : null
}

output "ingress_dns_bootstrapped_by_terraform" {
  value = var.bootstrap_ingress_dns_before_argocd
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN used on public ALB Ingresses"
  value       = local.platform_acm_certificate_arn
}
