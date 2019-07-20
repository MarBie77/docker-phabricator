FROM php:7.2-fpm-alpine
LABEL maintainer="Martin Biermair <martin@biermair.at>"

# install alpine packages
RUN apk add --no-cache bash openssh-server openssh-keygen git freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev py-pygments sudo sed procps zip \
 && apk add --virtual .phpize-deps \
    $PHPIZE_DEPS

# add php modules
RUN NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
 && docker-php-ext-configure gd --with-gd --with-freetype-dir=/usr/include/ --with-png-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
 && docker-php-ext-install -j${NPROC} gd \
 && docker-php-ext-configure opcache --enable-opcache \
 && docker-php-ext-install -j${NPROC} opcache \
 && docker-php-ext-install -j${NPROC} mysqli \
 && docker-php-ext-install -j${NPROC} zip \
 && docker-php-ext-install -j${NPROC} pcntl \
 && pecl install apcu \
 && docker-php-ext-enable apcu \
 && apk del --no-cache freetype-dev libpng-dev libjpeg-turbo-dev

# configure php for production
RUN mv $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY ./php-conf.d/*.ini $PHP_INI_DIR/conf.d/

# user management
ENV PHAB_PHD_USER=${PHAB_PHD_USER:-phduser}
ENV PHAB_DIFFUSION_SSH_PORT=${PHAB_DIFFUSION_SSH_PORT:-2430}
ENV PHAB_DIFFUSION_SSH_USER=${PHAB_DIFFUSION_SSH_USER:-git}

# add account git for diffusion
 RUN adduser -D ${PHAB_DIFFUSION_SSH_USER} \
# enable account git and unlock it with passwd -u
 && passwd -u ${PHAB_DIFFUSION_SSH_USER} \
# add account phduser for phabricator daemons
 && adduser -D ${PHAB_PHD_USER}

# link php, otherwise ssh with git won't work
RUN ln -s /usr/local/bin/php /bin/php

# create temp for phab config directory
RUN mkdir -p /usr/src/docker-phab/

# copy sudo file for git user
COPY ./git-sudo /usr/src/docker-phab/

# copy sshd config for phabricator to temp ssh config directory
COPY ./sshd_config.phabricator /usr/src/docker-phab/
COPY ./phabricator-ssh-hook.sh /usr/src/docker-phab/

# copy new entrypoint
COPY ./docker-php-entrypoint /usr/local/bin/

# export volume for ssh config, so keys won't be lost after restart
VOLUME ["/etc/ssh"]
