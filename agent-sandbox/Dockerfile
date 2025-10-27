ARG TARGETARCH
FROM --platform=linux/${TARGETARCH} node:24 AS node
FROM --platform=linux/${TARGETARCH} ubuntu:noble AS base

ARG TZ
ARG LANG
ARG LANGUAGE
ARG LC_ALL
ARG USERNAME
ARG TARGETARCH

ENV TZ="$TZ"
ENV LANG=${LANG:-"en_US.UTF-8"}
ENV LANGUAGE=${LANGUAGE:-"en_US:en"}
ENV LC_ALL=${LC_ALL:-"en_US.UTF-8"}
ENV USERNAME=${USERNAME:-"vscode"}
ENV DEVCONTAINER=true
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=~/.local/bin:$PATH:/usr/local/share/npm-global/bin

# Copy Node.js files
COPY --from=node /usr/local/include/ /usr/local/include/
COPY --from=node /usr/local/lib/ /usr/local/lib/
COPY --from=node /usr/local/bin/ /usr/local/bin/

# Create user and group with UID and GID 1000
RUN groupmod -n ${USERNAME} $(getent group 1000 | cut -d: -f1) && \
    usermod -l ${USERNAME} -d /home/${USERNAME} -m $(getent passwd 1000 | cut -d: -f1)

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y \
        libatomic1 \
        less git procps sudo zsh man-db fzf \
        unzip gnupg2 \
        gh \
        iptables ipset iproute2 dnsutils aggregate \
        jq nano vim curl wget ca-certificates tzdata \
        gosu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Persist bash history.
RUN mkdir /commandhistory && \
    touch /commandhistory/.bash_history && \
    chown -R ${USERNAME}:${USERNAME} /commandhistory

# Install Git Delta
ARG GIT_DELTA_VERSION=0.18.2

RUN cd /tmp && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        export GIT_DELTA_ARCH="arm64"; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
        export GIT_DELTA_ARCH="amd64"; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi && \
    curl -sSL $(curl -s https://api.github.com/repos/dandavison/delta/releases/tags/${GIT_DELTA_VERSION} | \
    jq -r '.assets[] | select(.name | contains("'${GIT_DELTA_ARCH}'") and endswith(".deb")) | .browser_download_url') \
    -o git-delta_${GIT_DELTA_VERSION}_${GIT_DELTA_ARCH}.deb && \
    dpkg -i git-delta_${GIT_DELTA_VERSION}_${GIT_DELTA_ARCH}.deb && \
    rm git-delta_${GIT_DELTA_VERSION}_${GIT_DELTA_ARCH}.deb

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR="/usr/local/bin/" INSTALLER_NO_MODIFY_PATH=1 sh

# Copy and setup entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# passless sudo for the non-root user
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}-nopasswd && \
    chmod 0440 /etc/sudoers.d/${USERNAME}-nopasswd

# Create workspace and set permissions
RUN mkdir -p /workspace /usr/local/share/npm-global && \
    chown -R ${USERNAME}:${USERNAME} /workspace \
        /usr/local/share/npm-global

WORKDIR /workspace

# Set up non-root user
USER ${USERNAME}

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Default powerline10k theme
ARG POWERLINE10K_VERSION=1.2.0

RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${POWERLINE10K_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x

# Install AI CLIs
RUN npm install -g \
    @anthropic-ai/claude-code \
    @google/gemini-cli \
    @openai/codex \
    @github/copilot && \
    curl https://cursor.com/install -fsS | bash

# Set entrypoint and default command
ENTRYPOINT ["sudo", "/usr/local/bin/entrypoint.sh"]
