FROM ubuntu:jammy-20230816

ARG PHP_VERSION="8.2.10"
ARG PHP_PACKAGE_BASENAME="php8.2"
ARG PHP_PACKAGE_BASE_VERSION="8.2"
ARG PHP_FPM_BINARY_PATH="/usr/sbin/php-fpm8.2"
ARG UNIT_VERSION="1.31.0"
ARG APACHE2_VERSION="2.4.52"
ENV PHP_VERSION=$PHP_VERSION
ENV PHP_PACKAGE_BASENAME=$PHP_PACKAGE_BASENAME
ENV PHP_FPM_BINARY_PATH=$PHP_FPM_BINARY_PATH
ENV UNIT_VERSION=$UNIT_VERSION
ENV APACHE2_VERSION=$APACHE2_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y software-properties-common gpg-agent --no-install-recommends && LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php && apt-get remove --purge -y software-properties-common && apt-get autoremove -y

RUN apt-get update && apt-get -y dist-upgrade

RUN apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    git-lfs \
    default-mysql-client \
    libmysqlcppconn7v5 \
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

RUN apt-get install -y ${PHP_PACKAGE_BASENAME}=${PHP_VERSION}-* lib${PHP_PACKAGE_BASENAME}-embed=${PHP_VERSION}-*

ENV PHP_INI_DIR=/etc/php/${PHP_PACKAGE_BASE_VERSION}/

RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-bcmath
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-calendar
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-curl
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-ctype
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-gd
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-fileinfo
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-ftp
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-iconv
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-intl
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-ldap
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-mbstring
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-mysqli
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-opcache
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-mysql
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-pgsql
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-sqlite3
RUN apt-get install -y  php-pear
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-amqp
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-apcu
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-tokenizer
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-igbinary
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-imagick
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-memcached
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-protobuf

RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-pgsql
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-phar
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-posix
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-redis
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-simplexml
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-soap
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-sockets
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-sqlite3
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-xdebug
RUN echo "xdebug.mode=off" >> /etc/php/${PHP_PACKAGE_BASE_VERSION}/mods-available/xdebug.ini
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-xml
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-xmlwriter
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-xmlreader
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-xsl
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-zip
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-grpc

RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-pcov
# add php.ini containing environment variables
COPY files/php.ini /etc/php/${PHP_PACKAGE_BASE_VERSION}/php.ini

RUN rm /etc/php/${PHP_PACKAGE_BASE_VERSION}/cli/php.ini \
  && ln -s /etc/php/${PHP_PACKAGE_BASE_VERSION}/php.ini /etc/php/${PHP_PACKAGE_BASE_VERSION}/cli/php.ini \
#  && rm /etc/php/${PHP_PACKAGE_BASE_VERSION}/fpm/php.ini \
#  && ln -s /etc/php/${PHP_PACKAGE_BASE_VERSION}/php.ini /etc/php/${PHP_PACKAGE_BASE_VERSION}/fpm/php.ini \
#  && rm /etc/php/${PHP_PACKAGE_BASE_VERSION}/apache2/php.ini \
#  && ln -s /etc/php/${PHP_PACKAGE_BASE_VERSION}/php.ini /etc/php/${PHP_PACKAGE_BASE_VERSION}/apache2/php.ini \
  && rm /etc/php/${PHP_PACKAGE_BASE_VERSION}/embed/php.ini \
  && ln -s /etc/php/${PHP_PACKAGE_BASE_VERSION}/php.ini /etc/php/${PHP_PACKAGE_BASE_VERSION}/embed/php.ini

# add composer
COPY --from=composer:2.5.1 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_HOME=/composer
RUN mkdir /composer && chown www-data:www-data /composer

# install php-fpm
RUN apt-get install -y  ${PHP_PACKAGE_BASENAME}-fpm=${PHP_VERSION}-*
# the ubuntu php fpm package, does not deliver php-fpm binary without suffix
RUN ln -s $PHP_FPM_BINARY_PATH /usr/sbin/php-fpm
# listen also externally for the php-fpm process
RUN sed -i -e 's/^listen = .*/listen = 0.0.0.0:9000/g' /etc/php/${PHP_PACKAGE_BASE_VERSION}/fpm/pool.d/www.conf
# expose the given environment variables to php
RUN sed -i -e 's/;clear_env = no/clear_env = no/g' /etc/php/${PHP_PACKAGE_BASE_VERSION}/fpm/pool.d/www.conf
# write error_log to /dev/stderr
RUN sed -i -e 's/error_log.*/error_log=\/dev\/stderr/g' /etc/php/${PHP_PACKAGE_BASE_VERSION}/fpm/php-fpm.conf
# expose the worker logs to stdout + stderr
RUN sed -i -e 's/;catch_workers_output = yes/catch_workers_output = yes/g' /etc/php/${PHP_PACKAGE_BASE_VERSION}/fpm/pool.d/www.conf
# avoid decoration like 'TIMESTAMP WARNING: [pool www] child 7 said into stderr "' around each log message
RUN sed -i -e 's/;decorate_workers_output = no/decorate_workers_output = no/g' /etc/php/${PHP_PACKAGE_BASE_VERSION}/fpm/pool.d/www.conf
# avoid nginx logging when fpm logged something (e.g. "FastCGI sent in stderr")
RUN echo "php_admin_flag[fastcgi.logging] = off" >> /etc/php/${PHP_PACKAGE_BASE_VERSION}/fpm/pool.d/www.conf

RUN rm /etc/php/${PHP_PACKAGE_BASE_VERSION}/fpm/php.ini \
  && ln -s /etc/php/${PHP_PACKAGE_BASE_VERSION}/php.ini /etc/php/${PHP_PACKAGE_BASE_VERSION}/fpm/php.ini



# install nginx unit and the php module for nginx unit
RUN curl --output /usr/share/keyrings/nginx-keyring.gpg  https://unit.nginx.org/keys/nginx-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/nginx-keyring.gpg] https://packages.nginx.org/unit/ubuntu/ jammy unit" > /etc/apt/sources.list.d/unit.list
RUN echo "deb-src [signed-by=/usr/share/keyrings/nginx-keyring.gpg] https://packages.nginx.org/unit/ubuntu/ jammy unit" >> /etc/apt/sources.list.d/unit.list
RUN apt-get update && apt-get install -y  unit=$UNIT_VERSION-* unit-php=$UNIT_VERSION-* --no-install-recommends
# add default nginx unit json file (listening on port 8080)
COPY files/unit/unit-default.json /var/lib/unit/conf.json
# chown the folder for control socket file
RUN mkdir /run/unit && chown www-data:www-data /run/unit/

# install apache2 and the php module for apache2
RUN apt-get install -y apache2=$APACHE2_VERSION-* libapache2-mod-${PHP_PACKAGE_BASENAME}=${PHP_VERSION}-* --no-install-recommends
# add default apache2 config file
COPY files/apache2/apache2-default.conf /etc/apache2/sites-available/000-default.conf
# listen port 8080
RUN sed -i -e 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf
# write ErrorLog to /dev/stderr
RUN sed -i -e 's/ErrorLog .*/ErrorLog \/dev\/stderr/g' /etc/apache2/apache2.conf
# write CustomLog to /dev/stdout
RUN sed -i -e 's/# a CustomLog.*/CustomLog \/dev\/stdout combined/g' /etc/apache2/apache2.conf
RUN rm /etc/apache2/conf-enabled/other-vhosts-access-log.conf
RUN rm /etc/apache2/conf-available/other-vhosts-access-log.conf
# write make it possible to write pid as www-data user to /run/apache2/httpd.pid
RUN chown www-data:www-data /run/apache2/
ENV APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    APACHE_RUN_DIR=/var/run/apache2 \ 
    APACHE_LOCK_DIR=/var/lock/apache2 \
    APACHE_LOG_DIR=/var/log/apache2
RUN rm /etc/php/${PHP_PACKAGE_BASE_VERSION}/apache2/php.ini \
  && ln -s /etc/php/${PHP_PACKAGE_BASE_VERSION}/php.ini /etc/php/${PHP_PACKAGE_BASE_VERSION}/apache2/php.ini

# crontab
RUN apt-get update && apt-get install --no-install-recommends -y cron \
    && rm -rf /var/lib/apt/lists/* \
    && mkfifo --mode 0666 /var/log/cron.log \
    && sed --regexp-extended --in-place \
    's/^session\s+required\s+pam_loginuid.so$/session optional pam_loginuid.so/' \
    /etc/pam.d/cron
# the start-cron script
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
    PHP_XDEBUG_IDEKEY='' \
    PHP_EXPOSE_PHP=1

ENV DEBIAN_FRONTEND=

RUN mkdir -p /usr/src/app
RUN chown -R www-data:www-data /usr/src/app
WORKDIR /usr/src/app

USER www-data
