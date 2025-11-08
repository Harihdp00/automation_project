############################################################
# PROVIDER & REGION
############################################################
provider "aws" {
  region = "ap-south-1"
}

############################################################
# DATA SOURCES (Default VPC & Subnets)
############################################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################################################
# SECURITY GROUP (Unique to Avoid Conflicts)
############################################################
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "aws_security_group" "devops_sg" {
  name        = "${var.project_prefix}-sg-${random_string.suffix.result}"
  description = "Allow SSH, Jenkins, and Web access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_prefix}-sg-${random_string.suffix.result}"
  }
}

############################################################
# COMMON BOOTSTRAP SCRIPT
############################################################
locals {
  base_user_data = <<-EOC
    #!/bin/bash
    apt update -y
    apt install -y python3 python3-pip git unzip curl awscli
    useradd -m -s /bin/bash devops
    echo "devops ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    mkdir -p /home/devops/.ssh
    cp /home/ubuntu/.ssh/authorized_keys /home/devops/.ssh/ || true
    chown -R devops:devops /home/devops/.ssh
    chmod 700 /home/devops/.ssh
    chmod 600 /home/devops/.ssh/authorized_keys || true
  EOC
}

############################################################
# 1️⃣ ANSIBLE CONTROL NODE
############################################################
resource "aws_instance" "ansible_node" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"  # ✅ Free Tier eligible
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    ${local.base_user_data}
    hostnamectl set-hostname ansible-control
  EOF

  tags = {
    Name = "${var.project_prefix}-ansible-control"
  }
}

############################################################
# 2️⃣ JENKINS MASTER NODE
############################################################
resource "aws_instance" "jenkins_master" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"  # ✅ Free Tier eligible
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  user_data = "${local.base_user_data}\n\nhostnamectl set-hostname jenkins-master\n"

  tags = {
    Name = "${var.project_prefix}-jenkins-master"
  }
}

############################################################
# 3️⃣ JENKINS WORKER NODE
############################################################
resource "aws_instance" "jenkins_worker" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"  # ✅ Free Tier eligible
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  user_data = "${local.base_user_data}\n\nhostnamectl set-hostname jenkins-worker\n"

  tags = {
    Name = "${var.project_prefix}-jenkins-worker"
  }
}

############################################################
# OUTPUTS
############################################################
output "ansible_control_ip" {
  value = aws_instance.ansible_node.public_ip
}

output "jenkins_master_ip" {
  value = aws_instance.jenkins_master.public_ip
}

output "jenkins_worker_ip" {
  value = aws_instance.jenkins_worker.public_ip
}
