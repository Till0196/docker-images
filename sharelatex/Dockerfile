ARG TARGETARCH

# x86_64の場合、DockerHubからベースイメージを利用
FROM sharelatex/sharelatex:6 AS base-amd64

# arm64の場合、DockerHubにarm64向けイメージが存在しないため事前にビルドしたベースイメージを利用
FROM ghcr.io/till0196/sharelatex-arm64:latest AS base-arm64

# アーキテクチャに応じてベースイメージを選択
FROM base-${TARGETARCH}

# ベースの古いTeX Liveを丸ごと捨ててから新しい版を載せる
RUN rm -rf /usr/local/texlive
COPY --from=registry.gitlab.com/islandoftex/images/texlive:latest /usr/local/texlive /usr/local/texlive

# tlmgrをPATHに登録し、年度が凍結済みならtlnet-finalへ向けてから更新
RUN TLMGR=$(echo /usr/local/texlive/*/bin/*/tlmgr) && \
    TL_YEAR=$(basename "$(dirname "$(dirname "$(dirname "$TLMGR")")")") && \
    FINAL_URL="https://ftp.math.utah.edu/pub/tex/historic/systems/texlive/${TL_YEAR}/tlnet-final" && \
    $TLMGR path add && \
    if curl -fsI "${FINAL_URL}/" >/dev/null 2>&1; then $TLMGR option repository "${FINAL_URL}"; fi && \
    $TLMGR update --self && $TLMGR update --all

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
