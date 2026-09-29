# syntax=docker/dockerfile:1
#
# Konnect (KiCad MCP server) + KiCad 10 CLI
#
# 構成B: 回路図編集(S式直接編集) + ERC/DRC + 製造ファイル出力までを
#        コンテナ内で完結させる。PCBのインタラクティブ編集(IPC API)は
#        GUIプロセスが必要なため、この環境では利用できない。
#
# ランタイムは KiCad 公式イメージ。公式イメージは kicad-cli 利用を
# 想定したもので、GUI 用途はサポート対象外。

ARG KICAD_TAG=10.0

###############################################################################
# Stage 1: Konnect をソースからビルド
#   - 公式リリースは Windows/macOS 向けバイナリなので Linux は自前ビルド
#   - ランタイムと同じ Debian bookworm 系で揃えて glibc 不一致を避ける
###############################################################################
FROM rust:1-bookworm AS builder

ARG KONNECT_REPO=https://github.com/mixelpixx/Konnect.git
# 再現性のためタグやコミットSHAを指定することを推奨 (例: v0.3.0)
ARG KONNECT_REF=main

RUN apt-get update && apt-get install -y --no-install-recommends \
        protobuf-compiler \
        libprotobuf-dev \
        pkg-config \
        libssl-dev \
        cmake \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch "${KONNECT_REF}" "${KONNECT_REPO}" . \
    && git rev-parse HEAD > /konnect-commit.txt

# schematic-viewer は別ワークスペース かつ system webview 依存のためビルドしない
RUN cargo build --release -p konnect \
    && install -m 0755 target/release/konnect /konnect

###############################################################################
# Stage 2: KiCad 10 公式イメージに載せる
###############################################################################
FROM kicad/kicad:${KICAD_TAG}

USER root

# イメージのライブラリ配置を起動時ではなくビルド時に検証する。
# レイアウトが変わっていたら黙って壊れるのではなくここで落とす。
RUN set -eux; \
    if [ ! -d /usr/share/kicad/symbols ] || [ ! -d /usr/share/kicad/footprints ]; then \
        echo "!! expected KiCad library layout not found"; \
        ls -la /usr/share/kicad || true; \
        exit 1; \
    fi; \
    command -v kicad-cli

COPY --from=builder /konnect /usr/local/bin/konnect
COPY --from=builder /konnect-commit.txt /etc/konnect-commit.txt

# --- ライブラリ探索パス -------------------------------------------------------
ENV KICAD10_SYMBOL_DIR=/usr/share/kicad/symbols \
    KICAD10_FOOTPRINT_DIR=/usr/share/kicad/footprints \
    KICAD10_3DMODEL_DIR=/usr/share/kicad/3dmodels \
    KICAD10_TEMPLATE_DIR=/usr/share/kicad/template

# --- 書き込み可能な HOME と グローバル lib-table -------------------------------
# コンテナは任意の UID (--user $(id -u)) で起動するので HOME は 0777。
# 新規 HOME には sym-lib-table / fp-lib-table が無く、これが無いと
# シンボル解決が効かず ERC が通らないので、テンプレートから配置しておく。
ARG KICAD_CONFIG_VER=10.0
ENV HOME=/konnect-home \
    XDG_CONFIG_HOME=/konnect-home/.config \
    XDG_CACHE_HOME=/konnect-home/.cache \
    XDG_DATA_HOME=/konnect-home/.local/share

RUN set -eux; \
    d="${XDG_CONFIG_HOME}/kicad/${KICAD_CONFIG_VER}"; \
    mkdir -p "$d" "${XDG_CACHE_HOME}" "${XDG_DATA_HOME}"; \
    for f in sym-lib-table fp-lib-table; do \
        if [ -f "/usr/share/kicad/template/$f" ]; then \
            cp "/usr/share/kicad/template/$f" "$d/$f"; \
        else \
            echo "!! template/$f not found - symbol/footprint resolution may fail"; \
        fi; \
    done; \
    chmod -R 0777 /konnect-home

# 作業ディレクトリ = ホストの ./projects をマウントする場所
WORKDIR /work

# MCP は stdio が既定。stdout に JSON-RPC 以外を出さないこと。
ENTRYPOINT ["/usr/local/bin/konnect"]
