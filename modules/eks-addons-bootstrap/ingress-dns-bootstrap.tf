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
    "cert-manager.io/cluster-issuer"           = "letsencrypt-prod"
    "alb.ingress.kubernetes.io/scheme"         = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"    = "ip"
    "alb.ingress.kubernetes.io/listen-ports"   = "[{\"HTTPS\":443},{\"HTTP\":80}]"
    "alb.ingress.kubernetes.io/ssl-redirect"   = "443"
    "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
    "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
  }
}

resource "kubernetes_namespace_v1" "cert_manager" {
  count = var.bootstrap_ingress_dns_before_argocd ? 1 : 0

  metadata {
    name = "cert-manager"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "cert_manager" {
  count = var.bootstrap_ingress_dns_before_argocd ? 1 : 0

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_chart_version
  namespace  = kubernetes_namespace_v1.cert_manager[0].metadata[0].name

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      crds = { enabled = true }
      prometheus = {
        enabled = false
      }
      tolerations = local.critical_addons_tolerations
      webhook = {
        tolerations = local.critical_addons_tolerations
      }
      cainjector = {
        tolerations = local.critical_addons_tolerations
      }
      startupapicheck = {
        tolerations = local.critical_addons_tolerations
      }
    }),
  ]

  depends_on = [
    helm_release.cilium_bootstrap,
    null_resource.remove_vpc_cni_and_kube_proxy,
  ]
}

resource "time_sleep" "wait_cert_manager" {
  count = var.bootstrap_ingress_dns_before_argocd ? 1 : 0

  depends_on      = [helm_release.cert_manager]
  create_duration = "60s"
}

resource "kubernetes_manifest" "letsencrypt_prod" {
  count = var.bootstrap_ingress_dns_before_argocd ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "alb"
              }
            }
          },
        ]
      }
    }
  }

  depends_on = [time_sleep.wait_cert_manager]
}

resource "helm_release" "aws_load_balancer_controller" {
  count = var.bootstrap_ingress_dns_before_argocd ? 1 : 0

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
      enableCertManager = true
      tolerations       = local.critical_addons_tolerations
    }),
  ]

  depends_on = [kubernetes_manifest.letsencrypt_prod]
}

resource "helm_release" "external_dns" {
  count = var.bootstrap_ingress_dns_before_argocd ? 1 : 0

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
