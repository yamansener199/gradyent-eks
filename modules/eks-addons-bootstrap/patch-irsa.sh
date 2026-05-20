#!/usr/bin/env bash
# Patch IRSA role ARNs and ACM certificate ARN onto Argo CD Applications (no sync/wait).
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

patch_acm_helm_ingress() {
  local app="$1"
  local values_path="$2"
  [[ -n "${ACM_CERTIFICATE_ARN:-}" ]] || return 0
  kubectl patch application "${app}" -n "${ARGOCD_NAMESPACE}" --type merge --patch "
spec:
  sources:
    - helm:
        parameters:
          - name: ${values_path}.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn
            value: ${ACM_CERTIFICATE_ARN}
" 2>/dev/null || true
}

patch_acm_kustomize_ingress() {
  local app="$1"
  [[ -n "${ACM_CERTIFICATE_ARN:-}" ]] || return 0
  kubectl patch application "${app}" -n "${ARGOCD_NAMESPACE}" --type merge --patch "
spec:
  source:
    kustomize:
      patches:
        - target:
            kind: Ingress
          patch: |-
            - op: add
              path: /metadata/annotations/alb.ingress.kubernetes.io~1certificate-arn
              value: ${ACM_CERTIFICATE_ARN}
" 2>/dev/null || true
}

patch_irsa_helm_app karpenter "${KARPENTER_CONTROLLER_ROLE_ARN:-}"
patch_irsa_helm_app fluentd "${FLUENTD_ROLE_ARN:-}"
patch_irsa_helm_app falco "${FALCO_ROLE_ARN:-}"
# LBC and external-dns are installed by Terraform when bootstrap_ingress_dns_before_argocd=true.

patch_acm_helm_ingress kube-prometheus-stack grafana.ingress
patch_acm_helm_ingress kube-prometheus-stack alertmanager.ingress
patch_acm_kustomize_ingress cilium
patch_acm_kustomize_ingress jaeger

echo "IRSA and ACM ingress parameters patched (sync from UI when ready)."
