.DEFAULT_GOAL := help

MY_IP := $(shell curl -s https://ifconfig.me)
TERRAFORM_VERSION := 0.12.24
DOCKER_OPTIONS := -v ${PWD}:/workdir \
-w /workdir/terraform/cluster \
-it \
-e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
-e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
-e TF_VAR_my_ip=${MY_IP}

init: ## Initialize the Terraform state
	docker run ${DOCKER_OPTIONS} hashicorp/terraform:${TERRAFORM_VERSION} init -upgrade=true

plan: ## Run a Terraform plan
	docker run ${DOCKER_OPTIONS} hashicorp/terraform:${TERRAFORM_VERSION} plan

apply: ## Create the resources with Terraform
	docker run ${DOCKER_OPTIONS} hashicorp/terraform:${TERRAFORM_VERSION} apply

destroy: ## Destroy the AWS resources with Terraform
	docker run ${DOCKER_OPTIONS} hashicorp/terraform:${TERRAFORM_VERSION} destroy

output: ## Display outputs from the Terraform state
	docker run ${DOCKER_OPTIONS} hashicorp/terraform:${TERRAFORM_VERSION} output

adhoc: ## Run an ad hoc Terraform command: COMMAND=version make adhoc
	docker run ${DOCKER_OPTIONS} hashicorp/terraform:${TERRAFORM_VERSION} ${COMMAND}

build_new_cluster: ## Standup new RKE cluster and install Rancher into it
	docker run ${DOCKER_OPTIONS} hashicorp/terraform:${TERRAFORM_VERSION} init -upgrade=true
	docker run ${DOCKER_OPTIONS} hashicorp/terraform:${TERRAFORM_VERSION} apply -auto-approve
	rke up
	helm repo add rancher-stable https://releases.rancher.com/server-charts/latest
	kubectl --kubeconfig=$(shell pwd)/kube_config_cluster.yml create namespace cattle-system
	kubectl --kubeconfig=$(shell pwd)/kube_config_cluster.yml apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.0/cert-manager.crds.yaml
	kubectl --kubeconfig=$(shell pwd)/kube_config_cluster.yml create namespace cert-manager
	helm --kubeconfig=$(shell pwd)/kube_config_cluster.yml install cert-manager jetstack/cert-manager --namespace cert-manager --version v0.15.0
	sleep 10
	helm --kubeconfig=$(shell pwd)/kube_config_cluster.yml install rancher rancher-stable/rancher  --namespace cattle-system  --set hostname=rancherlab.ddns.net

cleanup_lab_files: ## Delete cluster config, ssh key, kube config, terraform state.
	rm  -rf terraform/cluster/.terraform/ cluster.rkestate id_rsa kube_config_cluster.yml cluster.yml terraform/cluster/terraform.tfstate*

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
