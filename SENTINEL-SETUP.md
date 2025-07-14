# Sentinel Policies & Auto-Delete Setup Guide

This guide explains how to set up cost-saving Sentinel policies and automated resource deletion for your HCP Terraform workspace.

## 🛡️ **What's Included**

### **Cost Management Policy**
- ✅ **Instance Type Limits**: Prevents expensive instance types
- ✅ **Cost Thresholds**: Blocks resources exceeding $5/hour
- ✅ **Resource Warnings**: Alerts about expensive services (RDS, NAT Gateway)
- ✅ **Enforcement**: Hard-mandatory (blocks deployment)

### **Auto-Delete TTL Policy**
- ✅ **TTL Tags**: Enforces time-to-live tags on all resources
- ✅ **Format Validation**: Supports `24h`, `7d`, `168h` formats
- ✅ **Max TTL**: Limits resources to 7 days maximum
- ✅ **Enforcement**: Soft-mandatory (warnings, can be overridden)

### **Automated Cleanup**
- ✅ **Scheduled Checks**: Runs every 6 hours via GitLab CI/CD
- ✅ **Automatic Deletion**: Destroys expired resources via HCP Terraform API
- ✅ **Dry Run Mode**: Test without actually deleting resources
- ✅ **Manual Trigger**: Run cleanup on-demand

## 🚀 **Setup Instructions**

### **Step 1: Upload Policies to HCP Terraform**

1. **Create a Policy Set** in HCP Terraform:
   - Go to your organization settings
   - Navigate to "Policy Sets"
   - Click "New policy set"
   - Choose "Upload policy set"

2. **Upload the Policies**:
   ```bash
   # Create a zip file with your policies
   cd sentinel-policies
   zip -r vault-lab-policies.zip *.sentinel *.hcl
   ```
   
   Upload `vault-lab-policies.zip` to HCP Terraform

3. **Configure Policy Set**:
   - **Name**: `vault-lab-cost-and-ttl-policies`
   - **Description**: `Cost management and auto-delete policies for Vault Lab`
   - **Scope**: Select your `vault-lab` workspace
   - **Enforcement**: Leave as configured in `sentinel.hcl`

### **Step 2: Update Your Terraform Configuration**

Add these variables to your HCP Terraform workspace:

```hcl
# New TTL-related variables
resource_ttl = "24h"        # Default: 24 hours
additional_tags = {}        # Optional additional tags
```

### **Step 3: Set Up GitLab CI/CD Automation**

1. **Add GitLab CI/CD Variables**:
   - Go to your project → Settings → CI/CD → Variables
   - Add these **protected** and **masked** variables:
     - `TF_API_TOKEN`: Your HCP Terraform API token
     - `AWS_ACCESS_KEY_ID`: AWS access key (same as HCP Terraform)
     - `AWS_SECRET_ACCESS_KEY`: AWS secret key (same as HCP Terraform)

2. **Create HCP Terraform API Token**:
   ```bash
   # In HCP Terraform: User Settings > Tokens > Create API token
   # Add as GitLab CI/CD variable: TF_API_TOKEN
   ```

3. **Set Up Pipeline Schedule** (Optional):
   - Go to your project → CI/CD → Schedules
   - Click "New schedule"
   - Set interval: `0 */6 * * *` (every 6 hours)
   - Description: "Auto-delete expired AWS resources"
   - Target branch: `main`

### **Step 4: Test the Setup**

1. **Test Cost Policy**:
   ```bash
   # Try deploying with an expensive instance type
   vault_cluster_size = 1
   instance_type = "m5.4xlarge"  # This should be blocked
   ```

2. **Test TTL Policy**:
   ```bash
   # Deploy without TTL tags - should show warnings
   terraform plan
   ```

3. **Test Auto-Delete** (Dry Run):
   - Go to your project → CI/CD → Pipelines
   - Click "Run pipeline"
   - Add variable: `DRY_RUN = true`
   - Click "Run pipeline"

## 📋 **Resource TTL Tag Examples**

### **Required Tags for All Resources**:
```hcl
tags = {
  ttl        = "24h"                    # Required: Time to live
  created_at = "2024-07-11T10:30:00Z"   # Auto-generated
  auto_delete = "true"                  # Marks for auto-deletion
  owner      = "terraform"              # Resource owner
  environment = "dev"                   # Environment
}
```

### **TTL Format Examples**:
- `ttl = "1h"` - 1 hour
- `ttl = "24h"` - 24 hours (1 day)
- `ttl = "7d"` - 7 days (converted to 168h)
- `ttl = "30m"` - 30 minutes

### **Maximum TTL**: 168 hours (7 days)

## ⚙️ **Configuration Options**

### **Cost Policy Customization**:
Edit `sentinel-policies/cost-management.sentinel`:
```hcl
max_monthly_cost = 200.0     # Increase budget limit
max_hourly_cost = 10.0       # Increase hourly limit

# Add/remove allowed instance types
allowed_instance_types = [
    "t3.nano", "t3.micro", "t3.small", 
    "t3.medium", "t3.large", "m5.large",
    "m5.xlarge"  # Add larger instances if needed
]
```

### **TTL Policy Customization**:
Edit `sentinel-policies/auto-delete-ttl.sentinel`:
```hcl
default_ttl_hours = 48       # Change default TTL
max_ttl_hours = 336          # Change max TTL (14 days)
```

### **Automation Schedule**:
Edit pipeline schedule in GitLab:
- Go to CI/CD → Schedules
- Edit existing schedule
- Change interval to `0 */12 * * *` (every 12 hours)

## 🔥 **Manual Resource Cleanup**

### **HCP Terraform UI Method**:
1. Go to workspace → Settings → Destruction and Deletion
2. Click "Queue destroy plan"
3. Review and apply

### **GitLab CI/CD Method**:
1. Go to CI/CD → Pipelines
2. Click "Run pipeline"
3. Remove `DRY_RUN` variable (or set to `false`)
4. Click "Run pipeline"

### **Command Line Method**:
```bash
cd terraform
terraform login
terraform destroy
```

## 🛡️ **Safety Features**

### **Cost Policy** (Hard-Mandatory):
- ❌ **Blocks deployment** of expensive resources
- ❌ **Cannot be overridden** without policy changes
- ✅ **Protects against** accidental expensive deployments

### **TTL Policy** (Soft-Mandatory):
- ⚠️ **Shows warnings** for missing TTL tags
- ✅ **Can be overridden** by workspace admins
- ✅ **Educates users** about proper tagging

### **Auto-Delete Safeguards**:
- 🔍 **Dry run by default** on scheduled runs
- 📝 **Detailed logging** of all actions
- ⏰ **Grace period** before deletion
- 🚫 **Manual approval** option (configurable)

## 📊 **Monitoring & Alerts**

### **Cost Monitoring**:
- Monitor policy violations in HCP Terraform run logs
- Set up AWS Cost Explorer alerts for budget overruns
- Review monthly AWS bills for unexpected charges

### **Auto-Delete Monitoring**:
- GitLab CI/CD pipeline logs show all delete operations
- AWS CloudTrail logs track resource deletions
- Set up Slack/email notifications for GitLab CI/CD (Project → Settings → Integrations)

## 🚨 **Troubleshooting**

### **Policy Violations**:
```bash
# If cost policy blocks deployment:
# 1. Check instance types in terraform/variables.tf
# 2. Use smaller instance types (t3.small, t3.medium)
# 3. Contact admin to adjust policy limits

# If TTL policy shows warnings:
# 1. Add TTL tags to your resources
# 2. Use format: ttl = "24h"
# 3. Ensure created_at is auto-generated
```

### **Auto-Delete Issues**:
```bash
# If automation doesn't run:
# 1. Check GitLab CI/CD is enabled
# 2. Verify variables are set correctly in CI/CD settings
# 3. Check HCP Terraform API permissions
# 4. Verify pipeline schedule is active

# If resources aren't deleted:
# 1. Verify TTL tags are present and formatted correctly
# 2. Check if resources have actually expired
# 3. Run manual dry-run to test logic
```

### **Common Fixes**:
```bash
# Check GitLab CI/CD variable configuration:
# 1. Go to Project → Settings → CI/CD → Variables
# 2. Ensure TF_API_TOKEN is protected and masked
# 3. Verify AWS credentials are correctly set

# Fix HCP Terraform permissions:
# Ensure API token has workspace admin permissions
```

## 💰 **Expected Cost Savings**

### **With Cost Policies**:
- 🚫 **Blocks expensive instances**: Saves $100-500/month
- ⚠️ **Warns about expensive services**: Prevents RDS ($50-200/month)
- ✅ **Enforces small instances**: Keeps costs under $50/month

### **With Auto-Delete**:
- ⏰ **24h TTL**: Saves 90%+ on dev resources
- 🧹 **Automatic cleanup**: No forgotten resources
- 📉 **Predictable costs**: Resources can't run indefinitely

### **Total Potential Savings**: $200-800/month for typical dev environments

## 🎯 **Next Steps**

1. ✅ Deploy policies to HCP Terraform
2. ✅ Set up GitLab CI/CD automation
3. ✅ Test with a small deployment
4. ✅ Monitor costs and adjust policies as needed
5. ✅ Train team on TTL tagging requirements

Your infrastructure is now protected against cost overruns and resource sprawl! 🚀 