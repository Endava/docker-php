FROM alpine:3.19.1 as PHPZTSBUILDER

RUN apk add --no-cache libc6-compat
RUN apk add --no-cache alpine-sdk
RUN apk add --no-cache git git-lfs bash vim vimdiff curl

RUN adduser -h /workspace -s /bin/bash -S -D -u 501 -G dialout alpiner
RUN addgroup alpiner abuild

RUN apk add --no-cache sudo
RUN echo "alpiner ALL = NOPASSWD: ALL" > /etc/sudoers.d/alpiner

WORKDIR /workspace/
USER alpiner
RUN abuild-keygen -n -a
USER root
RUN cp /workspace/.abuild/*.rsa.pub /etc/apk/keys/
USER alpiner

RUN git clone -b 3.19-stable --single-branch --depth=1 https://gitlab.alpinelinux.org/alpine/aports

WORKDIR /workspace/aports/community/php83
RUN cp -rf /workspace/aports/community/php83 /workspace/aports/community/phpzts83
WORKDIR /workspace/aports/community/phpzts83
RUN sed -i -e 's/pkgname=php83/pkgname=phpzts83/' APKBUILD
# hadolint ignore=SC2016
RUN sed -i -e 's/\$pkgname-fpm.initd/php83-fpm.initd/' APKBUILD
# hadolint ignore=SC2016
RUN sed -i -e 's/\$pkgname-fpm.logrotate/php83-fpm.logrotate/' APKBUILD
# hadolint ignore=SC2016
RUN sed -i -e 's/\$pkgname-module.conf/php83-module.conf/' APKBUILD
# hadolint ignore=SC2016
RUN sed -i -e 's/\$pkgname-fpm-version-suffix.patch/php83-fpm-version-suffix.patch/' APKBUILD
# hadolint ignore=SC2016
RUN sed -i -e 's/php\$_suffix-module.conf/php83-module.conf/' APKBUILD
RUN sed -i -e 's/--host/--enable-zts --enable-zend-max-execution-timers --enable-zend-timer --disable-zend-signals --host/' APKBUILD
RUN echo "" >> disabled-tests.list
RUN echo "ext/posix/tests/bug75696.phpt" >> disabled-tests.list
RUN echo "ext/posix/tests/posix_getgrgid.phpt" >> disabled-tests.list
RUN echo "ext/posix/tests/posix_getgrgid_basic.phpt" >> disabled-tests.list
RUN echo "ext/posix/tests/posix_getgrnam_basic.phpt" >> disabled-tests.list
RUN echo "ext/posix/tests/posix_getpwnam_basic_01.phpt" >> disabled-tests.list
RUN echo "ext/posix/tests/posix_getpwuid_basic.phpt" >> disabled-tests.list
RUN echo "sapi/cli/tests/bug61546.phpt" >> disabled-tests.list
RUN echo "sapi/fpm/tests/socket-uds-numeric-ugid-nonroot.phpt" >> disabled-tests.list
RUN echo "ext/imap/tests/imap_mutf7_to_utf8.phpt" >> disabled-tests.list
RUN echo "ext/imap/tests/imap_utf8_to_mutf7_basic.phpt" >> disabled-tests.list
RUN echo "ext/curl/tests/curl_basic_009.phpt" >> disabled-tests.list
RUN echo "ext/curl/tests/curl_basic_024.phpt" >> disabled-tests.list
RUN echo "ext/standard/tests/file/bug52820.phpt" >> disabled-tests.list

USER root
RUN apk update
USER alpiner
RUN arch
RUN uname -m
RUN abuild -A
RUN abuild checksum && abuild -r
WORKDIR /workspace/aports/community/unit
# make phpver3 to be phpzts83
RUN sed -i -e 's/_phpver3=83/_phpver3=zts83/' APKBUILD
# make unit-php83 find the lphpzts83.so
# hadolint ignore=SC2016
RUN sed -i -e 's/.\/configure php --module=php\$_phpver3/sed -i -e "s\/lphp\/lphpzts\/g" auto\/modules\/php \&\& .\/configure php --module=php\$_phpver3/g' APKBUILD
RUN sed -i -e 's/_allow_fail=no/_allow_fail=yes/g' APKBUILD

RUN abuild checksum && abuild -r

FROM alpine:3.19.1

ARG PHP_VERSION="8.3.8"
ARG PHP_PACKAGE_BASENAME="phpzts83"
ARG PHP_FPM_BINARY_PATH="/usr/sbin/php-fpmzts83"
ARG UNIT_VERSION="1.32.1"
ARG APACHE2_VERSION="2.4.59"
ENV PHP_VERSION=$PHP_VERSION
ENV PHP_PACKAGE_BASENAME=$PHP_PACKAGE_BASENAME
ENV PHP_FPM_BINARY_PATH=$PHP_FPM_BINARY_PATH
ENV UNIT_VERSION=$UNIT_VERSION
ENV APACHE2_VERSION=$APACHE2_VERSION

RUN apk upgrade -U # 2023/01/05 to fix CVE-2022-3996

RUN apk add --no-cache \
    libc6-compat \
    git \
    git-lfs \
    mysql-client \
    mariadb-connector-c \
    vim \
    rsync \
    sshpass \
    bzip2 \
    msmtp \
    unzip \
    make \
    openssh-client \
    bash \
    sed

# Ensure we have www-data added with alpine's default uid/gid: 82
# (e.g. https://git.alpinelinux.org/aports/tree/main/apache2/apache2.pre-install for reference)
RUN set -eux; \
	adduser -u 82 -D -S -G www-data www-data

COPY --from=PHPZTSBUILDER /workspace/packages/community /opt/custom-packages
# hadolint ignore=DL3003,SC2035,SC2046
RUN apk add --no-cache abuild && \
     abuild-keygen -a -n && \
     rm /opt/custom-packages/*/APKINDEX.tar.gz && \
     cd /opt/custom-packages/*/ && \
     apk index -vU --allow-untrusted -o APKINDEX.tar.gz *.apk --no-warnings --rewrite-arch $(abuild -A) && \
     abuild-sign -k ~/.abuild/*.rsa /opt/custom-packages/*/APKINDEX.tar.gz && \
     cp ~/.abuild/*.rsa.pub /etc/apk/keys/ && \
     apk del abuild
# hadolint ignore=SC3037
RUN echo -e "/opt/custom-packages\n$(cat /etc/apk/repositories)" > /etc/apk/repositories

RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}~=${PHP_VERSION} ${PHP_PACKAGE_BASENAME}-embed~=${PHP_VERSION}

ENV PHP_INI_DIR=/etc/${PHP_PACKAGE_BASENAME}/

RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-bcmath
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-calendar
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-curl
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-ctype
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-gd
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-fileinfo
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-ftp
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-iconv
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-intl
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-ldap
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-mbstring
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-mysqli
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-opcache
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-openssl
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pcntl
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pdo_mysql
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pdo_pgsql
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pdo_sqlite
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pear
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-tokenizer
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-session

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-amqp
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers rabbitmq-c-dev ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install amqp \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/amqp.so \
    && echo "extension=amqp" > /etc/$PHP_PACKAGE_BASENAME/conf.d/40_amqp.ini \
    && apk del --no-network .build-deps \
    && apk add --no-cache rabbitmq-c

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-apcu
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install apcu \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/apcu.so \
    && echo "extension=apcu" > /etc/$PHP_PACKAGE_BASENAME/conf.d/apcu.ini \
    && apk del --no-network .build-deps

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-igbinary
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install igbinary \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/igbinary.so \
    && echo "extension=igbinary" > /etc/$PHP_PACKAGE_BASENAME/conf.d/10_igbinary.ini \
    && apk del --no-network .build-deps

# FIXME: # FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-imagick
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers imagemagick imagemagick-dev imagemagick-libs ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install imagick \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/imagick.so \
    && echo "extension=imagick" > /etc/$PHP_PACKAGE_BASENAME/conf.d/00_imagick.ini \
    && apk del --no-network .build-deps \
    && apk add --no-cache imagemagick imagemagick-libs libgomp

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-msgpack
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install msgpack \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/msgpack.so \
    && echo "extension=msgpack" > /etc/$PHP_PACKAGE_BASENAME/conf.d/10_msgpack.ini \
    && apk del --no-network .build-deps

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-memcached
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers zlib-dev libmemcached-dev cyrus-sasl-dev libevent-dev ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install -D 'enable-memcached-igbinary="yes" enable-memcached-session="yes" enable-memcached-json="yes" enable-memcached-protocol="yes" enable-memcached-msgpack="yes"' memcached \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/memcached.so \
    && echo "extension=memcached" > /etc/$PHP_PACKAGE_BASENAME/conf.d/20_memcached.ini \
    && apk del --no-network .build-deps \
    && apk add --no-cache libmemcached-libs libevent

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-protobuf
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install protobuf \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/protobuf.so \
    && echo "extension=protobuf" > /etc/$PHP_PACKAGE_BASENAME/conf.d/protobuf.ini \
    && apk del --no-network .build-deps

RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pgsql
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-phar
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-posix

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-redis
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers lz4-dev zstd-dev ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install -D 'enable-redis-igbinary="yes" enable-redis-lz4="yes" with-liblz4="yes" enable-redis-lzf="yes" enable-redis-zstd="yes"' redis \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/redis.so \
    && echo "extension=redis" > /etc/$PHP_PACKAGE_BASENAME/conf.d/20_redis.ini \
    && apk del --no-network .build-deps

RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-simplexml
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-soap
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-sockets
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-sodium
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-sqlite3

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xdebug
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install xdebug \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/xdebug.so \
    && echo ";zend_extension=xdebug.so" > /etc/$PHP_PACKAGE_BASENAME/conf.d/50_xdebug.ini \
    && echo ";xdebug.mode=off" >> /etc/$PHP_PACKAGE_BASENAME/conf.d/50_xdebug.ini \
    && apk del --no-network .build-deps

RUN sed -i -e 's/;zend/zend/g' /etc/${PHP_PACKAGE_BASENAME}/conf.d/50_xdebug.ini
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xml
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xmlwriter
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xmlreader
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xsl
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-zip

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-grpc~=$GRPC_EXTENSION_VERSION --repository $GRPC_EXTENSION_REPOSITORY
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install grpc \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/grpc.so \
    && echo "extension=grpc" > /etc/$PHP_PACKAGE_BASENAME/conf.d/grpc.ini \
    && apk del --no-network .build-deps

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-pcov~=$PCOV_EXTENSION_VERSION --repository $PCOV_EXTENSION_REPOSITORY
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts83 install pcov \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/pcov.so \
    && echo "extension=pcov" > /etc/$PHP_PACKAGE_BASENAME/conf.d/pcov.ini \
    && apk del --no-network .build-deps

# FIXME: we need this, since php83 is not the _default_php in https://git.alpinelinux.org/aports/tree/community/php83/APKBUILD
WORKDIR /usr/bin
RUN    ln -s phpzts83 php \
    && ln -s peardevzts83 peardev \
    && ln -s peclzts83 pecl \
    && ln -s phpizezts83 phpize \
    && ln -s php-configzts83 php-config \
    && ln -s phpdbgzts83 phpdbg \
    && ln -s lsphpzts83 lsphp \
    && ln -s php-cgizts83 php-cgi \
    && ln -s phar.pharzts83 phar.phar \
    && ln -s pharzts83 phar

# add php.ini containing environment variables
COPY files/php.ini /etc/${PHP_PACKAGE_BASENAME}/php.ini

# add composer
RUN wget --quiet --no-verbose https://github.com/composer/composer/releases/download/2.7.1/composer.phar -O /usr/bin/composer && chmod +x /usr/bin/composer
ENV COMPOSER_HOME=/composer
RUN mkdir /composer && chown www-data:www-data /composer

# install php-fpm
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-fpm~=${PHP_VERSION}
# the alpine php fpm package, does not deliver php-fpm binary without suffix
RUN ln -s $PHP_FPM_BINARY_PATH /usr/sbin/php-fpm
# use user www-data
RUN sed -i -e 's/user = nobody/user = www-data/g' /etc/${PHP_PACKAGE_BASENAME}/php-fpm.d/www.conf
# use group www-data
RUN sed -i -e 's/group = nobody/group = www-data/g' /etc/${PHP_PACKAGE_BASENAME}/php-fpm.d/www.conf
# listen also externally for the php-fpm process
RUN sed -i -e 's/listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/g' /etc/${PHP_PACKAGE_BASENAME}/php-fpm.d/www.conf
# expose the given environment variables to php
RUN sed -i -e 's/;clear_env = no/clear_env = no/g' /etc/${PHP_PACKAGE_BASENAME}/php-fpm.d/www.conf
# write error_log to /dev/stderr
RUN sed -i -e 's/;error_log.*/error_log=\/dev\/stderr/g' /etc/${PHP_PACKAGE_BASENAME}/php-fpm.conf
# expose the worker logs to stdout + stderr
RUN sed -i -e 's/;catch_workers_output = yes/catch_workers_output = yes/g' /etc/${PHP_PACKAGE_BASENAME}/php-fpm.d/www.conf
# avoid decoration like 'TIMESTAMP WARNING: [pool www] child 7 said into stderr "' around each log message
RUN sed -i -e 's/;decorate_workers_output = no/decorate_workers_output = no/g' /etc/${PHP_PACKAGE_BASENAME}/php-fpm.d/www.conf
# avoid nginx logging when fpm logged something (e.g. "FastCGI sent in stderr")
RUN echo "php_admin_flag[fastcgi.logging] = off" >> /etc/${PHP_PACKAGE_BASENAME}/php-fpm.d/www.conf

# install nginx unit and the php module for nginx unit
RUN apk add --no-cache unit~=$UNIT_VERSION unit-${PHP_PACKAGE_BASENAME}~=$UNIT_VERSION
# add default nginx unit json file (listening on port 8080)
COPY files/unit/unit-default.json /var/lib/unit/conf.json
# chown the folder for control socket file
RUN chown www-data:www-data /run/unit/

# install apache2 and the php module for apache2
RUN apk add --no-cache apache2~=$APACHE2_VERSION ${PHP_PACKAGE_BASENAME}-apache2~=${PHP_VERSION}
# add default apache2 config file
COPY files/apache2/apache2-default.conf /etc/apache2/conf.d/00_apache2-default.conf
# fix that the mod_php83.so is not properly renamed in the conf
RUN sed -i -e 's/mod_php83/mod_phpzts83/g' /etc/apache2/conf.d/php83-module.conf
# activate rewrite module
RUN sed -i -e 's/#LoadModule rewrite_module/LoadModule rewrite_module/g' /etc/apache2/httpd.conf
# listen port 8080
RUN sed -i -e 's/Listen 80/Listen 8080/g' /etc/apache2/httpd.conf
# use user www-data
RUN sed -i -e 's/User apache/User www-data/g' /etc/apache2/httpd.conf
# use group www-data
RUN sed -i -e 's/Group apache/Group www-data/g' /etc/apache2/httpd.conf
# write ErrorLog to /dev/stderr
RUN sed -i -e 's/ErrorLog logs\/error.log/ErrorLog \/dev\/stderr/g' /etc/apache2/httpd.conf
# write CustomLog to /dev/stdout
RUN sed -i -e 's/CustomLog logs\/access.log/CustomLog \/dev\/stdout/g' /etc/apache2/httpd.conf
# write make it possible to write pid as www-data user to /run/apache2/httpd.pid
RUN chown www-data:www-data /run/apache2/

# the start-cron script
RUN mkfifo -m 0666 /var/log/cron.log
RUN chown www-data:www-data /var/log/cron.log
COPY files/cron/start-cron /usr/sbin/start-cron
RUN chmod +x /usr/sbin/start-cron

# install caddy with frankenphp
# hadolint ignore=SC2016,SC2086,DL3003
RUN apk add --no-cache go~=1.21 --virtual .go-build-deps \
    && apk add --no-cache libxml2-dev sqlite-dev brotli-dev build-base openssl-dev ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && cd /opt \
    && git clone https://github.com/dunglas/frankenphp.git --recursive  --branch v1.1.0 --single-branch \
    && cd /opt/frankenphp/caddy/frankenphp \
    # make frankenphp to be happy about lphpzts83.so and not require us to have a lphp.so
    && sed -i -e "s/lphp/l${PHP_PACKAGE_BASENAME}/g" ../../frankenphp.go \
    && export PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 `php-config --includes`" \
    && export PHP_CPPFLAGS="$PHP_CFLAGS" \
    && export PHP_LDFLAGS="-Wl,-O1 -pie `php-config --ldflags`" \
    && export CGO_LDFLAGS="$PHP_LDFLAGS" CGO_CFLAGS=$PHP_CFLAGS CGO_CPPFLAGS=$PHP_CPPFLAGS \
    && go build \
    && rm -rf /root/.cache /root/go \
    && mv /opt/frankenphp/caddy/frankenphp/frankenphp /usr/sbin/frankenphp \
    && rm -rf /opt/frankenphp \
    && apk del --no-network .build-deps .go-build-deps

COPY files/frankenphp/Caddyfile /etc/Caddyfile
# FIXME: start with /usr/sbin/frankenphp run --config /etc/Caddyfile
# LISTEN on port 443! is always SSL and localhost!
# FIXME: check for modules via `./frankenphp list-modules | grep php` and see `frankenphp` and `http.handlers.php`
RUN apk add --no-cache nss-tools

CMD ["php", "-a"]


ENV PHP_DATE_TIMEZONE="UTC" \
    PHP_ALLOW_URL_FOPEN="On" \
    PHP_LOG_ERRORS_MAX_LEN=1024 \
    # default is: 0, but we need logs to stdout. https://www.php.net/manual/en/errorfunc.configuration.php#ini.log-errors
    PHP_LOG_ERRORS="1" \
    PHP_MAX_EXECUTION_TIME=0 \
    PHP_MAX_FILE_UPLOADS=20 \
    PHP_MAX_INPUT_VARS=1000 \
    PHP_MEMORY_LIMIT=128M \
    PHP_VARIABLES_ORDER="EGPCS" \
    PHP_SHORT_OPEN_TAG="On" \
    # default is: no value, but grpc breaks pcntl if not activated.
    # https://github.com/grpc/grpc/blob/master/src/php/README.md#pcntl_fork-support \
    PHP_GRPC_ENABLE_FORK_SUPPORT='1' \
    # default is: no value, but grpc breaks pcntl if not having a fork support with a poll strategy.
    # https://github.com/grpc/grpc/blob/master/doc/core/grpc-polling-engines.md#polling-engine-implementations-in-grpc
    PHP_GRPC_POLL_STRATEGY='epoll1' \
    PHP_OPCACHE_PRELOAD="" \
    PHP_OPCACHE_PRELOAD_USER="" \
    PHP_OPCACHE_MEMORY_CONSUMPTION=128 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=10000 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    PHP_REALPATH_CACHE_SIZE=4M \
    PHP_REALPATH_CACHE_TTL=120 \
    PHP_POST_MAX_SIZE=8M \
    PHP_SENDMAIL_PATH="/usr/sbin/sendmail -t -i" \
    PHP_SESSION_SAVE_HANDLER=files \
    PHP_SESSION_SAVE_PATH="" \
    PHP_UPLOAD_MAX_FILESIZE=2M \
    PHP_XDEBUG_MODE='off' \
    PHP_XDEBUG_START_WITH_REQUEST='default' \
    PHP_XDEBUG_CLIENT_HOST='localhost' \
    PHP_XDEBUG_DISCOVER_CLIENT_HOST='false' \
    PHP_XDEBUG_IDEKEY='' \
    PHP_DISPLAY_ERRORS='STDOUT' \
    PHP_DISPLAY_STARTUP_ERRORS=1 \
    PHP_EXPOSE_PHP=1

RUN mkdir -p /usr/src/app
RUN chown -R www-data:www-data /usr/src/app
WORKDIR /usr/src/app

USER www-data
