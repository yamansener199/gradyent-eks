# Gradyent platform documentation

Documentation for the production EKS platform (`gradyent-prod`, `eu-central-1`).

## Start here

1. **[ARCHITECTURE.md](ARCHITECTURE.md)** — system context, diagrams, responsibility split  
2. **[operations.md](operations.md)** — deploy, verify, upgrade, destroy  
3. **[cluster-test.md](cluster-test.md)** — smoke tests after deploy  
3. **[README.md](../README.md)** — prerequisites and command cheatsheet  

## Deep dives

| Document | Contents |
|----------|----------|
| [networking.md](networking.md) | VPC subnets, Cilium, ALB ingress, external-dns, TLS |
| [security.md](security.md) | Private API, SSM bastion, IRSA, Kyverno, Falco |
| [components.md](components.md) | Argo CD apps, sync waves, namespaces |

## Runbooks

Prometheus alert playbooks: [runbooks/](runbooks/)
