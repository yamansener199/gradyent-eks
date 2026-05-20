include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/eks-cluster.hcl"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id                   = "vpc-mock"
    private_subnet_ids       = ["subnet-private-a", "subnet-private-b", "subnet-private-c"]
    intra_subnet_ids         = ["subnet-intra-a", "subnet-intra-b", "subnet-intra-c"]
    vpc_cidr_block           = "10.0.0.0/16"
    private_route_table_ids  = ["rtb-mock"]
  }
}

dependency "kms" {
  config_path = "../eks-kms"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    key_arn = "arn:aws:kms:eu-central-1:123456789012:key/mock"
    key_id  = "mock-key-id"
  }
}

inputs = {
  vpc_id                   = dependency.vpc.outputs.vpc_id
  private_subnet_ids       = dependency.vpc.outputs.private_subnet_ids
  intra_subnet_ids         = dependency.vpc.outputs.intra_subnet_ids
  vpc_cidr_block           = dependency.vpc.outputs.vpc_cidr_block
  cluster_encryption_key   = dependency.kms.outputs.key_arn
  cluster_name             = include.env.locals.cluster_name
  eks_version              = include.env.locals.eks_version

  # Private API only — kubectl/terraform reach the cluster from the SSM bastion (or VPN).
  cluster_endpoint_public_access       = false
  cluster_endpoint_public_access_cidrs = []
}
