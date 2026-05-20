# Operations guide

How to deploy, upgrade, observe, and tear down the Gradyent production platform. For architecture context see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Prerequisites

| Tool | Minimum version |
|------|-----------------|
| Terraform | 1.5+ |
| Terragrunt | 0.62+ |
| AWS CLI | v2 |
| kubectl | Matches `eks_version` in env.hcl |
| git | — |

**AWS:** Profile with rights for VPC, EKS, IAM, KMS, S3 (state), DynamoDB (locks), Route 53, EC2, SSM.

**Git:** Repository pushed to `gitops_repo_url` on branch `gitops_revision` before `eks-addons-bootstrap` apply.

---

## Environment variables

From [`.envrc`](../.envrc) (direnv) or export manually:

```bash
export AWS_PROFILE=cirevo
export TERRAGRUNT_NON_INTERACTIVE=true
export TF_IN_AUTOMATION=true
```

`root.hcl` adds `-auto-approve` and `-input=false` to Terraform invocations.

---

## Terragrunt stacks

| Directory | Purpose |
|-----------|---------|
| `environments/prod/vpc` | VPC, subnets, NAT, endpoints |
| `environments/prod/eks-kms` | KMS key for EKS secrets |
| `environments/prod/eks-cluster` | EKS, bootstrap MNG, IRSA, Karpenter AWS |
| `environments/prod/bastion` | SSM bastion + EKS access entry |
| `environments/prod/eks-addons-bootstrap` | Cilium bootstrap, Argo CD, platform bootstrap |

### First-time backend

```bash
# From repository root
terragrunt backend bootstrap
```

Creates S3 bucket `gradyent-tfstate-<account>-<region>` and DynamoDB table `gradyent-tf-locks`.

---

## Deploy (full platform)

```bash
cd environments/prod
terragrunt run-all apply -auto-approve
```

### Effective order

1. **vpc** — networking foundation  
2. **eks-kms** — encryption key  
3. **eks-cluster** — control plane + bootstrap nodes + IRSA  
4. **bastion** — SSM host (depends on cluster for access entry)  
5. **eks-addons-bootstrap** — Cilium, Argo CD, GitOps sync  

### Private API constraint

`eks-addons-bootstrap` uses Terraform **Kubernetes** and **Helm** providers plus `local-exec` (`bootstrap-platform.sh`) that calls `kubectl`. These require connectivity to the **private** API endpoint.

| Option | When to use |
|--------|-------------|
| **SSM bastion** | Recommended — start session, run `terragrunt apply` from bastion (install Terraform/Terragrunt there if needed) |
| **VPN / Direct Connect** | Corporate network reaches VPC CIDR |
| **Temporary public API** | One-time bootstrap: set `cluster_endpoint_public_access = true` in `eks-cluster/terragrunt.hcl`, apply bootstrap, revert to `false` |

Without VPC connectivity, `eks-addons-bootstrap` will fail at the Helm/kubernetes steps.

---

## What `eks-addons-bootstrap` does

1. **Helm:** `cilium` (minimal) → wait ready  
2. **Helm:** `argocd` (ingress, TLS, tolerations for bootstrap nodes)  
3. **Kubernetes:** `AppProject/platform`, ConfigMap `gradyent-irsa-roles`  
4. **kubectl apply:** `platform-root` Application → `gitops/bootstrap/`  
5. **Optional:** `bootstrap-platform.sh` — patch IRSA ARNs, wait for each Application  

Controlled by Terragrunt inputs in [`environments/prod/eks-addons-bootstrap/terragrunt.hcl`](../environments/prod/eks-addons-bootstrap/terragrunt.hcl):

| Variable | Default | Meaning |
|----------|---------|---------|
| `bootstrap_platform_on_apply` | `true` | Run sync waiter script |
| `require_git_repo_access` | `true` | Fail if Git remote unreachable |
| `platform_sync_timeout_seconds` | `2400` | Max wait per Application |

---

## Verify deployment

From bastion or VPC-connected host:

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get pods -A | grep -v Running | grep -v Completed
```

Platform URLs (after external-dns + cert-manager): see [ARCHITECTURE.md#platform-dns-and-ingress](ARCHITECTURE.md#platform-dns-and-ingress).

```bash
kubectl get ingress -A
kubectl -n kube-system logs deploy/external-dns --tail=30
```

---

## Day-2 changes

### Platform Helm / manifests (no Terraform)

1. Edit `gitops/apps/<component>/` or `gitops/policies/`  
2. Push to `main`  
3. Argo CD auto-syncs (or `argocd app sync <name>`)  

Examples: bump chart version in `kustomization.yaml`, tune Grafana dashboards, add Kyverno policy.

### AWS / cluster shape (Terraform)

1. Edit `modules/` or `environments/prod/*/terragrunt.hcl`  
2. `terragrunt apply` in the affected stack(s)  

Examples: node group size, new IRSA role, VPC endpoint, EKS version.

### IRSA role changes

After changing IAM in `eks-cluster`:

```bash
cd environments/prod/eks-cluster && terragrunt apply -auto-approve
cd ../eks-addons-bootstrap && terragrunt apply -auto-approve
```

Re-applies ConfigMap and re-runs bootstrap patches for Helm parameters.

---

## Kubernetes version upgrade

EKS supports **one minor version at a time**.

1. Bump `eks_version` in [`environments/prod/env.hcl`](../environments/prod/env.hcl)  
2. `cd environments/prod/eks-cluster && terragrunt apply -auto-approve`  
3. Upgrade control plane + bootstrap node group (module handles)  
4. Update `gitops/apps/*/kustomization.yaml` chart/kube versions if needed  
5. Sync Argo CD applications  
6. Verify Karpenter AMIs (`al2023@latest` tracks automatically; confirm NodePools healthy)  

---

## Destroy

```bash
cd environments/prod
terragrunt run-all destroy -auto-approve
```

**Order:** Terragrunt reverses dependency order. `eks-addons-bootstrap` runs a **pre-destroy** hook (`cleanup-argocd.sh`) to remove Argo CD Application finalizers so namespaces do not hang.

If destroy stalls on `argocd` namespace:

```bash
cd environments/prod/eks-addons-bootstrap
terragrunt destroy -auto-approve
```

---

## CI/CD

| Workflow | Trigger | Action |
|----------|---------|--------|
| [`infra-ci.yml`](../.github/workflows/infra-ci.yml) | Terraform paths | `terragrunt validate` on prod stacks |
| [`gitops-ci.yml`](../.github/workflows/gitops-ci.yml) | `gitops/**` | Kustomize build + kubeconform |

CI does **not** apply to production automatically from these workflows alone.

---

## Observability operations

| Task | Command / URL |
|------|----------------|
| Grafana | https://grafana.dummy.cool |
| Alerts | https://alertmanager.dummy.cool |
| Flows | https://hubble.dummy.cool |
| Traces | https://jaeger.dummy.cool |
| Logs | CloudWatch log group prefix `/eks/gradyent-prod/` |
| Argo CD | https://argocd.dummy.cool |

**Secrets to set** (placeholders in Git):

- `monitoring/grafana-admin-credentials`
- `monitoring/alertmanager-notification-secrets`
- `falco/falcosidekick-notification-secrets`

---

## Troubleshooting

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| `run-all` prompts (y/n) | Missing env | `export TERRAGRUNT_NON_INTERACTIVE=true` |
| Bootstrap Git check fails | Repo not pushed | Push to `gitops_repo_url` or `require_git_repo_access = false` |
| Helm timeout on Argo CD | No CNI / no nodes | Check Cilium pods; bootstrap MNG healthy |
| Application `Unknown` | Repo-server error | `kubectl logs -n argocd deploy/argocd-repo-server` |
| Cannot reach API | Private endpoint | Use bastion SSM session |
| Karpenter no nodes | IAM, subnets, limits | Controller logs; EC2NodeClass events |
| ALB not created | LBC IRSA / subnets | LBC logs; subnet tags |
| DNS stale/wrong | external-dns | Logs; hosted zone in account |
| Cert `Pending` | HTTP-01 failure | Ingress reachable on :80; issuer logs |

Alert runbooks: [`docs/runbooks/`](runbooks/).

---

## Cilium migration (existing dual-CNI cluster)

If upgrading from vpc-cni + kube-proxy:

1. Deploy Cilium with `exclusive: false` first; validate pods  
2. Set `cni.exclusive: true` in Git; sync  
3. Remove `vpc-cni` and `kube-proxy` EKS add-ons; apply `eks-cluster`  
4. Confirm Hubble and Service connectivity  

Greenfield clusters in this repo already omit vpc-cni/kube-proxy.

---

## Support contacts (fill in for your org)

| Area | Contact |
|------|---------|
| Platform on-call | _#platform-oncall_ |
| AWS account | _cloud-team@_ |
| DNS / domain | _owner of dummy.cool zone_ |
