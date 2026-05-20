# Cluster test guide

Use this checklist to validate **gradyent-prod** after `terragrunt run-all apply` or after changes to GitOps/Terraform.

## Prerequisites

| Requirement | Check |
|-------------|--------|
| Cluster exists | `aws eks describe-cluster --name gradyent-prod --region eu-central-1` → `ACTIVE` |
| API reachable | Private endpoint only — use **SSM bastion** or VPN (see [operations.md](operations.md)) |
| `kubectl` configured | `kubectl config current-context` points at `gradyent-prod` |
| Git pushed | Same commit as `gitops_repo_url` / `main` |

```bash
export AWS_PROFILE=cirevo
export AWS_DEFAULT_REGION=eu-central-1

# Bastion (if API is private)
cd environments/prod/bastion
terragrunt output ssm_start_session_command
# aws ssm start-session --target <id> --region eu-central-1
```

Automated script (run from a host with `kubectl` + `aws`):

```bash
./hack/cluster-smoke-test.sh
```

---

## 1. AWS / Terraform layer

```bash
cd environments/prod

# All stacks should show no pending changes after a successful deploy
terragrunt run-all plan

# Cluster metadata
aws eks describe-cluster --name gradyent-prod \
  --query 'cluster.{status:status,version:version,endpoint:endpoint}' \
  --output table

# Node group (bootstrap MNG)
aws eks list-nodegroups --cluster-name gradyent-prod
aws eks describe-nodegroup --cluster-name gradyent-prod --nodegroup-name bootstrap \
  --query 'nodegroup.{status:status,scaling:scalingConfig,instanceTypes:instanceTypes}' \
  --output table
```

**Pass criteria:** Cluster `ACTIVE`, bootstrap nodegroup `ACTIVE`, desired nodes ≥ 2.

---

## 2. Cluster core (kubectl)

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get componentstatuses 2>/dev/null || true   # deprecated on newer K8s; optional
kubectl get pods -n kube-system
```

**Pass criteria:**

- All nodes `Ready`
- `cilium` DaemonSet pods running on every node
- `coredns` pods running
- `aws-node` (vpc-cni) **should NOT** exist if Cilium-only cutover is complete

```bash
# Cilium health
kubectl -n kube-system get pods -l k8s-app=cilium
cilium status 2>/dev/null || kubectl -n kube-system exec ds/cilium -- cilium status 2>/dev/null | head -20
```

---

## 3. Argo CD

```bash
kubectl get applications -n argocd
kubectl get applications -n argocd -o json | jq -r '
  .items[] | "\(.metadata.name)\t\(.status.sync.status)\t\(.status.health.status)"' | column -t
```

**Pass criteria:** All platform apps `Synced` + `Healthy` (or `Progressing` briefly after sync).

```bash
# Repo server healthy
kubectl -n argocd get pods
kubectl -n argocd logs deploy/argocd-repo-server --tail=30
```

UI: https://argocd.dummy.cool (after DNS + ACM ALB; or port-forward below).

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080
```

---

## 4. Platform components

### Networking (Cilium / Hubble)

```bash
kubectl -n kube-system get ds cilium
kubectl -n kube-system get pods -l app.kubernetes.io/name=hubble-ui
```

### ACM + LBC + external-dns

```bash
aws acm list-certificates --region eu-central-1 --query 'CertificateSummaryList[?DomainName==`dummy.cool`]'
kubectl -n kube-system get deploy aws-load-balancer-controller external-dns
kubectl get ingress -A
kubectl -n kube-system logs deploy/external-dns --tail=20
```

### Security

```bash
kubectl -n kyverno get pods
kubectl get clusterpolicies | head -15
kubectl -n falco get pods
```

### Observability

```bash
kubectl -n monitoring get pods
kubectl -n monitoring get prometheus,servicemonitor -A 2>/dev/null | head -5
kubectl -n observability get pods   # Jaeger
kubectl -n logging get pods         # Fluentd
```

### Autoscaling (Karpenter)

```bash
kubectl -n karpenter get pods
kubectl get nodepools,ec2nodeclasses 2>/dev/null
kubectl -n karpenter logs deploy/karpenter --tail=30
```

**Pass criteria:** Controllers running; no sustained `CrashLoopBackOff`.

---

## 5. Ingress, DNS, and TLS

```bash
kubectl get ingress -A
kubectl get certificate -A
```

| URL | Expect |
|-----|--------|
| https://grafana.dummy.cool | Grafana login |
| https://argocd.dummy.cool | Argo CD UI |
| https://hubble.dummy.cool | Hubble UI |
| https://jaeger.dummy.cool | Jaeger UI |
| https://alertmanager.dummy.cool | Alertmanager UI |

```bash
# From your machine (DNS must resolve)
curl -sI https://grafana.dummy.cool | head -5
```

**Pass criteria:** HTTPS returns 200/302; cert valid (Let's Encrypt). `external-dns` logs show record upserts without errors.

---

## 6. Functional smoke workload (optional)

Deploys a tiny pod to confirm scheduling, DNS, and egress:

```bash
kubectl run smoke-test --image=public.ecr.aws/docker/library/busybox:1.36 \
  --restart=Never --command -- sleep 300
kubectl wait --for=condition=Ready pod/smoke-test --timeout=120s
kubectl exec smoke-test -- nslookup kubernetes.default.svc.cluster.local
kubectl exec smoke-test -- wget -qO- --timeout=5 https://www.amazon.com 2>&1 | head -1 || echo "egress check done"
kubectl delete pod smoke-test
```

**Pass criteria:** Pod `Ready`, cluster DNS resolves, egress works (NAT/endpoints).

---

## 7. Prometheus / alerts (optional)

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090 — Targets should be UP
```

In Grafana (https://grafana.dummy.cool): open **Platform → Overview** dashboard.

---

## Failure quick reference

| Symptom | See |
|---------|-----|
| `kubectl` timeout | Private API — use bastion ([security.md](security.md)) |
| No nodes | Bootstrap MNG / `kubectl describe node` |
| Argo `Unknown` | `argocd-repo-server` logs; Git URL reachable |
| Ingress no ADDRESS | LBC IRSA, subnet tags ([networking.md](networking.md)) |
| Cert pending | HTTP-01, ALB listener on :80 |
| Pods pending | Cilium not ready, Kyverno deny, Karpenter not provisioning |

---

## Test after changes

| Change type | Re-run |
|-------------|--------|
| `gitops/apps/*` only | Sections 3–7 (+ `./hack/cluster-smoke-test.sh`) |
| Terraform `eks-cluster` | Sections 1–7 |
| Destroy + recreate | Full guide from section 1 |
