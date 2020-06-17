# [Certified Rancher Operator Level 1 Labs](https://academy.rancher.com/courses/course-v1:RANCHER+K101+2019/about)
      
Infrastructure code and tooling to setup and work through labs from the Certified Rancher Operator course.

These labs used [RKE](https://rancher.com/docs/rke/latest/en/installation/) and expect that you have an AWS access and secret key in your environment. All labs were done using [Linux Academy](https://linuxacademy.com/) Cloud Sandboxes that only stay active for four hours, so automation was added to make rebuilding the lab environments easier.

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
brew install kubectl

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

## [Lab 9](https://github.com/ccliver/certified-rancher-operator/tree/lab-9) - Deploy Rancher Into RKE
Deploy an HA RKE cluster to host Rancher using their [architecture guidelines](https://rancher.com/docs/rancher/v2.x/en/overview/architecture-recommendations/).

[Rancher Install Guide](https://rancher.com/docs/rancher/v2.x/en/installation/k8s-install/helm-rancher/)

```bash
brew install helm

# Create the lab cluster:
make init apply
rke up

# Install Cert Manager. This lab will use Rancher's self-signed certificates.
export KUBECONFIG=$(pwd)/kube_config_cluster.yml
helm repo add rancher-stable https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.0/cert-manager.crds.yaml
kubectl create namespace cert-manager
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v0.15.0

# Install Rancher:
# NOTE: rancherlab.ddns.net is a CNAME to the NLB address in my no-ip.com account.
helm install rancher rancher-stable/rancher  --namespace cattle-system  --set hostname=rancherlab.ddns.net

# Verify the deploy was successful:
kubectl -n cattle-system get deploy rancher
NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
rancher   3         3         3            3           15m

# Browse to https://rancherlab.ddns.net/
```

## [Lab 10](https://github.com/ccliver/certified-rancher-operator/tree/lab-10) - Backup and Restore an RKE Cluster

```bash
# Create a new cluster if you don't already have one up:
make init apply
rke up

# Install Rancher if needed (see notes for Lab 9).

# Take an etcd backup:
rke etcd snapshot-save # saves to s3

# Terminate the EC2 instances then rebuild them with Terraform:
aws ec2 terminate-instances --region us-west-2 --instance-ids i-0a417d8438afbd300 i-02cd252202bbac05a i-095640dd4ed6f9ef2
rm cluster.yml
make apply
# Comment out nodes 2 and 3
rke up

# Restore snapshot
rke etcd snapshot-restore --name rke_etcd_snapshot_2020-06-15T17:41:50-04:00 --config cluster.yml
rke up

# Uncomment nodes 2 and 3
rke up
```

## [Lab 11](https://github.com/ccliver/certified-rancher-operator/tree/lab-11) - Upgrade Rancher (RKE)

```bash
# Create a new cluster if you don't already have one up:
make init apply
rke up

# Install and older version of Rancher if needed (see notes for Lab 9 but add `--version v2.3.4` or whatever is appropriate).

# Backup cluster
rke etcd snapshot-save --name rke-pre-upgrade-$(date +%F)

# Install new version
helm repo update
helm list --all-namespaces -f rancher -o yaml # To get the namespace
helm get values -n cattle-system rancher -o yaml > values.yaml
helm upgrade rancher rancher-stable/rancher --version 2.4.4 --namespace cattle-system --values values.yaml
```

## [Lab 12](https://github.com/ccliver/certified-rancher-operator/tree/lab-12) - Create an RKE Template

```bash
# Build a new lab Rancher cluster if needed
make build_new_cluster # Update the rancherlab.ddns.net CNAME in no-ip.com with the output NLB address

# Browse to https://rancherlab.ddns.net and create an RKE template (Tools -> RKE Templates) select mostly default settings along with AWS as the provider and a previous version of Kubernetes that's overrideable for a future lab. Click View as YAML to save the template locally if the lab environment will be deleted soon.
```

## [Lab 13](https://github.com/ccliver/certified-rancher-operator/tree/lab-13) - Create a Node Template

```bash
# Build a new lab Rancher cluster if needed (see Lab 12)
# Browse to https://rancherlab.ddns.net and create a Node template (avatar in top right corner -> Node Templates) click Add Template, choose EC2, us-west-2, add the Linux Academy key pair and click Create.
```

## [Lab 14](https://github.com/ccliver/certified-rancher-operator/tree/lab-14) - Deploy an RKE Cluster

```bash
# Build a new lab Rancher cluster if needed (see Lab 12)
# Log into https://rancherlab.ddns.net and click Add Cluster, select the Node Template from lab 13 with 3 nodes etcd/control plane/worker on each, select the RKE template from lab 12, and a previous version of Kubernetes to be upgraded in a future lab. The cluster should go from Provisioning to Active when ready.
```

## [Lab 15](https://github.com/ccliver/certified-rancher-operator/tree/lab-15) - Troubleshooting Rancher API Server Logs

```bash
# Build a new lab Rancher cluster if needed (see Lab 12)
# Check that all pods are up and not in continuous restart then check logs
export KUBECONFIG=$(pwd)/kube_config_cluster.yml
kubectl get pods -n cattle-system -l app=rancher -o wide
kubectl logs -n cattle-system -l app=rancher
```

## [Lab 16](https://github.com/ccliver/certified-rancher-operator/tree/lab-16) - Troubleshooting Worker Nodes

```bash
# Build a new lab Rancher cluster if needed (see Lab 12)
# This lab was just showing how to get on a worker node and check the container runtime (Docker) logs
ssh -i id_rsa ubuntu@34.212.27.107 "docker logs kubelet"
ssh -i id_rsa ubuntu@34.212.27.107 "docker logs kube-proxy"
```

## [Lab 17](https://github.com/ccliver/certified-rancher-operator/tree/lab-17) - Troubleshooting Etcd Nodes
[Rancher etcd troubleshooting docs](https://rancher.com/docs/rancher/v2.x/en/troubleshooting/kubernetes-components/etcd/#check-endpoint-status)

```bash
# Build a new lab Rancher cluster if needed (see Lab 12)
# Log into an etcd node and ensure it's running
ssh -i id_rsa ubuntu@34.212.27.107
ubuntu@ip-10-0-101-168:~$ docker ps -a -f=name=etcd$
CONTAINER ID        IMAGE                                 COMMAND                  CREATED             STATUS              PORTS               NAMES
efebfc21a713        rancher/coreos-etcd:v3.4.3-rancher1   "/usr/local/bin/etcd…"   2 hours ago         Up 2 hours                              etcd 

# Check logs
docker logs etcd

# Check etcd members on all nodes (should be identical on each)
ubuntu@ip-10-0-101-168:~$ docker exec etcd etcdctl member list
2a9782adc0f341f, started, etcd-node2, https://10.0.101.168:2380, https://10.0.101.168:2379,https://10.0.101.168:4001, false
26333bf06aee8883, started, etcd-node3, https://10.0.101.214:2380, https://10.0.101.214:2379,https://10.0.101.214:4001, false
937ea053d06842c1, started, etcd-node1, https://10.0.101.20:2380, https://10.0.101.20:2379,https://10.0.101.20:4001, false

# Check endpoint status
ubuntu@ip-10-0-101-168:~$ docker exec -e ETCDCTL_ENDPOINTS=$(docker exec etcd /bin/sh -c "etcdctl member list | cut -d, -f5 | sed -e 's/ //g' | paste -sd ','") etcd etcdctl endpoint status --write-out table
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://10.0.101.168:2379 |  2a9782adc0f341f |   3.4.3 |   10 MB |     false |      false |         3 |      38642 |              38642 |        |
| https://10.0.101.214:2379 | 26333bf06aee8883 |   3.4.3 |   10 MB |     false |      false |         3 |      38642 |              38642 |        |
|  https://10.0.101.20:2379 | 937ea053d06842c1 |   3.4.3 |   10 MB |      true |      false |         3 |      38642 |              38642 |        |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

# Check endpoint health
ubuntu@ip-10-0-101-168:~$ docker exec -e ETCDCTL_ENDPOINTS=$(docker exec etcd /bin/sh -c "etcdctl member list | cut -d, -f5 | sed -e 's/ //g' | paste -sd ','") etcd etcdctl endpoint health
https://10.0.101.168:2379 is healthy: successfully committed proposal: took = 15.29209ms
https://10.0.101.20:2379 is healthy: successfully committed proposal: took = 14.723183ms
https://10.0.101.214:2379 is healthy: successfully committed proposal: took = 20.665624ms
```

## [Lab 18](https://github.com/ccliver/certified-rancher-operator/tree/lab-18) - Troubleshooting Control Plane Issues
[Rancher control plane troubleshooting](https://rancher.com/docs/rancher/v2.x/en/troubleshooting/kubernetes-components/controlplane/)

```bash
# Build a new lab Rancher cluster if needed (see Lab 12)
# Log into a control plane node in your test cluster: from the web console click on the cluster then nodes, click the node control button on the right and download SSH keys
ssh -i test-ec2/id_rsa ubuntu@52.12.73.131

# Make sure all containers are up
ubuntu@test-ec2:~$ sudo docker ps -a -f=name='kube-apiserver|kube-controller-manager|kube-scheduler'
CONTAINER ID        IMAGE                                 COMMAND                  CREATED             STATUS              PORTS               NAMES
f781fd5bcedb        rancher/hyperkube:v1.16.10-rancher2   "/opt/rke-tools/entr…"   8 minutes ago       Up 8 minutes                            kube-scheduler
d2fd16368a41        rancher/hyperkube:v1.16.10-rancher2   "/opt/rke-tools/entr…"   8 minutes ago       Up 8 minutes                            kube-controller-manager
b7afe9e26c2b        rancher/hyperkube:v1.16.10-rancher2   "/opt/rke-tools/entr…"   8 minutes ago       Up 8 minutes                            kube-apiserver

# Then check their logs
sudo docker logs kube-apiserver
sudo docker logs kube-controller-manager
sudo docker logs kube-scheduler
```

## [Lab 19](https://github.com/ccliver/certified-rancher-operator/tree/lab-19) - Troubleshooting the Network Overlay

```bash
# Build a new lab Rancher cluster if needed (see Lab 12)
```
Follow guide [here](https://academy.rancher.com/assets/courseware/v1/5503818b9b8e5c3edc4290c2ceaf0fa5/asset-v1:RANCHER+K101+2019+type@asset+block/Lab-19-Troubleshooting-the-Network-Overlay.pdf) to do a network overlay test.

## [Lab 20](https://github.com/ccliver/certified-rancher-operator/tree/lab-20) - Upgrade Downstream RKE Clusters

```bash
# Build a new lab Rancher cluster on an older version if needed (see Lab 12)
# Snapshot the downstream cluster (this can be done in the web console in the Global cluster view, click on the cluster edit button, then Snapshot Now
# Edit the cluster, choose a newer version, and the Rancher will perform a rolling upgrade on one node at a time
```

## [Lab 21](https://github.com/ccliver/certified-rancher-operator/tree/lab-21) - kubectl and the Rancher CLI

```bash
# Build a new lab Rancher cluster on an older version if needed (see Lab 12)
```

You can access a cluster with `kubectl` in a couple ways:
  * Log into the UI, click on a cluster, click Launch kubectl to get an in-browser kubectl configured for the cluster.
  * On the same screen click Kubeconfig file and copy that to `~/.kube/config ` or use `KUBECONFIG` to set it in your environment.

Alternatively, you can use the [rancher cli](https://rancher.com/docs/rancher/v2.x/en/cli/) to manage all downstream clusters managed by Rancher
```bash
brew install rancher-cli
# In the UI navigate to your avatar, click API & Keys, Add Key, give it a description, set it to expire in a day and "no scope" to work on all clusters
export RANCHER_TOKEN="$ACCESS_KEY:$SECRET_KEY"
rancher login --toke "$RANCHER_TOKEN" --name rancher-cert
rancher login --token "$RANCHER_TOKEN" https://rancherlab.ddns.net/v3
[carl@Carls-MacBook-Air-2:certified-rancher-operator (lab-21)]$ rancher kubectl get nodes
NAME      STATUS    ROLES                      AGE       VERSION
node1     Ready     controlplane,etcd,worker   15m       v1.17.6
node2     Ready     controlplane,etcd,worker   15m       v1.17.6
node3     Ready     controlplane,etcd,worker   15m       v1.17.6
[carl@Carls-MacBook-Air-2:certified-rancher-operator (lab-21)]$ rancher context switch
NUMBER    CLUSTER NAME   PROJECT ID        PROJECT NAME   PROJECT DESCRIPTION
1         test           c-48d5j:p-66756   System         System project created for the cluster
2         test           c-48d5j:p-pm6lb   Default        Default project created for the cluster
3         local          local:p-9x8rp     Default        Default project created for the cluster
4         local          local:p-bbd7x     System         System project created for the cluster
Select a Project:2
INFO[0003] Setting new context to project Default
INFO[0003] Saving config to /Users/carl/.rancher/cli2.json
[carl@Carls-MacBook-Air-2:certified-rancher-operator (lab-21)]$ rancher kubectl get nodes
NAME                                         STATUS    ROLES                      AGE       VERSION
ip-10-0-101-238.us-west-2.compute.internal   Ready     controlplane,etcd,worker   3m        v1.17.6
```

## [Lab 22](https://github.com/ccliver/certified-rancher-operator/tree/lab-22) - Activate and Use Advanced Monitoring

```bash
# Build a new lab Rancher cluster on an older version if needed (see Lab 12)
# From the cluster overview pane, select “Enable Monitoring to see live metrics” from the right corner of the screen
```

## [Lab 23](https://github.com/ccliver/certified-rancher-operator/tree/lab-23) - Activate and Use Advanced Monitoring

See [alert docs](https://rancher.com/docs/rancher/v2.x/en/cluster-admin/tools/alerts/) for information on setting up various types of alerts for a cluster.

## [Lab 24](https://github.com/ccliver/certified-rancher-operator/tree/lab-24) - Create a New Project with Dedicated Namespaces

Projects in Rancher allow you to group kubernetes namespaces and apply policy and configuration to them.
To create a project:
  * Navigate to a cluster in the UI
  * Click Projects/Namespaces
  * Add Project
  * Name the project and define appropriate parameters
  * Once created you'll have an Add Namespace button to add kubernetes namespaces to it

## [Lab 25](https://github.com/ccliver/certified-rancher-operator/tree/lab-25) - Create a Non-Privileged User

Creating a new user:
  * Navigate to the Global view then click on Security -> Users and create a user
  * Navigate to a cluster project
  * Select Edit
  * Under Members -> Add Member -> Enter name and role and click Save

## [Lab 26](https://github.com/ccliver/certified-rancher-operator/tree/lab-26) - Set and Test Resource Quota and Limits on Projects

Set resource limits
  * Navigate to a cluster project list
  * Click Edit on a project
  * Add Quotas under Resource Quotas

## [Lab 27](https://github.com/ccliver/certified-rancher-operator/tree/lab-27) - Move a Namespace Between Projects

A namespace and all of its workloads can be moved between projects. If there are no resource quotas navigate to Projects/Namespaces from the cluster overview screen, check the project, and click Move. If the origin project has resource quotas those will need to be removed in the project's edit page. If the destination project has resource quotas those will need to be removed as well.

## [Lab 28](https://github.com/ccliver/certified-rancher-operator/tree/lab-28) - Activating Project Monitoring

After advanced monitoring has been turned on for a cluster, you can setup monitoring at the project level that's independent. To do that navigate to the project list and click Edit on the desired project, then Tools -> Monitoring, set appropriate values and Enable.
