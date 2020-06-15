output "cluster_ips" {
  value = aws_instance.cluster_node.*.public_ip
}

output "lb_dns_name" {
  value = aws_lb.cluster.dns_name
}
