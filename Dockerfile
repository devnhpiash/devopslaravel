# Use official PHP + Apache image
FROM php:8.2-apache

# --- metadata ---
ARG USER=www-data
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

# --- system deps ---
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     git \
     unzip \
     libzip-dev \
     libpng-dev \
     libonig-dev \
     libjpeg-dev \
     libfreetype6-dev \
     libxml2-dev \
     wget \
     ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# --- PHP extensions ---
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) pdo_mysql mbstring zip exif pcntl gd bcmath xml

# --- composer ---
COPY --from=composer:2.6 /usr/bin/composer /usr/bin/composer

# --- Enable apache mods and set document root ---
RUN a2enmod rewrite expires headers
RUN sed -ri -e 's!/var/www/html!'"${APACHE_DOCUMENT_ROOT}"'!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!DocumentRoot /var/www/!DocumentRoot '"${APACHE_DOCUMENT_ROOT}"'!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

WORKDIR /var/www/html

# Copy composer files first to leverage Docker cache
COPY composer.json composer.lock* /var/www/html/

# Install composer dependencies (prefer no-dev in container build)
RUN composer install --no-interaction --prefer-dist --no-dev --optimize-autoloader || true

# Copy application code
COPY . /var/www/html

# Ensure storage and bootstrap cache are writable
RUN chown -R ${USER}:${USER} /var/www/html \
  && chmod -R 755 /var/www/html \
  && mkdir -p storage/framework storage/logs \
  && chown -R ${USER}:${USER} storage bootstrap/cache

# Expose port 80 (docker-compose maps host:8000 -> container:80)
EXPOSE 80

# Production-friendly entrypoint: run migrations/seeds optionally, then start Apache
# (Keep simple; further orchestration handled by docker-compose commands)
CMD ["apache2-foreground"]