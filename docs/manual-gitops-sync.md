# Manual GitOps sync (Argo CD UI)

This deployment path provisions **VPC + EKS + Argo CD** with Terraform, registers all platform **Applications** in Argo CD, and leaves **sync to you** in the UI.

Automated sync (`prune` / `selfHeal`) is **disabled** on every platform Application.

---

## What Terraform deploys

| Stack | Delivers |
|-------|----------|
| `vpc` | Network, NAT, VPC endpoints |
| `eks-kms` | KMS for secrets |
| `eks-cluster` | EKS `gradyent-prod`, bootstrap nodes, IRSA IAM roles |
| `bastion` | Optional SSM host for private API |
| `eks-addons-bootstrap` | Cilium (bootstrap) → Argo CD → `AppProject/platform` → `platform-root` Application |

Terraform does **not** run `bootstrap-platform.sh` (no wait-for-Synced loop).

It **does** `kubectl apply` `gitops/bootstrap/` so every platform Application appears in the UI as **OutOfSync** (ready for you to sync).

---

## Deploy commands

```bash
export AWS_PROFILE=cirevo
export AWS_DEFAULT_REGION=eu-central-1
export TERRAGRUNT_NON_INTERACTIVE=true
export TF_IN_AUTOMATION=true

cd environments/prod

terragrunt run-all apply -auto-approve
# Or step by step:
# terragrunt apply -auto-approve --terragrunt-working-dir vpc
# terragrunt apply -auto-approve --terragrunt-working-dir eks-kms
# terragrunt apply -auto-approve --terragrunt-working-dir eks-cluster
# terragrunt apply -auto-approve --terragrunt-working-dir eks-addons-bootstrap
```

Ensure Git is pushed to the URL in `environments/prod/env.hcl` (`gitops_repo_url`).

---

## Open Argo CD UI

### Option A — Port-forward (works immediately)

```bash
aws eks update-kubeconfig --name gradyent-prod --region eu-central-1
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open https://localhost:8080 (accept self-signed cert).

**Admin password:**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

### Option B — Ingress (after LBC + cert-manager + DNS)

https://argocd.dummy.cool (requires syncing ingress-related apps first).

---

## Manual sync order (recommended)

In the UI, use **Sync** (not Refresh only). Respect sync waves so dependencies exist.

| Step | Application | Wave | Why first |
|------|-------------|------|-----------|
| 1 | **platform-root** | — | Optional if you use app-of-apps; child apps are already registered by Terraform |
| 2 | metrics-server | -1 | Metrics API |
| 3 | karpenter | 0 | Node autoscaling |
| 4 | cert-manager | 1 | TLS for ingresses |
| 5 | cilium | 1 | Full Cilium/Hubble (upgrades bootstrap chart) |
| 6 | aws-load-balancer-controller | 2 | ALBs for Ingress |
| 7 | external-dns | 2 | Route 53 records |
| 8 | kyverno | 2 | Admission policies |
| 9 | kyverno-policies | 2 | Enforce policies |
| 10 | falco | 2 | Runtime security |
| 11 | istio-base | 3 | Istio CRDs |
| 12 | istiod | 3 | Istio control plane |
| 13 | fluentd | 4 | Logs |
| 14 | kube-prometheus-stack | 4 | Prometheus/Grafana |
| 15 | jaeger | 4 | Tracing |

**Tip:** After step 1, filter Applications by name. Sync **OutOfSync** apps in wave order. Use **Sync → Synchronize** with defaults; enable **Prune** only when you intend to delete removed resources.

### IRSA (AWS IAM roles for pods)

Terraform sets `patch_irsa_on_apply = true` to patch Helm parameters on:

- karpenter, fluentd, falco, aws-load-balancer-controller, external-dns

This runs after `platform-root` creates Application objects. If you sync **before** `eks-addons-bootstrap` finishes, patch IRSA from the UI: Application → **Parameters** → `serviceAccount.annotations.eks.amazonaws.com/role-arn`.

---

## CLI alternative (optional)

```bash
argocd login localhost:8080 --username admin --password <from-secret> --insecure
argocd app sync platform-root
argocd app sync metrics-server
argocd app sync karpenter
# ... etc.
```

---

## Re-enable automated sync (optional)

Edit `gitops/bootstrap/kustomization.yaml` and remove the patch that deletes `spec.syncPolicy.automated`, or set `bootstrap_platform_on_apply = true` in `eks-addons-bootstrap/terragrunt.hcl`.

---

## Verify

```bash
kubectl get nodes
kubectl get applications -n argocd
./hack/cluster-smoke-test.sh
```

See [cluster-test.md](cluster-test.md) for deeper checks.
