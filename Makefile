IMAGE       ?= konnect-kicad:10
# KICAD_TAG / KONNECT_REF は未指定なら Dockerfile の既定値 (検証済みの固定版) を使う
KICAD_TAG   ?=
KONNECT_REF ?=
GHCR_IMAGE  ?= ghcr.io/bols-blue/konnect-kicad:10
BUILD_ARGS   = $(if $(KICAD_TAG),--build-arg KICAD_TAG=$(KICAD_TAG)) \
               $(if $(KONNECT_REF),--build-arg KONNECT_REF=$(KONNECT_REF))
PROJECTS    ?= $(CURDIR)/projects
SCRIPTS      = plugins/kicad-konnect/scripts

# このリポジトリで作業するときは ./projects を /work にし、IPC と GUI 設定も
# リポジトリ内に置く (プラグインとして使うときの既定は scripts/_env.sh)
export KONNECT_IMAGE      = $(IMAGE)
export KONNECT_PROJECTS   = $(PROJECTS)
export KONNECT_IPC_DIR    = $(CURDIR)/.kicad-ipc
export KONNECT_GUI_CONFIG = $(CURDIR)/.kicad-gui-config
export KONNECT_BRIDGE_DIR_HOST = $(CURDIR)/.kicad-bridge

.PHONY: help build rebuild pull smoke shell gui gui-stop cli versions clean

help:
	@echo "make pull      公開イメージ $(GHCR_IMAGE) を取得して $(IMAGE) としてタグ付け"
	@echo "make build     イメージをローカルでビルド (KICAD_TAG= KONNECT_REF= で上書き可)"
	@echo "make rebuild   キャッシュを使わず再ビルド"
	@echo "make smoke     疎通確認 (kicad-cli / ライブラリ / MCP ハンドシェイク)"
	@echo "make shell     コンテナ内シェル"
	@echo "make gui       KiCad GUI を X11 転送で起動 (PCB系ツール用 / PROJECT=/work/...kicad_pro)"
	@echo "make gui-stop  KiCad GUI を停止"
	@echo "make versions  KiCad と Konnect のバージョンを表示"
	@echo "make clean     イメージを削除"

build:
	docker build $(BUILD_ARGS) -t $(IMAGE) .

rebuild:
	docker build --no-cache --pull $(BUILD_ARGS) -t $(IMAGE) .

pull:
	docker pull $(GHCR_IMAGE)
	docker tag $(GHCR_IMAGE) $(IMAGE)

smoke:
	@chmod +x $(SCRIPTS)/*.sh
	@bash $(SCRIPTS)/smoke-test.sh

shell:
	docker run --rm -it \
		--user "$$(id -u):$$(id -g)" \
		-v "$(PROJECTS):/work" -w /work \
		--entrypoint bash $(IMAGE)

gui:
	@bash $(SCRIPTS)/kicad-gui.sh $(PROJECT)

gui-stop:
	@bash $(SCRIPTS)/kicad-gui.sh --stop

cli:
	@bash $(SCRIPTS)/kicad-cli.sh $(ARGS)

versions:
	@echo -n "kicad-cli: "; bash $(SCRIPTS)/kicad-cli.sh version
	@echo -n "konnect commit: "; docker run --rm --entrypoint cat $(IMAGE) /etc/konnect-commit.txt

clean:
	-docker rmi $(IMAGE)
