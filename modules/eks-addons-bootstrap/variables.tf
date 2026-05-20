variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type      = string
  sensitive = true
}

variable "cluster_version" {
  type = string
}

variable "irsa_map" {
  type = map(string)
}

variable "gitops_repo_url" {
  type        = string
  description = "Git repository URL for ArgoCD platform apps (must match gitops/bootstrap/repo.env)"
}

variable "gitops_repo_username" {
  type        = string
  default     = null
  description = "Optional Git username for private platform repository"
}

variable "gitops_repo_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Optional Git token/password for private platform repository"
}

variable "gitops_revision" {
  type    = string
  default = "main"
}

variable "gitops_path" {
  type    = string
  default = "gitops/bootstrap"
}

variable "gitops_repo_root" {
  type        = string
  description = "Absolute path to the repository root (contains gitops/). Used to apply bootstrap manifests during terraform apply."
}

variable "bootstrap_platform_on_apply" {
  type        = bool
  default     = true
  description = "When true, run post-apply bootstrap to sync all platform Argo CD Applications from Git."
}

variable "platform_sync_timeout_seconds" {
  type        = number
  default     = 2400
  description = "Max seconds to wait for platform Argo CD Applications to become Synced during bootstrap."
}

variable "require_git_repo_access" {
  type        = bool
  default     = true
  description = "Fail bootstrap if gitops_repo_url is not reachable (recommended: push repo before apply)."
}

variable "argocd_chart_version" {
  type    = string
  default = "8.0.0"
}

variable "cilium_chart_version" {
  type        = string
  description = "Cilium chart version for bootstrap (match gitops/apps/cilium)"
  default     = "1.17.4"
}

variable "platform_domain" {
  type        = string
  description = "Public DNS zone for platform services (e.g. grafana.<domain>, argocd.<domain>)"
}

variable "tags" {
  type    = map(string)
  default = {}
}
