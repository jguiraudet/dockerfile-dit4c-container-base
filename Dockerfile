# DOCKER-VERSION 1.0

# Base image for other DIT4C platform images
FROM nvidia/cuda:8.0-cudnn5-devel
MAINTAINER t.dettrick@uq.edu.au

# Directories that don't need to be preserved in images
VOLUME ["/var/cache/apt", "/tmp"]


# Install
# - sudo and passwd for creating user/giving sudo
# - supervisord for monitoring
# - nginx for reverse-proxying
# - patching dependencies
RUN apt-get update && apt-get install -y \
    sudo passwd \
    supervisor \
    nginx \
    vim nano curl wget tmux screen bash-completion man tar zip unzip \
    patch && \
  apt-get clean


# Install Git
RUN apt-get update && apt-get install -y git && apt-get clean

# Install gotty
RUN VERSION=v0.0.12 && \
  curl -sL https://github.com/yudai/gotty/releases/download/$VERSION/gotty_linux_amd64.tar.gz \
    | tar xzC /usr/local/bin

# Install EasyDAV dependencies
RUN apt-get update && \
  apt-get install -y python-kid python-flup && \
  apt-get clean

# Install EasyDAV
COPY easydav_fix-archive-download.patch /tmp/
RUN cd /opt && \
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

RUN useradd -m researcher -s /bin/bash && \
    gpasswd -a researcher sudo && \
    passwd -d researcher && passwd -u researcher && \
    rm ~researcher/.bashrc ~researcher/.bash_logout ~researcher/.profile && \
    sed -i -e 's/PS1/#PS1/' /etc/bash.bashrc && \
    echo 'source /etc/profile.d/prompt.sh' >> /etc/bash.bashrc

RUN chown -R researcher /var/log/easydav /var/log/supervisor

# Logs do not need to be preserved when exporting
VOLUME ["/var/log"]
