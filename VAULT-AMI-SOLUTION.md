# Vault AMI Building - Solution Overview

## Question: "Do we build the AMI with Packer in the workflow?"

**Short Answer**: No, we now use a **standard Amazon Linux 2 AMI** and install Vault via user_data for better automation.

## ✅ **Current Solution: Standard AMI + User Data Installation**

We've modified the setup to **eliminate the need for custom AMI building** by:

1. **Using Standard Amazon Linux 2 AMI**: No pre-building required
2. **Installing Vault via User Data**: Automatic installation during instance launch
3. **Streamlined Workflow**: No Packer dependency in GitHub Actions

### **Benefits of This Approach**

- ✅ **Fully Automated**: No manual AMI building steps
- ✅ **Always Latest**: Gets the newest Amazon Linux 2 AMI automatically
- ✅ **Simpler Workflow**: No Packer complexity in CI/CD
- ✅ **Configurable**: Easy to change Vault version
- ✅ **Consistent**: Same installation process every time

### **What Was Changed**

#### **1. AMI Data Source (terraform/main.tf)**
```hcl
# Before: Custom Vault AMI
data "aws_ami" "vault" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["vault-amazonlinux2-vault*"]  # Custom AMI
  }
}

# After: Standard Amazon Linux 2 AMI
data "aws_ami" "vault" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]  # Standard AMI
  }
}
```

#### **2. Enhanced User Data Script (scripts/user_data.sh)**
Now includes:
- ✅ **Vault Installation**: Downloads and installs Vault binary
- ✅ **User Creation**: Creates vault system user
- ✅ **Service Setup**: Creates systemd service file
- ✅ **Directory Structure**: Creates all required directories
- ✅ **Permissions**: Sets proper file ownership and permissions

#### **3. Installation Process**
```bash
# What the user_data script now does:
1. Downloads Vault 1.20.0 from HashiCorp releases
2. Creates vault user and directories
3. Installs vault binary to /usr/local/bin/
4. Creates systemd service file
5. Configures Vault with KMS auto-unseal
6. Starts Vault service automatically
7. Initializes cluster and stores credentials in AWS SSM
```

## 🔄 **Alternative: Packer in GitHub Actions** (Advanced)

If you prefer to build custom AMIs, here's what you'd need to add:

### **Additional GitHub Secrets Required**
```yaml
AWS_ACCESS_KEY_ID: your-aws-access-key
AWS_SECRET_ACCESS_KEY: your-aws-secret-key
AWS_SESSION_TOKEN: your-session-token (if using temp creds)
```

### **Workflow Addition**
```yaml
jobs:
  packer-build:
    name: 'Build Vault AMI'
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
        
    - name: Setup Packer
      run: |
        wget https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
        unzip packer_1.9.4_linux_amd64.zip
        sudo mv packer /usr/local/bin/
        
    - name: Build Vault AMI
      run: packer build vault.pkr.hcl

  terraform:
    needs: [packer-build]
    # ... rest of terraform job
```

### **Pros and Cons of Each Approach**

| Approach | Pros | Cons |
|----------|------|------|
| **Standard AMI + User Data** | ✅ Simple<br/>✅ No AMI management<br/>✅ Always latest OS<br/>✅ Fast workflow | ⚠️ Longer instance boot time<br/>⚠️ Network dependency |
| **Custom AMI + Packer** | ✅ Fast instance boot<br/>✅ Immutable infrastructure<br/>✅ Pre-configured | ❌ Complex workflow<br/>❌ AMI management overhead<br/>❌ Additional AWS costs |

## 🚀 **Recommendation**

**Stick with the current Standard AMI + User Data approach** because:

1. **Simplicity**: No AMI building complexity
2. **Automation**: Fully automated deployment
3. **Maintenance**: No custom AMI lifecycle management
4. **Cost**: No additional AMI storage costs
5. **Flexibility**: Easy to update Vault versions

## 🔧 **If You Need Custom AMIs Later**

The Packer configuration (`vault.pkr.hcl`) is still included in the repository. You can:

1. **Build manually**: `packer build vault.pkr.hcl`
2. **Add to workflow**: Use the advanced example above
3. **Hybrid approach**: Build AMIs periodically, not on every deployment

## 📋 **Current Workflow Summary**

```mermaid
graph LR
    A[Push to main] --> B[GitHub Actions]
    B --> C[Terraform Init/Plan/Apply]
    C --> D[Launch EC2 with Standard AMI]
    D --> E[User Data Installs Vault]
    E --> F[Vault Auto-Initializes]
    F --> G[Ready for Use]
```

**Result**: Fully automated Vault cluster deployment without any manual AMI building steps!

## 🎯 **Key Takeaway**

The current solution **eliminates the AMI building requirement** while maintaining full automation and security. This makes the deployment process simpler and more reliable for users. 