terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "master_server" {
  ami                    = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type          = "t3.small"
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  user_data              = file("${path.module}/scripts/masterbootstrap.sh")

  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_security_group" "allow_ssh" {
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_inbound_rule" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGW9uO5m+sTquPQV6CsaQRZ+JhqmAAxArvluSRs5FINQ manickaraj.km@LT8649"
}

output "master_node_public_address" {
  value = aws_instance.master_server.public_dns
}