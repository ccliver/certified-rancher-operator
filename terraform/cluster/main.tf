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
  azs                = [data.aws_availability_zones.available.names[0]]
  private_subnets    = ["10.0.1.0/24"]
  public_subnets     = ["10.0.101.0/24"]
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
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "tcp"
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
  name        = "${var.cluster_name}-${var.cluster_region}"
  path        = "/"
  description = "My test policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "001",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "${aws_s3_bucket.backups.arn}"
    },
    {
      "Sid": "002",
      "Effect": "Allow",
      "Action": "s3:*Object",
      "Resource": "${aws_s3_bucket.backups.arn}/*"
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
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.cluster_node_instance_type
  vpc_security_group_ids = [aws_security_group.cluster.id]
  subnet_id              = module.vpc.public_subnets[0]
  key_name               = aws_key_pair.cluster.key_name
  user_data              = <<SCRIPT
#!/bin/bash -ex
curl https://releases.rancher.com/install-docker/18.09.sh | sh
sudo usermod -aG docker ubuntu
SCRIPT

  tags = {
    Name = "cluster"
  }
}

data "template_file" "rke_config" {
  template = file("${path.module}/config/cluster.yml.tpl")

  vars = {
    public_ip          = aws_instance.cluster_node.public_ip
    private_ip         = aws_instance.cluster_node.private_ip
    kubernetes_version = var.kubernetes_version
  }
}

resource "local_file" "rke_config" {
  content         = data.template_file.rke_config.rendered
  filename        = "${path.module}/../../cluster.yml"
  file_permission = "0644"
}

resource "local_file" "ssh_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/../../id_rsa"
  file_permission = "0400"
}

resource "aws_s3_bucket" "backups" {
  bucket = "${var.cluster_name}-${var.cluster_region}-backups"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }
}
