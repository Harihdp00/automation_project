############################################################
# PROVIDER & REGION
############################################################
provider "aws" {
  region = "ap-south-1"
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
# SECURITY GROUP
############################################################
resource "aws_security_group" "devops_sg" {
  name        = "${var.project_prefix}-sg"
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
    Name = "${var.project_prefix}-sg"
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
  instance_type               = "t3.micro"
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    ${local.base_user_data}
    hostnamectl set-hostname ansible-control

    # Add GitHub SSH private key securely
    echo "${filebase64(abspath(var.github_private_key_path))}" | base64 -d > /home/devops/.ssh/id_ed25519
    chmod 600 /home/devops/.ssh/id_ed25519
    chown devops:devops /home/devops/.ssh/id_ed25519

    # Add GitHub to known_hosts
    ssh-keyscan github.com >> /home/devops/.ssh/known_hosts
    chown devops:devops /home/devops/.ssh/known_hosts

    # Clone automation repo
    sudo -u devops git clone git@github.com:Harihdp00/automation_project.git /home/devops/iac/automation_project || true
    chown -R devops:devops /home/devops/iac

    # Install Ansible and run site playbook
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
  ami                         = var.ami_id
  instance_type               = "t3.micro"
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
  instance_type               = "t3.micro"
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
# 4️⃣ DYNAMIC ANSIBLE INVENTORY
############################################################
resource "local_file" "ansible_inventory" {
  filename = "../ansible/hosts"
  content = templatefile("${path.module}/inventory.tpl", {
    control_ip = aws_instance.ansible_node.public_ip
    master_ip  = aws_instance.jenkins_master.public_ip
    worker_ips = [aws_instance.jenkins_worker.public_ip]
  })
}

############################################################
# 5️⃣ RUN ANSIBLE FROM CONTROL NODE
############################################################
resource "null_resource" "run_ansible" {
  depends_on = [local_file.ansible_inventory]

  provisioner "local-exec" {
    command = <<EOT
      echo "🚀 Starting Ansible automation from Control Node..."
      sleep 60

      KEY_PATH="$HOME/.ssh/${var.key_name}.pem"

      if [ ! -f "$KEY_PATH" ]; then
        echo "❌ ERROR: SSH key not found at $KEY_PATH"
        exit 1
      fi

      chmod 600 "$KEY_PATH"
      echo "✅ Permissions set for $KEY_PATH"

      ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" devops@${aws_instance.ansible_node.public_ip} <<'EOF'
        echo "🧠 Inside Control Node - Executing Ansible Playbook"
        cd /home/devops/iac/automation_project/ansible
        ansible-playbook -i hosts playbooks/site.yaml
      EOF
    EOT
  }
}

