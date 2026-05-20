# Grafana dashboards (GitOps-provisioned)

Vendored from Grafana.com with pinned revisions at import time. Provisioned via ConfigMaps and the Grafana sidecar (`grafana_dashboard=1`).

| Folder | File | Grafana ID | Notes |
|--------|------|------------|-------|
| Overview | `overview/gradyent-cluster-overview.json` | custom | Cluster at-a-glance |
| Nodes | `nodes/node-exporter-full.json` | 1860 | Node CPU/mem/disk/network |
| Storage | `storage/k8s-persistent-volumes.json` | 13646 | PVC usage |
| Platform | `platform/istio-mesh.json` | 7636 | Istio service metrics |
| Platform | `platform/istio-control-plane.json` | 7639 | istiod health |
| Platform | `platform/cilium-metrics.json` | 16611 | Cilium agent |
| Platform | `platform/karpenter.json` | 20398 | Karpenter capacity |
| Platform | `platform/hubble-overview.json` | custom | Hubble flow/drop/DNS metrics |
| Observability | `observability/falco.json` | 11914 | Falco security metrics |
| Observability | `observability/jaeger.json` | 10001 | Jaeger tracing |
| Observability | `observability/cert-manager.json` | 11001 | Certificate expiry |
| Observability | `observability/fluentd-health.json` | custom | Fluentd pod health (kube-state-metrics) |

Chart default dashboards (kubernetes-mixin) remain enabled via `grafana.defaultDashboardsEnabled`.
