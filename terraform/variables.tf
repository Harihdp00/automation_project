############################################################
# VARIABLES
############################################################

# AWS Region
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-south-1"
}

# Project Prefix
variable "project_prefix" {
  description = "Prefix for naming AWS resources"
  type        = string
  default     = "automation-project"
}

# Key Name
variable "key_name" {
  description = "AWS key pair name (auto-generated in main.tf)"
  type        = string
  default     = "Hari_ubuntu_auto"
}

# Ubuntu 22.04 Free-Tier AMI for ap-south-1
variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS (Free Tier eligible)"
  type        = string
  default     = "ami-0522ab6e1ddcc7055" # ✅ Verified in ap-south-1
}

# Instance type
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro" # ✅ Free Tier eligible
}
