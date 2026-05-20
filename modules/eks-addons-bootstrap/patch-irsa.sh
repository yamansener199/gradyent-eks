#!/usr/bin/env bash
# Patch IRSA role ARNs onto Helm-based Argo CD Applications (no sync/wait).
set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

patch_irsa_helm_app() {
  local app="$1"
  local arn="$2"
  [[ -n "${arn}" ]] || return 0
  kubectl patch application "${app}" -n "${ARGOCD_NAMESPACE}" --type merge --patch "
spec:
  sources:
    - helm:
        parameters:
          - name: serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn
            value: ${arn}
" 2>/dev/null || true
}

patch_irsa_helm_app karpenter "${KARPENTER_CONTROLLER_ROLE_ARN:-}"
patch_irsa_helm_app fluentd "${FLUENTD_ROLE_ARN:-}"
patch_irsa_helm_app falco "${FALCO_ROLE_ARN:-}"
# LBC and external-dns are installed by Terraform when bootstrap_ingress_dns_before_argocd=true.

echo "IRSA parameters patched on Helm Applications (sync from UI when ready)."
