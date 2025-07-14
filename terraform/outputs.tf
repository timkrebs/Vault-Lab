output "vault_load_balancer_dns" {
  description = "DNS name of the Vault load balancer"
  value       = aws_lb.vault.dns_name
}

output "vault_url" {
  description = "URL to access Vault"
  value       = var.enable_public_access ? "http://${aws_lb.vault.dns_name}:${var.vault_port}" : "http://${aws_lb.vault.dns_name}:${var.vault_port}"
}

output "vault_ui_url" {
  description = "URL to access Vault UI"
  value       = var.enable_public_access ? "http://${aws_lb.vault.dns_name}:${var.vault_port}/ui" : "http://${aws_lb.vault.dns_name}:${var.vault_port}/ui"
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

# New connectivity outputs
output "vault_access_type" {
  description = "Type of access configured (public or private)"
  value       = var.enable_public_access ? "public" : "private"
}

output "vault_kms_key_id" {
  description = "KMS key ID used for Vault auto-unseal"
  value       = aws_kms_key.vault.key_id
}

output "vault_kms_key_arn" {
  description = "KMS key ARN used for Vault auto-unseal"
  value       = aws_kms_key.vault.arn
}

output "vault_root_token_parameter" {
  description = "AWS Systems Manager parameter name for Vault root token"
  value       = "/vault/${var.environment}/root-token"
}

output "vault_unseal_key_parameter" {
  description = "AWS Systems Manager parameter name for Vault unseal key"
  value       = "/vault/${var.environment}/unseal-key"
}

output "vault_initialization_commands" {
  description = "Commands to retrieve Vault initialization data"
  value = <<-EOT
    # Retrieve root token (requires AWS CLI and appropriate IAM permissions):
    aws ssm get-parameter --region ${var.aws_region} --name "/vault/${var.environment}/root-token" --with-decryption --query 'Parameter.Value' --output text

    # Retrieve unseal key (backup, auto-unseal should handle unsealing):
    aws ssm get-parameter --region ${var.aws_region} --name "/vault/${var.environment}/unseal-key" --with-decryption --query 'Parameter.Value' --output text

    # Example Vault CLI usage:
    export VAULT_ADDR="${var.enable_public_access ? "http://${aws_lb.vault.dns_name}:${var.vault_port}" : "http://${aws_lb.vault.dns_name}:${var.vault_port}"}"
    export VAULT_TOKEN="$(aws ssm get-parameter --region ${var.aws_region} --name "/vault/${var.environment}/root-token" --with-decryption --query 'Parameter.Value' --output text)"
    vault status
  EOT
}

output "vault_cluster_info" {
  description = "Information about the Vault cluster"
  value = {
    cluster_size    = var.vault_cluster_size
    environment     = var.environment
    project_name    = var.project_name
    aws_region      = var.aws_region
    auto_unseal     = "KMS"
    public_access   = var.enable_public_access
    allowed_cidrs   = var.allowed_cidr_blocks
  }
} 