IMAGE       ?= konnect-kicad:10
KICAD_TAG   ?= 10.0
KONNECT_REF ?= main
PROJECTS    ?= $(CURDIR)/projects

export KONNECT_IMAGE    = $(IMAGE)
export KONNECT_PROJECTS = $(PROJECTS)

.PHONY: help build rebuild smoke shell gui gui-stop cli versions clean

help:
	@echo "make build     イメージをビルド (KICAD_TAG=$(KICAD_TAG) KONNECT_REF=$(KONNECT_REF))"
	@echo "make rebuild   キャッシュを使わず再ビルド"
	@echo "make smoke     疎通確認 (kicad-cli / ライブラリ / MCP ハンドシェイク)"
	@echo "make shell     コンテナ内シェル"
	@echo "make gui       KiCad GUI を X11 転送で起動 (PCB系ツール用 / PROJECT=/work/...kicad_pro)"
	@echo "make gui-stop  KiCad GUI を停止"
	@echo "make versions  KiCad と Konnect のバージョンを表示"
	@echo "make clean     イメージを削除"

build:
	docker build \
		--build-arg KICAD_TAG=$(KICAD_TAG) \
		--build-arg KONNECT_REF=$(KONNECT_REF) \
		-t $(IMAGE) .

rebuild:
	docker build --no-cache --pull \
		--build-arg KICAD_TAG=$(KICAD_TAG) \
		--build-arg KONNECT_REF=$(KONNECT_REF) \
		-t $(IMAGE) .

smoke:
	@chmod +x scripts/*.sh
	@bash scripts/smoke-test.sh

shell:
	docker run --rm -it \
		--user "$$(id -u):$$(id -g)" \
		-v "$(PROJECTS):/work" -w /work \
		--entrypoint bash $(IMAGE)

gui:
	@bash scripts/kicad-gui.sh $(PROJECT)

gui-stop:
	@bash scripts/kicad-gui.sh --stop

cli:
	@bash scripts/kicad-cli.sh $(ARGS)

versions:
	@echo -n "kicad-cli: "; bash scripts/kicad-cli.sh version
	@echo -n "konnect commit: "; docker run --rm --entrypoint cat $(IMAGE) /etc/konnect-commit.txt

clean:
	-docker rmi $(IMAGE)
