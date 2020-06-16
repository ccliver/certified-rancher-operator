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
# Build a new lab Rancher cluster if needed
make build_new_cluster # Update the rancherlab.ddns.net CNAME in no-ip.com with the output NLB address

# Browse to https://rancherlab.ddns.net and create a Node template (avatar in top right corner -> Node Templates) click Add Template, choose EC2, us-west-2, add the Linux Academy key pair and click Create.
```
