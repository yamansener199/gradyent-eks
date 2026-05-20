#!/usr/bin/env bash
# Validate eks-addons-bootstrap Cilium networking bootstrap (config + optional live cluster).
# CI runs config/helm tests only; pass --live to assert cluster state after apply.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_DIR="${REPO_ROOT}/modules/eks-addons-bootstrap"
CILIUM_CHART_VERSION="${CILIUM_CHART_VERSION:-1.17.4}"
RUN_LIVE=0
FAIL=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--live]

  (default)  Static config + rendered Helm checks (no cluster required)
  --live     Also verify a reachable cluster matches bootstrap expectations
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live) RUN_LIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

pass() { echo "  OK  $*"; }
fail() { echo "  FAIL $*"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "==> $*"; }

section "Cilium bootstrap Terraform config"
CILIUM_EGRESS="${MODULE_DIR}/cilium-egress.tf"
CLEANUP_TF="${MODULE_DIR}/legacy-networking-cleanup.tf"

if rg -q 'operator\s*=\s*"Exists"' "${CILIUM_EGRESS}"; then
  pass "cilium-egress.tf sets operator = Exists tolerations"
else
  fail "cilium-egress.tf missing operator = Exists tolerations"
fi

if rg -q 'key\s*=\s*"CriticalAddonsOnly"' "${CILIUM_EGRESS}" && \
   ! rg -q 'operator\s*=\s*"Exists"' "${CILIUM_EGRESS}"; then
  fail "cilium-egress.tf still uses CriticalAddonsOnly-only tolerations"
fi

if rg -q 'cilium_id\s*=' "${CLEANUP_TF}"; then
  fail "legacy-networking-cleanup.tf still triggers on cilium_id (re-runs cleanup on Helm upgrades)"
else
  pass "cleanup null_resource does not trigger on cilium_id"
fi

if rg -q 'script_sha\s*=\s*filesha256' "${CLEANUP_TF}"; then
  pass "cleanup null_resource uses script_sha trigger"
else
  fail "cleanup null_resource missing script_sha trigger"
fi

section "Rendered Cilium Helm values from Terraform locals"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
VALUES_JSON="${TMP_DIR}/cilium-bootstrap-values.json"
VALUES_FILE="${TMP_DIR}/cilium-bootstrap-values.yaml"

CONSOLE_TFVARS="${MODULE_DIR}/tests/console.tfvars"
if [[ ! -f "${CONSOLE_TFVARS}" ]]; then
  fail "missing ${CONSOLE_TFVARS} for terraform console"
fi

(
  cd "${MODULE_DIR}"
  terraform console -input=false -var-file="${CONSOLE_TFVARS}" <<'EOF' | jq -r . > "${VALUES_JSON}"
jsonencode(local.cilium_platform_values)
EOF
)

if [[ ! -s "${VALUES_JSON}" ]]; then
  fail "terraform console did not render cilium_platform_values"
else
  pass "terraform console rendered cilium_platform_values"
fi

yq -P '.' "${VALUES_JSON}" > "${VALUES_FILE}" 2>/dev/null || cp "${VALUES_JSON}" "${VALUES_FILE}"

if jq -e '.tolerations[] | select(.operator == "Exists")' "${VALUES_JSON}" >/dev/null 2>&1; then
  pass "agent tolerations include operator: Exists"
else
  fail "agent tolerations missing operator: Exists"
fi

if jq -e '.operator.tolerations[] | select(.operator == "Exists")' "${VALUES_JSON}" >/dev/null 2>&1; then
  pass "operator tolerations include operator: Exists"
else
  fail "operator tolerations missing operator: Exists"
fi

if jq -e '.tolerations[] | select(.key == "CriticalAddonsOnly")' "${VALUES_JSON}" >/dev/null 2>&1; then
  fail "agent tolerations still narrow to CriticalAddonsOnly only"
else
  pass "agent tolerations are not CriticalAddonsOnly-only"
fi

section "Helm template: Cilium schedules on bootstrap taints"
if ! command -v helm >/dev/null 2>&1; then
  fail "helm CLI not installed (required for template test)"
else
  helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
  helm repo update cilium >/dev/null 2>&1 || true

  RENDERED="${TMP_DIR}/cilium-manifests.yaml"
  helm template cilium cilium/cilium \
    --version "${CILIUM_CHART_VERSION}" \
    --namespace kube-system \
    -f "${VALUES_JSON}" \
    > "${RENDERED}"

  DS_TOLERATIONS="$(python3 - "${RENDERED}" <<'PY'
import json, sys, yaml
docs = list(yaml.safe_load_all(open(sys.argv[1])))
for d in docs:
    if d.get("kind") == "DaemonSet" and d.get("metadata", {}).get("name") == "cilium":
        print(json.dumps(d["spec"]["template"]["spec"]["tolerations"]))
        break
PY
)"
  if echo "${DS_TOLERATIONS}" | jq -e '.[] | select(.operator == "Exists")' >/dev/null 2>&1; then
    pass "rendered cilium DaemonSet tolerates all taints (operator: Exists)"
  else
    fail "rendered cilium DaemonSet missing operator: Exists toleration"
    echo "${DS_TOLERATIONS}" | head -20
  fi

  if echo "${DS_TOLERATIONS}" | jq -e '.[] | select(.operator == "Exists" or .key == "node.cilium.io/agent-not-ready")' >/dev/null 2>&1; then
    pass "rendered cilium DaemonSet can schedule while node.cilium.io/agent-not-ready is present"
  else
    fail "rendered cilium DaemonSet would deadlock on node.cilium.io/agent-not-ready"
  fi
fi

section "GitOps Cilium values alignment"
GITOPS_VALUES="${REPO_ROOT}/gitops/apps/cilium/values.yaml"
if python3 - "${GITOPS_VALUES}" <<'PY'
import sys, yaml
vals = yaml.safe_load(open(sys.argv[1]))
tol = vals.get("tolerations") or []
sys.exit(0 if any(t.get("operator") == "Exists" for t in tol) else 1)
PY
then
  pass "gitops/apps/cilium values use operator: Exists (matches bootstrap)"
else
  fail "gitops/apps/cilium tolerations diverge from bootstrap"
fi

if [[ "${RUN_LIVE}" -eq 1 ]]; then
  section "Live cluster bootstrap state"
  CLUSTER_NAME="${CLUSTER_NAME:-gradyent-prod}"
  AWS_REGION="${AWS_REGION:-eu-central-1}"

  if ! kubectl cluster-info &>/dev/null; then
    if command -v aws >/dev/null 2>&1; then
      aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1 || true
    fi
  fi

  if ! kubectl cluster-info &>/dev/null; then
    fail "kubectl cannot reach cluster (skip live checks or fix kubeconfig)"
  else
    pass "kubectl can reach API server"

    NODE_COUNT="$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    CILIUM_DESIRED="$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
    CILIUM_READY="$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"

    if [[ "${CILIUM_DESIRED}" -ge 1 && "${CILIUM_DESIRED}" == "${NODE_COUNT}" ]]; then
      pass "cilium DaemonSet desired=${CILIUM_DESIRED} matches node count=${NODE_COUNT}"
    else
      fail "cilium DaemonSet desired=${CILIUM_DESIRED}, nodes=${NODE_COUNT}"
    fi

    if [[ "${CILIUM_READY}" == "${CILIUM_DESIRED}" && "${CILIUM_READY}" -ge 1 ]]; then
      pass "cilium pods ready=${CILIUM_READY}/${CILIUM_DESIRED}"
    else
      fail "cilium pods ready=${CILIUM_READY}/${CILIUM_DESIRED}"
      kubectl -n kube-system get pods -l k8s-app=cilium -o wide || true
    fi

    if kubectl -n kube-system get ds aws-node >/dev/null 2>&1; then
      fail "aws-node DaemonSet still present after bootstrap cleanup"
    else
      pass "aws-node DaemonSet absent (Cilium-only CNI)"
    fi

    if kubectl -n kube-system get ds kube-proxy >/dev/null 2>&1; then
      fail "kube-proxy DaemonSet still present after bootstrap cleanup"
    else
      pass "kube-proxy DaemonSet absent (Cilium kube-proxy replacement)"
    fi

    # No node should be stuck with agent-not-ready while cilium is absent on that node.
    STUCK=0
    while IFS= read -r node; do
      [[ -z "${node}" ]] && continue
      if kubectl get node "${node}" -o json | jq -e '.spec.taints[]? | select(.key=="node.cilium.io/agent-not-ready")' >/dev/null; then
        local_pods="$(kubectl -n kube-system get pods -l k8s-app=cilium --field-selector "spec.nodeName=${node}" --no-headers 2>/dev/null | awk '$3=="Running"{c++} END{print c+0}')"
        if [[ "${local_pods}" -lt 1 ]]; then
          fail "node ${node} has agent-not-ready taint but no Running cilium pod"
          STUCK=$((STUCK + 1))
        fi
      fi
    done < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

    if [[ "${STUCK}" -eq 0 ]]; then
      pass "no agent-not-ready / missing-cilium deadlock on nodes"
    fi

    LIVE_TOLERATIONS="$(kubectl -n kube-system get ds cilium -o jsonpath='{.spec.template.spec.tolerations}' 2>/dev/null || echo '[]')"
    if echo "${LIVE_TOLERATIONS}" | jq -e '.[] | select(.operator=="Exists")' >/dev/null 2>&1; then
      pass "live cilium DaemonSet has operator: Exists toleration"
    else
      fail "live cilium DaemonSet missing operator: Exists toleration (apply Terraform fix)"
    fi
  fi
fi

echo ""
if [[ "${FAIL}" -eq 0 ]]; then
  echo "All eks-addons-bootstrap tests passed."
  exit 0
fi
echo "${FAIL} test(s) failed."
exit 1
