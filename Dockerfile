FROM hachque/systemd-none

# Install requirements
RUN zypper --non-interactive in nginx

# Expose Nginx on port 80 and 443
EXPOSE 80
EXPOSE 443

# Remove preconfigured Nginx files
RUN rm -Rv /etc/nginx
RUN mkdir /etc/nginx

# Add files
ADD nginx.conf /etc/nginx/nginx.conf
ADD reverse.inc /etc/nginx/reverse.inc
ADD mime.types /etc/nginx/mime.types
ADD 25-nginx /etc/init.simple/25-nginx

# Set /init as the default
CMD ["/init"]
