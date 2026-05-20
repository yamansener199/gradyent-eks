variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "eks_version" {
  type    = string
  default = "1.35"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "intra_subnet_ids" {
  type = list(string)
}

variable "cluster_encryption_key" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "bootstrap_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "bootstrap_desired_size" {
  type    = number
  default = 2
}

variable "bootstrap_min_size" {
  type    = number
  default = 2
}

variable "bootstrap_max_size" {
  type    = number
  default = 3
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Public Kubernetes API (disable for private-only; use SSM bastion in VPC)"
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed when public endpoint is enabled"
  default     = []
}
