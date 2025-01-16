#!/bin/bash

set -e

cd fpm
docker-compose down
docker-compose up -d php-fpm nginx

docker compose exec php-fpm bash -c 'wget nginx:8080/index.php -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS IN NGINX PHP-FPM" > /dev/null
docker compose exec php-fpm bash -c 'wget nginx:8080/ -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS IN NGINX PHP-FPM" > /dev/null
docker compose exec php-fpm bash -c 'wget nginx:8080/static.txt -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS STATIC IN NGINX PHP-FPM" > /dev/null

docker compose exec php-fpm bash -c 'wget nginx:8080/warning.php -q -O /tmp/response && cat /tmp/response' | grep "warningToGrepFor" > /dev/null
docker compose logs php-fpm | grep warningToGrepFor > /dev/null

if [ ! -z "`docker compose logs nginx | grep 'FastCGI sent in stderr'`" ]
then
	echo "The docker compose logs from nginx returned FastCGI sent in stderr!" 1>&2
	exit 1
fi

docker compose exec php-fpm bash -c 'wget nginx:8080/phpinfo.php -q -O /tmp/response && cat /tmp/response' | grep "VARIABLE_NECESSARY_FOR_TEST" > /dev/null

docker-compose down
