# Data sources
data "aws_ami" "vault" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["vault-amazonlinux2-vault*"]
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_caller_identity" "current" {}

# KMS key for Vault auto-unseal
resource "aws_kms_key" "vault" {
  description             = "KMS key for ${var.project_name} Vault auto-unseal"
  deletion_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-vault-kms"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_kms_alias" "vault" {
  name          = "alias/${var.project_name}-vault"
  target_key_id = aws_kms_key.vault.key_id
}

# Security Group for Vault
resource "aws_security_group" "vault" {
  name_prefix = "${var.project_name}-vault-"
  vpc_id      = var.vpc_id

  # Vault API
  ingress {
    from_port   = var.vault_port
    to_port     = var.vault_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  # Vault cluster communication
  ingress {
    from_port = 8201
    to_port   = 8201
    protocol  = "tcp"
    self      = true
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-vault-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role for Vault instances
resource "aws_iam_role" "vault" {
  name = "${var.project_name}-vault-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for Vault auto-join and KMS
resource "aws_iam_role_policy" "vault" {
  name = "${var.project_name}-vault-policy"
  role = aws_iam_role.vault.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.vault.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DeleteParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/vault/${var.environment}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "vault" {
  name = "${var.project_name}-vault-profile"
  role = aws_iam_role.vault.name
}

# Launch Template for Vault instances
resource "aws_launch_template" "vault" {
  name_prefix   = "${var.project_name}-vault-"
  image_id      = data.aws_ami.vault.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.vault.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.vault.name
  }

  user_data = base64encode(templatefile("${path.module}/../scripts/user_data.sh", {
    vault_cluster_size = var.vault_cluster_size
    environment       = var.environment
    kms_key_id        = aws_kms_key.vault.key_id
    aws_region        = var.aws_region
    vault_config      = base64encode(file("${path.module}/../files/vault.hcl"))
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-vault"
      Environment = var.environment
      Project     = var.project_name
      vault       = var.aws_region
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Auto Scaling Group for Vault cluster
resource "aws_autoscaling_group" "vault" {
  name                = "${var.project_name}-vault-asg"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.vault.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.vault_cluster_size
  max_size         = var.vault_cluster_size
  desired_capacity = var.vault_cluster_size

  launch_template {
    id      = aws_launch_template.vault.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-vault-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "vault"
    value               = var.aws_region
    propagate_at_launch = true
  }

  tag {
    key                 = "ttl"
    value               = var.resource_ttl
    propagate_at_launch = false
  }

  tag {
    key                 = "created_at"
    value               = timestamp()
    propagate_at_launch = false
  }

  tag {
    key                 = "auto_delete"
    value               = "true"
    propagate_at_launch = false
  }

  tag {
    key                 = "owner"
    value               = "terraform"
    propagate_at_launch = false
  }
}

# Application Load Balancer for Vault
resource "aws_lb" "vault" {
  name               = "${var.project_name}-vault-alb"
  internal           = !var.enable_public_access
  load_balancer_type = "application"
  security_groups    = [aws_security_group.vault_alb.id]
  subnets            = var.subnet_ids

  tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ttl         = var.resource_ttl
      created_at  = timestamp()
      auto_delete = "true"
      owner       = "terraform"
    },
    var.additional_tags
  )
}

resource "aws_security_group" "vault_alb" {
  name_prefix = "${var.project_name}-vault-alb-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.vault_port
    to_port     = var.vault_port
    protocol    = "tcp"
    cidr_blocks = var.enable_public_access ? var.allowed_cidr_blocks : [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-vault-alb-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_lb_target_group" "vault" {
  name     = "${var.project_name}-vault-tg"
  port     = var.vault_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/v1/sys/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_lb_listener" "vault" {
  load_balancer_arn = aws_lb.vault.arn
  port              = var.vault_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault.arn
  }
} 