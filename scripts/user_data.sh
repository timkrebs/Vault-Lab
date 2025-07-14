#!/bin/bash

# Set up logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Vault configuration..."

# Copy vault configuration files
sudo cp /tmp/vault.hcl /etc/vault.d/vault.hcl
sudo chown vault:vault /etc/vault.d/vault.hcl
sudo chmod 640 /etc/vault.d/vault.hcl

# Create vault data directory
sudo mkdir -p /opt/vault/data
sudo chown vault:vault /opt/vault/data

# Enable and start vault service
sudo systemctl enable vault
sudo systemctl start vault

echo "Vault configuration completed." 