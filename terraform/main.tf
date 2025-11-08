############################################################
# PROVIDER & REGION
############################################################
provider "aws" {
  region = "ap-south-1"
}

############################################################
# CREATE SSH KEY (Hari_ubuntu) INSIDE TERRAFORM
############################################################
resource "tls_private_key" "hari_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "hari_key_pair" {
  key_name   = "Hari_ubuntu"
  public_key = tls_private_key.hari_key.public_key_openssh
}

# Wait for AWS to register key
resource "time_sleep" "wait_for_key_pair" {
  depends_on      = [aws_key_pair.hari_key_pair]
  create_duration = "10s"
}

# Save the private key locally (for Ansible or debugging)
resource "local_file" "save_private_key" {
  content    = tls_private_key.hari_key.private_key_pem
  filename   = "${path.module}/Hari_ubuntu.pem"
  depends_on = [tls_private_key.hari_key]
}

############################################################
# TLS + AWS KEY PAIR (Auto-created)
############################################################
resource "tls_private_key" "hari_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "hari_key_pair" {
  key_name   = "Hari_ubuntu"
  public_key = tls_private_key.hari_key.public_key_openssh
}

# Wait for AWS to register keypair before using
resource "time_sleep" "wait_for_key_pair" {
  depends_on      = [aws_key_pair.hari_key_pair]
  create_duration = "10s"
}

# Save private key locally for SSH/Ansible
resource "local_file" "hari_private_key" {
  depends_on = [tls_private_key.hari_key]
  content    = tls_private_key.hari_key.private_key_pem
  filename   = "${path.module}/Hari_ubuntu.pem"
}

############################################################
# DATA SOURCES (VPC & SUBNETS)
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
# SECURITY GROUP (with random suffix)
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
  depends_on = [time_sleep.wait_for_key_pair]

  ami                         = var.ami_id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.hari_key_pair.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    ${local.base_user_data}
    hostnamectl set-hostname ansible-control

    echo "${filebase64(abspath(var.github_private_key_path))}" | base64 -d > /home/devops/.ssh/id_ed25519
    chmod 600 /home/devops/.ssh/id_ed25519
    chown devops:devops /home/devops/.ssh/id_ed25519

    ssh-keyscan github.com >> /home/devops/.ssh/known_hosts
    chown devops:devops /home/devops/.ssh/known_hosts

    sudo -u devops git clone git@github.com:Harihdp00/automation_project.git /home/devops/iac/automation_project || true
    chown -R devops:devops /home/devops/iac

    apt install -y ansible
    cd /home/devops/iac/automation_project/ansible
    ansible-playbook -i hosts playbooks/site.yaml
  EOF

  tags = {
    Name = "${var.project_prefix}-ansible-control"
  }
}

############################################################
# 2️⃣ JENKINS MASTER NODE
############################################################
resource "aws_instance" "jenkins_master" {
  depends_on = [time_sleep.wait_for_key_pair]

  ami                         = var.ami_id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.hari_key_pair.key_name
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
  depends_on = [time_sleep.wait_for_key_pair]

  ami                         = var.ami_id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.hari_key_pair.key_name
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
output "key_name" {
  value = aws_key_pair.hari_key_pair.key_name
}

output "ansible_control_ip" {
  value = aws_instance.ansible_node.public_ip
}

output "jenkins_master_ip" {
  value = aws_instance.jenkins_master.public_ip
}

output "jenkins_worker_ip" {
  value = aws_instance.jenkins_worker.public_ip
}
