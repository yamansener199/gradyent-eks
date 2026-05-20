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
| `eks-addons-bootstrap` | Cilium → **cert-manager → AWS LBC → external-dns** → Argo CD (with Ingress) → register GitOps apps |

**Ingress/DNS before Argo CD:** Terraform installs cert-manager, the AWS Load Balancer Controller, and external-dns **before** the Argo CD Helm release. When Argo CD’s Ingress is created, **external-dns** can immediately create `argocd.<platform_domain>` in Route 53. The same applies to any later Ingress you deploy via GitOps sync (Grafana, Jaeger, etc.) — external-dns is already running.

Terraform does **not** run `bootstrap-platform.sh` (no wait-for-Synced loop).

It **does** `kubectl apply` `gitops/bootstrap/` so platform Applications appear in the UI as **OutOfSync** (cert-manager / LBC / external-dns are **not** duplicated there; Terraform owns them).

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

### Option B — Public DNS (default after Terraform)

https://argocd.dummy.cool — created automatically if the Route 53 hosted zone for `platform_domain` exists in the account.

Prerequisites: hosted zone for `dummy.cool` (or your `platform_domain`), ACM not required (Let's Encrypt via cert-manager).

---

## Manual sync order (recommended)

In the UI, use **Sync** (not Refresh only). Respect sync waves so dependencies exist.

| Step | Application | Wave | Notes |
|------|-------------|------|-------|
| — | *(Terraform)* | — | cert-manager, AWS LBC, external-dns, **Argo CD Ingress** already running |
| 1 | **platform-root** | — | Optional; child apps already registered by Terraform |
| 2 | metrics-server | -1 | Metrics API |
| 3 | karpenter | 0 | Node autoscaling |
| 4 | cilium | 1 | Full Cilium/Hubble (upgrades bootstrap chart) |
| 5 | kyverno | 2 | Admission policies |
| 6 | kyverno-policies | 2 | Enforce policies |
| 7 | falco | 2 | Runtime security |
| 8 | istio-base | 3 | Istio CRDs |
| 9 | istiod | 3 | Istio control plane |
| 10 | fluentd | 4 | Logs |
| 11 | kube-prometheus-stack | 4 | Grafana Ingress → external-dns creates record |
| 12 | jaeger | 4 | Jaeger Ingress → external-dns creates record |

**Tip:** After step 1, filter Applications by name. Sync **OutOfSync** apps in wave order. Use **Sync → Synchronize** with defaults; enable **Prune** only when you intend to delete removed resources.

### IRSA (AWS IAM roles for pods)

Terraform sets `patch_irsa_on_apply = true` to patch Helm parameters on:

- karpenter, fluentd, falco

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
