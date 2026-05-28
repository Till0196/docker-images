ARG TARGETARCH
FROM --platform=linux/${TARGETARCH} node:24-slim AS node
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
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libatomic1 \
        less git procps sudo zsh man-db fzf \
        unzip gnupg2 \
        gh \
        iptables ipset iproute2 dnsutils aggregate \
        jq nano vim curl wget ca-certificates locales tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN locale-gen ${LANG} && \
    update-locale LANG=${LANG} LANGUAGE=${LANGUAGE} LC_ALL=${LC_ALL}

# Persist directory.
RUN mkdir \
        /commandhistory \
        /configs && \
    touch /commandhistory/.bash_history && \
    chown -R ${USERNAME}:${USERNAME} \
        /commandhistory \
        /configs

# Install Git Delta
# renovate: datasource=github-releases depName=dandavison/delta
ARG GIT_DELTA_VERSION=0.18.2

RUN cd /tmp && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        export GIT_DELTA_ARCH="arm64"; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
        export GIT_DELTA_ARCH="amd64"; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi && \
    curl -fsSL -o git-delta_${GIT_DELTA_VERSION}_${GIT_DELTA_ARCH}.deb \
        "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${GIT_DELTA_ARCH}.deb" && \
    dpkg -i git-delta_${GIT_DELTA_VERSION}_${GIT_DELTA_ARCH}.deb && \
    rm git-delta_${GIT_DELTA_VERSION}_${GIT_DELTA_ARCH}.deb

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR="/usr/local/bin/" INSTALLER_NO_MODIFY_PATH=1 sh

# Copy scripts and set permissions
COPY ./scripts/user-migration.sh /usr/local/bin/user-migration.sh
COPY ./scripts/setup-links.sh /usr/local/bin/setup-links.sh
RUN chmod +x /usr/local/bin/user-migration.sh /usr/local/bin/setup-links.sh

# passless sudo for the non-root user
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}-nopasswd && \
    chmod 0440 /etc/sudoers.d/${USERNAME}-nopasswd

# Create workspace and set permissions
RUN mkdir -p /workspace /usr/local/share/npm-global && \
    chown -R ${USERNAME}:${USERNAME} \
        /workspace \
        /usr/local/share/npm-global

# Set up fzf key bindings and completion scripts.
# fzf switched tag conventions mid-history: <=0.44 uses bare `0.44.1`,
# >=0.45 uses `v0.45.0`. Try the `v`-prefixed form first, then fall back.
RUN FZF_VER=$(fzf --version | awk '{print $1}') && \
    for tag in "v${FZF_VER}" "${FZF_VER}"; do \
        if wget -q "https://raw.githubusercontent.com/junegunn/fzf/${tag}/shell/key-bindings.zsh" \
                -O /usr/share/doc/fzf/examples/key-bindings.zsh && \
           wget -q "https://raw.githubusercontent.com/junegunn/fzf/${tag}/shell/completion.zsh" \
                -O /usr/share/doc/fzf/examples/completion.zsh; then \
            break; \
        fi; \
    done

WORKDIR /workspace

# Set up non-root user
USER ${USERNAME}

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Default powerline10k theme (versioned via deluan/zsh-in-docker installer)
# renovate: datasource=github-releases depName=deluan/zsh-in-docker
ARG POWERLINE10K_VERSION=1.2.0

RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${POWERLINE10K_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x

# Install AI CLIs via npm
RUN npm install -g \
    @anthropic-ai/claude-code \
    @google/gemini-cli \
    @github/copilot && \
    npm cache clean --force && \
    rm -rf /tmp/*

# Install Codex CLI
# renovate: datasource=github-releases depName=openai/codex extractVersion=^rust-v(?<version>\d+\.\d+\.\d+)$
ARG CODEX_VERSION="0.134.0"
RUN cd /tmp && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        export CODEX_ARCH="aarch64"; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
        export CODEX_ARCH="x86_64"; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi && \
    curl -fsSL -o codex-${CODEX_ARCH}-unknown-linux-musl.tar.gz \
        "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-${CODEX_ARCH}-unknown-linux-musl.tar.gz" && \
    sudo tar -zxvf codex-${CODEX_ARCH}-unknown-linux-musl.tar.gz -C /usr/local/bin && \
    sudo mv /usr/local/bin/codex-${CODEX_ARCH}-unknown-linux-musl /usr/local/bin/codex && \
    rm codex-${CODEX_ARCH}-unknown-linux-musl.tar.gz

# Install Cursor-agent
RUN curl https://cursor.com/install -fsS | bash

ENV CLAUDE_CONFIG_DIR=/configs/claude
ENV GEMINI_CLI_SYSTEM_SETTINGS_PATH=/configs/gemini-system/settings.json