FROM ubuntu:18.04

# Adapted from: https://github.com/cruizba/ubuntu-dind

RUN apt update \
    && apt install -y ca-certificates openssh-client \
    wget curl iptables supervisor \
    && rm -rf /var/lib/apt/list/*

ENV DOCKER_CHANNEL=stable \
	DOCKER_VERSION=20.10.18 \
	DOCKER_COMPOSE_VERSION=1.29.2 \
	DEBUG=false

# Docker installation
RUN set -eux; \
	\
	arch="$(uname --m)"; \
	case "$arch" in \
        # amd64
		x86_64) dockerArch='x86_64' ;; \
        # arm32v6
		armhf) dockerArch='armel' ;; \
        # arm32v7
		armv7) dockerArch='armhf' ;; \
        # arm64v8
		aarch64) dockerArch='aarch64' ;; \
		*) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;\
	esac; \
	\
	if ! wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
		echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
		exit 1; \
	fi; \
	\
	tar --extract \
		--file docker.tgz \
		--strip-components 1 \
		--directory /usr/local/bin/ \
	; \
	rm docker.tgz; \
	\
	dockerd --version; \
	docker --version

COPY modprobe startup.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh

RUN chmod +x /usr/local/bin/startup.sh /usr/local/bin/modprobe
VOLUME /var/lib/docker

# Docker compose installation
RUN curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
	&& chmod +x /usr/local/bin/docker-compose && docker-compose version

### ssh and ubuntu user stuff
# install utilities
RUN apt update
RUN apt install -y      \
    vim-tiny            \
    vim                 \
    nano                \
    sudo                \
    python-pip			\
    iproute2

# install sshd
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/London
RUN apt install openssh-server -y

# configure ssh access
RUN sed 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config -i
RUN sed 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config -i

# configure ssh for root
RUN mkdir /root/.ssh
COPY zdm_deploy_public_key /root/.ssh/authorized_keys

# create ubuntu user
RUN useradd -ms /bin/bash ubuntu
RUN usermod -aG sudo ubuntu
USER ubuntu
WORKDIR /home/ubuntu/

USER root
RUN echo 'ubuntu ALL=NOPASSWD: ALL' >> /etc/sudoers

# configure ssh for ubuntu
WORKDIR /home/ubuntu/
RUN mkdir .ssh
RUN touch .ssh/config
RUN chmod 664 .ssh/config
COPY zdm_deploy_public_key .ssh/authorized_keys
RUN chown -R ubuntu:ubuntu .ssh/*

###

ENTRYPOINT ["startup.sh"]
CMD ["/bin/bash"]
