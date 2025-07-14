
variable "aws_region" {
  type    = string
  default = "${env("AWS_REGION")}"
}

variable "vault_version" {
  type    = string
  default = "1.20.0"
}

variable "vpc_id" {
  type    = string
  default = "vpc-0dd7e9c9a5991c3be"
}

variable "subnet_id" {
  type    = string
  default = "subnet-081957444ccb77028"
}

data "amazon-ami" "amazon-linux-2" {
  filters = {
    name                = "amzn2-ami-hvm-2.*-x86_64-gp2"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = var.aws_region
}

source "amazon-ebs" "amazon-ebs-amazonlinux-2" {
  ami_description             = "Vault - Amazon Linux 2"
  ami_name                    = "vault-amazonlinux2-vault"
  ami_regions                 = ["us-east-1"]
  ami_virtualization_type     = "hvm"
  associate_public_ip_address = true
  force_delete_snapshot       = true
  force_deregister            = true
  instance_type               = "m5.large"
  region                      = var.aws_region
  source_ami                  = data.amazon-ami.amazon-linux-2.id
  spot_price                  = "0"
  ssh_pty                     = true
  ssh_timeout                 = "5m"
  ssh_username                = "ec2-user"
  tags = {
    Name           = "HashiCorp Vault"
    OS             = "Amazon Linux 2"
  }
  subnet_id                   = var.subnet_id
  vpc_id                      = var.vpc_id
}

build {
  sources = ["source.amazon-ebs.amazon-ebs-amazonlinux-2"]

  provisioner "shell" {
    inline = [
      "echo 'Downloading Vault ${var.vault_version}...'",
      "curl -L -o /tmp/vault.zip https://releases.hashicorp.com/vault/${var.vault_version}/vault_${var.vault_version}_linux_amd64.zip",
      "echo 'Vault download completed'"
    ]
  }

  provisioner "file" {
    destination = "/tmp"
    source      = "files/"
  }
}