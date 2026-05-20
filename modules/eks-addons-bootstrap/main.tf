resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/name" = "argocd"
    }
  }
}

resource "helm_release" "argocd" {
  name  = "argocd"
  chart = "https://github.com/argoproj/argo-helm/releases/download/argo-cd-${var.argocd_chart_version}/argo-cd-${var.argocd_chart_version}.tgz"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  wait    = true
  timeout = 900

  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.platform_domain}"
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
      }
      controller = {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
      }
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          hostname         = "argocd.${var.platform_domain}"
          annotations = {
            "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
            "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"         = "ip"
            "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTPS\":443},{\"HTTP\":80}]"
            "alb.ingress.kubernetes.io/ssl-redirect"        = "443"
            "alb.ingress.kubernetes.io/backend-protocol"    = "HTTPS"
          }
          tls = true
        }
        certificate = {
          enabled = true
          domain  = "argocd.${var.platform_domain}"
          issuer = {
            group = "cert-manager.io"
            kind  = "ClusterIssuer"
            name  = "letsencrypt-prod"
          }
        }
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
      }
      applicationSet = {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
      }
      notifications = {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
      }
      redis = {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
      }
      redisSecretInit = {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
      }
      dex = {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
      }
      # Drop CRDs on uninstall so destroy does not leave stuck Application objects.
      crds = {
        install = true
        keep    = false
      }
      configs = {
        cm = {
          url = "https://argocd.${var.platform_domain}"
        }
        params = {
          "server.insecure" = false
        }
        credentialTemplates = var.gitops_repo_password != null ? {
          gradyent-platform-creds = {
            url      = var.gitops_repo_url
            username = coalesce(var.gitops_repo_username, "git")
            password = var.gitops_repo_password
          }
        } : {}
        repositories = merge(
          {
            gradyent-platform = {
              url      = var.gitops_repo_url
              type     = "git"
              insecure = false
            }
          },
          var.gitops_repo_password != null ? {
            gradyent-platform = {
              url                = var.gitops_repo_url
              type               = "git"
              insecure           = false
              credentialTemplate = "gradyent-platform-creds"
            }
          } : {},
        )
      }
      repoServer = {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
      }
    }),
  ]

  depends_on = [
    helm_release.cilium_bootstrap,
    kubernetes_namespace_v1.argocd,
  ]
}

resource "kubernetes_config_map_v1" "irsa_roles" {
  metadata {
    name      = "gradyent-irsa-roles"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = var.irsa_map

  depends_on = [helm_release.argocd]
}
