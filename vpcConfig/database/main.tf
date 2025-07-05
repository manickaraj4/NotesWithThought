
resource "aws_db_subnet_group" "private_sub_group" {
  name       = "private"
  subnet_ids = [var.private_subnet_b, var.private_subnet_a, var.private_subnet_c]

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "db_secret" {
  name        = "kube_db_secret"
  description = "Master DB password"
  type        = "SecureString"
  value       = random_password.db_password.result

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_db_instance" "master_db" {
  allocated_storage    = 20
  db_name              = "masterdb"
  engine               = "mysql"
  engine_version       = "8.0.40"
  instance_class       = "db.t4g.micro"
  username             = "admin"
  password             = random_password.db_password.result
  availability_zone    = "${var.aws_region}a"
  db_subnet_group_name = aws_db_subnet_group.private_sub_group.id
  parameter_group_name = "default.mysql8.0"
  #manage_master_user_password = false
  multi_az               = false
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [var.allow_ec2_sg]
}