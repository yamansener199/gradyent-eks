# After Argo CD and platform-root exist, bootstrap all CNCF platform Applications from Git
# and wait until they are Synced (terraform apply → full platform stack).
resource "null_resource" "platform_bootstrap" {
  count = var.bootstrap_platform_on_apply ? 1 : 0

  depends_on = [
    null_resource.platform_root_app,
    helm_release.argocd,
    kubernetes_config_map_v1.irsa_roles,
    null_resource.platform_appproject,
  ]

  triggers = {
    cluster_name    = var.cluster_name
    aws_region      = var.aws_region
    gitops_repo     = var.gitops_repo_url
    gitops_revision = var.gitops_revision
    gitops_root     = var.gitops_repo_root
    irsa_sha        = sha256(jsonencode(var.irsa_map))
    script_sha      = filesha256("${path.module}/bootstrap-platform.sh")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      export CLUSTER_NAME="${var.cluster_name}"
      export AWS_REGION="${var.aws_region}"
      export GITOPS_REPO_URL="${var.gitops_repo_url}"
      export GITOPS_REVISION="${var.gitops_revision}"
      export GITOPS_REPO_ROOT="${var.gitops_repo_root}"
      export PLATFORM_SYNC_TIMEOUT="${var.platform_sync_timeout_seconds}"
      export REQUIRE_GIT_REPO="${var.require_git_repo_access ? "true" : "false"}"
      export KARPENTER_CONTROLLER_ROLE_ARN="${var.irsa_map["karpenter_controller_role_arn"]}"
      export FLUENTD_ROLE_ARN="${var.irsa_map["fluentd_role_arn"]}"
      export FALCO_ROLE_ARN="${var.irsa_map["falco_role_arn"]}"
      export AWS_LBC_ROLE_ARN="${var.irsa_map["aws_load_balancer_controller_role_arn"]}"
      export EXTERNAL_DNS_ROLE_ARN="${var.irsa_map["external_dns_role_arn"]}"
      export VPC_ID="${var.irsa_map["vpc_id"]}"
      exec "${path.module}/bootstrap-platform.sh"
    EOT
  }
}
