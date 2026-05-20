output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "cluster_version" {
  value = module.eks.cluster_version
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "karpenter_controller_role_arn" {
  value = module.karpenter_controller_irsa.iam_role_arn
}

output "karpenter_node_role_name" {
  value = module.karpenter.node_iam_role_name
}

output "karpenter_node_role_arn" {
  value = module.karpenter.node_iam_role_arn
}

output "karpenter_interruption_queue_name" {
  value = module.karpenter.queue_name
}

output "fluentd_role_arn" {
  value = module.fluentd_irsa.iam_role_arn
}

output "falco_role_arn" {
  value = module.falco_irsa.iam_role_arn
}

output "aws_load_balancer_controller_role_arn" {
  value = module.aws_load_balancer_controller_irsa.iam_role_arn
}

output "external_dns_role_arn" {
  value = module.external_dns_irsa.iam_role_arn
}

output "vpc_id" {
  value = var.vpc_id
}

output "irsa_map" {
  description = "IRSA metadata for ArgoCD ConfigMap"
  value = {
    karpenter_controller_role_arn              = module.karpenter_controller_irsa.iam_role_arn
    karpenter_node_role_name                   = module.karpenter.node_iam_role_name
    karpenter_interruption_queue_name          = module.karpenter.queue_name
    fluentd_role_arn                           = module.fluentd_irsa.iam_role_arn
    falco_role_arn                             = module.falco_irsa.iam_role_arn
    aws_load_balancer_controller_role_arn      = module.aws_load_balancer_controller_irsa.iam_role_arn
    external_dns_role_arn                      = module.external_dns_irsa.iam_role_arn
    cluster_name                               = var.cluster_name
    aws_region                                 = var.aws_region
    vpc_id                                     = var.vpc_id
  }
}
