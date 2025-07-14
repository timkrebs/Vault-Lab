policy "cost-management" {
  source = "./cost-management.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "auto-delete-ttl" {
  source = "./auto-delete-ttl.sentinel"
  enforcement_level = "soft-mandatory"
} 