provider "aws" {
  region = var.cluster_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "2.38.0"
  name               = "${var.cluster_name}-${var.cluster_region}"
  cidr               = "10.0.0.0/16"
  azs                = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1], data.aws_availability_zones.available.names[2]]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway = true

  vpc_tags = {
    Name = "${var.cluster_name}-${var.cluster_region}"
  }
}

resource "aws_security_group" "cluster" {
  name   = "${var.cluster_name}-${var.cluster_region}"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32", "10.0.0.0/8"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8", "${var.my_ip}/32"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "cluster" {
  name = "${var.cluster_name}-${var.cluster_region}"
  role = aws_iam_role.cluster.name
}

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-${var.cluster_region}"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy" "cluster" {
  name = "${var.cluster_name}-${var.cluster_region}"
  path = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "001",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "${aws_s3_bucket.backups.arn}",
        "${aws_s3_bucket.backups.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = aws_iam_policy.cluster.arn
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-202*"]
  }

  owners = ["099720109477"] # Canonical
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "aws_key_pair" "cluster" {
  key_name   = "${var.cluster_name}-${var.cluster_region}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "aws_instance" "cluster_node" {
  count                  = var.cluster_node_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.cluster_node_instance_type
  vpc_security_group_ids = [aws_security_group.cluster.id]
  subnet_id              = module.vpc.public_subnets[0]
  key_name               = aws_key_pair.cluster.key_name
  iam_instance_profile   = aws_iam_instance_profile.cluster.name
  user_data              = <<SCRIPT
#!/bin/bash -ex
curl https://releases.rancher.com/install-docker/18.09.sh | sh
sudo usermod -aG docker ubuntu
SCRIPT

  tags = {
    Name = "${var.cluster_name}-node${count.index + 1}-${var.cluster_region}"
  }
}

resource "local_file" "rke_config" {
    content            = templatefile("${path.module}/config/cluster.yml.tpl", {
    kubernetes_version = var.kubernetes_version,
    backup_bucket      = aws_s3_bucket.backups.id,
    backup_folder      = var.cluster_name,
    backup_interval    = var.backup_interval,
    cluster_region     = var.cluster_region,
    public_ips         = aws_instance.cluster_node.*.public_ip
    private_ips        = aws_instance.cluster_node.*.private_ip
  })
  filename        = "${path.module}/../../cluster.yml"
  file_permission = "0644"
}

resource "local_file" "ssh_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/../../id_rsa"
  file_permission = "0400"
}

resource "random_string" "string" {
  length  = 6
  lower   = true
  number  = false
  upper   = false
  special = false
}

resource "aws_s3_bucket" "backups" {
  bucket        = "${var.cluster_name}-${var.cluster_region}-backups-${random_string.string.result}"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }
}

resource "aws_lb" "cluster" {
  name               = "${var.cluster_name}-${var.cluster_region}"
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets

  depends_on = [module.vpc]
}

resource "aws_lb_target_group" "cluster" {
  name     = "${var.cluster_name}-${var.cluster_region}"
  port     = 443
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_target_group_attachment" "cluster" {
  count            = var.cluster_node_count
  target_group_arn = aws_lb_target_group.cluster.arn
  target_id        = aws_instance.cluster_node[count.index].id
  port             = 443
}

resource "aws_lb_listener" "cluster_443" {
  load_balancer_arn = aws_lb.cluster.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cluster.arn
  }
}
