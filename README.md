# endava/docker-php:8.0.x

## Usage

1. Create a folder public with an index.php

```shell
$ mkdir public
$ echo '<?php phpinfo();' > public/index.php
```

2. Run the NGINX Unit Version with:

```shell
$ docker run --rm -p 8080:8080 -v `pwd`/public:/usr/src/app/public -it  endava/php:8.0.28-unit
```

and open http://localhost:8080 to see phpinfo unit.

```shell
$ ab -n 1000 -c 20 http://localhost:8080/
Requests per second:    1646.91 [#/sec] (mean)
Time per request:       12.144 [ms] (mean)
```

3. Run the Apache2 Version with:

```shell
$ docker run --rm -p 8080:8080 -v `pwd`/public:/usr/src/app/public -it  endava/php:8.0.28-apache2
```

and open http://localhost:8080 to see phpinfo on apache2.

Short benchmark:

```shell
$ ab -n 1000 -c 20 http://localhost:8080/
Requests per second:    2844.56 [#/sec] (mean)
Time per request:       7.031 [ms] (mean)
```

4. Run the php fpm version with (e.g. docker-compose.yml)

Create a `docker-compose.yml`:

```yaml
version: "2.1"

services:
  php-cli:
    image: endava/php:8.0.28
    volumes:
      - ./:/usr/src/app
    user: "${UID-www-data}:${GID-www-data}"
    entrypoint: bash
    depends_on:
      - nginx
  php-fpm:
    image: endava/php:8.0.28-fpm
    user: "${UID-www-data}:${GID-www-data}"
    volumes:
      - ./:/usr/src/app
  nginx:
    image: nginx:1.11.10
    depends_on:
      - php-fpm
    ports:
      - "8080:8080"
    volumes:
      - ./:/usr/src/app
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
```

Create a `nginx.conf`:
```text
server {
    listen 8080 default_server;
    root /usr/src/app/public;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ \.php$ {
        fastcgi_pass php-fpm:9000;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
    }
}
```

Launch the php cli bash:

``` console
$docker-compose run php-cli
⠿ Network docker-php_default
⠿ Container docker-php-php-fpm-1
⠿ Container docker-php-nginx-1
bash-5.1$ php -v
PHP 8.0.28 (cli) (built: Feb 14 2023 20:50:39) ( NTS )
Copyright (c) The PHP Group
Zend Engine v4.0.28, Copyright (c) Zend Technologies
    with Zend OPcache v8.0.28, Copyright (c), by Zend Technologies
    with Xdebug v3.1.6, Copyright (c) 2002-2022, by Derick Rethans
```

and open http://localhost:8080/ to see phpinfo with FPM/FastCGI as server api.

# Best Practices

The following best practices are included in the default configuration files for php.ini, php-fpm, nginx unit and apache2. This section is meant to describe what is implemented and why it has been done like this.

## nginx unit

This docker image contains a [files/unit/unit-default.json](files/unit/unit-default.json) which is used as default /var/lib/unit/conf.json for the boot of nginx unit.

The property `applications.php.targets.*.root` is set to `/usr/src/app/public` to deliver `index.php` from this folder.

The property `applications.phpapp.processes` and it's content:

```json
{
   "max": 32,
   "spare": 2,
   "idle_timeout": 10
}
```

is set to ensure that nginx unit uses more then one process (which is the default).

The property `access_log` is set to `/dev/stdout` to ensure that we have the access log as output to the docker container.

The `listeners` are set to port `8080`

```json
{
  "*:8080": {
    "pass": "routes"
  }
}
```

to be sure that the server is reachable via port 8080.

The `-unit` tagged docker image (because it has attached this snippet at [files/unit/unit.Dockerfile.snippet.txt](files/unit/unit.Dockerfile.snippet.txt) has two settings set:

* The `STOPSIGNAL` is set to `SIGQUIT` to allow graceful stop.
* The `CMD` has `unitd --no-daemon` set to run unitd in foreground
* The `CMD` has `--user www-data` and `--group www-data` to ensure it's running www-data as user/group
* The `CMD` has `--log /dev/stdout`
* THE `CMD` has `--control unix:/run/unit/control.unit.sock --pid /run/unit/unit.pid` set to be writeable by www-data

## apache2

This docker image contains a [files/apache2/apache2-default.conf](files/apache2/apache2-default.conf) which is used as default /etc/apache2/conf.d/00_apache2-default.conf for the boot of apache2.

The directive `DocumentRoot` is set to `/usr/src/app/public` to deliver `index.php` from this folder.

The directive `ErrorLog` in `httpd.conf` is set to `/dev/stderr` to ensure that we have the error log as output to the docker container.

The directive `CustomLog` (which includes `TransferLog`) in `httpd.conf` is set to `/dev/stdout` to ensure that we have the access log and normal log as output to the docker container.

The `/etc/apache2/httpd.conf` is adjusted to enable `LoadModule rewrite_module`.

The default `Listen 8080` in `httpd.conf` to ensure that the server is reachable via port 8080.

The default user and group in `httpd.conf` is set to `www-data`.


The `-apache2` tagged docker image (because it has attached this snippet at [files/apache2/apache2.Dockerfile.snippet.txt](files/apache2/apache2.Dockerfile.snippet.txt) has two settings set:

* The `STOPSIGNAL` is set to `WINCH` to allow graceful stop.
* The `CMD` has `httpd -DFOREGROUND` set to run httpd in foreground

## php.ini Variables

We made it possible for you to override special php ini settings with environment variables: (see included [php.ini](./files/php.ini) for a full list, see [this blog post for reasons](https://dracoblue.net/dev/use-environment-variables-for-php-ini-settings-in-docker/)).

Some special settings for this docker image (can be found in the [Dockerfile](./Dockerfile)):

    # default is: 30, but we want to be able to have it configurable for server and cli the same
    PHP_MAX_EXECUTION_TIME=0 \
    # default is: GPRCS, but is necessary to make environment variables available in nginx unit, too 
    PHP_VARIABLES_ORDER="EGPCS" \
    # default is: 0, but we need logs to stdout. https://www.php.net/manual/en/errorfunc.configuration.php#ini.log-errors
    PHP_LOG_ERRORS="1" \
    # default is: no value, but grpc breaks pcntl if not activated.
    # https://github.com/grpc/grpc/blob/master/src/php/README.md#pcntl_fork-support \
    PHP_GRPC_ENABLE_FORK_SUPPORT='1' \
    # default is: no value, but grpc breaks pcntl if not having a fork support with a poll strategy.
    # https://github.com/grpc/grpc/blob/master/doc/core/grpc-polling-engines.md#polling-engine-implementations-in-grpc
    PHP_GRPC_POLL_STRATEGY='epoll1' \
    

## Sending E-Mail

Since there is no exim or something like this running in your docker image, it's not possible to send emails with `mail()`
 out of the box on php with docker. But this image ships with [msmtp](https://wiki.archlinux.org/index.php/msmtp) and a configurable sendmail path.

Thus you can configure send mail for instance like this:

```text
PHP_SENDMAIL_PATH=/usr/bin/msmtp -t --host=smtp.example.org --port=1025
```

and `mail('hans@example.org', 'subject', 'message!');` will use the smtp host at `smtp.example.org`.

We recommend to use a service like [mailhog](https://hub.docker.com/r/mailhog/mailhog/) as a service to fetch mails
on development.

This in your `docker-compose.yaml`:

```yaml
services:
  mailhog:
    image: mailhog/mailhog:v1.0.0
    ports:
      - "1025"
      - "8025:8025"
```

makes a mailhog server at `http://127.0.0.1:8025` available. If you set 

```text
PHP_SENDMAIL_PATH=/usr/bin/msmtp -t --host=mailhog --port=1025
```

all your mails will be visible there.

## Using "Cron": Setting `CRONTAB_CONTENT` and `CRONTAB_USER`

You can define the crontab's content with an environment variable like this:

`docker-compose.yml`:
```yaml
services:
  import-data-cron:
    image: endava/php:8.0.28
    command: start-cron
    environment:
      - 'CRONTAB_USER=www-data'
      - |
         CRONTAB_CONTENT=
         */10 * * * * cd /usr/src/app && php run-import.php >> /var/log/cron.log 2>&1
    volumes:
      - ./:/usr/src/app:cached
```

It's very important to specify `/var/log/cron.log` as response for all outputs of your
cronjob, since crontab will otherwise try to send the response by email, which cannot work
in this docker setup.

We recommend to use **one** cronjob/container to ensure that your monitoring, restarting, recovery and
 so on works properly. Otherwise you don't **know**, which of your cronjobs is consuming which amount of
 resources.

## Alternative way to use "Cron": Mounting `/etc/cron.d` OR setting `CRON_PATH`

**Hint:** Please use this way only, if the previous way (setting `CRONTAB_CONTENT` Environment variable) does not work for your
project.

Create your crontab directory in project folder and put all your cron files in this directory.

`crontabs` directory:
```text
  - one-cron
  - other-cron
```
`one-cron` file:
```console
*/10 * * * * root php your-command/script >> /var/log/cron.log 2>&1
# Don't remove the empty line at the end of this file. It is required to run the cron job
```

Even though it's possible, we do not recommend to use **multiple** cronjob/container in one crontab file. This makes
monitoring the different cron jobs harder for your operation/monitoring/alerting tools.

Usage in your `docker-compose.yml`:
```yaml
services:
  crontab:
    image: endava/php:8.0.28
    command: start-cron
    volumes:
      - ./:/usr/src/app
      - ./crontabs:/etc/cron.d
```

If your cron folder is already part or your project, you can override the
cron location with the `CRON_PATH` environment variable:

```yaml
services:
  crontab:
    image: endava/php:8.0.28
    command: start-cron
    environment:
      - CRON_PATH=/usr/src/app/crontabs
    volumes:
      - ./:/usr/src/app
```

# Contributing
Please refer to [CONTRIBUTING.md](CONTRIBUTING.md). 

# License
Please refer to [LICENSE](LICENSE). 
