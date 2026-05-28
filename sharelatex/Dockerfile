ARG TARGETARCH

# x86_64の場合、DockerHubからベースイメージを利用
FROM sharelatex/sharelatex:6 AS base-amd64

# arm64の場合、DockerHubにarm64向けイメージが存在しないため事前にビルドしたベースイメージを利用
FROM ghcr.io/till0196/sharelatex-arm64:latest AS base-arm64

# アーキテクチャに応じてベースイメージを選択
FROM base-${TARGETARCH}

COPY --from=registry.gitlab.com/islandoftex/images/texlive:latest /usr/local/texlive /usr/local/texlive

# add tlmgr to PATH (新しい方のTeX Liveを採用。ベースイメージに古い年度が同居している場合に備えて最新年度のtlmgrを選ぶ)
RUN echo "Set PATH to $PATH" && \
    NEW_TL_BIN=$(ls -d /usr/local/texlive/20*/bin/*/ | sort -V | tail -n1) && \
    "${NEW_TL_BIN}tlmgr" path add

# update tlmgr
RUN tlmgr update --self

# update packages
RUN tlmgr update --all

# update system packages
RUN apt-get update && apt-get upgrade -y

# install inkscape for svg support
RUN apt-get install inkscape -y

# install lilypond
RUN apt-get install lilypond -y

# enable shell-escape by default:
RUN TEXLIVE_FOLDER=$(find /usr/local/texlive/ -type d -name '20*') \
    && echo % enable shell-escape by default >> /$TEXLIVE_FOLDER/texmf.cnf \
    && echo shell_escape = t >> /$TEXLIVE_FOLDER/texmf.cnf
