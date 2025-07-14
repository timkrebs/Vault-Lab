storage "raft" {
  path    = "/opt/vault/data"
  node_id = "node-${HOSTNAME}"
  retry_join {
    auto_join = "provider=aws region=${AWS_REGION} tag_key=vault tag_value=${AWS_REGION}"
  }
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = 1
}

seal "awskms" {
  region     = "${AWS_REGION}"
  kms_key_id = "${KMS_KEY_ID}"
}

api_addr     = "http://${LOCAL_IP}:8200"
cluster_addr = "http://${LOCAL_IP}:8201"
cluster_name = "${ENVIRONMENT}-vault-cluster"
ui           = true
log_level    = "INFO"
