FROM ubuntu:18.04

# Install required packages
RUN apt-get update -q \
    && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
      ca-certificates \
      openssh-server \
      wget \
      apt-transport-https \
      vim \
      tzdata \
      curl

ENV VERSION=10.8.7-ce.0
RUN wget -O /tmp/gitlab.deb --content-disposition https://packages.gitlab.com/gitlab/gitlab-ce/packages/debian/jessie/gitlab-ce_${VERSION}_amd64.deb/download.deb && \
    dpkg -i /tmp/gitlab.deb && \
    rm /tmp/gitlab.deb && \
    rm -rf /var/lib/apt/lists/*


# Manage SSHD through runit
RUN mkdir -p /opt/gitlab/sv/sshd/supervise \
    && mkfifo /opt/gitlab/sv/sshd/supervise/ok \
    && printf "#!/bin/sh\nexec 2>&1\numask 077\nexec /usr/sbin/sshd -D" > /opt/gitlab/sv/sshd/run \
    && chmod a+x /opt/gitlab/sv/sshd/run \
    && ln -s /opt/gitlab/sv/sshd /opt/gitlab/service \
    && mkdir -p /var/run/sshd

# Disabling use DNS in ssh since it tends to slow connecting
RUN echo "UseDNS no" >> /etc/ssh/sshd_config

# Prepare default configuration
RUN ( \
  echo "" && \
  echo "# Docker options" && \
  echo "# Prevent Postgres from trying to allocate 25% of total memory" && \
  echo "postgresql['shared_buffers'] = '1MB'" ) >> /etc/gitlab/gitlab.rb && \
  mkdir -p /assets/ && \
  cp /etc/gitlab/gitlab.rb /assets/gitlab.rb

# Expose web & ssh
EXPOSE 80 22

# Define data volumes
VOLUME ["/etc/gitlab", "/var/opt/gitlab", "/var/log/gitlab"]

# Copy assets
COPY assets/wrapper /usr/local/bin/


RUN ["chmod", "+x", "/usr/local/bin/wrapper"]
ENTRYPOINT ["bash"]
# Wrapper to handle signal, trigger runit and reconfigure GitLab
CMD [ "/usr/local/bin/wrapper"]

RUN sed -i 's/\r$//' /usr/local/bin/wrapper

