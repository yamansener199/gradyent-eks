# Shared Cilium values for correct pod egress on all nodes (ENI mode + native routing).
# Fixes broken SNAT for pods on secondary ENIs; required for LBC, external-dns (Route 53 API), etc.
locals {
  cilium_platform_values = {
    cni = {
      exclusive                   = true
      enableRouteMTUForCNIChain = true
    }
    eni = {
      enabled                   = true
      awsReleaseExcessIPs       = true
      awsEnablePrefixDelegation = true
    }
    ipam = {
      mode = "eni"
    }
    routingMode                = "native"
    ipv4NativeRoutingCIDR        = var.vpc_cidr
    enableIPv4Masquerade         = true
    # Incompatible with bpf.masquerade on Cilium 1.17.x (agent fatal on startup).
    enableMasqueradeRouteSource  = false
    bpf = {
      masquerade = true
    }
    ipMasqAgent = {
      enabled = true
      config = {
        nonMasqueradeCIDRs = [var.vpc_cidr]
        masqLinkLocal       = false
      }
    }
    kubeProxyReplacement = true
    k8sServiceHost       = local.k8s_service_host
    k8sServicePort       = "443"
    # Helm replaces (not merges) chart defaults when tolerations are set. Bootstrap nodes
    # use CriticalAddonsOnly; Cilium adds node.cilium.io/agent-not-ready until its agent
    # is running — a narrow CriticalAddonsOnly-only list deadlocks fresh installs.
    operator = {
      tolerations = [
        {
          operator = "Exists"
        },
      ]
    }
    tolerations = [
      {
        operator = "Exists"
      },
    ]
  }
}
