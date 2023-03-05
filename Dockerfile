# FIXME: use a fixed alpine release as soon as it is available with php8.2 support
FROM --platform=${BUILDPLATFORM} alpine:edge

ARG TARGETPLATFORM

ARG PHP_VERSION="8.2.3"
ARG PHP_PACKAGE_BASENAME="php82"
ARG PHP_FPM_BINARY_PATH="/usr/sbin/php-fpm82"
ARG UNIT_VERSION="1.29.1"
ARG APACHE2_VERSION="2.4.55"
ARG GRPC_EXTENSION_VERSION="1.51.1"
ARG GRPC_EXTENSION_REPOSITORY="http://dl-cdn.alpinelinux.org/alpine/edge/testing"
ARG PCOV_EXTENSION_VERSION="1.0.11"
ARG PCOV_EXTENSION_REPOSITORY="http://dl-cdn.alpinelinux.org/alpine/edge/testing"
ENV PHP_VERSION=$PHP_VERSION
ENV PHP_PACKAGE_BASENAME=$PHP_PACKAGE_BASENAME
ENV PHP_FPM_BINARY_PATH=$PHP_FPM_BINARY_PATH
ENV UNIT_VERSION=$UNIT_VERSION
ENV APACHE2_VERSION=$APACHE2_VERSION
ENV GRPC_EXTENSION_VERSION=$GRPC_EXTENSION_VERSION
ENV GRPC_EXTENSION_REPOSITORY=$GRPC_EXTENSION_REPOSITORY
ENV PCOV_EXTENSION_VERSION=$PCOV_EXTENSION_VERSION
ENV PCOV_EXTENSION_REPOSITORY=$PCOV_EXTENSION_REPOSITORY

RUN apk upgrade -U # 2023/01/05 to fix CVE-2022-3996

RUN apk add --no-cache \
    libc6-compat \
    git \
    git-lfs \
    mysql-client \
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
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-amqp --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-apcu
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-tokenizer
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-igbinary
# FIXME: necessary to have "ImageMagick number of supported formats:  => 252"
RUN apk add --no-cache imagemagick imagemagick-libs libgomp
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-imagick --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-memcached
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-protobuf --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pgsql
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-phar
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-posix
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-redis
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-simplexml
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-soap
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-sockets
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-sodium
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-sqlite3
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xdebug
RUN sed -i -e 's/;xdebug.mode/xdebug.mode/g' /etc/${PHP_PACKAGE_BASENAME}/conf.d/50_xdebug.ini
RUN sed -i -e 's/;zend/zend/g' /etc/${PHP_PACKAGE_BASENAME}/conf.d/50_xdebug.ini
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xml
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xmlwriter
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xmlreader
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-xsl
RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-zip

RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-grpc~=$GRPC_EXTENSION_VERSION --repository $GRPC_EXTENSION_REPOSITORY
# FIXME: RUN apk add --no-cache ${PHP_PACKAGE_BASENAME}-pecl-pcov~=$PCOV_EXTENSION_VERSION --repository $PCOV_EXTENSION_REPOSITORY
RUN apk add --no-cache binutils build-base openssl-dev autoconf pcre2-dev automake libtool linux-headers ${PHP_PACKAGE_BASENAME}-dev~=${PHP_VERSION} --virtual .build-deps \
    && MAKEFLAGS="-j $(nproc)" pecl82 install pcov \
    && strip --strip-all /usr/lib/$PHP_PACKAGE_BASENAME/modules/pcov.so \
    && echo "extension=pcov" > /etc/$PHP_PACKAGE_BASENAME/conf.d/00_pcov.ini \
    && apk del --no-network .build-deps

# FIXME: we need this, since php82 is not the _default_php in https://git.alpinelinux.org/aports/tree/community/php82/APKBUILD
WORKDIR /usr/bin
RUN    ln -s php82 php \
    && ln -s peardev82 peardev \
    && ln -s pecl82 pecl \
    && ln -s phpize82 phpize \
    && ln -s php-config82 php-config \
    && ln -s phpdbg82 phpdbg \
    && ln -s lsphp82 lsphp \
    && ln -s php-cgi82 php-cgi \
    && ln -s phar.phar82 phar.phar \
    && ln -s phar82 phar

# we need this, because memcached expects msgpack to be loaded before memcached
RUN mv /etc/php82/conf.d/20_memcached.ini /etc/php82/conf.d/60_memcached.ini

# add php.ini containing environment variables
COPY files/php.ini /etc/${PHP_PACKAGE_BASENAME}/php.ini

# add composer
COPY --from=composer:2.5.1 /usr/bin/composer /usr/bin/composer
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
# write error_log to /dev/stderr
RUN sed -i -e 's/;error_log.*/error_log=\/dev\/stderr/g' /etc/${PHP_PACKAGE_BASENAME}/php-fpm.conf

# install nginx unit and the php module for nginx unit
RUN apk add --no-cache unit~=$UNIT_VERSION unit-${PHP_PACKAGE_BASENAME}~=$UNIT_VERSION
# add default nginx unit json file (listening on port 8080)
COPY files/unit/unit-default.json /var/lib/unit/conf.json
# add folder for control socket file
RUN mkdir /run/unit/
RUN chown www-data:www-data /run/unit/

# install apache2 and the php module for apache2
RUN apk add --no-cache apache2~=$APACHE2_VERSION ${PHP_PACKAGE_BASENAME}-apache2~=${PHP_VERSION}
# add default apache2 config file
COPY files/apache2/apache2-default.conf /etc/apache2/conf.d/00_apache2-default.conf
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
    PHP_XDEBUG_IDEKEY=''

RUN mkdir -p /usr/src/app
RUN chown -R www-data:www-data /usr/src/app
WORKDIR /usr/src/app

USER www-data
