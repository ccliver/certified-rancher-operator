output "ssh_private_key" {
  value = tls_private_key.ssh_key.private_key_pem
}

output "rke_cluster_config" {
  value = data.template_file.rke_config.rendered
}

output "cluster_ip" {
  value = aws_instance.cluster_node.public_ip
}
