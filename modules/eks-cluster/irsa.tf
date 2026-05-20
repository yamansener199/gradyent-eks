# Karpenter controller IRSA (single controller role for Helm/GitOps).
module "karpenter_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "${var.cluster_name}-karpenter-controller"

  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_name       = module.eks.cluster_name
  karpenter_controller_node_iam_role_arns = [module.karpenter.node_iam_role_arn]
  karpenter_sqs_queue_arn                 = module.karpenter.queue_arn

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }

  tags = var.tags
}

resource "aws_iam_role_policy" "karpenter_controller_instance_profile" {
  name = "${var.cluster_name}-karpenter-instance-profile"
  role = module.karpenter_controller_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InstanceProfileLifecycle"
        Effect = "Allow"
        Action = [
          "iam:GetInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:ListInstanceProfiles",
          "iam:ListInstanceProfilesForRole",
        ]
        Resource = "*"
      },
      {
        Sid      = "PassNodeRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = module.karpenter.node_iam_role_arn
      },
    ]
  })
}

# Karpenter 1.3+ dry-run RunInstances auth check uses launch templates that may not
# yet carry the discovery tag required by the module-managed controller policy.
resource "aws_iam_role_policy" "karpenter_controller_run_instances" {
  name = "${var.cluster_name}-karpenter-run-instances"
  role = module.karpenter_controller_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RunInstancesLaunchTemplateAuthCheck"
        Effect   = "Allow"
        Action   = "ec2:RunInstances"
        Resource = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:launch-template/*"
      },
    ]
  })
}

# Fluentd IRSA — scoped CloudWatch Logs
module "fluentd_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "${var.cluster_name}-fluentd"

  role_policy_arns = {
    fluentd = aws_iam_policy.fluentd.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["logging:fluentd"]
    }
  }

  tags = var.tags
}

resource "aws_iam_policy" "fluentd" {
  name_prefix = "${var.cluster_name}-fluentd-"
  description = "CloudWatch Logs write for Fluentd"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/eks/${var.cluster_name}/*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/eks/${var.cluster_name}/*:*",
        ]
      },
    ]
  })

  tags = var.tags
}

# AWS Load Balancer Controller IRSA (ALB/NLB Ingress for Grafana and HTTP-01).
module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "${var.cluster_name}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

# Falco IRSA — minimal (optional CloudWatch export)
module "falco_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "${var.cluster_name}-falco"

  role_policy_arns = {
    falco = aws_iam_policy.falco.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["falco:falco"]
    }
  }

  tags = var.tags
}

# external-dns IRSA — Route 53 records for platform Ingress hostnames.
module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "${var.cluster_name}-external-dns"

  attach_external_dns_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  tags = var.tags
}

resource "aws_iam_policy" "falco" {
  name_prefix = "${var.cluster_name}-falco-"
  description = "Minimal Falco IRSA policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "Falco"
          }
        }
      },
    ]
  })

  tags = var.tags
}
