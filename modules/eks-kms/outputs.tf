output "key_arn" {
  description = "KMS key ARN for EKS encryption"
  value       = aws_kms_key.eks.arn
}

output "key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.eks.key_id
}
