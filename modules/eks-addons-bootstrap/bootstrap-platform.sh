#!/usr/bin/env bash
# Invoked by Terraform null_resource.platform_bootstrap after Argo CD is installed.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:?}"
AWS_REGION="${AWS_REGION:?}"
GITOPS_REPO_URL="${GITOPS_REPO_URL:?}"
GITOPS_REVISION="${GITOPS_REVISION:-main}"
GITOPS_REPO_ROOT="${GITOPS_REPO_ROOT:?}"
PLATFORM_SYNC_TIMEOUT="${PLATFORM_SYNC_TIMEOUT:-2400}"
REQUIRE_GIT_REPO="${REQUIRE_GIT_REPO:-true}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

KARPENTER_IRSA="${KARPENTER_CONTROLLER_ROLE_ARN:-}"
FLUENTD_IRSA="${FLUENTD_ROLE_ARN:-}"
FALCO_IRSA="${FALCO_ROLE_ARN:-}"
AWS_LBC_IRSA="${AWS_LBC_ROLE_ARN:-}"
EXTERNAL_DNS_IRSA="${EXTERNAL_DNS_ROLE_ARN:-}"
VPC_ID="${VPC_ID:-}"

aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null

echo "==> Waiting for Argo CD control plane..."
kubectl wait --for=condition=available deployment/argocd-server \
  -n "${ARGOCD_NAMESPACE}" --timeout="${PLATFORM_SYNC_TIMEOUT}s"
kubectl wait --for=condition=available deployment/argocd-repo-server \
  -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl wait --for=condition=available deployment/argocd-applicationset-controller \
  -n "${ARGOCD_NAMESPACE}" --timeout=300s 2>/dev/null || true

echo "==> Verifying Git repository (${GITOPS_REPO_URL} @ ${GITOPS_REVISION})..."
if git ls-remote "${GITOPS_REPO_URL}" "refs/heads/${GITOPS_REVISION}" >/dev/null 2>&1; then
  echo "    Git remote is reachable."
else
  if [[ "${REQUIRE_GIT_REPO}" == "true" ]]; then
    echo "ERROR: Cannot reach ${GITOPS_REPO_URL} (branch ${GITOPS_REVISION})." >&2
    echo "Push this repository to that URL before running terragrunt apply." >&2
    echo "Or set require_git_repo_access = false in eks-addons-bootstrap." >&2
    exit 1
  fi
  echo "WARNING: Git remote not reachable; Argo CD may not sync application manifests."
fi

BOOTSTRAP_DIR="${GITOPS_REPO_ROOT}/gitops/bootstrap"
if [[ ! -d "${BOOTSTRAP_DIR}" ]]; then
  echo "ERROR: Missing ${BOOTSTRAP_DIR}" >&2
  exit 1
fi

echo "==> Applying platform App-of-Apps (Kustomize)..."
kubectl kustomize "${BOOTSTRAP_DIR}" | kubectl apply -f -

refresh_app() {
  local app="$1"
  kubectl annotate application "${app}" -n "${ARGOCD_NAMESPACE}" \
    argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
}

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

echo "==> Configuring IRSA on Helm-managed platform apps..."
patch_irsa_helm_app karpenter "${KARPENTER_IRSA}"
patch_irsa_helm_app fluentd "${FLUENTD_IRSA}"
patch_irsa_helm_app falco "${FALCO_IRSA}"
patch_irsa_helm_app aws-load-balancer-controller "${AWS_LBC_IRSA}"
patch_irsa_helm_app external-dns "${EXTERNAL_DNS_IRSA}"

if [[ -n "${AWS_LBC_IRSA}" && -n "${VPC_ID}" ]]; then
  kubectl patch application aws-load-balancer-controller -n "${ARGOCD_NAMESPACE}" --type merge --patch "
spec:
  sources:
    - helm:
        parameters:
          - name: serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn
            value: ${AWS_LBC_IRSA}
          - name: vpcId
            value: ${VPC_ID}
" 2>/dev/null || true
fi

refresh_app platform-root

APP_WAVES="$(cat <<'EOF'
metrics-server
karpenter
aws-load-balancer-controller
external-dns
cilium
kyverno
kyverno-policies
falco
istio-base
istiod
fluentd
kube-prometheus-stack
jaeger
EOF
)"

wait_for_app() {
  local app="$1"
  local remaining=$((PLATFORM_SYNC_TIMEOUT - SECONDS))
  if (( remaining < 60 )); then
    echo "WARN: timeout budget exhausted before waiting on ${app}"
    return 1
  fi

  echo "==> Syncing Application/${app} (timeout ${remaining}s)..."
  local deadline=$((SECONDS + remaining))

  until kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" &>/dev/null; do
    if (( SECONDS >= deadline )); then
      echo "WARN: Application/${app} was not created in time"
      return 1
    fi
    sleep 5
  done

  refresh_app "${app}"

  while (( SECONDS < deadline )); do
    local sync_status health_status
    sync_status="$(kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" \
      -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")"
    health_status="$(kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" \
      -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")"

    if [[ "${sync_status}" == "Synced" ]]; then
      case "${health_status}" in
        Healthy|Progressing)
          echo "    ${app}: sync=${sync_status} health=${health_status}"
          return 0
          ;;
        Degraded|Missing)
          echo "    ${app}: sync=${sync_status} health=${health_status} (continuing)"
          return 0
          ;;
      esac
    fi

    if [[ "${sync_status}" == "Unknown" && -z "${health_status}" ]]; then
      refresh_app "${app}"
    fi

    sleep 15
  done

  echo "WARN: Application/${app} did not reach Synced within timeout"
  kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" -o yaml | tail -30 || true
  return 1
}

failed=0
while IFS= read -r app; do
  [[ -z "${app}" ]] && continue
  wait_for_app "${app}" || failed=$((failed + 1))
done <<< "${APP_WAVES}"

echo ""
echo "==> Platform Applications status:"
kubectl get applications -n "${ARGOCD_NAMESPACE}" -o wide

if (( failed > 0 )); then
  echo ""
  echo "WARN: ${failed} application(s) did not fully sync."
  echo "Re-run: cd environments/prod/eks-addons-bootstrap && terragrunt apply"
  exit 1
fi

echo ""
echo "Platform bootstrap completed successfully."
