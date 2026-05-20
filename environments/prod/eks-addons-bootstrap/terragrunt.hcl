include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/eks-addons-bootstrap.hcl"
}

dependency "eks" {
  config_path = "../eks-cluster"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    cluster_name                       = "gradyent-prod"
    cluster_endpoint                   = "https://mock.eks.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    cluster_version                    = "1.31"
    oidc_provider_arn                  = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/MOCK"
    irsa_map = {
      karpenter_controller_role_arn              = "arn:aws:iam::123456789012:role/mock-karpenter-controller"
      karpenter_node_role_name                   = "gradyent-prod-karpenter-node"
      karpenter_interruption_queue_name          = "gradyent-prod-karpenter"
      fluentd_role_arn                           = "arn:aws:iam::123456789012:role/mock-fluentd"
      falco_role_arn                             = "arn:aws:iam::123456789012:role/mock-falco"
      aws_load_balancer_controller_role_arn      = "arn:aws:iam::123456789012:role/mock-aws-lbc"
      external_dns_role_arn                      = "arn:aws:iam::123456789012:role/mock-external-dns"
      cluster_name                               = "gradyent-prod"
      aws_region                                 = "eu-central-1"
      vpc_id                                     = "vpc-mock"
    }
  }
}

inputs = {
  platform_domain                    = include.env.locals.platform_domain
  aws_region                         = include.region.locals.aws_region
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  cluster_version                    = dependency.eks.outputs.cluster_version
  irsa_map                           = dependency.eks.outputs.irsa_map
  gitops_repo_url                    = include.env.locals.gitops_repo_url
  gitops_revision                    = include.env.locals.gitops_revision
  gitops_repo_root                   = dirname(find_in_parent_folders("root.hcl"))
  bootstrap_platform_on_apply        = true
  require_git_repo_access            = true
  platform_sync_timeout_seconds      = 2400
}
