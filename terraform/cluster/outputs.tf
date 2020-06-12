output "ssh_private_key" {
  value = tls_private_key.ssh_key.private_key_pem
}

output "cluster_ips" {
  value = aws_instance.cluster_node.*.public_ip
}
