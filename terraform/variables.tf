############################################################
# VARIABLES — Terraform input definitions
############################################################

# ✅ AWS Region
variable "aws_region" {
  description = "AWS region where infrastructure will be created"
  type        = string
  default     = "ap-south-1"
}

# ✅ Ubuntu AMI
variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS"
  type        = string
  default     = "ami-02d26659fd82cf299" # ap-south-1 region
}

# ✅ SSH Key Pair
variable "key_name" {
  description = "Existing AWS EC2 key pair name used for SSH access"
  type        = string
  default     = "Hari_ubuntu"
}

# ✅ GitHub Private Key Path (fixed)
variable "github_private_key_path" {
  description = "Local path to GitHub deploy private key (used by Ansible control node)"
  type        = string
  default     = "terraform/ansible_git_key"
}

# ✅ Jenkins Worker Hostnames
variable "worker_hostnames" {
  description = "List of Jenkins worker node hostnames"
  type        = list(string)
  default     = ["jenkins-worker"]
}

# ✅ EC2 Instance Type
variable "instance_type" {
  description = "EC2 instance type for all servers"
  type        = string
  default     = "t3.micro"
}

# ✅ Tag Prefix
variable "project_prefix" {
  description = "Tag prefix for all AWS resources"
  type        = string
  default     = "automation-project"
}
