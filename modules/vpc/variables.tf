variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-central-1"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name for subnet tagging"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "az_count" {
  type        = number
  description = "Number of availability zones"
  default     = 3
}

variable "tags" {
  type        = map(string)
  description = "Common resource tags"
  default     = {}
}
