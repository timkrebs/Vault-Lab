# Vault Lab - GitHub Actions & Terraform Cloud Integration

This project provides infrastructure-as-code for deploying HashiCorp Vault clusters on AWS using GitHub Actions, Packer (for AMI building), and Terraform with CLI-based deployment and external connectivity options.

## Project Structure

```
Vault-Lab/
├── vault.pkr.hcl           # Packer configuration for Vault AMI
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Input variables
├── versions.tf             # Provider and version constraints
├── outputs.tf              # Output values
├── files/                  # Vault configuration files
│   ├── vault.hcl          # Main Vault configuration
│   ├── vault.service      # Systemd service file
│   └── vault_int_storage.hcl # Alternative storage config
└── scripts/
    ├── login.sh           # HCP/AWS authentication script
    └── user_data.sh       # EC2 instance startup script
```

## Prerequisites

1. **HCP Terraform Account**: Sign up at [app.terraform.io](https://app.terraform.io)
2. **AWS Account**: With appropriate permissions for EC2, VPC, IAM, KMS
3. **Git Repository**: Push this code to a Git repository (GitHub, GitLab, etc.)
4. **Tools**:
   - Terraform CLI (>= 1.0)
   - Packer
   - AWS CLI configured
   - `doormat` (for AWS credential management)

## Setup Instructions

### 1. Configure HCP Terraform

1. **Update `versions.tf`**:
   ```hcl
   cloud {
     organization = "your-org-name"  # Replace with your HCP Terraform organization
     
     workspaces {
       name = "vault-lab"  # Choose your workspace name
     }
   }
   ```

2. **Create HCP Terraform Workspace**:
   - Go to [app.terraform.io](https://app.terraform.io)
   - Create a new workspace
   - Choose "Version control workflow"
   - Connect your Git repository
   - Select this directory as the working directory

### 2. Configure Variables in HCP Terraform

Set these variables in your HCP Terraform workspace:

#### Terraform Variables
- `aws_region`: AWS region (default: "us-east-1")
- `vpc_id`: Your VPC ID (update default in variables.tf)
- `subnet_id`: Your subnet ID (update default in variables.tf)
- `environment`: Environment name (dev/staging/prod)
- `vault_cluster_size`: Number of Vault nodes (default: 3)

#### Environment Variables
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `AWS_SESSION_TOKEN`: AWS session token (if using temporary credentials)

### 3. Build Vault AMI (One-time setup)

Before running Terraform, build your Vault AMI. Packer will automatically download the Vault binary during the build process:

```bash
# Authenticate with AWS
./scripts/login.sh

# Build the Vault AMI (downloads Vault binary automatically)
packer build vault.pkr.hcl

# Optional: Specify a different Vault version
packer build -var 'vault_version=1.20.0' vault.pkr.hcl
```

### 4. Deploy Infrastructure

#### Option A: Via HCP Terraform UI
1. Go to your workspace in HCP Terraform
2. Click "Queue plan"
3. Review the plan
4. Apply the changes

#### Option B: Via Terraform CLI
```bash
# Login to HCP Terraform
terraform login

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the changes
terraform apply
```

### 5. Verify Deployment

After successful deployment:

1. **Check Vault URL**: Use the `vault_url` output to access Vault
2. **Initialize Vault**: 
   ```bash
   export VAULT_ADDR="http://[load-balancer-dns]:8200"
   vault operator init
   ```
3. **Unseal Vault**: Use the unseal keys from initialization

## Key Features

- **GitHub Actions CI/CD**: Automated deployment pipeline with Terraform
- **External Connectivity**: Configurable public/private access to Vault
- **Auto-Initialization**: Automatic Vault initialization with secure credential storage
- **High Availability**: Multi-node Vault cluster with Raft storage
- **Auto Scaling**: EC2 Auto Scaling Group maintains desired cluster size
- **Load Balancing**: Application Load Balancer for Vault API access
- **KMS Auto-Unseal**: Automatic unsealing using AWS KMS
- **Security**: Security groups, IAM roles, and configurable access controls
- **Monitoring**: Health checks and auto-recovery

## 🚨 Common Setup Questions

### **GitHub Actions Issues?**
If you're experiencing workflow failures, see **[GITHUB-ACTIONS-FIXES.md](GITHUB-ACTIONS-FIXES.md)** for solutions to:
- Deprecated `set-output` command errors  
- Terraform exit code 3 issues
- Action version compatibility problems

### **AWS Credentials in HCP Terraform?**
If your AWS credentials are in HCP Terraform and you don't want to duplicate them in GitHub, see **[TERRAFORM-CLOUD-CREDENTIALS.md](TERRAFORM-CLOUD-CREDENTIALS.md)** for the solution using remote operations.

### **Terraform Template Variable Issues?**
If you're getting "vars map does not contain key" errors, see **[TEMPLATEFILE-VARIABLE-FIX.md](TEMPLATEFILE-VARIABLE-FIX.md)** for the solution to template variable escaping.

## 🚀 Quick Start with GitHub Actions

1. **Fork this repository**
2. **Set up Terraform Cloud**:
   - Create organization and workspace
   - Add AWS credentials as environment variables
3. **Add GitHub secret**: `TF_API_TOKEN` (from Terraform Cloud)
4. **Configure variables**: Copy `terraform/terraform.tfvars.example` to `terraform.tfvars`
5. **Push to main branch** - automatic deployment starts!

### Accessing Your Deployed Vault

```bash
# Get outputs after deployment
cd terraform && terraform output

# Retrieve root token
ROOT_TOKEN=$(aws ssm get-parameter --region us-east-1 --name "/vault/dev/root-token" --with-decryption --query 'Parameter.Value' --output text)

# Connect to Vault
export VAULT_ADDR="http://your-alb-dns:8200"
export VAULT_TOKEN="$ROOT_TOKEN"
vault status
```

## Vault Configuration

The Vault configuration includes:
- **Raft Storage**: Integrated storage for high availability
- **AWS KMS Auto-unsealing**: Automatic unsealing using AWS KMS
- **Auto-join**: Automatic cluster formation using AWS EC2 tags
- **API Access**: Load balancer endpoint for Vault API

## Customization

### Adding More Environments

1. Create new `.tfvars` files for each environment
2. Set up separate HCP Terraform workspaces for each environment
3. Use workspace-specific variable sets

### Scaling the Cluster

Modify the `vault_cluster_size` variable to scale up/down the number of Vault nodes.

### Security Enhancements

- Enable TLS in Vault configuration
- Restrict security group access
- Use dedicated KMS keys
- Implement proper backup strategies

## Troubleshooting

### Common Issues

1. **AMI Not Found**: Ensure Packer build completed successfully
2. **AWS Credentials**: Verify AWS credentials are set in HCP Terraform
3. **VPC/Subnet**: Ensure VPC and subnet IDs are correct
4. **Permissions**: Check IAM permissions for EC2, KMS, and VPC access

### Useful Commands

```bash
# Check Vault status
vault status

# View Vault logs
sudo journalctl -u vault -f

# Check auto scaling group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names vault-lab-vault-asg
```

## Security Considerations

- Store Vault root token and unseal keys securely
- Enable audit logging
- Regular security updates
- Network segmentation
- Monitor access patterns

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test
4. Submit a pull request

## License

This project is licensed under the MIT License.
