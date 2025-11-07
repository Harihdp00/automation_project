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
  description = "Local path to GitHub deploy private key (used by Ansible control node)"
  type        = string
  default     = "terraform/ansible_git_key"   # ✅ Simple string — no interpolation
}

variable "project_prefix" {
  description = "Project prefix for tagging"
  type        = string
  default     = "automation-project"
}
