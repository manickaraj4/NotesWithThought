
data "aws_s3_object" "kube_ca_cert" {
  bucket = var.config_s3_bucket
  key    = "KubeConfig/cluster-ca-cert.pem"
}

data "aws_s3_object" "kube_ca_key" {
  bucket = var.config_s3_bucket
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
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_default_subnet" "default_1b" {
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_default_subnet" "default_1c" {
  availability_zone = "${var.aws_region}c"

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
  name               = "masterlb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_default_subnet.default_1a.id, aws_default_subnet.default_1b.id, aws_default_subnet.default_1c.id]

  tags = {
    Name = "TerraformManaged"
  }

  provisioner "local-exec" {
    command = "aws ssm put-parameter --name lb_name --type String --value ${aws_lb.master_lb.dns_name} --overwrite --region ${var.aws_region}"
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
  target_id        = var.master_node
  port             = 6443
}

