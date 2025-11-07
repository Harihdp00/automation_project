[jenkins_master]
jenkins-master ansible_host=${master_ip} ansible_user=devops ansible_python_interpreter=/usr/bin/python3

[jenkins_worker]
jenkins-worker ansible_host=${worker_ips[0]} ansible_user=devops ansible_python_interpreter=/usr/bin/python3

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
