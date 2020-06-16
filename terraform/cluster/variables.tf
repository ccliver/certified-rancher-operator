variable "cluster_name" {
  default = "rancher-operator-labs"
}

variable "cluster_region" {
  default = "us-west-2"
}

variable "cluster_node_instance_type" {
  default = "t2.medium"
}

variable "kubernetes_version" {
  default = "v1.17.6-rancher2-1"
}

variable "backup_interval" {
  default = 6
}

variable "cluster_node_count" {
  default = 3
}

variable "my_ip" {} # Set in the Makefile
