# Vault Lab Environment - Deployment Guide

This guide explains how to deploy and connect to the Vault lab environment using GitHub Actions and Terraform CLI.

## Overview

This lab environment has been updated to provide:

- **External Connectivity**: Optional public access to Vault instances
- **GitHub Actions Workflow**: Automated CI/CD pipeline for infrastructure deployment
- **CLI-based Deployment**: Uses Terraform Cloud remote backend instead of VCS workflow
- **Auto-Unseal**: KMS-based auto-unsealing for Vault
- **Secure Initialization**: Root tokens and unseal keys stored in AWS Systems Manager Parameter Store

## Prerequisites

1. **GitHub Repository**: Fork or clone this repository
2. **Terraform Cloud Account**: Sign up at [app.terraform.io](https://app.terraform.io)
3. **AWS Account**: With appropriate permissions for EC2, VPC, KMS, and SSM
4. **Vault AMI**: Build the Vault AMI using the provided Packer configuration

## Setup Instructions

### 1. Terraform Cloud Setup

1. **Create Organization**: Create or use existing Terraform Cloud organization
2. **Create Workspace**: Create a new CLI-driven workspace named `vault-lab`
3. **Configure Variables**: Add the following environment variables in your workspace:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key (mark as sensitive)
   - `AWS_SESSION_TOKEN`: If using temporary credentials (mark as sensitive)

### 2. GitHub Secrets Setup

Add the following secrets to your GitHub repository:

1. **TF_API_TOKEN**: 
   - Go to Terraform Cloud → User Settings → Tokens
   - Create a new API token
   - Add it as a GitHub secret named `TF_API_TOKEN`

### 3. Configuration

1. **Update Organization Name**: 
   ```hcl
   # In terraform/versions.tf
   backend "remote" {
     organization = "your-org-name"  # Update this
     workspaces {
       name = "vault-lab"
     }
   }
   ```

2. **Configure Variables** (optional):
   Create `terraform/terraform.tfvars` to customize deployment:
   ```hcl
   # Connectivity options
   enable_public_access = true  # Set to false for private-only access
   allowed_cidr_blocks  = ["0.0.0.0/0"]  # Restrict in production
   admin_cidr_blocks    = ["your.ip.address.here/32"]  # Your IP for SSH
   
   # Infrastructure settings
   vault_cluster_size = 3
   instance_type     = "m5.large"
   environment       = "dev"
   
   # AWS settings
   aws_region = "us-east-1"
   vpc_id     = "vpc-your-vpc-id"
   subnet_ids = ["subnet-1", "subnet-2"]
   ```

## Deployment Process

### Automatic Deployment (Recommended)

1. **Push to Main Branch**: 
   ```bash
   git add .
   git commit -m "Deploy Vault lab environment"
   git push origin main
   ```

2. **Monitor Workflow**: 
   - Go to GitHub Actions tab
   - Watch the Terraform workflow execute
   - Review plan output
   - Terraform apply runs automatically on main branch

### Manual Deployment

1. **Trigger Workflow**: Use GitHub's "Run workflow" button in Actions tab
2. **Local Development**: 
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

## Accessing Vault

### 1. Get Connection Information

After deployment, check the Terraform outputs:

```bash
cd terraform
terraform output
```

Key outputs:
- `vault_url`: Direct access URL to Vault API
- `vault_ui_url`: Web UI access URL
- `vault_initialization_commands`: Commands to get root token

### 2. Retrieve Root Token

```bash
# Set your AWS region
export AWS_REGION=us-east-1

# Get root token
ROOT_TOKEN=$(aws ssm get-parameter \
  --region $AWS_REGION \
  --name "/vault/dev/root-token" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)

echo "Root Token: $ROOT_TOKEN"
```

### 3. Connect to Vault

#### Option A: Vault CLI
```bash
# Set Vault address (use output from terraform)
export VAULT_ADDR="http://your-alb-dns:8200"
export VAULT_TOKEN="$ROOT_TOKEN"

# Test connection
vault status
vault auth list
```

#### Option B: Web UI
1. Navigate to the `vault_ui_url` from terraform output
2. Use the root token to sign in
3. Start configuring your Vault instance

#### Option C: API Access
```bash
# Health check
curl http://your-alb-dns:8200/v1/sys/health

# Authenticated request
curl -H "X-Vault-Token: $ROOT_TOKEN" \
     http://your-alb-dns:8200/v1/sys/mounts
```

## Security Considerations

### Production Deployment

1. **Restrict Access**:
   ```hcl
   enable_public_access = false  # Use private ALB
   allowed_cidr_blocks  = ["10.0.0.0/8"]  # Internal only
   admin_cidr_blocks    = ["192.168.1.0/24"]  # Specific admin subnets
   ```

2. **Root Token Security**:
   - Rotate the root token immediately after setup
   - Create individual user tokens with appropriate policies
   - Never store root tokens in plain text

3. **Network Security**:
   - Use TLS/SSL certificates (requires ALB HTTPS listener)
   - Implement VPN or bastion hosts for access
   - Enable VPC Flow Logs for monitoring

### Emergency Access

If auto-unseal fails, use the backup unseal key:

```bash
# Get unseal key
UNSEAL_KEY=$(aws ssm get-parameter \
  --region $AWS_REGION \
  --name "/vault/dev/unseal-key" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)

# Manually unseal if needed
vault operator unseal $UNSEAL_KEY
```

## Troubleshooting

### Common Issues

1. **Vault Not Accessible**:
   - Check security group rules
   - Verify ALB health checks are passing
   - Check Vault service status on instances

2. **Initialization Failed**:
   - Check CloudWatch logs: `/aws/ec2/vault`
   - SSH to instance and check: `sudo journalctl -u vault`
   - Verify KMS permissions

3. **GitHub Actions Failing**:
   - Verify `TF_API_TOKEN` secret is set
   - Check Terraform Cloud workspace permissions
   - Ensure AWS credentials are properly configured

### Useful Commands

```bash
# Check Vault cluster status
vault operator raft list-peers

# View Vault logs on instance
sudo journalctl -u vault -f

# Check health endpoint
curl http://your-alb-dns:8200/v1/sys/health?standbyok=true

# List AWS SSM parameters
aws ssm describe-parameters --filters "Key=Name,Values=/vault/"
```

## Cleanup

To destroy the infrastructure:

1. **Via GitHub Actions**: Delete the workspace in Terraform Cloud (triggers destroy)
2. **Manually**:
   ```bash
   cd terraform
   terraform destroy
   ```

3. **Clean up secrets**:
   ```bash
   aws ssm delete-parameter --name "/vault/dev/root-token"
   aws ssm delete-parameter --name "/vault/dev/unseal-key"
   ```

## Next Steps

1. **Configure Authentication**: Set up AWS auth, LDAP, or other auth methods
2. **Create Policies**: Implement least-privilege access policies
3. **Enable Audit Logging**: Configure audit devices for compliance
4. **Set up Monitoring**: Implement CloudWatch or Prometheus monitoring
5. **Configure Backups**: Set up automated Raft snapshot backups

## Support

- **Vault Documentation**: [https://www.vaultproject.io/docs](https://www.vaultproject.io/docs)
- **Terraform Cloud Docs**: [https://www.terraform.io/cloud-docs](https://www.terraform.io/cloud-docs)
- **GitHub Actions Docs**: [https://docs.github.com/en/actions](https://docs.github.com/en/actions) 