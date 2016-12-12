# DOCKER-VERSION 1.0

# Base image for other DIT4C platform images
FROM nvidia/cuda:8.0-cudnn5-devel
MAINTAINER jguiraudet@gmail.com

# Directories that don't need to be preserved in images
VOLUME ["/var/cache/apt", "/tmp"]

### Remove yum setting which blocks man page install
##RUN sed -i'' 's/tsflags=nodocs/tsflags=/' /etc/yum.conf
##
### Update all packages and install docs, except:
### * reinstalling glibc-common would add 100MB and no docs, so it's excluded
### * iputils install & AUFS don't currently play well (docker/docker#6980)
##RUN yum upgrade -y && \
##  rpm -qa | grep -v -E "glibc-common|filesystem|iputils" | xargs yum reinstall -y



# Install Nginx repo
# - rebuild workaround from:
#   https://github.com/docker/docker/issues/10180#issuecomment-76347566
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

# Install
# - supervisord for monitoring
# - nginx for reverse-proxying
# - sudo and passwd for creating user/giving sudo
# - Git and development tools
# - node.js for TTY.js
# - PIP so we can install EasyDav dependencies
# - patching dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
  supervisor \
  nginx \
  sudo passwd \
  git vim-nox     nano wget tmux screen bash-completion man \
  tar zip unzip \
  python-pip \
  patch

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y curl

# Install gotty
RUN VERSION=v0.0.12 && \
  curl -sL https://github.com/yudai/gotty/releases/download/$VERSION/gotty_linux_amd64.tar.gz \
    | tar xzC /usr/local/bin

# Install EasyDAV dependencies
RUN pip install kid flup

# Install EasyDAV
COPY easydav_fix-archive-download.patch /tmp/
RUN cd /opt && \
  curl http://koti.kapsi.fi/jpa/webdav/easydav-0.4.tar.gz | tar zxvf - && \
  mv easydav-0.4 easydav && \
  cd easydav && \
  patch -p1 < /tmp/easydav_fix-archive-download.patch && \
  cd -

# Log directory for easydav & supervisord
RUN mkdir -p /var/log/{easydav,supervisor}

# Add supporting files (directory at a time to improve build speed)
COPY etc /etc
COPY opt /opt
COPY var /var

# Check nginx config is OK
RUN adduser --system --no-create-home --disabled-login --disabled-password --group nginx && nginx -t

EXPOSE 8080
# Run all processes through supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

RUN useradd -m researcher && \
    gpasswd -a researcher sudo && \
    passwd -d researcher && passwd -u    researcher
##### TODO: remove this: WAR for 'passwd -d researcher' not working on Ubuntu
##### https://www.psychocats.net/ubuntucat/creating-a-passwordless-account-in-ubuntu/
RUN echo 'researcher          ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers

RUN mkdir -p /var/log/easydav && chown -R researcher /var/log/easydav /var/log/supervisor

# Logs do not need to be preserved when exporting
VOLUME ["/var/log"]
