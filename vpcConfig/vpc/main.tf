resource "aws_vpc" "kubernetes_vpc" {
  cidr_block                       = "172.31.0.0/16"
  instance_tenancy                 = "default"
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.kubernetes_vpc.id

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_vpc.kubernetes_vpc.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gw.id
}

resource "aws_egress_only_internet_gateway" "egress_gw" {
  vpc_id = aws_vpc.kubernetes_vpc.id

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.kubernetes_vpc.id

  /*   route {
    cidr_block = "172.31.0.0/16"
    gateway_id = "local"
  }

  route {
    ipv6_cidr_block = aws_vpc.kubernetes_vpc.ipv6_cidr_block
    gateway_id  = "local"
  }
 */

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.egress_gw.id
  }

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "public_subnet_1a" {
  vpc_id                  = aws_vpc.kubernetes_vpc.id
  cidr_block              = "172.31.0.0/20"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "public_subnet_1b" {
  vpc_id                  = aws_vpc.kubernetes_vpc.id
  cidr_block              = "172.31.16.0/20"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "public_subnet_1c" {
  vpc_id                  = aws_vpc.kubernetes_vpc.id
  cidr_block              = "172.31.32.0/20"
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = true

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "private_subnet_1a" {
  vpc_id                          = aws_vpc.kubernetes_vpc.id
  cidr_block                      = "172.31.48.0/20"
  availability_zone               = "${var.aws_region}a"
  assign_ipv6_address_on_creation = false
  enable_dns64                    = false
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.kubernetes_vpc.ipv6_cidr_block, 4, 1)
  map_public_ip_on_launch         = false

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "private_subnet_1b" {
  vpc_id                          = aws_vpc.kubernetes_vpc.id
  cidr_block                      = "172.31.64.0/20"
  availability_zone               = "${var.aws_region}b"
  assign_ipv6_address_on_creation = false
  enable_dns64                    = false
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.kubernetes_vpc.ipv6_cidr_block, 4, 2)
  map_public_ip_on_launch         = false

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "private_subnet_1c" {
  vpc_id                          = aws_vpc.kubernetes_vpc.id
  cidr_block                      = "172.31.80.0/20"
  availability_zone               = "${var.aws_region}c"
  assign_ipv6_address_on_creation = false
  enable_dns64                    = false
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.kubernetes_vpc.ipv6_cidr_block, 4, 3)
  map_public_ip_on_launch         = false

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_route_table_association" "private_route_asc_a" {
  subnet_id      = aws_subnet.private_subnet_1a.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_route_asc_b" {
  subnet_id      = aws_subnet.private_subnet_1b.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_route_asc_c" {
  subnet_id      = aws_subnet.private_subnet_1c.id
  route_table_id = aws_route_table.private_route_table.id
}

