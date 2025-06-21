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

resource "aws_security_group" "allow_all_tcp_between_nodes" {
  name = "allow_cross_node_communication"
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

resource "aws_vpc_security_group_ingress_rule" "allow_cross_node_communication" {
  security_group_id            = aws_security_group.allow_all_tcp_between_nodes.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.allow_all_tcp_between_nodes.id
}

resource "aws_security_group" "allow_all_from_lb" {
  name = "allow_all_from_lb"
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
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_all_tcp_between_nodes.id, aws_security_group.allow_ssh.id, aws_security_group.allow_all_from_lb.id]
  user_data              = templatefile("${path.module}/scripts/masterbootstrap.sh", { region = "${var.aws_region}", bucket = "${var.config_s3_bucket}" })
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.id

  tags = {
    Name      = "masterServer",
    ManagedBy = "Terraform"
  }
}

resource "aws_instance" "worker_node" {
  depends_on             = [time_sleep.wait_300_seconds]
  ami                    = var.ami
  #ami                    = "ami-002c8f09d560aa82e" /*eks AMI*/
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_all_tcp_between_nodes.id, aws_security_group.allow_ssh.id]
  user_data              = templatefile("${path.module}/scripts/workerbootstrap.sh", { region = "${var.aws_region}" })
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.id

  tags = {
    Name      = "workerNode",
    ManagedBy = "Terraform"
  }
}

/*
resource "aws_instance" "bastion_node" {
  ami                    = "ami-002c8f09d560aa82e"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_all_tcp_between_nodes.id, aws_security_group.allow_ssh.id]
  user_data              = file("${path.module}/scripts/bastionbootstrap.sh")
  disable_api_termination = true
  tags = {
    Name      = "BastionHost",
    ManagedBy = "Terraform"
  }
}
*/