# Register child Application CRs (OutOfSync) so they appear in the UI before you sync anything.
resource "null_resource" "register_platform_applications" {
  count = var.register_platform_applications ? 1 : 0

  depends_on = [
    null_resource.platform_appproject,
    time_sleep.wait_argocd_crds,
  ]

  triggers = {
    bootstrap_sha = filesha256("${var.gitops_repo_root}/gitops/bootstrap/kustomization.yaml")
    repo_url      = var.gitops_repo_url
    revision      = var.gitops_revision
    cluster_name  = var.cluster_name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name "${var.cluster_name}" --region "${var.aws_region}" >/dev/null
      kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=300s
      kubectl kustomize "${var.gitops_repo_root}/gitops/bootstrap" | kubectl apply -f -
      echo "Platform Application CRs registered (OutOfSync until you sync in the UI)."
    EOT
  }
}
