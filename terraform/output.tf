############################################################
# OUTPUTS
############################################################

output "key_pair_name" {
  description = "Name of the key pair created in AWS"
  value       = aws_key_pair.hari_key_pair.key_name
}

output "private_key_path" {
  description = "Local path to the generated private key"
  value       = local_file.save_private_key.filename
}

output "ansible_control_ip" {
  description = "Public IP of the Ansible control node"
  value       = aws_instance.ansible_node.public_ip
}

output "jenkins_master_ip" {
  description = "Public IP of the Jenkins master node"
  value       = aws_instance.jenkins_master.public_ip
}

output "jenkins_worker_ip" {
  description = "Public IP of the Jenkins worker node"
  value       = aws_instance.jenkins_worker.public_ip
}
