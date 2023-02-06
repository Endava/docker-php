# draft-docker-php

The PoC for https://github.com/exozet/docker-php-fpm/wiki/Draft-for-new-Structure

## Test it

1. Clone the repo
2. Run for php 8.1

```shell
$ ./build_images.sh exozet/draft-docker-php:8.1.14
```

If you lack specific emulators (for running the multiarch build), install:

```shell
docker run --privileged --rm tonistiigi/binfmt --install arm64,riscv64,arm,386
```

3. Create a folder public with an index.php

```shell
$ mkdir public
$ echo '<?php phpinfo();' > public/index.php
```

4. Run the NGINX Unit Version with:

```shell
$ docker run --rm -p 8080:8080 -v `pwd`/public:/usr/src/app/public -it  exozet/draft-docker-php:8.1.14-unit
```

and open http://localhost:8080 to see phpinfo unit.

```shell
$ ab -n 1000 -c 20 http://localhost:8080/
Requests per second:    1646.91 [#/sec] (mean)
Time per request:       12.144 [ms] (mean)
```

5. Run the Apache2 Version with:

```shell
$ docker run --rm -p 8080:8080 -v `pwd`/public:/usr/src/app/public -it  exozet/draft-docker-php:8.1.14-apache2
```

and open http://localhost:8080 to see phpinfo on apache2.

Short benchmark:

```shell
$ ab -n 1000 -c 20 http://localhost:8080/
Requests per second:    2844.56 [#/sec] (mean)
Time per request:       7.031 [ms] (mean)
```


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

# Contributing
Please refer to [CONTRIBUTING.md](CONTRIBUTING.md). 

# License
Please refer to [LICENSE](LICENSE). 
