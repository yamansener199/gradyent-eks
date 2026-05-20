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
| `eks-addons-bootstrap` | Cilium → **ACM (DNS validation) → AWS LBC → external-dns** → Argo CD (with Ingress) → register GitOps apps |

**Ingress/DNS before Argo CD:** Terraform requests an **ACM** certificate for `platform_domain` and `*.platform_domain`, installs the AWS Load Balancer Controller and external-dns, then Argo CD with an ALB Ingress (`alb.ingress.kubernetes.io/certificate-arn`). **external-dns** creates `argocd.<platform_domain>` in Route 53 as soon as the Ingress exists.

Terraform does **not** run `bootstrap-platform.sh` (no wait-for-Synced loop).

It **does** `kubectl apply` `gitops/bootstrap/` so platform Applications appear in the UI as **OutOfSync** (ACM / LBC / external-dns are **not** duplicated there; Terraform owns them).

**Not Argo CD apps (Terraform only):** `cert-manager`, `aws-load-balancer-controller`, `external-dns`, and `argocd-ingress`. If you still see them in the UI after an older deploy, delete the stale Application CRs:

```bash
kubectl delete application cert-manager aws-load-balancer-controller external-dns -n argocd --ignore-not-found
```

Public ingress TLS uses **ACM**, not in-cluster cert-manager.

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

Prerequisites: public Route 53 hosted zone for `dummy.cool` (or your `platform_domain`). Terraform creates and validates the ACM certificate via DNS.

---

## Manual sync order (recommended)

In the UI, use **Sync** (not Refresh only). Respect sync waves so dependencies exist.

| Step | Application | Wave | Notes |
|------|-------------|------|-------|
| — | *(Terraform)* | — | ACM cert, AWS LBC, external-dns, **Argo CD Ingress** already running |
| 1 | **platform-root** | — | Optional; child apps already registered by Terraform |
| 2 | metrics-server | -1 | Metrics API |
| 3 | karpenter | 0 | Controller + CRDs (Helm only) |
| 4 | karpenter-provisioner | 1 | EC2NodeClass + NodePools (after CRDs exist) |
| 5 | cilium | 1 | Full Cilium/Hubble (upgrades bootstrap chart) |
| 6 | kyverno | 2 | Admission policies |
| 7 | kyverno-policies | 2 | Enforce policies |
| 8 | falco | 2 | Runtime security |
| 9 | istio-base | 3 | Istio CRDs |
| 10 | istiod | 3 | Istio control plane |
| 11 | fluentd | 4 | Logs |
| 12 | kube-prometheus-stack | 4 | Monitoring / Grafana (installs ServiceMonitor CRDs) |
| 13 | jaeger | 4 | Tracing |
| 14 | cilium-servicemonitors | 5 | Cilium + Hubble metrics (after Prometheus CRDs) |
| 15 | falco-servicemonitors | 5 | Falco metrics (after Prometheus CRDs) |

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
argocd app sync karpenter-provisioner
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
