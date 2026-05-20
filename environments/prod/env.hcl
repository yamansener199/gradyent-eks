locals {
  environment  = "prod"
  cluster_name = "gradyent-prod"
  vpc_cidr     = "10.0.0.0/16"
  az_count     = 3
  eks_version  = "1.35"

  # Platform GitOps only (no frontend/backend apps). Must match gitops/bootstrap/repo.env.
  gitops_repo_url = "https://github.com/gradyent/gradyent.ai.git"
  gitops_revision = "main"

  # Public DNS for platform UIs (Route 53 / external DNS). Must match gitops/bootstrap/platform-dns.env.
  platform_domain = "dummy.cool"

  tags = {
    Environment = "prod"
    Project     = "gradyent"
  }
}
