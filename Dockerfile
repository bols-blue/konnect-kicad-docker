# syntax=docker/dockerfile:1
#
# Konnect (KiCad MCP server) + KiCad 10 CLI
#
# 構成B: 回路図編集(S式直接編集) + ERC/DRC + 製造ファイル出力までを
#        コンテナ内で完結させる。PCBのインタラクティブ編集(IPC API)は
#        GUIプロセスが必要なので、plugins/kicad-konnect/scripts/kicad-gui.sh で同じイメージの
#        KiCad GUI を X11 転送で起動し、IPC ソケットを Konnect と共有する。
#
# ランタイムは KiCad 公式イメージ。公式イメージは kicad-cli 利用を
# 想定したもので、GUI 用途はサポート対象外。

# 既定値は動作検証済みの組み合わせ (make smoke / 自動配線の通し検証)。
# 上げる場合は Makefile 経由で KICAD_TAG= / KONNECT_REF= を渡して検証してから変える。
ARG KICAD_TAG=10.0.6

###############################################################################
# Stage 1: Konnect をソースからビルド
#   - 公式リリースは Windows/macOS 向けバイナリなので Linux は自前ビルド
#   - ランタイム (KiCad 10.0.6 = Debian 13 trixie) より古い bookworm でビルドし、
#     新しい glibc 上でそのまま動くようにする
###############################################################################
FROM rust:1-bookworm AS builder

ARG KONNECT_REPO=https://github.com/mixelpixx/Konnect.git
# ブランチ・タグ・コミット SHA のいずれも可。既定は検証済みの 0.12.1 相当の main
ARG KONNECT_REF=9d582b6560f6c476dafae025f7991792c7f70d31

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
# clone --branch は SHA を受け付けないので fetch で取る (GitHub は SHA 直指定の fetch 可)
RUN git init -q . \
    && git remote add origin "${KONNECT_REPO}" \
    && git fetch -q --depth 1 origin "${KONNECT_REF}" \
    && git checkout -q FETCH_HEAD \
    && git rev-parse HEAD > /konnect-commit.txt

# schematic-viewer は別ワークスペース かつ system webview 依存のためビルドしない
RUN cargo build --release -p konnect \
    && install -m 0755 target/release/konnect /konnect

###############################################################################
# Stage 1b: Freerouting (自動配線)
#   - Konnect は `java -jar freerouting*.jar` を headless MCP モードで起動する
#   - Konnect のテストが対象にしている 2.3.0 に固定し、SHA-256 を検証する
#     (値は GitHub Releases の asset digest)
#   - builder と別ステージにして、更新時に cargo のキャッシュを壊さない
###############################################################################
FROM rust:1-bookworm AS freerouting

ARG FREEROUTING_VERSION=2.3.0
ARG FREEROUTING_SHA256=3cf18d608437740bc497db6b8ef5888e2e60a08de0def20691d1bad0c0e0ee24

RUN set -eux; \
    curl -fsSL -o /freerouting.jar \
      "https://github.com/freerouting/freerouting/releases/download/v${FREEROUTING_VERSION}/freerouting-${FREEROUTING_VERSION}.jar"; \
    echo "${FREEROUTING_SHA256}  /freerouting.jar" | sha256sum -c -

###############################################################################
# Stage 2: KiCad 10 公式イメージに載せる
###############################################################################
FROM kicad/kicad:${KICAD_TAG}

USER root

# Freerouting 2.3.0 は Java 25 ターゲット (build.gradle の languageVersion)。
# GUI は使わない (--gui.enabled=false) ので headless JRE で足りる。
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-25-jre-headless \
    && rm -rf /var/lib/apt/lists/*

ARG FREEROUTING_VERSION=2.3.0
COPY --from=freerouting /freerouting.jar /opt/freerouting/freerouting-${FREEROUTING_VERSION}.jar

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
# kicad_common.json は IPC API サーバ有効化のみ(他の項目は KiCad が既定値で補う)。
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
    printf '{\n  "api": {\n    "enable_server": true\n  }\n}\n' > "$d/kicad_common.json"; \
    chmod -R 0777 /konnect-home

# 作業ディレクトリ = ホストの ./projects をマウントする場所
WORKDIR /work

# MCP は stdio が既定。stdout に JSON-RPC 以外を出さないこと。
ENTRYPOINT ["/usr/local/bin/konnect"]
