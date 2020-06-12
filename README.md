# [Certified Rancher Operator Level 1 Labs](https://academy.rancher.com/courses/course-v1:RANCHER+K101+2019/about)
      
Infrastructure code and tooling to setup and work through labs from the Certified Rancher Operator course.

These labs used [RKE](https://rancher.com/docs/rke/latest/en/installation/) and expect that you have an AWS access and secret key in your environment.

## Lab 1 Download and Install RKE
```bash
brew install rke
brew switch rke 1.1.2
```


## [Lab 2](https://github.com/ccliver/certified-rancher-operator/tree/lab-2-and-3) Create an RKE Configuration File
See https://rancher.com/docs/rke/latest/en/config-options/nodes/


## [Lab 3](https://github.com/ccliver/certified-rancher-operator/tree/lab-2-and-3) - Deploy an RKE Cluster
The "cluster" was deployed on a single Ubuntu 18 node using Terraform. Make can be used with a Docker/Terraform command runner to build the infrastructure

```bash
# Create the lab cluster:
make init apply
rke up
kubectl --kubeconfig ./kube_config_cluster.yml get nodes

# To SSH to the cluster:
ssh -i id_rsa ubuntu@$clusterIp # The cluster ip is in Terraform outputs: `make output`

# To clean up:
make destroy
```


## [Lab 4](https://github.com/ccliver/certified-rancher-operator/tree/lab-4) - Upgrade an RKE Cluster
The cluster deployed in Lab 2/3 is on a previous version so that it can be upgraded in this lab. Added S3 bucket for backups and configured rke to backup etcd on a schedule.

```bash
# Create the lab cluster:
make init apply
rke up

# Create a backup:
rke etcd snapshot-save --config cluster.yml --name lab-4-backup$(date +%F) --s3 --bucket-name rancher-operator-labs-us-west-2-backups

# Update version in variables.tf and update cluster config:
make apply

# Upgrade the cluster:
rke up
rke version
```

## [Lab 5](https://github.com/ccliver/certified-rancher-operator/tree/lab-5) - Add Nodes to an RKE Cluster
Updated Terraform to build multiple nodes and add them to the rke config.

```bash
# Create the lab cluster:
make init apply
rke up
kubectl --kubeconfig ./kube_config_cluster.yml get nodes
NAME      STATUS    ROLES                      AGE       VERSION
node1     Ready     controlplane,etcd,worker   1m        v1.17.6
node2     Ready     controlplane,etcd,worker   1m        v1.17.6
node3     Ready     controlplane,etcd,worker   1m        v1.17.6
```

## [Lab 6](https://github.com/ccliver/certified-rancher-operator/tree/lab-6) - Install Rancher with Docker
This lab just shows how to run the Rancher docker container for a sandbox/testing environment. This should not be used for production workloads.

```bash
make init apply

# SSH into one of the node instances:
sudo docker run -d --restart=unless-stopped -p 80:80 -p 443:443 -v /opt/rancher:/var/lib/rancher rancher/rancher:v2.4.1

# Allow port 443 from your IP and browse to the instance to access the Rancher web console.
```
