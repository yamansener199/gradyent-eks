# EKS still seeds self-managed aws-node/kube-proxy DaemonSets at cluster creation even when
# vpc-cni/kube-proxy are omitted from cluster_addons. Remove them once Cilium is ready.
resource "null_resource" "remove_vpc_cni_and_kube_proxy" {
  depends_on = [helm_release.cilium_bootstrap]

  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
    cilium_id    = helm_release.cilium_bootstrap.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name "${var.cluster_name}" --region "${var.aws_region}" >/dev/null

      kubectl -n kube-system rollout status daemonset/cilium --timeout=600s
      kubectl -n kube-system wait --for=condition=ready pod -l k8s-app=cilium --timeout=300s

      for ds in aws-node kube-proxy; do
        if kubectl -n kube-system get daemonset "$ds" >/dev/null 2>&1; then
          kubectl -n kube-system delete daemonset "$ds" --wait=true --timeout=180s
        fi
      done

      kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
    EOT
  }
}
