#!/bin/bash

set -e

cd fpm

cleanup() {
  status=$?
  if [ "$status" -ne 0 ]; then
    docker compose ps
    docker compose logs php-fpm nginx
  fi
  docker compose down
  exit "$status"
}

trap cleanup EXIT

docker compose down
docker compose up -d php-fpm nginx

ready=false
for attempt in `seq 1 30`
do
	if docker compose exec -T php-fpm bash -c 'wget nginx:8080/index.php -q -O /tmp/response && cat /tmp/response' | grep -q "IT WORKS IN NGINX PHP-FPM"
	then
		ready=true
		break
	fi
	sleep 1
done

if [ "$ready" != true ]; then
	echo "PHP-FPM did not become ready within 30 seconds" >&2
	exit 1
fi

docker compose exec -T php-fpm bash -c 'wget nginx:8080/index.php -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS IN NGINX PHP-FPM" > /dev/null
docker compose exec -T php-fpm bash -c 'wget nginx:8080/ -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS IN NGINX PHP-FPM" > /dev/null
docker compose exec -T php-fpm bash -c 'wget nginx:8080/static.txt -q -O /tmp/response && cat /tmp/response' | grep "IT WORKS STATIC IN NGINX PHP-FPM" > /dev/null

docker compose exec -T php-fpm bash -c 'wget nginx:8080/warning.php -q -O /tmp/response && cat /tmp/response' | grep "warningToGrepFor" > /dev/null
docker compose logs php-fpm | grep warningToGrepFor > /dev/null

if [ ! -z "`docker compose logs nginx | grep 'FastCGI sent in stderr'`" ]
then
	echo "The docker compose logs from nginx returned FastCGI sent in stderr!" 1>&2
	exit 1
fi

docker compose exec -T php-fpm bash -c 'wget nginx:8080/phpinfo.php -q -O /tmp/response && cat /tmp/response' | grep "VARIABLE_NECESSARY_FOR_TEST" > /dev/null
