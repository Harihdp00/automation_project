############################################################
# PROVIDER CONFIGURATION
############################################################
provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAT7ZNLMUVXIxxxxx"
  secret_key = "HNTZZF9WY/s942mitaO97lzqjxxxxxs"
}

############################################################
# DATA SOURCES
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
    description = "Allow HTTP (Optional)"
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
# COMMON BOOTSTRAP USER DATA (for all nodes)
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
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids      = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    ${local.base_user_data}

    # Configure hostname
    hostnamectl set-hostname ansible-control

    # Add GitHub SSH private key for repo access
    cat <<'EOKEY' > /home/devops/.ssh/id_ed25519
    ${file(var.github_private_key_path)}
    EOKEY
    chmod 600 /home/devops/.ssh/id_ed25519
    chown devops:devops /home/devops/.ssh/id_ed25519

    # Add GitHub to known_hosts
    ssh-keyscan github.com >> /home/devops/.ssh/known_hosts
    chown devops:devops /home/devops/.ssh/known_hosts

    # Clone your Ansible automation repo
    sudo -u devops git clone git@github.com:Harihdp00/automation_project.git /home/devops/iac/automation_project || true
    chown -R devops:devops /home/devops/iac

    # Install Ansible
    apt install -y ansible

    # Run Ansible site playbook automatically after startup
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
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = element(data.aws_subnets.default.ids, 1)
  vpc_security_group_ids      = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  user_data = "${local.base_user_data}\n\nhostnamectl set-hostname jenkins-master\n"

  tags = {
    Name = "${var.project_prefix}-jenkins-master"
  }
}

############################################################
# 3️⃣ JENKINS WORKER NODES
############################################################
resource "aws_instance" "jenkins_workers" {
  count                       = length(var.worker_hostnames)
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = element(data.aws_subnets.default.ids, (count.index + 2) % length(data.aws_subnets.default.ids))
  vpc_security_group_ids      = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  user_data = "${local.base_user_data}\n\nhostnamectl set-hostname ${var.worker_hostnames[count.index]}\n"

  tags = {
    Name = "${var.project_prefix}-${var.worker_hostnames[count.index]}"
  }
}

############################################################
# 4️⃣ DYNAMIC ANSIBLE INVENTORY
############################################################
resource "local_file" "ansible_inventory" {
  filename = "../ansible/hosts"
  content  = templatefile("${path.module}/inventory.tpl", {
    control_ip = aws_instance.ansible_node.public_ip
    master_ip  = aws_instance.jenkins_master.public_ip
    worker_ips = aws_instance.jenkins_workers[*].public_ip
  })
}

############################################################
# 5️⃣ OPTIONAL — RUN ANSIBLE FROM CONTROL NODE (AFTER BOOT)
############################################################
resource "null_resource" "run_ansible" {
  depends_on = [local_file.ansible_inventory]

  provisioner "local-exec" {
    command = <<EOT
      echo "Executing Ansible playbooks remotely from control node..."
      sleep 60
      ssh -o StrictHostKeyChecking=no -i ~/.ssh/${var.key_name}.pem devops@${aws_instance.ansible_node.public_ip} <<'EOF'
        cd /home/devops/iac/automation_project/ansible
        ansible-playbook -i hosts playbooks/site.yaml
      EOF
    EOT
  }
}
