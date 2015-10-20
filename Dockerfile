# DOCKER-VERSION 1.0

# Base image for other DIT4C platform images
FROM dit4c/centos-notroot:7
MAINTAINER t.dettrick@uq.edu.au

USER root

# Create researcher user for notebook
RUN chown notroot:notroot / && \
  rm -f /root/anaconda-ks.cfg && \
  groupmod -n researcher notroot && \
  usermod -l researcher -m -d /home/researcher notroot && \
  chmod u+w /home/researcher && \
  yum remove -y rootfiles && \
  rm -rf /root /var/cache/yum/* /tmp/*

USER researcher

# Directories that don't need to be preserved in images
VOLUME ["/var/cache/yum", "/tmp"]

COPY /usr/local/bin /usr/local/bin

# Remove yum setting which blocks man page install
RUN sed -i'' 's/tsflags=nodocs/tsflags=/' /etc/yum.conf

# Update all packages and install docs
# (reinstalling glibc-common would add 100MB and no docs, so it's excluded)
RUN fsudo yum upgrade -y && \
  rpm -qa | grep -v -E "glibc-common|filesystem" | xargs fsudo yum reinstall -y

# Install EPEL repo
RUN fsudo yum install -y epel-release
# Install Nginx repo
# - rebuild workaround from:
#   https://github.com/docker/docker/issues/10180#issuecomment-76347566
RUN fsudo rpm --rebuilddb && \
  fsudo yum install -y http://nginx.org/packages/centos/7/noarch/RPMS/$(\
  curl http://nginx.org/packages/centos/7/noarch/RPMS/ | \
  grep -Po 'nginx-release.*?\.rpm' | head -1)

# Install
# - supervisord for monitoring
# - nginx for reverse-proxying
# - Git and development tools
# - PIP so we can install EasyDav dependencies
# - patching dependencies
RUN fsudo yum install -y \
  supervisor \
  nginx \
  git vim-enhanced nano wget tmux screen bash-completion man \
  tar zip unzip \
  python-pip \
  patch

# Install EasyDAV dependencies
RUN fsudo pip install kid flup

# Install gotty
RUN VERSION=v0.0.11 && \
  curl -sL https://github.com/yudai/gotty/releases/download/$VERSION/linux_amd64.tar.gz \
    | tar xzC /usr/local/bin

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

# Because COPY doesn't respect USER...
USER root
RUN chown -R researcher:researcher /etc /usr/local/bin /opt /var
USER researcher

# Remove setuid & setgid flags from binaries
RUN find / -perm +4000 -xdev -not -type f -exec chmod u-s {} \; && \
  find / -perm +2000 -xdev -type f -exec chmod g-s {} \;

# Check nginx config is OK
RUN nginx -t

EXPOSE 8080
# Run all processes through supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

# Logs do not need to be preserved when exporting
VOLUME ["/var/log"]
