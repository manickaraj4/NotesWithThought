terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    time = {
      source = "hashicorp/time"
      version = "0.13.1"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-south-1"
}

provider "time" {
}

data "aws_caller_identity" "current" {}

data "aws_s3_object" "kube_ca_cert" {
  bucket = "samplebucketfortesting12345"
  key    = "KubeConfig/cluster-ca-cert.pem"
}

data "aws_s3_object" "kube_ca_key" {
  bucket = "samplebucketfortesting12345"
  key    = "KubeConfig/cluster-ca-key.pem"
}

/*
resource "tls_private_key" "lb-cert-key" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "lb_self_cert" {
  private_key_pem = tls_private_key.lb-cert-key.private_key_pem

  subject {
    common_name  = "masterlb-985247139.ap-south-1.elb.amazonaws.com"
    organization = "Sample Corp"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}
*/

resource "aws_acm_certificate" "lb_cert_new" {
  /* private_key      = tls_private_key.lb-cert-key.private_key_pem
  certificate_body = tls_self_signed_cert.lb_self_cert.cert_pem */
  private_key      = data.aws_s3_object.kube_ca_key.body
  certificate_body = data.aws_s3_object.kube_ca_cert.body
}

resource "aws_default_vpc" "default_vpc" {
  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_default_subnet" "default_1a" {
  availability_zone = "ap-south-1a"

  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_default_subnet" "default_1b" {
  availability_zone = "ap-south-1b"

  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_default_subnet" "default_1c" {
  availability_zone = "ap-south-1c"

  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_security_group" "alb_sg" {
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

resource "aws_vpc_security_group_ingress_rule" "allow_kube_master_ports" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8443
  ip_protocol       = "tcp"
  to_port           = 8443
}

resource "aws_lb" "master_lb" {
  depends_on         = [time_sleep.wait_300_seconds, aws_instance.master_server]
  name               = "masterlb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_default_subnet.default_1a.id, aws_default_subnet.default_1b.id, aws_default_subnet.default_1c.id]

  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_lb_listener" "master_listener" {
  load_balancer_arn = aws_lb.master_lb.arn
  port              = "8443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.lb_cert_new.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.master_tg.arn
  }
}

/*
resource "aws_lb_listener_rule" "master_rule" {
  listener_arn = aws_lb_listener.master_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.master_tg.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }

}
*/

resource "aws_lb_target_group" "master_tg" {
  name     = "mastertg"
  port     = 8443
  protocol = "HTTPS"
  vpc_id   = aws_default_vpc.default_vpc.id
  health_check {
    path     = "/livez"
    port     = 6443
    protocol = "HTTPS"
    matcher  = "200,202"
  }
}

resource "aws_lb_target_group_attachment" "master_tg_attachment" {
  target_group_arn = aws_lb_target_group.master_tg.arn
  target_id        = aws_instance.master_server.id
  port             = 6443
}

resource "time_sleep" "wait_300_seconds" {
  create_duration = "300s"
}

resource "aws_security_group" "allow_all_tcp_between_nodes" {
  name = "allow_cross_node_communication"
  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_security_group" "allow_all_from_lb" {
  name = "allow_all_from_lb"
  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_cross_node_communication" {
  security_group_id            = aws_security_group.allow_all_tcp_between_nodes.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.allow_all_tcp_between_nodes.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_lb_sg" {
  security_group_id            = aws_security_group.allow_all_from_lb.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_instance" "master_server" {
  ami                    = "ami-0f535a71b34f2d44a"
  instance_type          = "t3.small"
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_all_tcp_between_nodes.id, aws_security_group.allow_ssh.id, aws_security_group.allow_all_from_lb.id]
  user_data              = file("${path.module}/scripts/masterbootstrap.sh")
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.id

  tags = {
    Name      = "masterServer",
    ManagedBy = "Terraform"
  }
}

resource "aws_instance" "worker_node" {
  depends_on             = [time_sleep.wait_300_seconds]
  ami                    = "ami-0f535a71b34f2d44a"
  instance_type          = "t3.small"
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_all_tcp_between_nodes.id, aws_security_group.allow_ssh.id]
  user_data              = file("${path.module}/scripts/workerbootstrap.sh")
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.id

  tags = {
    Name      = "workerNode",
    ManagedBy = "Terraform"
  }
}

/*
resource "aws_instance" "bastion_node" {
  ami                    = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_all_tcp_between_nodes.id, aws_security_group.allow_ssh.id]
  disable_api_termination = true
  tags = {
    Name = "TerraformManaged"
  }
}
*/

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

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_instance_role.name
}

resource "aws_iam_role" "ec2_instance_role" {
  name               = "ec2_instance_role"
  path               = "/"
  assume_role_policy = file("${path.module}/scripts/assumeroleec2policy.json")
}

resource "aws_iam_role_policy_attachment" "cni_policy_attach" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_policy_attach" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "ssm_policy" {
  name = "ssm_policy"
  role = aws_iam_role.ec2_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ssm:ap-south-1:${data.aws_caller_identity.current.account_id}:parameter/kube_*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:ReEncrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ],
        "Resource" : "arn:aws:kms:ap-south-1:${data.aws_caller_identity.current.account_id}:key/e9dff97e-31dd-4c66-a0ab-d561c610e5be"
      },
      {
        "Effect" : "Allow",
        "Action" : "s3:PutObject",
        "Resource" : "arn:aws:s3:::samplebucketfortesting12345/KubeConfig/*"
      }
    ]
  })
}

output "master_node_public_address" {
  value = aws_instance.master_server.public_dns
}

output "worker_node_public_address" {
  value = aws_instance.worker_node.public_dns
}

output "lb_dns" {
  value = aws_lb.master_lb.dns_name
}