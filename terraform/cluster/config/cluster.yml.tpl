nodes:
%{ for index, ip in public_ips }
- address: ${ip}
  role:
    - controlplane
    - worker
    - etcd
  user: ubuntu
  hostname_override: node${index + 1}
  internal_address: ${private_ips[index]}
  docker_socket: /var/run/docker.sock
  ssh_key_path: ./id_rsa
%{ endfor }

kubernetes_version: ${kubernetes_version}

services:
  etcd:
    backup_config:
        interval_hours: ${backup_interval}
        s3backupconfig:
          bucket_name: ${backup_bucket}
          folder: ${backup_folder}
          endpoint: s3.${cluster_region}.amazonaws.com
