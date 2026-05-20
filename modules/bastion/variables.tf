variable "cluster_name" {
  type = string
}

variable "eks_version" {
  type        = string
  description = "EKS/kubernetes version for kubectl binary"
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type        = string
  description = "Private subnet for the bastion instance"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "tags" {
  type    = map(string)
  default = {}
}
