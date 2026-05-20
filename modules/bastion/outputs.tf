output "instance_id" {
  description = "EC2 instance ID for SSM Session Manager"
  value       = aws_instance.bastion.id
}

output "instance_arn" {
  value = aws_instance.bastion.arn
}

output "iam_role_arn" {
  value = aws_iam_role.bastion.arn
}

output "security_group_id" {
  value = aws_security_group.bastion.id
}

output "ssm_start_session_command" {
  description = "Connect with Session Manager (no SSH)"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.aws_region}"
}
