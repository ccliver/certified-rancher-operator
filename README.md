# [Certified Rancher Operator Level 1 Labs](https://academy.rancher.com/courses/course-v1:RANCHER+K101+2019/about)
      
Infrastructure code and tooling to setup and work through labs from the Certified Rancher Operator course.


## Lab 1 Download and Install RKE
`brew install rke`


## Lab 2 Create an RKE Configuration File
See https://rancher.com/docs/rke/latest/en/config-options/nodes/


## Lab 3 - Deploy an RKE Cluster
The "cluster" was deployed on a single Ubuntu 18 node using Terraform. Make can be used with a Docker/Terraform command runner to build the infrastructure

### Usage
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
