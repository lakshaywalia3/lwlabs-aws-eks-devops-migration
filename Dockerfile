# Use the official PHP image with Apache
FROM php:8.2-apache

# Install the mysqli extension required for your database connection
RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

# Copy your application files from the src directory to the Apache document root
COPY src/ /var/www/html/

# Set appropriate permissions for security
RUN chown -R www-data:www-data /var/www/html/ \
    && chmod -R 755 /var/www/html/

# Expose port 80 for web traffic
EXPOSE 80