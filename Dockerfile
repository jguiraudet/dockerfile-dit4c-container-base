# DOCKER-VERSION 1.0

# Base image for other DIT4C platform images
FROM alpine:3.3
MAINTAINER t.dettrick@uq.edu.au

# Directories that don't need to be preserved in images
VOLUME ["/var/cache/apk", "/tmp"]

# Install
# - sudo for giving sudo
# - coreutils for dircolors
# - supervisord for monitoring
# - nginx for reverse-proxying
# - patching dependencies
RUN apk add --update \
    sudo \
    coreutils \
    supervisor \
    nginx \
    vim nano curl wget tmux screen bash-completion man tar zip unzip \
    patch

# Install Git
RUN apk add --update git

# Install gotty
RUN VERSION=v0.0.12 && \
  curl -sL https://github.com/yudai/gotty/releases/download/$VERSION/gotty_linux_amd64.tar.gz \
    | tar xzC /usr/local/bin

# Install EasyDAV dependencies
RUN apk add --update py-pip && pip install kid flup

# Install EasyDAV
COPY easydav_fix-archive-download.patch /tmp/
RUN mkdir -p /opt && cd /opt && \
  curl http://koti.kapsi.fi/jpa/webdav/easydav-0.4.tar.gz | tar zxvf - && \
  mv easydav-0.4 easydav && \
  cd easydav && \
  patch -p1 < /tmp/easydav_fix-archive-download.patch && \
  cd -

# Log directory for easydav & supervisord
RUN mkdir -p /var/log/easydav /var/log/supervisor

# Add supporting files (directory at a time to improve build speed)
COPY etc /etc
COPY opt /opt
COPY var /var

# Check nginx config is OK
RUN nginx -t

EXPOSE 8080
# Run all processes through supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

RUN adduser -D -s /bin/bash -G wheel researcher && \
    truncate -s 0 /etc/sudoers && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    passwd -d -u researcher

RUN chown -R researcher /var/log/easydav /var/log/supervisor

# Logs do not need to be preserved when exporting
VOLUME ["/var/log"]
