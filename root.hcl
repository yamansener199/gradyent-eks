# Root Terragrunt configuration — inherited by all live stacks.
locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  aws_region   = local.region_vars.locals.aws_region
  environment  = local.env_vars.locals.environment
  cluster_name = local.env_vars.locals.cluster_name

  common_tags = merge(
    local.env_vars.locals.tags,
    {
      Environment = local.environment
      ManagedBy   = "terragrunt"
      Repository  = "gradyent.ai"
    }
  )

  # Set TG_ACCOUNT_ID for CI/validate when AWS credentials are unavailable.
  account_id = get_env("TG_ACCOUNT_ID", "") != "" ? get_env("TG_ACCOUNT_ID") : get_aws_account_id()
}

# Avoid interactive prompts during apply/destroy (CI and local automation).
terraform {
  extra_arguments "auto_approve" {
    commands  = ["apply", "destroy"]
    arguments = ["-auto-approve"]
  }

  extra_arguments "no_input" {
    commands  = ["apply", "destroy", "plan", "import", "refresh"]
    arguments = ["-input=false"]
  }
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    encrypt        = true
    bucket         = "gradyent-tfstate-${local.account_id}-${local.aws_region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "gradyent-tf-locks"
    s3_bucket_tags = local.common_tags
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"

      default_tags {
        tags = ${jsonencode(local.common_tags)}
      }
    }
  EOF
}

inputs = {
  aws_region   = local.aws_region
  environment  = local.environment
  cluster_name = local.cluster_name
  tags         = local.common_tags
}
