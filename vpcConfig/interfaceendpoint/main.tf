
resource "aws_security_group" "allow_https" {
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

resource "aws_vpc_security_group_ingress_rule" "allow_https_inbound_rule" {
  security_group_id = aws_security_group.allow_https.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_endpoint" "ssm_private_endpoint" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  ip_address_type     = "ipv4"

  security_group_ids = [
    aws_security_group.allow_https.id
  ]

  subnet_ids = [
    var.public_subnet_1a
  ]
}

resource "aws_vpc_endpoint" "kms_private_endpoint" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  ip_address_type     = "ipv4"

  security_group_ids = [
    aws_security_group.allow_https.id
  ]

  subnet_ids = [
    var.public_subnet_1a
  ]
}

resource "aws_vpc_endpoint" "ecr_dcr_private_endpoint" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  ip_address_type     = "ipv4"

  security_group_ids = [
    aws_security_group.allow_https.id
  ]

  subnet_ids = [
    var.public_subnet_1a
  ]
}

resource "aws_vpc_endpoint" "ecr_api_private_endpoint" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  ip_address_type     = "ipv4"

  security_group_ids = [
    aws_security_group.allow_https.id
  ]

  subnet_ids = [
    var.public_subnet_1a
  ]
}

resource "aws_vpc_endpoint" "ec2_private_endpoint" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  ip_address_type     = "ipv4"

  security_group_ids = [
    aws_security_group.allow_https.id
  ]

  subnet_ids = [
    var.public_subnet_1a
  ]
}

resource "aws_vpc_endpoint" "s3_private_endpoint" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  #private_dns_enabled = true
  #ip_address_type = "ipv4"
  route_table_ids = [var.private_route_table_id]

  /*   security_group_ids = [
    aws_security_group.allow_https.id
  ] */

  /*   subnet_ids = [
    var.public_subnet_1a
  ] */
}