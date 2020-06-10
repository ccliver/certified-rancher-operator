# If you intened to deploy Kubernetes in an air-gapped environment,
# please consult the documentation on how to configure custom RKE images.
nodes:
- address: ${public_ip}
  role:
  - controlplane
  - worker
  - etcd
  user: ubuntu
  internal_address: ${private_ip}
  docker_socket: /var/run/docker.sock
  ssh_key_path: ./id_rsa

kubernetes_version: ${kubernetes_version}
