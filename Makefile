export DOCKER_CONTEXT := pi

DASHLANE_TFSTATE_ID = 246CBCB3-BA34-4369-8BD4-D43DCD8F57BC

#
#--------------------------------------------------------------------------
##@ Help
#--------------------------------------------------------------------------
#
.PHONY: help
help: ## Print this help with list of available commands/targets and their purpose
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } /^##~ [a-zA-Z_-]+:.*/ { printf "  \033[36m%-15s\033[0m %s\n", substr($$1, 5), $$2 }' $(MAKEFILE_LIST)

#
#--------------------------------------------------------------------------
##@ Deploy Commands
#--------------------------------------------------------------------------
#
.PHONY: deploy
deploy-docker: ## Deploy the docker stack
	@docker compose up -d

.PHONY: deploy
deploy-terraform: ## Deploy the terraform stack
	@terraform -chdir=terraform/cloudflare-apps apply

#
#--------------------------------------------------------------------------
##@ Bootstrapping
#--------------------------------------------------------------------------
#
.PHONY: bootstrap
bootstrap: bootstrap-docker bootstrap-tf ## Bootstrap the environment

.PHONY: bootstrap-docker
bootstrap-docker: start-docker-desktop create-docker-context ## Bootstrap the Docker environment

.PHONY: bootstrap-tf
bootstrap-tf: bootstrap-tf-cloudflare-apps ## Initialize the Terraform workspaces

.PHONY: bootstrap-tf-cloudflare-apps
bootstrap-tf-cloudflare-apps: ## Initialize the Cloudflare Apps Terraform workspace
	@dcli sync
	@echo "cloudflare_api_token = \"$$(dcli read dl://cloudflare_api_token/content)\"" > terraform/cloudflare-apps/provider.auto.tfvars
	@terraform -chdir=terraform/cloudflare-apps init -reconfigure -backend-config access_key="$$(dcli read dl://$(DASHLANE_TFSTATE_ID)/content?json=cloudflare_s3_access_key)" -backend-config secret_key="$$(dcli read dl://$(DASHLANE_TFSTATE_ID)/content?json=cloudflare_s3_secret_key)"
	@echo "TUNNEL_TOKEN=$$(terraform -chdir=terraform/cloudflare-apps output -raw tunnel_token)" > .env

#
#--------------------------------------------------------------------------
##@ Miscellaneous
#--------------------------------------------------------------------------
#
.PHONY: start-docker-desktop
start-docker-desktop: ## Start the Docker Desktop process
	@case "$$(uname -sr)" in \
		Darwin*) \
			echo "Mac detected. Starting Docker Desktop..."; \
			open -a Docker; \
			;; \
		Linux*WSL*) \
			echo "WSL detected. Starting Docker Desktop..."; \
			powershell.exe -Command "Start-Process 'C:\\Program Files\\Docker\\Docker\\Docker Desktop.exe'"; \
			;; \
		*) \
			echo "Could not detect OS. Please start Docker Desktop manually"; \
			;; \
	esac

	@$(MAKE) -s wait-for-docker

.PHONE: wait-for-docker
wait-for-docker: ## Wait for the docker command to be come available
	@echo "Waiting for Docker Desktop to start..."
	@while ! docker info > /dev/null 2>&1; do \
		echo "Docker is not ready. Retrying in 5 seconds..."; \
		sleep 5; \
	done
	@echo "Docker Desktop is ready!"

.PHONY: create-docker-context
create-docker-context: ## Create the Docker context to communicate with the Raspberry Pi
	@docker context create pi --description "Raspberry Pi" --docker "host=ssh://pi@192.168.1.2" || true
