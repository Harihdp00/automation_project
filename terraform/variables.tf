variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI"
  type        = string
  default     = "ami-02d26659fd82cf299"
}

variable "key_name" {
  description = "Existing AWS Key Pair"
  type        = string
  default     = "Hari_ubuntu"
}

variable "github_private_key_path" {
  description = "Path to GitHub private key"
  type        = string
  default     = "${path.module}/ansible_git_key"
}

variable "project_prefix" {
  description = "Project prefix for tagging"
  type        = string
  default     = "automation-project"
}
