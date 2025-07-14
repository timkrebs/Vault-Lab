terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote backend configuration for Terraform Cloud CLI workflow
  backend "remote" {
    organization = "tim-krebs-org"  # Replace with your Terraform Cloud organization
    
    workspaces {
      name = "vault-lab"  # Replace with your desired workspace name
    }
  }
}

provider "aws" {
  region = var.aws_region
} 