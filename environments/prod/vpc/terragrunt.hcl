include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vpc.hcl"
  expose = true
}

inputs = {
  vpc_cidr     = include.env.locals.vpc_cidr
  az_count     = include.env.locals.az_count
  cluster_name = include.env.locals.cluster_name
}
