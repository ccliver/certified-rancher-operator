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
  default = "v1.16.10-rancher2-1"
}
