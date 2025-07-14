output "vault_load_balancer_dns" {
  description = "DNS name of the Vault load balancer"
  value       = aws_lb.vault.dns_name
}

output "vault_url" {
  description = "URL to access Vault"
  value       = "http://${aws_lb.vault.dns_name}:8200"
}

output "vault_security_group_id" {
  description = "Security group ID for Vault instances"
  value       = aws_security_group.vault.id
}

output "vault_iam_role_arn" {
  description = "ARN of the Vault IAM role"
  value       = aws_iam_role.vault.arn
}

output "vault_ami_id" {
  description = "AMI ID used for Vault instances"
  value       = data.aws_ami.vault.id
} 