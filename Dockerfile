FROM php:7.1-fpm

MAINTAINER Revin Roman <roman@rmrevin.com>

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

ONBUILD ARG _UID
ONBUILD ARG _GID

ONBUILD RUN groupmod -g $_GID www-data \
 && usermod -u $_UID -g $_GID -s /bin/bash www-data \
 && echo "    IdentityFile ~/.ssh/id_rsa" >> /etc/ssh/ssh_config

RUN mkdir -p /var/www/ \
 && mkdir -p /var/run/php/ \
 && mkdir -p /var/log/php/ \
 && mkdir -p /var/log/app/ \
 && chown www-data:www-data /var/www/

ARG GOSU_VERSION=1.10

RUN set -xe \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends \
        apt-utils bash-completion ca-certificates gnupg2 bzip2 net-tools ssh-client \
        dirmngr gcc make rsync chrpath curl wget rsync git vim unzip htop cron supervisor \

 # GOSU
 && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
 && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
 && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
 && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
 && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
 && chmod +x /usr/local/bin/gosu \
 && gosu nobody true \

 # MySQL
 && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8C718D3B5072E1F5 \
 && echo "deb http://repo.mysql.com/apt/debian/ jessie mysql-apt-config" >> /etc/apt/sources.list.d/mysql.list \
 && echo "deb http://repo.mysql.com/apt/debian/ jessie mysql-5.7" >> /etc/apt/sources.list.d/mysql.list \
 && echo "deb-src http://repo.mysql.com/apt/debian/ jessie mysql-5.7" >> /etc/apt/sources.list.d/mysql.list \
 && apt-get install -y --no-install-recommends mysql-client \

 # PHP Extensions
 && docker-php-ext-install -j$(nproc) \
    bcmath gettext json mbstring pdo \
    opcache pcntl posix shmop sockets \

 # PHP mysql
 && docker-php-ext-install -j$(nproc) pdo_mysql mysqli \

 # PHP pgsql
 && apt-get install -y --no-install-recommends libpq-dev \
 && docker-php-ext-install -j$(nproc) pdo_pgsql pgsql \

 # PHP mcrypt
 #&& apt-get install -y --no-install-recommends libmcrypt-dev \
 #&& docker-php-ext-install -j$(nproc) mcrypt \

 # PHP intl
 && apt-get install -y --no-install-recommends libicu-dev libicu57 \
 && docker-php-ext-install -j$(nproc) intl \

 # PHP zip
 && apt-get install -y --no-install-recommends libzip-dev \
 && docker-php-ext-install -j$(nproc) zip \

 # PHP gd
 && apt-get install -y --no-install-recommends libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
 && docker-php-ext-install -j$(nproc) gd \

 # PHP gmp
 && apt-get install -y --no-install-recommends libgmp-dev \
 && docker-php-ext-install -j$(nproc) gmp \

 # PHP apcu
 && pecl install apcu-5.1.8 \
 && docker-php-ext-enable apcu \

 # PHP xdebug
 && pecl install xdebug-2.5.5 \
 # && docker-php-ext-enable xdebug \ # to enable xdebug manualy call this command in container

 # PHP imagick
 && apt-get install -y --no-install-recommends libmagickwand-dev \
 && pecl install imagick-3.4.3 \
 && docker-php-ext-enable imagick \

 # PHP event
 && apt-get install -y --no-install-recommends libssl-dev libcurl4-openssl-dev libevent-dev \
 && pecl install event-2.3.0 eio-2.0.2 inotify-2.0.0 \
 && docker-php-ext-enable event eio inotify \

 # PHP redis
 && pecl install redis-3.1.3 \
 && docker-php-ext-enable redis \

 # PHP mongodb
 && pecl install mongodb-1.2.9 \
 && docker-php-ext-enable mongodb \

 # PHP memcached
 && apt-get install -y --no-install-recommends libmemcached-dev zlib1g-dev \
 && pecl install memcached-3.0.3 \
 && docker-php-ext-enable memcached \

 # PHP geoip
 && apt-get install -y --no-install-recommends geoip-bin geoip-database libgeoip-dev \
 && pecl install geoip-1.1.1 \
 && docker-php-ext-enable geoip \

 # PHP geoip database
 && mkdir /usr/local/share/GeoIP/ \
 && cd /usr/local/share/GeoIP/ \
 && curl -O "http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz" 2>&1 \
 && gunzip GeoLite2-City.mmdb.gz \

 # Clean
 && rm -rf /var/lib/apt/lists/* \

 # Composer
 && cd /opt \
 && curl -sS https://getcomposer.org/installer | php \
 && ln -s /opt/composer.phar /usr/local/bin/composer

COPY supervisor.d/ /etc/supervisor/

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

WORKDIR /var/www/

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
