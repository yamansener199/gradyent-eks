# Patch IRSA ARNs onto Argo CD Helm apps after platform-root registers them (no auto-sync).
resource "null_resource" "irsa_gitops_patch" {
  count = var.patch_irsa_on_apply ? 1 : 0

  depends_on = [
    null_resource.platform_root_app,
    null_resource.register_platform_applications,
    kubernetes_config_map_v1.irsa_roles,
  ]

  triggers = {
    irsa_sha     = sha256(jsonencode(var.irsa_map))
    script_sha   = filesha256("${path.module}/patch-irsa.sh")
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name "${var.cluster_name}" --region "${var.aws_region}" >/dev/null
      export KARPENTER_CONTROLLER_ROLE_ARN="${var.irsa_map["karpenter_controller_role_arn"]}"
      export FLUENTD_ROLE_ARN="${var.irsa_map["fluentd_role_arn"]}"
      export FALCO_ROLE_ARN="${var.irsa_map["falco_role_arn"]}"
      export AWS_LBC_ROLE_ARN="${var.irsa_map["aws_load_balancer_controller_role_arn"]}"
      export EXTERNAL_DNS_ROLE_ARN="${var.irsa_map["external_dns_role_arn"]}"
      export VPC_ID="${var.irsa_map["vpc_id"]}"
      # Wait until Application CRs exist (created when you sync platform-root, or already present).
      for _ in $(seq 1 60); do
        if kubectl get application karpenter -n argocd &>/dev/null; then
          break
        fi
        sleep 5
      done
      exec "${path.module}/patch-irsa.sh"
    EOT
  }
}
