# Terraform scope: AWS + EKS control plane, bootstrap node group, EKS add-ons (CoreDNS, EBS CSI),
# Karpenter AWS primitives (node IAM, SQS), and IRSA roles. Cilium (GitOps) is the sole CNI/kube-proxy.
# Platform Helm charts are owned by Argo CD under gitops/ — see docs/ARCHITECTURE.md.

data "aws_caller_identity" "current" {}

locals {
  cluster_subnet_ids = concat(var.private_subnet_ids, var.intra_subnet_ids)
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.eks_version

  vpc_id                   = var.vpc_id
  subnet_ids               = local.cluster_subnet_ids
  control_plane_subnet_ids = var.intra_subnet_ids

  cluster_endpoint_public_access                   = var.cluster_endpoint_public_access
  cluster_endpoint_private_access                  = true
  cluster_endpoint_public_access_cidrs             = var.cluster_endpoint_public_access_cidrs

  enable_cluster_creator_admin_permissions = true

  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = var.cluster_encryption_key
  }

  cluster_addons = {
    coredns = {
      most_recent                 = true
      resolve_conflicts_on_update = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      most_recent                 = true
      resolve_conflicts_on_update = "OVERWRITE"
      service_account_role_arn    = module.ebs_csi_irsa.iam_role_arn
      # Bootstrap nodes are small and overloaded; CSI controller health probes time out there.
      configuration_values = jsonencode({
        controller = {
          affinity = {
            nodeAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = {
                nodeSelectorTerms = [{
                  matchExpressions = [{
                    key      = "role"
                    operator = "NotIn"
                    values   = ["bootstrap"]
                  }]
                }]
              }
            }
          }
        }
      })
    }
  }

  eks_managed_node_groups = {
    bootstrap = {
      name            = "bootstrap"
      use_name_prefix = false

      subnet_ids = var.private_subnet_ids

      ami_type             = "AL2023_x86_64_STANDARD"
      kubernetes_version   = var.eks_version
      force_update_version = true

      instance_types = var.bootstrap_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.bootstrap_min_size
      max_size     = var.bootstrap_max_size
      desired_size = var.bootstrap_desired_size

      update_config = {
        max_unavailable_percentage = 33
      }

      labels = {
        role = "bootstrap"
      }

      taints = {
        critical_addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      tags = var.tags
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = var.tags
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name_prefix = "${var.cluster_name}-ebs-csi-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}
