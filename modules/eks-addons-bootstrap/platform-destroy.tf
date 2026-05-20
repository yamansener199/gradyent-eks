# Pre-destroy hook: strip Argo CD Application finalizers so Helm/namespace teardown does not hang.
resource "null_resource" "argocd_pre_destroy" {
  depends_on = [
    helm_release.argocd,
    null_resource.platform_root_app,
    null_resource.platform_bootstrap,
    null_resource.platform_appproject,
    kubernetes_config_map_v1.irsa_roles,
  ]

  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
    script_sha   = filesha256("${path.module}/cleanup-argocd.sh")
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export CLUSTER_NAME="${self.triggers.cluster_name}"
      export AWS_REGION="${self.triggers.aws_region}"
      exec "${path.module}/cleanup-argocd.sh"
    EOT
  }
}
