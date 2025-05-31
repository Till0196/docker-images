FROM ubuntu:noble AS build

# GStreamer プラグインのバージョン
ARG GST_PLUGINS_RS_VERSION="0.13.6"

# 環境変数設定
ENV DEBIAN_FRONTEND=noninteractive
ENV RUST_LOG=debug
ENV GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0

# 基本パッケージとGStreamer開発ライブラリをインストール
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    curl \
    git \
    cmake \
    ninja-build \
    meson \
    libssl-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-bad1.0-dev \
    libgstreamer-plugins-good1.0-dev \
    libgstrtspserver-1.0-dev \
    libges-1.0-dev \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    alsa-utils \
    v4l-utils \
    libcairo2-dev \
    libpango1.0-dev \
    libgdk-pixbuf2.0-dev \
    libgtk-4-dev \
    libwebp-dev \
    libclang-dev \
    && rm -rf /var/lib/apt/lists/*

# NDI SDKをインストール
RUN curl -fsSL https://raw.githubusercontent.com/DistroAV/DistroAV/refs/heads/master/CI/libndi-get.sh | bash

# Rustをインストール
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# cargo-cをインストール
RUN cargo install cargo-c

# gst-plugins-rsをtar.gzでダウンロードして展開
WORKDIR /build
RUN curl -L "https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs/-/archive/${GST_PLUGINS_RS_VERSION}/gst-plugins-rs-${GST_PLUGINS_RS_VERSION}.tar.gz" | tar -xz
WORKDIR /build/gst-plugins-rs-${GST_PLUGINS_RS_VERSION}

# cargo-cを使用してgst-plugins-rs全体をビルド・インストール
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    cargo cbuild --prefix=/usr/local --libdir=lib
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    cargo cinstall --prefix=/usr/local --libdir=lib

# プラグインが正しくインストールされているか確認
RUN ldconfig && \
    echo "=== インストールされたライブラリファイル ===" && \
    find /usr/local/lib -name "libgst*.so" -o -name "*.so" | sort && \
    echo "=== GStreamerプラグインパス ===" && \
    echo "GST_PLUGIN_PATH: $GST_PLUGIN_PATH" && \
    ls -la /usr/local/lib/gstreamer-1.0/ || echo "ディレクトリが存在しません" && \
    echo "=== インストールされた全プラグイン ===" && \
    gst-inspect-1.0 --print-all | grep "Plugin Details:" -A 5 | grep -E "(Name|Filename)" | head -20 && \
    echo "=== Rustプラグイン確認 ===" && \
    gst-inspect-1.0 --print-all | grep -B2 -A5 "gst-plugins-rs" || echo "Rustプラグインが見つかりません" && \
    echo "=== cargo-c インストール確認 ===" && \
    find /usr/local -name "*gst*" -type f | head -20

# 主要なエレメントの確認
RUN ldconfig && \
    echo "=== 主要なエレメント確認 ===" && \
    for element in webrtcsink webrtcsrc whipclientsink whipserversrc s3sink s3src hlssink3 awstranscriber mp4mux fmp4mux dav1ddec rav1eenc fallbacksrc fallbackswitch livesync; do \
        if gst-inspect-1.0 $element >/dev/null 2>&1; then \
            echo "✓ $element: OK"; \
        else \
            echo "✗ $element: NOT FOUND"; \
        fi; \
    done

# 作業ディレクトリをクリーンアップ
WORKDIR /
RUN rm -rf /build

# 実行時に必要なパッケージのみ残す軽量版を作成（マルチステージビルド）
FROM ubuntu:noble AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0

# 実行時必要なパッケージのみインストール
RUN apt-get update && apt-get install -y \
    gstreamer1.0-tools \
    gstreamer1.0-alsa \
    gstreamer1.0-libav \
    gstreamer1.0-rtsp \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    libgstreamer1.0-0 \
    libgstreamer-plugins-base1.0-0 \
    libgstreamer-plugins-bad1.0-0 \
    libnice-dev \
    alsa-utils \
    v4l-utils \
    curl \
    && rm -rf /var/lib/apt/lists/*

# ビルドステージからプラグインをコピー
COPY --from=build /usr/local/lib/gstreamer-1.0/ /usr/local/lib/gstreamer-1.0/
COPY --from=build /usr/local/lib/libgst*.so* /usr/local/lib/

# ライブラリキャッシュを更新
RUN ldconfig
