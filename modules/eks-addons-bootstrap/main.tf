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
          enabled          = var.bootstrap_ingress_dns_before_argocd
          ingressClassName = "alb"
          hostname         = "argocd.${var.platform_domain}"
          annotations      = local.alb_ingress_annotations
          # TLS terminates at ALB using ACM (alb.ingress.kubernetes.io/certificate-arn).
          tls = false
        }
        certificate = {
          enabled = false
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
          # gitops/apps/* use Kustomize helmCharts generators (same as gitops-ci.yml).
          "kustomize.buildOptions" = "--enable-helm"
          # CRDs can take a few seconds to reach Established; wait instead of failing mid-sync.
          "resource.customizations.health.apiextensions.k8s.io_CustomResourceDefinition" = <<-EOT
            hs = {}
            if obj.status ~= nil and obj.status.conditions ~= nil then
              for _, condition in ipairs(obj.status.conditions) do
                if condition.type == "Established" and condition.status == "True" then
                  hs.status = "Healthy"
                  hs.message = "CRD is established"
                  return hs
                end
              end
            end
            hs.status = "Progressing"
            hs.message = "Waiting for CRD to be established"
            return hs
          EOT
        }
        params = {
          # TLS terminates at ALB; server speaks HTTP to the load balancer.
          "server.insecure" = true
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
              url  = var.gitops_repo_url
              type = "git"
            }
          },
          var.gitops_repo_password != null ? {
            gradyent-platform = {
              url                = var.gitops_repo_url
              type               = "git"
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
    null_resource.remove_vpc_cni_and_kube_proxy,
    kubernetes_namespace_v1.argocd,
    helm_release.external_dns,
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

  data = merge(
    var.irsa_map,
    local.platform_acm_certificate_arn != null ? { acm_certificate_arn = local.platform_acm_certificate_arn } : {},
  )

  depends_on = [helm_release.argocd]
}
