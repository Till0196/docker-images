FROM ubuntu:resolute

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install the Docker and GitHub CLI apt repositories
RUN apt-get update && apt-get install -y --no-install-recommends --no-install-suggests \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    \
    # Docker
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /usr/share/keyrings/docker-archive-keyring.asc \
    && echo "Types: deb" > /etc/apt/sources.list.d/docker.sources \
    && echo "URIs: https://download.docker.com/linux/ubuntu" >> /etc/apt/sources.list.d/docker.sources \
    && echo "Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")" >> /etc/apt/sources.list.d/docker.sources \
    && echo "Components: stable" >> /etc/apt/sources.list.d/docker.sources \
    && echo "Architectures: $(dpkg --print-architecture)" >> /etc/apt/sources.list.d/docker.sources \
    && echo "Signed-By: /usr/share/keyrings/docker-archive-keyring.asc" >> /etc/apt/sources.list.d/docker.sources \
    \
    # GitHub CLI
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "Types: deb" > /etc/apt/sources.list.d/github-cli.sources \
    && echo "URIs: https://cli.github.com/packages" >> /etc/apt/sources.list.d/github-cli.sources \
    && echo "Suites: stable" >> /etc/apt/sources.list.d/github-cli.sources \
    && echo "Components: main" >> /etc/apt/sources.list.d/github-cli.sources \
    && echo "Architectures: $(dpkg --print-architecture)" >> /etc/apt/sources.list.d/github-cli.sources \
    && echo "Signed-By: /usr/share/keyrings/githubcli-archive-keyring.gpg" >> /etc/apt/sources.list.d/github-cli.sources \
    \
    # Node.js
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o /usr/share/keyrings/nodesource.asc \
    && echo "Types: deb" > /etc/apt/sources.list.d/nodesource.sources \
    && echo "URIs: https://deb.nodesource.com/node_24.x" >> /etc/apt/sources.list.d/nodesource.sources \
    && echo "Suites: nodistro" >> /etc/apt/sources.list.d/nodesource.sources \
    && echo "Components: main" >> /etc/apt/sources.list.d/nodesource.sources \
    && echo "Architectures: $(dpkg --print-architecture)" >> /etc/apt/sources.list.d/nodesource.sources \
    && echo "Signed-By: /usr/share/keyrings/nodesource.asc" >> /etc/apt/sources.list.d/nodesource.sources

# Install baseline packages
RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y --no-install-recommends --no-install-suggests \
    bash \
    zsh \
    fzf \
    tmux \
    build-essential \
    containerd.io \
    curl \
    docker-ce \
    docker-ce-cli \
    docker-buildx-plugin \
    docker-compose-plugin \
    htop \
    jq \
    locales \
    man \
    pipx \
    python3 \
    python3-pip \
    software-properties-common \
    sudo \
    systemd \
    systemd-sysv \
    unzip \
    vim \
    nano \
    wget \
    rsync \
    iproute2 \
    gh \
    nodejs && \
# Install latest Git using their official PPA
    add-apt-repository ppa:git-core/ppa && \
    apt-get install --yes git \
    && rm -rf /var/lib/apt/lists/*

# Enables Docker starting with systemd
RUN systemctl enable docker

# Create a symlink for standalone docker-compose usage
RUN ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose

# Generate the desired locale (en_US.UTF-8)
RUN locale-gen en_US.UTF-8

# Make typing unicode characters in the terminal work.
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# renovate: datasource=github-releases depName=filebrowser/filebrowser extractVersion=^v(?<version>.*)$
ARG FILEBROWSER_VERSION=2.63.18

RUN set -e; \
    FB_ARCH=$(dpkg --print-architecture); \
    if [ "$FB_ARCH" = "arm" ]; then FB_ARCH="armv7"; fi; \
    URL="https://github.com/filebrowser/filebrowser/releases/download/v${FILEBROWSER_VERSION}/linux-${FB_ARCH}-filebrowser.tar.gz"; \
    echo "Downloading ${URL} ..."; \
    curl -fsSL "$URL" | tar -xz -C /usr/local/bin filebrowser; \
    chmod +x /usr/local/bin/filebrowser

# Remove the `ubuntu` user and add a user `coder` so that you're not developing as the `root` user
RUN userdel -r ubuntu && \
    useradd coder \
    --create-home \
    --shell=/bin/bash \
    --groups=docker \
    --uid=1000 \
    --user-group && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers.d/nopasswd

USER coder
RUN pipx ensurepath # adds user's bin directory to PATH

# renovate: datasource=github-releases depName=coder/code-server extractVersion=^v(?<version>.*)$
ARG CODE_SERVER_VERSION=4.129.0

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- \
        --method standalone \
        --version "${CODE_SERVER_VERSION}" \
        --prefix "~/.cache/code-server"

ENV PATH="/home/coder/.cache/code-server/bin:${PATH}"

COPY --chown=coder:coder setup-code-server-locale.sh /opt/scripts/
RUN chmod +x /opt/scripts/setup-code-server-locale.sh \
    && code-server --install-extension ms-ceintl.vscode-language-pack-ja \
    && /opt/scripts/setup-code-server-locale.sh ja
