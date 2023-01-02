#!/bin/bash

set -e

CONTAINER_NAME="container-$(uuidgen)"

docker run --rm -d --entrypoint bash --name $CONTAINER_NAME $DOCKER_REGISTRY_IMAGE -c "sleep 3000"> /dev/null
docker exec -d $CONTAINER_NAME mkdir /usr/src/app/public
docker exec -d $CONTAINER_NAME bash -c "echo '<?php echo \"\\nIT WORKS IN NGINX UNIT\\n\";' > /usr/src/app/public/index.php"
docker exec -d $CONTAINER_NAME unitd --no-daemon --user www-data --group www-data
docker exec $CONTAINER_NAME bash -c 'wget localhost:8080 -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS IN NGINX UNIT" > /dev/null
docker kill $CONTAINER_NAME > /dev/null
