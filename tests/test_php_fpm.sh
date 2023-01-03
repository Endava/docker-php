#!/bin/bash

set -e

CONTAINER_NAME="container-$(uuidgen)"

docker run --rm -d --entrypoint bash --name $CONTAINER_NAME $DOCKER_REGISTRY_IMAGE -c "sleep 3000"> /dev/null
docker exec $CONTAINER_NAME mkdir /usr/src/app/public
docker exec $CONTAINER_NAME bash -c "echo '<?php echo \"\\nIT WORKS IN NGINX PHP-FPM\\n\";' > /usr/src/app/public/index.php"
docker exec $CONTAINER_NAME apk add -U nginx > /dev/null
docker exec $CONTAINER_NAME bash -c "echo 'server { listen 8080 default_server; root /usr/src/app/public;     location / { try_files \$uri /index.php\$is_args\$args; }
 location ~ \.php\$ {fastcgi_pass 127.0.0.1:9000; fastcgi_split_path_info ^(.+\.php)(/.*)$; include fastcgi_params; fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name; fastcgi_param DOCUMENT_ROOT \$realpath_root;}}' > /etc/nginx/http.d/default.conf"
docker exec -d $CONTAINER_NAME php-fpm --nodaemonize
docker exec -d $CONTAINER_NAME nginx -g 'daemon off;'
docker exec $CONTAINER_NAME bash -c 'wget localhost:8080/ -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS IN NGINX PHP-FPM" > /dev/null
docker kill $CONTAINER_NAME > /dev/null
