# DOCKER-VERSION 1.0

# Base image for other DIT4C platform images
FROM alpine:3.4
MAINTAINER t.dettrick@uq.edu.au

# Directories that don't need to be preserved in images
VOLUME ["/var/cache/apk", "/tmp"]

# Install
# - bash for shell
# - sudo for giving sudo
# - coreutils for dircolors
# - supervisord for monitoring
# - nginx for reverse-proxying
# - patching dependencies
# - useful documentation
RUN apk add --update \
    bash bash-doc \
    sudo \
    coreutils \
    supervisor \
    nginx \
    vim nano curl wget tmux screen bash-completion man tar zip unzip \
    patch \
    bash-doc coreutils-doc \
    vim-doc nano-doc curl-doc wget-doc tar-doc zip-doc unzip-doc

# Install Git
RUN apk add --update git git-doc

# Install gotty
RUN VERSION=v0.0.13 && \
  curl -sL https://github.com/yudai/gotty/releases/download/$VERSION/gotty_linux_amd64.tar.gz \
    | tar xzC /usr/local/bin

# Install Caddy with filemanager plugin
RUN mkdir -p /opt/caddy && \
  curl -L "https://caddyserver.com/download/build?os=linux&arch=amd64&features=filemanager%2Crealip" \
    | tar xzv -C /opt/caddy

# Log directory for supervisord
RUN mkdir -p /var/log/supervisor

# Add supporting files (directory at a time to improve build speed)
COPY etc /etc
COPY var /var

RUN chown -R nginx:nginx /var/lib/nginx
# Check nginx config is OK
RUN nginx -t

EXPOSE 8080
# Run all processes through supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

RUN adduser -D -s /bin/bash -G wheel researcher && \
    truncate -s 0 /etc/sudoers && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    passwd -d -u researcher

RUN chown -R researcher /var/log/supervisor

RUN su - researcher -c "mkdir -p ~/.caddy/conf.d && printf \"import conf.d/*\" > ~/.caddy/Caddyfile && printf \"localhost:3100 {\nfilemanager /files {\nallow_commands false\nallow dotfiles\n}\n}\" > ~/.caddy/conf.d/files.conf"

# Logs do not need to be preserved when exporting
VOLUME ["/var/log"]
