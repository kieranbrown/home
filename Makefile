export OP_ACCOUNT := my.1password.com

MAKEFLAGS += --no-print-directory
SSH_HOST := pi@192.168.1.2

#
#--------------------------------------------------------------------------
##@ Deploy Commands
#--------------------------------------------------------------------------
#
.PHONY: deploy
deploy: bootstrap-env sync-config ## Deploy the docker stack
	@DOCKER_HOST=ssh://$(SSH_HOST) docker compose up -d --remove-orphans --force-recreate

.PHONY: sync-config
sync-config: ## Sync the config folder to the remote host
	@rsync -a --recursive --rsync-path="sudo rsync" config/ $(SSH_HOST):/home/pi/docker

#
#--------------------------------------------------------------------------
##@ Bootstrapping
#--------------------------------------------------------------------------
#
.PHONY: bootstrap
bootstrap: bootstrap-tf bootstrap-env ## Bootstrap the environment

.PHONY: bootstrap-tf
bootstrap-tf: bootstrap-tf-cloudflare-access-settings bootstrap-tf-cloudflare-apps ## Initialize the Terraform workspaces

.PHONY: bootstrap-tf-cloudflare-access-settings
bootstrap-tf-cloudflare-access-settings: # Initialize the Cloudflare Access Settings Terraform workspace
	@echo "cloudflare_api_token = \"$$(op read 'op://Private/cloudflare.com/Tokens/Home')\"" > terraform/cloudflare-access-settings/provider.auto.tfvars
	@terraform -chdir=terraform/cloudflare-access-settings init -reconfigure -backend-config access_key="$$(op read 'op://Private/cloudflare.com/Terraform State Keys/S3 Access Key')" -backend-config secret_key="$$(op read 'op://Private/cloudflare.com/Terraform State Keys/S3 Secret Key')"

.PHONY: bootstrap-tf-cloudflare-apps
bootstrap-tf-cloudflare-apps: # Initialize the Cloudflare Apps Terraform workspace
	@echo "cloudflare_api_token = \"$$(op read 'op://Private/cloudflare.com/Tokens/Home')\"" > terraform/cloudflare-apps/provider.auto.tfvars
	@echo "cloudflare_s3_access_key = \"$$(op read 'op://Private/cloudflare.com/Terraform State Keys/S3 Access Key')\"" >> terraform/cloudflare-apps/provider.auto.tfvars
	@echo "cloudflare_s3_secret_key = \"$$(op read 'op://Private/cloudflare.com/Terraform State Keys/S3 Secret Key')\"" >> terraform/cloudflare-apps/provider.auto.tfvars
	@terraform -chdir=terraform/cloudflare-apps init -reconfigure -backend-config access_key="$$(op read 'op://Private/cloudflare.com/Terraform State Keys/S3 Access Key')" -backend-config secret_key="$$(op read 'op://Private/cloudflare.com/Terraform State Keys/S3 Secret Key')"

.PHONY: bootstrap-env
bootstrap-env: ## Bootstrap the environment variables file
	@touch .env
	@$(MAKE) set-env KEY=CLOUDFLARED_TUNNEL_TOKEN VALUE=$$(terraform -chdir=terraform/cloudflare-apps output -raw tunnel_token)

#
#--------------------------------------------------------------------------
##@ Miscellaneous
#--------------------------------------------------------------------------
#
.PHONY: set-env
set-env:
	@if grep -q "^$(KEY)=" .env; then \
		sed -i.bak "s|^$(KEY)=.*|$(KEY)=$(VALUE)|" .env && rm -f .env.bak; \
	else \
		echo "$(KEY)=$(VALUE)" >> .env; \
	fi

#
#--------------------------------------------------------------------------
## Help
#--------------------------------------------------------------------------
#
.PHONY: help
.DEFAULT_GOAL := help
help: # Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } /^##~ [a-zA-Z_-]+:.*/ { printf "  \033[36m%-15s\033[0m %s\n", substr($$1, 5), $$2 }' $(MAKEFILE_LIST)
