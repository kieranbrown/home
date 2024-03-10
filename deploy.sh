#!/bin/bash
set -euxo pipefail

until DOCKER_HOST=ssh://dietpi@pi01 docker compose -f docker-compose.pi01.yaml up -d --remove-orphans
do sleep 1
done

until DOCKER_HOST=ssh://kieran@nas docker compose -f docker-compose.nas.yaml up -d --remove-orphans
do sleep 1
done
