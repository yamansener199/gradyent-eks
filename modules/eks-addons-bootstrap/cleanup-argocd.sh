#!/usr/bin/env bash
# Runs on terraform destroy before Helm uninstalls Argo CD (avoids stuck Terminating namespace).
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:?}"
AWS_REGION="${AWS_REGION:?}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

if ! aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "Cluster ${CLUSTER_NAME} not reachable; skipping Argo CD cleanup."
  exit 0
fi

if ! kubectl get namespace "${ARGOCD_NAMESPACE}" &>/dev/null; then
  echo "Namespace ${ARGOCD_NAMESPACE} not found; nothing to clean up."
  exit 0
fi

echo "==> Removing Argo CD Application finalizers in ${ARGOCD_NAMESPACE}..."
for app in $(kubectl get applications -n "${ARGOCD_NAMESPACE}" -o name 2>/dev/null || true); do
  kubectl patch "${app}" -n "${ARGOCD_NAMESPACE}" \
    --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
done
kubectl delete applications --all -n "${ARGOCD_NAMESPACE}" --timeout=120s 2>/dev/null || true

echo "==> Clearing namespace finalizers on ${ARGOCD_NAMESPACE}..."
if kubectl get namespace "${ARGOCD_NAMESPACE}" -o json 2>/dev/null | grep -q Terminating; then
  kubectl get namespace "${ARGOCD_NAMESPACE}" -o json | \
    python3 -c "import sys,json; n=json.load(sys.stdin); n['spec']['finalizers']=[]; print(json.dumps(n))" | \
    kubectl replace --raw "/api/v1/namespaces/${ARGOCD_NAMESPACE}/finalize" -f - 2>/dev/null || true
fi

echo "Argo CD pre-destroy cleanup finished."
