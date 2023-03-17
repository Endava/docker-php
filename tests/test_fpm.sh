#!/bin/bash

set -e

cd fpm
docker-compose down
docker-compose up -d php-fpm nginx

docker compose exec php-fpm bash -c 'wget nginx:8080/index.php -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS IN NGINX PHP-FPM" > /dev/null
docker compose exec php-fpm bash -c 'wget nginx:8080/ -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS IN NGINX PHP-FPM" > /dev/null
docker compose exec php-fpm bash -c 'wget nginx:8080/static.txt -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS STATIC IN NGINX PHP-FPM" > /dev/null

docker-compose down
