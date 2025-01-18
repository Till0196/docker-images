FROM wordpress:php8.3-fpm-alpine

RUN set -ex; \
	\
	apk add --no-cache \
		ssmtp \
        less \
    ;
    
RUN set -ex; \
	\
    curl -o /usr/local/bin/wp-cli -fL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \
    chmod +x /usr/local/bin/wp-cli \
    ;

RUN set -ex; \
    \
    apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS; \
    pecl install redis; \
    docker-php-ext-enable redis; \
    apk del --no-network .build-deps \
    ;

RUN set -ex; \
    \
    cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini \
    ;

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
