FROM ubuntu:18.04

# Install required packages
RUN apt-get update -q \
    && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
      ca-certificates \
      openssh-server \
      wget \
      apt-transport-https \
      vim \
      curl

RUN curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh > script.deb.sh && bash script.deb.sh

# Attempt to fix sticking at "ruby_block[supervise_rabbitmq_sleep] action run"
# Result of being unable to determine what startup mechanism system uses
# https://stackoverflow.com/questions/26614489/chef-server-stuck-ruby-blocksupervise-rabbitmq-sleep-action-run-on-docker-cont
RUN dpkg-divert --local --rename --add /sbin/initctl && ln -sf /bin/true /sbin/initctl

RUN apt-get update && apt-get install -y --no-install-recommends  gitlab-ce=10.8.7-ce.0

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

