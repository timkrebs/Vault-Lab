# GitHub Actions Workflow Fixes

This document addresses the two main issues preventing the GitHub Actions workflow from running successfully.

## Issues Identified

1. **Deprecated set-output command**: The workflow uses deprecated GitHub Actions syntax
2. **Terraform Exit Code 3**: Configuration errors in Terraform files

## ✅ **Fixes Applied**

### 1. Updated Terraform Configuration

**Problem**: The user_data script expected `/tmp/vault.hcl` to exist but there was no mechanism to copy it to instances.

**Solution**: Modified the launch template to pass the vault configuration as a base64-encoded variable:

```hcl
# In terraform/main.tf - Launch Template user_data
user_data = base64encode(templatefile("${path.module}/../scripts/user_data.sh", {
  vault_cluster_size = var.vault_cluster_size
  environment       = var.environment
  kms_key_id        = aws_kms_key.vault.key_id
  aws_region        = var.aws_region
  vault_config      = base64encode(file("${path.module}/../files/vault.hcl"))  # NEW
}))
```

**Updated user_data script** to decode and use the configuration:

```bash
# Template variables from Terraform
VAULT_CONFIG_B64="${vault_config}"

# Create vault configuration from template
echo "$VAULT_CONFIG_B64" | base64 -d > /tmp/vault.hcl
sudo cp /tmp/vault.hcl /etc/vault.d/vault.hcl
```

### 2. Added Terraform Variables Example

**Problem**: Missing or misconfigured variables could cause Terraform failures.

**Solution**: Created `terraform/terraform.tfvars.example` with all required variables:

```hcl
# Copy this file to terraform.tfvars and customize
aws_region = "us-east-1"
vpc_id     = "vpc-your-vpc-id"
subnet_ids = ["subnet-1", "subnet-2"]
enable_public_access = true
# ... and more
```

### 3. Improved GitHub Actions Workflow

**Problem**: Deprecated `set-output` commands and old action versions.

**Solution**: Updated workflow with:
- Latest action versions (hashicorp/setup-terraform@v2)
- Added terraform validation step
- Better error handling

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v2  # Updated from v1
  with:
    cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}

- name: Terraform Validate  # NEW
  run: terraform validate
```

## 🔧 **Manual Fixes Required**

### Fix 1: Update Terraform Action Version

If you encounter action resolution issues, update the workflow manually:

```yaml
# In .github/workflows/terraform.yml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v2  # Use v2 instead of v1
  with:
    cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
```

### Fix 2: Create terraform.tfvars

Copy the example file and customize:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Required variables to update**:
- `vpc_id`: Your AWS VPC ID
- `subnet_ids`: Your subnet IDs (at least 2 in different AZs)
- `allowed_cidr_blocks`: IP ranges allowed to access Vault
- `admin_cidr_blocks`: IP ranges allowed SSH access

### Fix 3: Ensure Vault AMI Exists

The configuration expects a Vault AMI with name pattern `vault-amazonlinux2-vault*`. 

**Option A**: Build the AMI using Packer:
```bash
packer build vault.pkr.hcl
```

**Option B**: Use a standard AMI and install Vault via user_data:
```hcl
# In terraform/main.tf, replace the data source:
data "aws_ami" "vault" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

## 🚀 **Quick Fix Commands**

1. **Update the workflow**:
```bash
# Manual edit to .github/workflows/terraform.yml
# Change hashicorp/setup-terraform@v1 to @v2
```

2. **Configure variables**:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS settings
```

3. **Test locally**:
```bash
cd terraform
terraform init
terraform validate
terraform plan
```

## 📋 **Verification Steps**

After applying fixes:

1. **Check workflow syntax**:
   - Push changes to a feature branch
   - Create a pull request
   - Verify GitHub Actions runs without syntax errors

2. **Validate Terraform**:
   ```bash
   cd terraform
   terraform init
   terraform validate  # Should pass
   terraform plan      # Should show valid plan
   ```

3. **Deploy and test**:
   ```bash
   # After merging to main, check outputs:
   terraform output
   
   # Test Vault connectivity:
   curl http://$(terraform output -raw vault_load_balancer_dns):8200/v1/sys/health
   ```

## 🔒 **Security Recommendations**

For production deployment:

```hcl
# In terraform.tfvars
enable_public_access = false  # Use private ALB
allowed_cidr_blocks  = ["10.0.0.0/8"]  # Internal network only  
admin_cidr_blocks    = ["192.168.1.0/24"]  # Specific admin subnet
```

## 📞 **Troubleshooting**

If issues persist:

1. **Check GitHub Actions logs** for specific error messages
2. **Run terraform locally** to isolate configuration issues
3. **Verify AWS credentials** have proper permissions
4. **Check AMI availability** in your region

## 🎯 **Summary**

The main fixes address:
- ✅ Deprecated GitHub Actions syntax
- ✅ Missing vault configuration handling
- ✅ Variable configuration guidance
- ✅ Better error validation

After applying these fixes, the workflow should run successfully and deploy a functional Vault cluster with proper connectivity options. 