#!/bin/bash

set -e

CONTAINER_NAME="container-$(uuidgen)"

docker run --rm -d --entrypoint bash --name $CONTAINER_NAME $DOCKER_REGISTRY_IMAGE -c "sleep 3000" > /dev/null
docker exec $CONTAINER_NAME mkdir /usr/src/app/public
docker exec $CONTAINER_NAME bash -c "echo '<?php echo \"\\nIT WORKS IN FRANKENPHP\\n\";' > /usr/src/app/public/index.php"
docker exec $CONTAINER_NAME bash -c "echo 'IT WORKS STATIC IN FRANKENPHP' > /usr/src/app/public/static.txt"
docker exec -d $CONTAINER_NAME /usr/sbin/frankenphp run --config /etc/Caddyfile
sleep 5
docker exec $CONTAINER_NAME bash -c 'wget --no-check-certificate https://localhost/index.php -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS IN FRANKENPHP" > /dev/null
docker exec $CONTAINER_NAME bash -c 'wget --no-check-certificate https://localhost/ -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS IN FRANKENPHP" > /dev/null
docker exec $CONTAINER_NAME bash -c 'wget --no-check-certificate https://localhost/static.txt -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS STATIC IN FRANKENPHP" > /dev/null
docker kill $CONTAINER_NAME > /dev/null
