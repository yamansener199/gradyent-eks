#!/usr/bin/env bash
# Smoke-test gradyent-prod after deploy. Run from bastion or any host with kubectl + aws CLI.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-gradyent-prod}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
ARGOCD_NS="${ARGOCD_NS:-argocd}"
FAIL=0

pass() { echo "  OK  $*"; }
fail() { echo "  FAIL $*"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "==> $*"; }

section "AWS cluster"
if aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
  --query 'cluster.status' --output text 2>/dev/null | grep -q ACTIVE; then
  pass "EKS cluster ${CLUSTER_NAME} is ACTIVE"
else
  fail "EKS cluster ${CLUSTER_NAME} missing or not ACTIVE (deploy with: cd environments/prod && terragrunt run-all apply)"
fi

section "kubectl connectivity"
if kubectl cluster-info &>/dev/null; then
  pass "kubectl can reach API server"
else
  fail "kubectl cannot reach API (private API? use SSM bastion — see docs/cluster-test.md)"
  echo ""
  echo "Stopped early: fix API access first."
  exit 1
fi

section "Nodes"
READY_NODES="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"{c++} END{print c+0}')"
TOTAL_NODES="$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${READY_NODES}" -ge 1 && "${READY_NODES}" == "${TOTAL_NODES}" ]]; then
  pass "Nodes Ready: ${READY_NODES}/${TOTAL_NODES}"
else
  fail "Nodes Ready: ${READY_NODES}/${TOTAL_NODES}"
  kubectl get nodes -o wide || true
fi

section "Core system pods (kube-system)"
if kubectl -n kube-system get pods -l k8s-app=cilium --no-headers 2>/dev/null | grep -q Running; then
  pass "cilium pods running"
else
  fail "cilium not running"
fi
if kubectl -n kube-system get pods -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -q Running; then
  pass "coredns pods running"
else
  fail "coredns not running"
fi

if kubectl -n kube-system get ds -l k8s-app=aws-node --no-headers 2>/dev/null | grep -q .; then
  fail "aws-node (vpc-cni) still present — Cilium-only expected"
else
  pass "no aws-node DaemonSet (Cilium-only)"
fi

section "Argo CD applications"
if kubectl get applications -n "${ARGOCD_NS}" &>/dev/null; then
  UNSYNCED="$(kubectl get applications -n "${ARGOCD_NS}" -o json 2>/dev/null | \
    jq -r '[.items[] | select(.status.sync.status != "Synced")] | length' 2>/dev/null || echo "?")"
  UNHEALTHY="$(kubectl get applications -n "${ARGOCD_NS}" -o json 2>/dev/null | \
    jq -r '[.items[] | select(.status.health.status != "Healthy" and .status.health.status != "Progressing")] | length' 2>/dev/null || echo "?")"
  if [[ "${UNSYNCED}" == "0" && "${UNHEALTHY}" == "0" ]]; then
    pass "All Applications Synced and Healthy/Progressing"
  else
    fail "Applications: not Synced=${UNSYNCED}, unhealthy=${UNHEALTHY}"
    kubectl get applications -n "${ARGOCD_NS}" -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status 2>/dev/null || true
  fi
else
  fail "No Argo CD Applications in ${ARGOCD_NS}"
fi

section "Platform controllers"
checks=(
  "cert-manager:cert-manager:app.kubernetes.io/instance=cert-manager"
  "kube-system:aws-load-balancer-controller:app.kubernetes.io/name=aws-load-balancer-controller"
  "kube-system:external-dns:app.kubernetes.io/name=external-dns"
  "kyverno:kyverno:app.kubernetes.io/instance=kyverno"
  "karpenter:karpenter:app.kubernetes.io/name=karpenter"
  "monitoring:prometheus:app.kubernetes.io/name=kube-prometheus-stack"
)
for entry in "${checks[@]}"; do
  IFS=: read -r ns name selector <<< "${entry}"
  if kubectl -n "${ns}" get pods -l "${selector}" --no-headers 2>/dev/null | grep -q Running; then
    pass "${name} (${ns})"
  else
    fail "${name} (${ns}) not all Running"
  fi
done

section "Ingresses"
ING_COUNT="$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${ING_COUNT}" -ge 1 ]]; then
  pass "Ingress resources: ${ING_COUNT}"
  kubectl get ingress -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[*].hostname 2>/dev/null | head -10 || true
else
  fail "No Ingress resources found"
fi

section "Optional smoke pod"
if kubectl run cluster-smoke-test --image=public.ecr.aws/docker/library/busybox:1.36 \
  --restart=Never --command -- sleep 60 &>/dev/null; then
  if kubectl wait --for=condition=Ready pod/cluster-smoke-test --timeout=90s &>/dev/null; then
    pass "smoke pod scheduled and Ready"
    kubectl delete pod cluster-smoke-test --wait=false &>/dev/null || true
  else
    fail "smoke pod did not become Ready"
    kubectl describe pod cluster-smoke-test | tail -20 || true
    kubectl delete pod cluster-smoke-test --ignore-not-found &>/dev/null || true
  fi
else
  fail "could not create smoke pod (Kyverno deny or quota?)"
fi

echo ""
if [[ "${FAIL}" -eq 0 ]]; then
  echo "All smoke checks passed."
  exit 0
fi
echo "${FAIL} check(s) failed. See docs/cluster-test.md for manual steps."
exit 1
