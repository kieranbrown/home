export DOCKER_CONTEXT := pi

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
##@ Commands
#--------------------------------------------------------------------------
#
.PHONY: bootstrap
bootstrap: start-docker-desktop create-docker-context ## Bootstrap the environment

.PHONY: deploy
deploy: ## Deploy the docker stack
	@docker compose up -d --pull=always

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
