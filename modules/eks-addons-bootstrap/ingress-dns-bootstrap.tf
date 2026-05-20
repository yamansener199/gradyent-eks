# Install ingress/DNS stack before Argo CD so its (and later GitOps) Ingress hostnames get Route 53 records.
locals {
  critical_addons_tolerations = [
    {
      key      = "CriticalAddonsOnly"
      operator = "Exists"
      effect   = "NoSchedule"
    },
  ]

  alb_ingress_annotations = {
    "alb.ingress.kubernetes.io/certificate-arn"    = local.platform_acm_certificate_arn
    "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"          = "ip"
    "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTPS\":443},{\"HTTP\":80}]"
    "alb.ingress.kubernetes.io/ssl-redirect"         = "443"
    "alb.ingress.kubernetes.io/backend-protocol"     = "HTTP"
    "alb.ingress.kubernetes.io/healthcheck-path"     = "/healthz"
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_lbc_chart_version
  namespace  = "kube-system"

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.aws_region
      vpcId       = var.irsa_map["vpc_id"]
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.irsa_map["aws_load_balancer_controller_role_arn"]
        }
      }
      enableCertManager = false
      tolerations       = local.critical_addons_tolerations
    }),
  ]

  depends_on = [
    helm_release.cilium_bootstrap,
    null_resource.remove_vpc_cni_and_kube_proxy,
    aws_acm_certificate_validation.platform,
  ]
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_chart_version
  namespace  = "kube-system"

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      provider = { name = "aws" }
      aws = {
        region = var.aws_region
      }
      domainFilters = [var.platform_domain]
      policy        = "sync"
      txtOwnerId    = var.cluster_name
      txtPrefix     = "externaldns-"
      registry      = "txt"
      sources       = ["ingress", "service"]
      serviceAccount = {
        create = true
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.irsa_map["external_dns_role_arn"]
        }
      }
      tolerations = local.critical_addons_tolerations
    }),
  ]

  depends_on = [helm_release.aws_load_balancer_controller]
}
