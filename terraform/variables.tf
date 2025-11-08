variable "ami_id" {
  description = "Ubuntu 22.04 AMI ID for ap-south-1"
  default     = "ami-02d26659fd82cf299"  # ✅ Free Tier eligible
}

variable "key_name" {
  description = "AWS key pair name"
  default     = "Hari_ubuntu"
}

variable "project_prefix" {
  description = "Prefix for tagging AWS resources"
  default     = "automation-project"
}
