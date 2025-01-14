FROM alpine:3.21.0 AS alpine-distro
FROM alpine-distro AS php-zts-builder

RUN apk add --no-cache libc6-compat
RUN apk add --no-cache alpine-sdk
RUN apk add --no-cache git git-lfs bash vim vimdiff curl

RUN apk upgrade -U # 2024/01/14 to fix CVEs

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


RUN git clone -b 3.21-stable --single-branch --depth=1 https://gitlab.alpinelinux.org/alpine/aports

WORKDIR /workspace/aports/community/php84
RUN cp -rf /workspace/aports/community/php84 /workspace/aports/community/phpzts84
WORKDIR /workspace/aports/community/phpzts84
RUN sed -i -e 's/pkgname=php84/pkgname=phpzts84/' APKBUILD
# hadolint ignore=SC2016
RUN sed -i -e 's/\$pkgname-fpm.initd/php84-fpm.initd/' APKBUILD
# hadolint ignore=SC2016
RUN sed -i -e 's/\$pkgname-fpm.logrotate/php84-fpm.logrotate/' APKBUILD
# hadolint ignore=SC2016
RUN sed -i -e 's/\$pkgname-module.conf/php84-module.conf/' APKBUILD
# hadolint ignore=SC2016
RUN sed -i -e 's/\$pkgname-fpm-version-suffix.patch/php84-fpm-version-suffix.patch/' APKBUILD
# hadolint ignore=SC2016
RUN sed -i -e 's/php\$_suffix-module.conf/php84-module.conf/' APKBUILD
RUN sed -i -e 's/--host/--enable-zts --enable-zend-max-execution-timers --enable-zend-timer --disable-zend-signals --host/' APKBUILD
RUN sed -i -e 's/--with-openssl-argon2//' APKBUILD
#RUN sed -i -e 's/--with-password-argon2//' APKBUILD
RUN sed -i -e 's/--with-libxml/--with-expat/' APKBUILD
RUN sed -i -e 's/_default_php="yes"/_default_php="no"/g' APKBUILD
RUN echo "" >> disabled-tests.list
RUN echo "ext/posix/tests/bug75696.phpt" >> disabled-tests.list
RUN echo "ext/posix/tests/posix_getgrgid.phpt" >> disabled-tests.list
RUN echo "ext/posix/tests/posix_getgrgid_basic.phpt" >> disabled-tests.list
RUN echo "ext/posix/tests/posix_getgrnam_basic.phpt" >> disabled-tests.list
RUN echo "ext/posix/tests/posix_getpwnam_basic_01.phpt" >> disabled-tests.list
RUN echo "ext/posix/tests/posix_getpwuid_basic.phpt" >> disabled-tests.list
RUN echo "sapi/cli/tests/bug61546.phpt" >> disabled-tests.list
RUN echo "sapi/fpm/tests/socket-uds-numeric-ugid-nonroot.phpt" >> disabled-tests.list
RUN echo "ext/curl/tests/curl_basic_009.phpt" >> disabled-tests.list
RUN echo "ext/curl/tests/curl_basic_024.phpt" >> disabled-tests.list
RUN echo "ext/standard/tests/file/bug52820.phpt" >> disabled-tests.list
RUN echo "ext/xml/tests/XML_OPTION_PARSE_HUGE.phpt" >> disabled-tests.list
RUN echo "ext/xml/tests/xml003.phpt" >> disabled-tests.list

USER root
RUN apk update
USER alpiner
RUN arch
RUN uname -m
RUN abuild -A
RUN abuild checksum && abuild -r
WORKDIR /workspace/aports/community/unit
# make phpver3 to be phpzts84
RUN sed -i -e 's/_phpver4=84/_phpver4=zts84/' APKBUILD
RUN sed -i -e 's/.\/configure php --module=php\$_phpver2 --config=php-config\$_phpver2//' APKBUILD
RUN sed -i -e 's/.\/configure php --module=php\$_phpver3 --config=php-config\$_phpver3//' APKBUILD
RUN sed -i -e 's/perl php\$_phpver2 php\$_phpver3 php\$_phpver4/perl php\$_phpver4 /' APKBUILD
# make unit-php84 find the lphpzts84.so
# hadolint ignore=SC2016
#RUN sed -i -e 's/.\/configure php --module=php\$_phpver4/sed -i -e "s\/lphp\/lphpzts\/g" auto\/modules\/php \&\& cat auto\/modules\/php \&\& .\/configure php --module=php\$_phpver4/g' APKBUILD
RUN sed -i -e 's/_allow_fail=no/_allow_fail=yes/g' APKBUILD

RUN abuild checksum && abuild -r

FROM alpine-distro AS php-zts-base

ARG PHP_VERSION="8.4.2"
ARG PHP_PACKAGE_BASENAME="phpzts84"
ARG PHP_PACKAGE_INCLUDE="/usr/include/php84"
ARG PHP_FPM_BINARY_PATH="/usr/sbin/php-fpmzts84"
ENV PHP_VERSION=$PHP_VERSION
ENV PHP_PACKAGE_BASENAME=$PHP_PACKAGE_BASENAME
ENV PHP_PACKAGE_INCLUDE=$PHP_PACKAGE_INCLUDE
ENV PHP_FPM_BINARY_PATH=$PHP_FPM_BINARY_PATH

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

COPY --from=php-zts-builder /workspace/packages/community /opt/custom-packages
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
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-sockets

# FIXME: we need this, since phpzts84 is not the _default_php in https://git.alpinelinux.org/aports/tree/community/php84/APKBUILD
WORKDIR /usr/bin
RUN    ln -s phpzts84 php \
    && ln -s peardevzts84 peardev \
    && ln -s peclzts84 pecl \
    && ln -s phpizezts84 phpize \
    && ln -s php-configzts84 php-config \
    && ln -s phpdbgzts84 phpdbg \
    && ln -s lsphpzts84 lsphp \
    && ln -s php-cgizts84 php-cgi \
    && ln -s phar.pharzts84 phar.phar \
    && ln -s pharzts84 phar

FROM php-zts-base AS PECL-BUILDER-AMQP

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-amqp
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers rabbitmq-c-dev ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts84 install amqp \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/amqp.so \
    && echo "extension=amqp" > /etc/$PHP_PACKAGE_BASENAME/conf.d/40_amqp.ini \
    && apk del --no-network .build-deps \
    && apk add --no-cache rabbitmq-c

FROM php-zts-base AS PECL-BUILDER-APCU

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-apcu
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts84 install apcu \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/apcu.so \
    && echo "extension=apcu" > /etc/$PHP_PACKAGE_BASENAME/conf.d/apcu.ini \
    && apk del --no-network .build-deps

FROM php-zts-base AS PECL-BUILDER-IGBINARY

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-igbinary
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts84 install igbinary \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/igbinary.so \
    && echo "extension=igbinary" > /etc/$PHP_PACKAGE_BASENAME/conf.d/10_igbinary.ini \
    && apk del --no-network .build-deps

FROM php-zts-base AS PECL-BUILDER-IMAGICK

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-imagick
# FIXME: we do this because of https://github.com/Imagick/imagick/issues/689
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers imagemagick imagemagick-dev imagemagick-libs ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && wget --quiet --no-verbose https://github.com/Imagick/imagick/archive/refs/heads/3.7.0.tar.gz -O /tmp/imagick.tar.gz \
    && tar --strip-components=1 -xf /tmp/imagick.tar.gz \
    && sed -i -e 's/php_strtolower/zend_str_tolower/' imagick.c \
    && phpizezts84 \
    && ./configure \
    && MAKEFLAGS="-j $(nproc)" make \
    && MAKEFLAGS="-j $(nproc)" make install \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/imagick.so \
    && echo "extension=imagick.so" > /etc/$PHP_PACKAGE_BASENAME/conf.d/00_imagick.ini \
    && rm -rf /tmp/imagick.tar.gz \
    && apk del --no-network .build-deps \
    && apk add --no-cache imagemagick imagemagick-libs libgomp
    
FROM php-zts-base AS PECL-BUILDER-MSGPACK

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-msgpack
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts84 install msgpack \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/msgpack.so \
    && echo "extension=msgpack" > /etc/$PHP_PACKAGE_BASENAME/conf.d/10_msgpack.ini \
    && apk del --no-network .build-deps

FROM php-zts-base AS PECL-BUILDER-MEMCACHED

COPY --from=PECL-BUILDER-IGBINARY /usr/lib/$PHP_PACKAGE_BASENAME/modules/igbinary.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/igbinary.so
COPY --from=PECL-BUILDER-IGBINARY /etc/$PHP_PACKAGE_BASENAME/conf.d/10_igbinary.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/10_igbinary.ini
COPY --from=PECL-BUILDER-IGBINARY $PHP_PACKAGE_INCLUDE/ext/igbinary $PHP_PACKAGE_INCLUDE/ext/igbinary
COPY --from=PECL-BUILDER-MSGPACK /usr/lib/$PHP_PACKAGE_BASENAME/modules/msgpack.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/msgpack.so
COPY --from=PECL-BUILDER-MSGPACK /etc/$PHP_PACKAGE_BASENAME/conf.d/10_msgpack.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/10_msgpack.ini
COPY --from=PECL-BUILDER-MSGPACK $PHP_PACKAGE_INCLUDE/ext/msgpack $PHP_PACKAGE_INCLUDE/ext/msgpack
# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-memcached
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers zlib-dev libmemcached-dev cyrus-sasl-dev libevent-dev ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts84 install -D 'enable-memcached-igbinary="yes" enable-memcached-session="yes" enable-memcached-json="yes" enable-memcached-protocol="yes" enable-memcached-msgpack="yes"' memcached \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/memcached.so \
    && echo "extension=memcached" > /etc/$PHP_PACKAGE_BASENAME/conf.d/20_memcached.ini \
    && apk del --no-network .build-deps \
    && apk add --no-cache libmemcached-libs libevent

FROM php-zts-base AS PECL-BUILDER-PROTOBUF

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-protobuf
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts84 install protobuf \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/protobuf.so \
    && echo "extension=protobuf" > /etc/$PHP_PACKAGE_BASENAME/conf.d/protobuf.ini \
    && apk del --no-network .build-deps

FROM php-zts-base AS PECL-BUILDER-REDIS

COPY --from=PECL-BUILDER-IGBINARY /usr/lib/$PHP_PACKAGE_BASENAME/modules/igbinary.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/igbinary.so
COPY --from=PECL-BUILDER-IGBINARY /etc/$PHP_PACKAGE_BASENAME/conf.d/10_igbinary.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/10_igbinary.ini
COPY --from=PECL-BUILDER-IGBINARY $PHP_PACKAGE_INCLUDE/ext/igbinary $PHP_PACKAGE_INCLUDE/ext/igbinary
# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-redis
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers lz4-dev zstd-dev ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts84 install -D 'enable-redis-igbinary="yes" enable-redis-lz4="yes" with-liblz4="yes" enable-redis-lzf="yes" enable-redis-zstd="yes"' redis \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/redis.so \
    && echo "extension=redis" > /etc/$PHP_PACKAGE_BASENAME/conf.d/20_redis.ini \
    && apk del --no-network .build-deps

FROM php-zts-base AS PECL-BUILDER-XDEBUG

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xdebug
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts84 install xdebug \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/xdebug.so \
    && echo ";zend_extension=xdebug.so" > /etc/$PHP_PACKAGE_BASENAME/conf.d/50_xdebug.ini \
    && echo ";xdebug.mode=off" >> /etc/$PHP_PACKAGE_BASENAME/conf.d/50_xdebug.ini \
    && sed -i -e 's/;zend/zend/g' /etc/${PHP_PACKAGE_BASENAME}/conf.d/50_xdebug.ini \
    && apk del --no-network .build-deps

FROM php-zts-base AS PECL-BUILDER-GRPC

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-grpc~=$GRPC_EXTENSION_VERSION --repository $GRPC_EXTENSION_REPOSITORY
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts84 install grpc \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/grpc.so \
    && echo "extension=grpc" > /etc/$PHP_PACKAGE_BASENAME/conf.d/grpc.ini \
    && apk del --no-network .build-deps

FROM php-zts-base AS PECL-BUILDER-PCOV

# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-pcov~=$PCOV_EXTENSION_VERSION --repository $PCOV_EXTENSION_REPOSITORY
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" peclzts84 install pcov \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/pcov.so \
    && echo "extension=pcov" > /etc/$PHP_PACKAGE_BASENAME/conf.d/pcov.ini \
    && apk del --no-network .build-deps

FROM php-zts-base AS FRANKENPHPBUILDER

# Install e-dant/watcher (necessary for file watching)
RUN mkdir -p /usr/local/src/watcher
WORKDIR /usr/local/src/watcher
RUN apk add --no-cache binutils build-base libstdc++ cmake automake libtool linux-headers --virtual .watcher-build-deps \
       && wget --quiet --no-verbose https://github.com/e-dant/watcher/archive/refs/tags/0.13.2.tar.gz -O /tmp/watcher.tar.gz \
        && tar xz --strip-component=1 -xf /tmp/watcher.tar.gz \
        && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
	&& cmake --build build \
	&& cmake --install build \
        && apk del --no-network .watcher-build-deps

# install caddy with frankenphp
# hadolint ignore=SC2016,SC2086,DL3003
RUN apk add --no-cache go~=1.23 --virtual .go-build-deps \
    && apk add --no-cache libxml2-dev sqlite-dev argon2-dev brotli-dev build-base openssl-dev ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && cd /opt \
    && find / | grep php | grep .so \
    && git clone https://github.com/dunglas/frankenphp.git --recursive  --branch v1.4.0 --single-branch \
    && cd /opt/frankenphp/caddy/frankenphp \
    && export PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 `php-config --includes`" \
    && export PHP_CPPFLAGS="$PHP_CFLAGS" \
    && export PHP_LDFLAGS="-Wl,-O1 -pie `php-config --ldflags` `php-config --libs` -L/usr/lib/${PHP_PACKAGE_BASENAME}" \
    && export CGO_LDFLAGS="$PHP_LDFLAGS" CGO_CFLAGS=$PHP_CFLAGS CGO_CPPFLAGS=$PHP_CPPFLAGS \
    && go build \
    && rm -rf /root/.cache /root/go \
    && mv /opt/frankenphp/caddy/frankenphp/frankenphp /usr/sbin/frankenphp \
    && rm -rf /opt/frankenphp \
    && apk del --no-network .build-deps .go-build-deps

FROM php-zts-base

COPY --from=PECL-BUILDER-AMQP /usr/lib/$PHP_PACKAGE_BASENAME/modules/amqp.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/amqp.so
COPY --from=PECL-BUILDER-AMQP /etc/$PHP_PACKAGE_BASENAME/conf.d/40_amqp.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/40_amqp.ini
RUN apk add --no-cache rabbitmq-c

COPY --from=PECL-BUILDER-APCU /usr/lib/$PHP_PACKAGE_BASENAME/modules/apcu.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/apcu.so
COPY --from=PECL-BUILDER-APCU /etc/$PHP_PACKAGE_BASENAME/conf.d/apcu.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/apcu.ini
COPY --from=PECL-BUILDER-APCU $PHP_PACKAGE_INCLUDE/ext/apcu $PHP_PACKAGE_INCLUDE/ext/apcu

COPY --from=PECL-BUILDER-IGBINARY /usr/lib/$PHP_PACKAGE_BASENAME/modules/igbinary.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/igbinary.so
COPY --from=PECL-BUILDER-IGBINARY /etc/$PHP_PACKAGE_BASENAME/conf.d/10_igbinary.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/10_igbinary.ini
COPY --from=PECL-BUILDER-IGBINARY $PHP_PACKAGE_INCLUDE/ext/igbinary $PHP_PACKAGE_INCLUDE/ext/igbinary

COPY --from=PECL-BUILDER-IMAGICK /usr/lib/$PHP_PACKAGE_BASENAME/modules/imagick.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/imagick.so
COPY --from=PECL-BUILDER-IMAGICK /etc/$PHP_PACKAGE_BASENAME/conf.d/00_imagick.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/00_imagick.ini
RUN apk add --no-cache imagemagick imagemagick-libs libgomp

COPY --from=PECL-BUILDER-MSGPACK /usr/lib/$PHP_PACKAGE_BASENAME/modules/msgpack.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/msgpack.so
COPY --from=PECL-BUILDER-MSGPACK /etc/$PHP_PACKAGE_BASENAME/conf.d/10_msgpack.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/10_msgpack.ini
COPY --from=PECL-BUILDER-MSGPACK $PHP_PACKAGE_INCLUDE/ext/msgpack $PHP_PACKAGE_INCLUDE/ext/msgpack

COPY --from=PECL-BUILDER-MEMCACHED /usr/lib/$PHP_PACKAGE_BASENAME/modules/memcached.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/memcached.so
COPY --from=PECL-BUILDER-MEMCACHED /etc/$PHP_PACKAGE_BASENAME/conf.d/20_memcached.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/20_memcached.ini
RUN apk add --no-cache libmemcached-libs libevent

COPY --from=PECL-BUILDER-PROTOBUF /usr/lib/$PHP_PACKAGE_BASENAME/modules/protobuf.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/protobuf.so
COPY --from=PECL-BUILDER-PROTOBUF /etc/$PHP_PACKAGE_BASENAME/conf.d/protobuf.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/protobuf.ini


RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pgsql
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-phar
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-posix

COPY --from=PECL-BUILDER-REDIS /usr/lib/$PHP_PACKAGE_BASENAME/modules/redis.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/redis.so
COPY --from=PECL-BUILDER-REDIS /etc/$PHP_PACKAGE_BASENAME/conf.d/20_redis.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/20_redis.ini

RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-simplexml
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-soap
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-sodium
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-sqlite3

COPY --from=PECL-BUILDER-XDEBUG /usr/lib/$PHP_PACKAGE_BASENAME/modules/xdebug.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/xdebug.so
COPY --from=PECL-BUILDER-XDEBUG /etc/$PHP_PACKAGE_BASENAME/conf.d/50_xdebug.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/50_xdebug.ini

RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xml
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xmlwriter
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xmlreader
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xsl
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-zip

COPY --from=PECL-BUILDER-GRPC /usr/lib/$PHP_PACKAGE_BASENAME/modules/grpc.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/grpc.so
COPY --from=PECL-BUILDER-GRPC /etc/$PHP_PACKAGE_BASENAME/conf.d/grpc.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/grpc.ini

COPY --from=PECL-BUILDER-PCOV /usr/lib/$PHP_PACKAGE_BASENAME/modules/pcov.so /usr/lib/$PHP_PACKAGE_BASENAME/modules/pcov.so
COPY --from=PECL-BUILDER-PCOV /etc/$PHP_PACKAGE_BASENAME/conf.d/pcov.ini /etc/$PHP_PACKAGE_BASENAME/conf.d/pcov.ini

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
RUN apk add --no-cache unit unit-${PHP_PACKAGE_BASENAME}
# add default nginx unit json file (listening on port 8080)
COPY files/unit/unit-default.json /var/lib/unit/conf.json
# create folder for socket (necessary since alpine 3.20)
RUN mkdir /run/unit/
# chown the folder for control socket file
RUN chown www-data:www-data /run/unit/

# install apache2 and the php module for apache2
RUN apk add --no-cache apache2 ${PHP_PACKAGE_BASENAME}-apache2~=${PHP_VERSION}
# add default apache2 config file
COPY files/apache2/apache2-default.conf /etc/apache2/conf.d/00_apache2-default.conf
# fix that the mod_php84.so is not properly renamed in the conf
RUN sed -i -e 's/mod_php84/mod_phpzts84/g' /etc/apache2/conf.d/php84-module.conf
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

COPY --from=FRANKENPHPBUILDER /usr/sbin/frankenphp /usr/sbin/frankenphp
COPY --from=FRANKENPHPBUILDER /usr/local/lib/libwatcher* /usr/local/lib/
RUN apk add --no-cache libstdc++ && ldconfig /usr/local/lib

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
