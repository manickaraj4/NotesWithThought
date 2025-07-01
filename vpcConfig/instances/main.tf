resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_key_pub
}

resource "time_sleep" "wait_300_seconds" {
  depends_on      = [aws_instance.master_server]
  create_duration = "240s"
}

data "aws_caller_identity" "current" {}

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

resource "aws_iam_role_policy" "ecr_pull_cache_policy" {
  name = "ecr_pull_cache"
  role = aws_iam_role.ec2_instance_role.id

  policy = templatefile("${path.module}/scripts/pullcacheecrpolicy.json", { region = "${var.aws_region}", account_id = "${data.aws_caller_identity.current.account_id}" })
}

resource "aws_iam_role_policy" "ebs_csi_policy" {
  name = "ebs_csi"
  role = aws_iam_role.ec2_instance_role.id

  policy = file("${path.module}/scripts/ebscsidriverpolicy.json")
}

resource "aws_iam_role_policy" "ssm_policy" {
  name = "ssm_policy"
  role = aws_iam_role.ec2_instance_role.id

  policy = templatefile("${path.module}/scripts/ssmec2policy.json", { region = "${var.aws_region}", account_id = "${data.aws_caller_identity.current.account_id}", bucket = "${var.config_s3_bucket}" })
}

resource "aws_iam_role_policy" "loadbalancer_controller_policy" {
  name = "loadbalancer_controller_policy"
  role = aws_iam_role.ec2_instance_role.id

  policy = file("${path.module}/scripts/loadbalancercontrollerpolicy.json")
}

/* resource "aws_security_group" "allow_ssh" {
  vpc_id = var.vpc_id

  tags = {
    Name = "TerraformManaged"
  }
} */

resource "aws_security_group" "allow_all_tcp_between_nodes" {
  name   = "allow_cross_node_communication"
  vpc_id = var.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  tags = {
    Name = "TerraformManaged"
  }
}

/* resource "aws_vpc_security_group_ingress_rule" "allow_ssh_inbound_rule" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
} */

resource "aws_vpc_security_group_ingress_rule" "allow_cross_node_communication" {
  security_group_id            = aws_security_group.allow_all_tcp_between_nodes.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.allow_all_tcp_between_nodes.id
}

resource "aws_security_group" "allow_all_from_lb" {
  name   = "allow_all_from_lb"
  vpc_id = var.vpc_id

  tags = {
    Name = "TerraformManaged"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_lb_sg" {
  security_group_id            = aws_security_group.allow_all_from_lb.id
  ip_protocol                  = "-1"
  referenced_security_group_id = var.lb_sg_id
}

resource "aws_instance" "master_server" {
  ami                    = var.arm64_ami
  instance_type          = var.master_instance_type
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_all_tcp_between_nodes.id, aws_security_group.allow_all_from_lb.id]
  user_data              = templatefile("${path.module}/scripts/masterbootstrap.sh", { region = "${var.aws_region}", bucket = "${var.config_s3_bucket}" })
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.id
  # user_data_replace_on_change = true
  subnet_id                   = var.subnet_1a
  associate_public_ip_address = !var.in_private_subnet ? true : false
  ipv6_address_count          = var.in_private_subnet ? 1 : 0

  tags = {
    Name      = "masterServer",
    ManagedBy = "Terraform"
  }
}

resource "aws_instance" "worker_node" {
  depends_on             = [time_sleep.wait_300_seconds]
  ami                    = var.x86_ami
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_all_tcp_between_nodes.id, aws_security_group.allow_all_from_lb.id]
  user_data              = templatefile("${path.module}/scripts/workerbootstrap.sh", { region = "${var.aws_region}" })
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.id
  # user_data_replace_on_change = true
  subnet_id                   = var.subnet_1b
  associate_public_ip_address = !var.in_private_subnet ? true : false
  ipv6_address_count          = var.in_private_subnet ? 1 : 0

  tags = {
    Name      = "workerNode",
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role" "jenkins_ec2_instance_role" {
  name               = "jenkins_ec2_instance_role"
  path               = "/"
  assume_role_policy = file("${path.module}/scripts/assumeroleec2policy.json")
}

resource "aws_iam_instance_profile" "jenkins_ec2_instance_profile" {
  name = "jenkins_ec2_instance_profile"
  role = aws_iam_role.jenkins_ec2_instance_role.name
}

resource "aws_iam_role_policy_attachment" "cni_policy_attach" {
  role       = aws_iam_role.jenkins_ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_instance" "jenkins_slave_node" {
  ami                    = var.x86_ami
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_all_tcp_between_nodes.id]
  user_data              = file("${path.module}/scripts/jenkinsslavebootstrap.sh")
  iam_instance_profile   = aws_iam_instance_profile.jenkins_ec2_instance_profile.id
  # user_data_replace_on_change = true
  subnet_id                   = var.subnet_1c
  associate_public_ip_address = !var.in_private_subnet ? true : false
  ipv6_address_count          = var.in_private_subnet ? 1 : 0

  tags = {
    Name      = "JenkinsSlaveHost",
    ManagedBy = "Terraform"
  }
}
