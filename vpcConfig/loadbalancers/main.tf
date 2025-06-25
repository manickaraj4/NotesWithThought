
/* data "aws_s3_object" "kube_ca_cert" {
  bucket = var.config_s3_bucket
  key    = "KubeConfig/cluster-ca-cert.pem"
}

data "aws_s3_object" "kube_ca_key" {
  bucket = var.config_s3_bucket
  key    = "KubeConfig/cluster-ca-key.pem"
} */

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "lb_cert_id" {
  name = var.certid_ssmname
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

resource "aws_acm_certificate" "lb_cert_new" {
  private_key      = tls_private_key.lb-cert-key.private_key_pem
  certificate_body = tls_self_signed_cert.lb_self_cert.cert_pem
}


*/

/* resource "aws_acm_certificate" "lb_cert_new" {
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
} */

resource "aws_security_group" "nlb_sg" {
  vpc_id = var.vpc_id

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

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.nlb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_kubernetes_api_server" {
  security_group_id = aws_security_group.nlb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.nlb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_lb" "master_lb" {
  name                             = "masterlb"
  internal                         = false
  load_balancer_type               = "network"
  security_groups                  = [aws_security_group.nlb_sg.id]
  subnets                          = ["${var.public_subnet_1a}", "${var.public_subnet_1b}", "${var.public_subnet_1c}"]
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "TerraformManaged"
  }

  provisioner "local-exec" {
    command = "aws ssm put-parameter --name lb_name --type String --value ${aws_lb.master_lb.dns_name} --overwrite --region ${var.aws_region}"
  }
}

resource "aws_lb_listener" "master_https_listener" {
  load_balancer_arn = aws_lb.master_lb.arn
  port              = "6443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.master_tls_tg.arn
  }
}

resource "aws_lb_listener" "master_ssh_listener" {
  load_balancer_arn = aws_lb.master_lb.arn
  port              = "22"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.master_ssh_tg.arn
  }
}


resource "aws_lb_target_group" "master_tls_tg" {
  name     = "mastertlstg"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.vpc_id
  health_check {
    path     = "/livez"
    port     = 6443
    protocol = "HTTPS"
    matcher  = "200,202"
  }
}

resource "aws_lb_target_group" "master_ssh_tg" {
  name     = "mastersshtg"
  port     = 22
  protocol = "TCP"
  vpc_id   = var.vpc_id
  health_check {
    port     = 22
    protocol = "TCP"
  }
}

resource "aws_lb_target_group_attachment" "master_tg_tls_attachment" {
  target_group_arn = aws_lb_target_group.master_tls_tg.arn
  target_id        = var.master_node
  port             = 6443
}

resource "aws_lb_target_group_attachment" "master_tg_tcp_attachment" {
  target_group_arn = aws_lb_target_group.master_ssh_tg.arn
  target_id        = var.master_node
  port             = 22
}

resource "aws_lb_listener" "worker_https_listener" {
  load_balancer_arn = aws_lb.master_lb.arn
  port              = "443"
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/${data.aws_ssm_parameter.lb_cert_id.value}"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.worker_nginx_tg.arn
  }
}

resource "aws_lb_target_group" "worker_nginx_tg" {
  name     = "wokertg"
  port     = 443
  protocol = "TLS"
  vpc_id   = var.vpc_id
  health_check {
    path     = "/livez"
    port     = 30008
    protocol = "HTTP"
    matcher  = "200,202"
  }
}

resource "aws_lb_target_group_attachment" "worker_https_attachment" {
  target_group_arn = aws_lb_target_group.worker_nginx_tg.arn
  target_id        = var.worker_node
  port             = 30008
}

