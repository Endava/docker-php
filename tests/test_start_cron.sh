#!/bin/bash

set -e

CONTAINER_NAME="container-$(uuidgen)"

docker run --rm -d -e 'CRONTAB_USER=www-data' -e 'CRONTAB_CONTENT=* * * * * php -v >/var/log/cron.log' --name $CONTAINER_NAME $DOCKER_REGISTRY_IMAGE start-cron> /dev/null
sleep 70
docker logs $CONTAINER_NAME | grep "PHP" > /dev/null
docker kill $CONTAINER_NAME > /dev/null
