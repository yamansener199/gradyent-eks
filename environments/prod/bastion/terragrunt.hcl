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
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/bastion.hcl"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-private-a", "subnet-private-b", "subnet-private-c"]
  }
}

dependency "eks" {
  config_path = "../eks-cluster"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    cluster_name    = "gradyent-prod"
    cluster_version = "1.35"
  }
}

inputs = {
  vpc_id        = dependency.vpc.outputs.vpc_id
  subnet_id     = dependency.vpc.outputs.private_subnet_ids[0]
  cluster_name  = dependency.eks.outputs.cluster_name
  eks_version   = dependency.eks.outputs.cluster_version
  aws_region    = include.region.locals.aws_region
}
