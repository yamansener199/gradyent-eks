# Gradyent Production EKS (Terragrunt + GitOps)

AWS EKS in `eu-central-1` with **Terragrunt** for infrastructure and **Argo CD** for the CNCF platform stack (Karpenter, Cilium, Istio, Prometheus, Grafana, Falco, Kyverno, …).

## Documentation

| Guide | Description |
|-------|-------------|
| **[Architecture overview](docs/ARCHITECTURE.md)** | Design goals, diagrams, Terraform vs GitOps, quick reference |
| **[Networking](docs/networking.md)** | VPC, Cilium, ingress, DNS, TLS |
| **[Security](docs/security.md)** | Private API, bastion, IRSA, Kyverno, Falco |
| **[Operations](docs/operations.md)** | Deploy, destroy, upgrades, troubleshooting |
| **[Components](docs/components.md)** | Every Argo CD app, sync waves, namespaces |
| **[Runbooks](docs/runbooks/)** | Alert response playbooks |
| **[Cluster test](docs/cluster-test.md)** | Post-deploy smoke checklist + `hack/cluster-smoke-test.sh` |
| **[Manual Argo CD sync](docs/manual-gitops-sync.md)** | VPC/EKS deploy, then sync platform apps yourself in the UI |

## Prerequisites

- AWS CLI, Terraform `>= 1.5`, Terragrunt `>= 0.62`, `kubectl`, `git`
- AWS profile with rights for VPC, EKS, IAM, KMS, S3, DynamoDB
- **This repository pushed** to the URL in [`environments/prod/env.hcl`](environments/prod/env.hcl) (`gitops_repo_url`) on branch `main`
- Same URL in [`gitops/bootstrap/repo.env`](gitops/bootstrap/repo.env)

Argo CD clones that Git repo to deploy **platform components only** under [`gitops/`](gitops/) (see scope below).

### GitOps scope (this repository)

| In scope (`gitops/`) | Out of scope (not in this repo) |
|----------------------|----------------------------------|
| Karpenter, Cilium, Istio control plane | Frontend / backend / API services |
| Kyverno, Falco, cert-manager, metrics-server | Business application Helm charts |
| Prometheus, Grafana, Jaeger, Fluentd | Demo or sample microservices |

To change a **platform** chart version or values: edit [`gitops/apps/<component>/`](gitops/apps/), push Git — Argo CD reconciles. No Terraform apply needed for chart bumps.

When you add application workloads later, use a **separate Git repo** (or `gitops/apps/` paths) and register another Argo CD Application — not covered here.

## One-time setup

```bash
# Optional: auto-load env vars in this directory (recommended)
direnv allow   # requires direnv

# Or export manually every session:
export AWS_PROFILE=cirevo
export TERRAGRUNT_NON_INTERACTIVE=true
export TF_IN_AUTOMATION=true
```

```bash
terragrunt backend bootstrap   # from repo root, first time only
```

## Deploy everything (no y/n prompts)

```bash
cd environments/prod
terragrunt run-all apply -auto-approve
```

This provisions, in order:

1. **vpc** → **eks-kms** → **eks-cluster** (private API, Cilium-only add-ons, IRSA roles)
2. **bastion** (SSM-only EC2 in a private subnet, EKS cluster-admin access entry)
3. **eks-addons-bootstrap** (Argo CD + platform App-of-Apps from Git + automatic sync wait)

The Kubernetes API is **private-only** (`cluster_endpoint_public_access = false`). Run `eks-addons-bootstrap` from a host that can reach the VPC (SSM bastion shell or VPN), not from the public internet.

`root.hcl` injects `-auto-approve` and `-input=false` into Terraform.  
`TERRAGRUNT_NON_INTERACTIVE=true` skips Terragrunt’s `run-all` confirmation.

## Destroy everything (no y/n prompts)

```bash
cd environments/prod
terragrunt run-all destroy -auto-approve
```

A pre-destroy hook removes Argo CD Application finalizers so the `argocd` namespace does not hang.

## Verify

From the **SSM bastion** (or any host with VPC reachability to the private EKS endpoint):

```bash
# Instance ID from: cd environments/prod/bastion && terragrunt output instance_id
aws ssm start-session --target <bastion-instance-id> --region eu-central-1

# On the bastion (kubectl/kubeconfig preconfigured):
kubectl get applications -n argocd
kubectl get nodes
```

Your IAM user/role also needs `ssm:StartSession` on the bastion and the usual EKS IAM permissions for your own kubeconfig if you use port-forwarding/VPN instead.

## Terraform vs Argo CD

| **Terraform** | **Argo CD** ([`gitops/`](gitops/)) |
|---------------|-------------------------------------|
| VPC, KMS, EKS (private API), SSM bastion, bootstrap MNG | Cilium + Hubble (sole CNI / kube-proxy replacement) |
| EKS add-ons (CoreDNS, EBS CSI only) | **Karpenter** controller + NodePools |
| Karpenter AWS IAM / SQS | Kyverno, Falco, Istio |
| IRSA roles (LBC, external-dns, …) | cert-manager, external-dns, metrics-server |
| Argo CD install + bootstrap | Fluentd, Prometheus, Grafana, Alertmanager, Jaeger |

## Repository layout

| Path | Purpose |
|------|---------|
| [`environments/prod/`](environments/prod/) | Terragrunt stacks (`vpc`, `eks-cluster`, `bastion`, `eks-addons-bootstrap`, …) |
| [`modules/`](modules/) | Terraform modules |
| [`gitops/bootstrap/`](gitops/bootstrap/) | Argo CD App-of-Apps |
| [`gitops/apps/`](gitops/apps/) | Platform Helm/Kustomize only (no app workloads) |
| [`.envrc`](.envrc) | Non-interactive env defaults (direnv) |

## Kubernetes upgrades

EKS allows **one minor version at a time**. Bump `eks_version` in [`environments/prod/env.hcl`](environments/prod/env.hcl), then:

```bash
cd environments/prod/eks-cluster && terragrunt apply -auto-approve
cd ../eks-addons-bootstrap && terragrunt apply -auto-approve
```

Update pins under `gitops/apps/`, push Git, and sync Argo CD apps.

## Troubleshooting

| Symptom | Action |
|---------|--------|
| Stuck on `(y/n)` | `export TERRAGRUNT_NON_INTERACTIVE=true` and use `-auto-approve` on `run-all` |
| Bootstrap fails on Git | Push repo to `gitops_repo_url` or set `require_git_repo_access = false` in `eks-addons-bootstrap/terragrunt.hcl` |
| Application stays `Unknown` | Check `kubectl logs -n argocd deploy/argocd-repo-server` |
| Karpenter installed via Helm manually | `helm uninstall karpenter -n karpenter` before first GitOps apply |
| Destroy hangs on `argocd` namespace | Re-run `terragrunt destroy -auto-approve` in `eks-addons-bootstrap` (pre-destroy hook should run) |

## CI

- [`.github/workflows/infra-ci.yml`](.github/workflows/infra-ci.yml) — Terragrunt validate  
- [`.github/workflows/gitops-ci.yml`](.github/workflows/gitops-ci.yml) — Kustomize + kubeconform  

## Platform URLs and secrets

Public DNS, ingress, bastion access, and Cilium networking are documented in **[docs/networking.md](docs/networking.md)** and **[docs/security.md](docs/security.md)**.

| Service | URL |
|---------|-----|
| Grafana | https://grafana.dummy.cool |
| Alertmanager | https://alertmanager.dummy.cool |
| Argo CD | https://argocd.dummy.cool |
| Jaeger | https://jaeger.dummy.cool |
| Hubble | https://hubble.dummy.cool |

### Grafana and alerting

1. Point DNS names above to their ALB hostnames.
2. Replace secrets before production:
   - `grafana-admin-credentials` in `monitoring`
   - `alertmanager-notification-secrets` (Slack webhook + PagerDuty routing key)
   - `falcosidekick-notification-secrets` in `falco` (Slack webhook for runtime security alerts)
3. Open **https://grafana.dummy.cool**.

**Dashboard folders:** Overview, Nodes, Storage, Platform (Istio, Cilium, Hubble, Karpenter), Observability (Falco, Jaeger, cert-manager, Fluentd), plus chart defaults (kubernetes-mixin).

**Alertmanager** routes critical alerts to Slack and PagerDuty; warnings to Slack. Runbooks: [`docs/runbooks/`](docs/runbooks/).
