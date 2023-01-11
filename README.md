# draft-docker-php

The PoC for https://github.com/exozet/docker-php-fpm/wiki/Draft-for-new-Structure

## Test it

1. Clone the repo
2. Run for php 8.2

```shell
$ ./build_images.sh exozet/draft-docker-php:8.2.1
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
$ docker run --rm -p 8080:8080 -v `pwd`/public:/usr/src/app/public -it  exozet/draft-docker-php:8.2.1-unit
```

and open http://localhost:8080 to see phpinfo unit.

```shell
$ ab -n 1000 -c 20 http://localhost:8080/
Requests per second:    213.56 [#/sec] (mean)
Time per request:       93.651 [ms] (mean)
```

5. Run the Apache2 Version with:

```shell
$ docker run --rm -p 8080:8080 -v `pwd`/public:/usr/src/app/public -it  exozet/draft-docker-php:8.2.1-apache2
```

and open http://localhost:8080 to see phpinfo on apache2.

Short benchmark:

```shell
$ ab -n 1000 -c 20 http://localhost:8080/
Requests per second:    551.83 [#/sec] (mean)
Time per request:       36.243 [ms] (mean)
```