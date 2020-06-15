.DEFAULT_GOAL := help

TERRAFORM_VERSION := 0.12.24
DOCKER_OPTIONS := -v ${PWD}:/workdir \
-w /workdir/terraform/cluster \
-it \
-e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
-e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

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

cleanup_lab_files: ## Delete cluster config, ssh key, kube config, etc.
	rm  -rf terraform/cluster/.terraform/ cluster.rkestate id_rsa kube_config_cluster.yml cluster.yml 

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
