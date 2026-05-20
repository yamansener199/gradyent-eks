# KubePodCrashLooping

## Symptoms
Prometheus alert `KubePodCrashLooping` is firing on cluster `gradyent-prod`.

## Impact
Workloads or platform components may be degraded.

## Diagnosis
1. Open Grafana → **Overview** or default **Kubernetes** dashboards.
2. `kubectl get pods -A | grep -v Running`
3. `kubectl describe pod -n <namespace> <pod>`
4. `kubectl get events -A --sort-by=.lastTimestamp | tail -20`

## Mitigation
- **CrashLoop:** inspect logs, fix image/config, rollback deployment.
- **NodeNotReady:** check Karpenter, EC2, Cilium; `kubectl describe node`.
- **PV filling:** expand PVC or prune data; see Storage dashboard.
- **API down:** check EKS control plane in AWS console.

## Escalation
Page platform on-call if unresolved after 30 minutes.
