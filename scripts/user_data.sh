#!/bin/bash

# Set up logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Vault configuration..."

# Get instance metadata
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
HOSTNAME=$(hostname)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Template variables from Terraform
VAULT_CLUSTER_SIZE=${vault_cluster_size}
ENVIRONMENT=${environment}
KMS_KEY_ID=${kms_key_id}
AWS_REGION=${aws_region}

# Create vault configuration from template
sudo cp /tmp/vault.hcl /etc/vault.d/vault.hcl

# Substitute variables in vault config
sudo sed -i "s/\$${AWS_REGION}/$AWS_REGION/g" /etc/vault.d/vault.hcl
sudo sed -i "s/\$${KMS_KEY_ID}/$KMS_KEY_ID/g" /etc/vault.d/vault.hcl
sudo sed -i "s/\$${LOCAL_IP}/$LOCAL_IP/g" /etc/vault.d/vault.hcl
sudo sed -i "s/\$${HOSTNAME}/$HOSTNAME/g" /etc/vault.d/vault.hcl
sudo sed -i "s/\$${ENVIRONMENT}/$ENVIRONMENT/g" /etc/vault.d/vault.hcl

# Set proper ownership and permissions
sudo chown vault:vault /etc/vault.d/vault.hcl
sudo chmod 640 /etc/vault.d/vault.hcl

# Create vault data directory
sudo mkdir -p /opt/vault/data
sudo chown vault:vault /opt/vault/data

# Enable and start vault service
sudo systemctl enable vault
sudo systemctl start vault

# Wait for Vault to start
sleep 30

# Check if this is the first node to initialize the cluster
VAULT_STATUS=""
for i in {1..10}; do
    VAULT_STATUS=$(vault status -format=json 2>/dev/null | jq -r '.initialized' 2>/dev/null)
    if [ "$VAULT_STATUS" != "null" ]; then
        break
    fi
    echo "Waiting for Vault to start... attempt $i"
    sleep 10
done

# Initialize Vault if not already initialized
if [ "$VAULT_STATUS" = "false" ] || [ "$VAULT_STATUS" = "" ]; then
    echo "Initializing Vault cluster..."
    
    # Initialize with 1 key share and threshold (since we're using auto-unseal)
    INIT_OUTPUT=$(vault operator init -key-shares=1 -key-threshold=1 -format=json 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "Vault initialized successfully"
        
        # Store initialization data in AWS Systems Manager Parameter Store
        ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')
        UNSEAL_KEY=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')
        
        # Store root token (encrypted)
        aws ssm put-parameter \
            --region $AWS_REGION \
            --name "/vault/$ENVIRONMENT/root-token" \
            --value "$ROOT_TOKEN" \
            --type "SecureString" \
            --description "Vault root token for $ENVIRONMENT environment" \
            --overwrite
        
        # Store unseal key (encrypted) - backup in case auto-unseal fails
        aws ssm put-parameter \
            --region $AWS_REGION \
            --name "/vault/$ENVIRONMENT/unseal-key" \
            --value "$UNSEAL_KEY" \
            --type "SecureString" \
            --description "Vault unseal key for $ENVIRONMENT environment" \
            --overwrite
        
        echo "Vault initialization data stored in AWS Systems Manager Parameter Store"
        echo "Root token parameter: /vault/$ENVIRONMENT/root-token"
        echo "Unseal key parameter: /vault/$ENVIRONMENT/unseal-key"
    else
        echo "Failed to initialize Vault"
    fi
fi

echo "Vault configuration completed." 