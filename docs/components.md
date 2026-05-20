# Platform components reference

Catalog of every platform workload managed from this repository: Argo CD Application name, sync wave, source path, target namespace, and role.

Parent doc: [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Argo CD Applications (bootstrap)

All Applications are defined under [`gitops/bootstrap/`](../gitops/bootstrap/) and assigned to Argo CD project **`platform`** via Kustomize patch.

| Application | Wave | Path | Destination namespace | Chart / type |
|-------------|------|------|----------------------|--------------|
| metrics-server | -1 | `gitops/apps/metrics-server` | `kube-system` | Helm |
| karpenter | 0 | `gitops/apps/karpenter` | `karpenter` | Helm + manifests |
| cert-manager | 1 | `gitops/apps/cert-manager` | `cert-manager` | Helm + ClusterIssuer |
| cilium | 1 | `gitops/apps/cilium` | `kube-system` | Helm + Hubble Ingress |
| aws-load-balancer-controller | 2 | `gitops/apps/aws-load-balancer-controller` | `kube-system` | Helm |
| external-dns | 2 | `gitops/apps/external-dns` | `kube-system` | Helm |
| kyverno | 2 | `gitops/apps/kyverno` | `kyverno` | Helm |
| kyverno-policies | 2 | `gitops/policies` | cluster-scoped | Kustomize |
| falco | 2 | `gitops/apps/falco` | `falco` | Helm |
| istio-base | 3 | `gitops/apps/istio-base` | `istio-system` | Helm |
| istiod | 3 | `gitops/apps/istiod` | `istio-system` | Helm |
| fluentd | 4 | `gitops/apps/fluentd` | `logging` | Helm |
| kube-prometheus-stack | 4 | `gitops/apps/kube-prometheus-stack` | `monitoring` | Helm + dashboards |
| jaeger | 4 | `gitops/apps/jaeger` | `observability` | Helm + Ingress |

**Terraform-managed (not in bootstrap kustomization):**

| Resource | Module | Notes |
|----------|--------|-------|
| Argo CD | `eks-addons-bootstrap` | Helm; wave N/A |
| Cilium bootstrap | `eks-addons-bootstrap` | Minimal chart pre-Argo |
| `platform-root` | `eks-addons-bootstrap` | Points at `gitops/bootstrap` |

---

## Component details

### metrics-server (wave -1)

- **Purpose:** Resource metrics API for HPA and `kubectl top`.
- **Why early:** Other components may depend on metrics.

### Karpenter (wave 0)

- **Purpose:** Node autoscaling (EC2 provisioning).
- **AWS (Terraform):** Controller IRSA, node IAM role, interruption SQS queue.
- **GitOps:** Helm chart + `EC2NodeClass`, `NodePool` manifests.
- **Discovery:** Subnet/SG tag `karpenter.sh/discovery=gradyent-prod`.

### cert-manager (wave 1)

- **Purpose:** TLS certificate automation.
- **Issuer:** `letsencrypt-prod` ClusterIssuer — HTTP-01 via `ingress.class: alb`.
- **Used by:** Grafana, Alertmanager, Jaeger, Hubble, Argo CD ingress certificates.

### Cilium (wave 1)

- **Purpose:** CNI, kube-proxy replacement, network policy, Hubble.
- **Version pin:** `1.17.4` in `kustomization.yaml`.
- **See:** [networking.md](networking.md).

### aws-load-balancer-controller (wave 2)

- **Purpose:** Manage ALB/NLB for Kubernetes `Ingress` and `Service type=LoadBalancer`.
- **IRSA:** `gradyent-prod-aws-load-balancer-controller`.
- **Config:** `vpcId`, `clusterName`, `region` in values; IRSA ARN patched at bootstrap.

### external-dns (wave 2)

- **Purpose:** Sync Ingress hostnames to Route 53 (`dummy.cool`).
- **IRSA:** `gradyent-prod-external-dns`.
- **Policy:** `sync` — removes records when Ingress deleted.

### Kyverno + policies (wave 2)

- **Controller:** Admission webhooks for policy enforcement.
- **Policies:** [`gitops/policies/`](../gitops/policies/) — 11 enforce rules; platform namespaces excluded.
- **See:** [security.md](security.md).

### Falco (wave 2)

- **Purpose:** Runtime threat detection (syscall/K8s audit).
- **Sidekick:** Slack notifications for security events.
- **IRSA:** Optional CloudWatch metrics namespace `Falco`.

### Istio (waves 3)

- **istio-base:** CRDs and base resources.
- **istiod:** Control plane.
- **Purpose:** Service mesh foundation for **future application** workloads; not required for platform UIs.

### Fluentd (wave 4)

- **Purpose:** Container log forwarding.
- **Destination:** CloudWatch Logs `/eks/gradyent-prod/*`.
- **IRSA:** `gradyent-prod-fluentd`.

### kube-prometheus-stack (wave 4)

- **Purpose:** Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics, default rules.
- **Ingress:** Grafana + Alertmanager public hostnames.
- **Dashboards:** Vendored JSON + ConfigMap generator.
- **Alerts:** Slack channels + PagerDuty for critical; runbook URLs on rules.
- **Scrapes:** Platform ServiceMonitors (Karpenter, Jaeger, Cilium, cert-manager, etc.).

### Jaeger (wave 4)

- **Purpose:** Distributed tracing UI.
- **Storage:** In-memory (dev/platform; not HA).
- **Ingress:** `jaeger.dummy.cool`.

---

## Terraform-only resources

| Component | Stack | Description |
|-----------|-------|-------------|
| VPC | vpc | 10.0.0.0/16, 3 AZ, NAT, endpoints |
| KMS | eks-kms | EKS secrets encryption |
| EKS cluster | eks-cluster | `gradyent-prod`, private API, bootstrap MNG |
| EBS CSI | eks-cluster add-on | Persistent volumes (gp3 default class expected) |
| CoreDNS | eks-cluster add-on | Cluster DNS |
| Bastion | bastion | SSM EC2 |
| Karpenter AWS | eks-cluster | IAM, SQS |

---

## Namespaces summary

| Namespace | Workloads |
|-----------|-----------|
| `kube-system` | Cilium, LBC, external-dns, metrics-server, CoreDNS, EBS CSI |
| `karpenter` | Karpenter controller |
| `cert-manager` | cert-manager |
| `kyverno` | Kyverno |
| `falco` | Falco, Falcosidekick |
| `istio-system` | Istiod |
| `monitoring` | Prometheus, Grafana, Alertmanager |
| `observability` | Jaeger |
| `logging` | Fluentd |
| `argocd` | Argo CD |

---

## Sync policy defaults

Bootstrap Applications use:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - ServerSideApply=true
```

`platform-root` uses `prune: false` on the root app to avoid accidental mass deletion from the app-of-apps parent.

---

## Version bumps

| Change | Where to edit |
|--------|----------------|
| Helm chart version | `gitops/apps/<app>/kustomization.yaml` → `helmCharts[].version` |
| Container images | Usually chart defaults; override in `values.yaml` |
| EKS version | `environments/prod/env.hcl` → Terraform |
| Argo CD version | `modules/eks-addons-bootstrap/variables.tf` → `argocd_chart_version` |

After edits: push Git (Argo) or `terragrunt apply` (Terraform).

---

## Adding a new platform component

1. Create `gitops/apps/<name>/` (Kustomize + Helm or manifests).  
2. Add `gitops/bootstrap/<name>-app.yaml` with appropriate **sync wave**.  
3. List it in `gitops/bootstrap/kustomization.yaml`.  
4. If IRSA needed: add module in `modules/eks-cluster/irsa.tf`, extend `irsa_map`, patch in `bootstrap-platform.sh`.  
5. Document in this file.  
6. Extend `gitops-ci.yml` validation loop if Helm-based.

---

## Adding application workloads (out of scope today)

1. Create a new namespace (not in Kyverno exclude list).  
2. Separate Git repo or `gitops/apps/my-product/` path.  
3. New Argo CD `Application` (separate project recommended).  
4. Comply with Kyverno policies (probes, limits, non-root, etc.).  
5. Use Istio injection only if mesh policies are defined.
