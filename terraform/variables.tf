variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where Vault will be deployed"
  type        = string
  default     = "vpc-0dd7e9c9a5991c3be"
}

variable "subnet_ids" {
  description = "List of subnet IDs for Vault instances (at least 2 in different AZs)"
  type        = list(string)
  default     = ["subnet-081957444ccb77028", "subnet-0960fb8a4d44c769b"]
}

# Keep the old variable for backward compatibility (will be deprecated)
variable "subnet_id" {
  description = "DEPRECATED: Use subnet_ids instead. Single subnet ID (for backward compatibility)"
  type        = string
  default     = "subnet-081957444ccb77028"
}

variable "instance_type" {
  description = "EC2 instance type for Vault servers"
  type        = string
  default     = "m5.large"
}

variable "vault_cluster_size" {
  description = "Number of Vault nodes in the cluster"
  type        = number
  default     = 3
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "vault-lab"
}

variable "resource_ttl" {
  description = "Time to live for resources (format: 24h, 7d, etc.)"
  type        = string
  default     = "24h"
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# New variables for connectivity
variable "enable_public_access" {
  description = "Enable public access to Vault (internet-facing ALB)"
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Vault (use ['0.0.0.0/0'] for public access)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed SSH access to Vault instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}

variable "vault_port" {
  description = "Port for Vault API"
  type        = number
  default     = 8200
}

variable "vault_version" {
  description = "Version of Vault to install"
  type        = string
  default     = "1.20.0"
} 