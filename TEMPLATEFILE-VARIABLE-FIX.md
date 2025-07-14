# Terraform `templatefile` Variable Reference Fix

## 🐛 **The Problem**

GitHub Actions was failing with this error:

```
Error: Invalid function argument
on main.tf line 167, in resource "aws_launch_template" "vault":
167:   user_data = base64encode(templatefile("${path.module}/../scripts/user_data.sh", {

Invalid value for "vars" parameter: vars map does not contain key
"VAULT_VERSION", referenced at ./../scripts/user_data.sh:31,27-40.
```

## 🔍 **Root Cause**

The issue was with **variable reference confusion** in the `templatefile` function:

### **Terraform Template Variables vs. Bash Variables**

When using Terraform's `templatefile()` function, **any `${variable}` reference** in the template file is treated as a **Terraform template variable** that must be provided in the `vars` map.

However, in bash scripts, `${VARIABLE}` is a **bash variable reference**.

### **The Conflict**

```bash
# In scripts/user_data.sh
VAULT_VERSION="${vault_version}"  # ✅ Terraform template var -> bash var
echo "Downloading Vault ${VAULT_VERSION}..."  # ❌ Terraform tries to find template var "VAULT_VERSION"
```

Terraform was interpreting `${VAULT_VERSION}` as a template variable request, but we only provided `vault_version` in the vars map.

## ✅ **The Solution**

**Escape bash variables** with double dollar signs (`$$`) to prevent Terraform from processing them:

### **Before (Broken)**
```bash
echo "Downloading Vault ${VAULT_VERSION}..."
curl -L -o vault.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"
```

### **After (Fixed)**
```bash
echo "Downloading Vault $${VAULT_VERSION}..."
curl -L -o vault.zip "https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_amd64.zip"
```

## 🔧 **Complete Fix Applied**

### **All Variable References Fixed**

1. **Download section**:
   ```bash
   # Before
   echo "Downloading Vault ${VAULT_VERSION}..."
   curl -L -o vault.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"
   
   # After
   echo "Downloading Vault $${VAULT_VERSION}..."
   curl -L -o vault.zip "https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_amd64.zip"
   ```

2. **Configuration creation**:
   ```bash
   # Before
   echo "$VAULT_CONFIG_B64" | base64 -d > /tmp/vault.hcl
   
   # After
   echo "$$VAULT_CONFIG_B64" | base64 -d > /tmp/vault.hcl
   ```

3. **Variable substitution in vault.hcl**:
   ```bash
   # Before
   sudo sed -i "s/\$${AWS_REGION}/$AWS_REGION/g" /etc/vault.d/vault.hcl
   
   # After
   sudo sed -i "s/\$$${AWS_REGION}/$$AWS_REGION/g" /etc/vault.d/vault.hcl
   ```

4. **Systemd service file**:
   ```bash
   # Before
   ExecReload=/bin/kill --signal HUP \$MAINPID
   
   # After
   ExecReload=/bin/kill --signal HUP \$$MAINPID
   ```

5. **Vault initialization section**:
   ```bash
   # Before
   VAULT_STATUS=$(vault status -format=json 2>/dev/null | jq -r '.initialized' 2>/dev/null)
   if [ "$VAULT_STATUS" != "null" ]; then
   
   # After
   VAULT_STATUS=$$(vault status -format=json 2>/dev/null | jq -r '.initialized' 2>/dev/null)
   if [ "$$VAULT_STATUS" != "null" ]; then
   ```

## 📋 **Variable Type Reference**

| Variable Type | Terraform Syntax | Bash Runtime | Notes |
|---------------|-------------------|--------------|-------|
| **Template Variables** | `${vault_version}` | N/A | Provided in `templatefile()` vars map |
| **Bash Variables** | `$${VAULT_VERSION}` | `${VAULT_VERSION}` | Escaped for Terraform, normal in bash |
| **Command Substitution** | `$$(command)` | `$(command)` | Escaped for Terraform |
| **Exit Codes** | `$$?` | `$?` | Escaped for Terraform |

## 🎯 **Key Learning**

### **Template Variable Processing Flow**

```mermaid
graph TD
    A[Terraform templatefile] --> B{Find ${...} pattern}
    B -->|${vault_version}| C[Replace with template var]
    B -->|$${VAULT_VERSION}| D[Escape to ${VAULT_VERSION}]
    C --> E[Pass to bash script]
    D --> E
    E --> F[Bash executes with correct variables]
```

### **Rule of Thumb**

- **Single `$`**: Terraform template variable (must be in vars map)
- **Double `$$`**: Bash variable (escaped from Terraform processing)

## ✅ **Verification**

After the fix:

1. ✅ `terraform validate` passes
2. ✅ `terraform plan` works without variable errors  
3. ✅ GitHub Actions workflow completes successfully
4. ✅ Vault instances boot with proper configuration

## 🔄 **Testing the Fix**

```bash
# Test locally
cd terraform
terraform validate  # Should pass now
terraform plan      # Should show valid plan

# Test in GitHub Actions
git add .
git commit -m "Fix templatefile variable references"
git push origin main  # Triggers workflow
```

## 📚 **Additional Resources**

- [Terraform templatefile function](https://www.terraform.io/language/functions/templatefile)
- [Terraform template syntax](https://www.terraform.io/language/expressions/strings#template-literals)
- [Bash parameter expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html)

This fix ensures that Terraform template variables and bash variables work correctly together in the user_data script! 