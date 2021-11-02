NAME := build-container
IMAGE := local/$(NAME):latest
TARGET := x86_64
VERSION := "develop"
RELEASE_DIR := release/$(VERSION)
DOCKER_BUILDKIT := 1
export
ifeq ($(strip $(shell git status --porcelain 2>/dev/null)),)
	GIT_STATE=clean
else
	GIT_STATE=dirty
endif
OUT_DIR := build/
include config.env
$(eval export $(shell sed -ne 's/ *#.*$//; /./ s/=.*$$// p' config.env))

docker = docker
executables = $(docker git sed paste)

.DEFAULT_GOAL := all

.PHONY: all
all: $(RELEASE_DIR)/$(NAME).tar

$(RELEASE_DIR):
	mkdir -p $(RELEASE_DIR)

.PHONY: image
$(RELEASE_DIR)/$(NAME).tar: $(RELEASE_DIR)
	$(docker) build \
		$(shell cat config.env | sed 's@^@--build-arg @g' | paste -s -d " ") \
		--tag $(IMAGE) \
		--file $(PWD)/Dockerfile \
		--output type=tar,dest=$@ \
		$(IMAGE_OPTIONS) \
		$(PWD)

.PHONY: mrproper
mrproper:
	docker image rm -f $(IMAGE)
	rm -rf build

.PHONY: update-packages
update-packages:
	docker rm -f "$(NAME)-update-packages" || :
	docker run \
		--rm \
		--detach \
		--name "$(NAME)-update-packages" \
		--volume $(PWD)/files/etc/apt/packages-base.list:/etc/apt/packages-base.list \
		--volume $(PWD)/files/usr/local/bin:/usr/local/bin \
		debian@sha256:$(DEBIAN_IMAGE_HASH) tail -f /dev/null
	docker exec -it "$(NAME)-update-packages" update-packages
	docker cp \
		"$(NAME)-update-packages:/etc/apt/packages.list" \
		"$(PWD)/files/etc/apt/packages.list"
	docker cp \
		"$(NAME)-update-packages:/etc/apt/sources.list" \
		"$(PWD)/files/etc/apt/sources.list"
	docker cp \
		"$(NAME)-update-packages:/etc/apt/package-hashes.txt" \
		"$(PWD)/files/etc/apt/package-hashes.txt"
	docker rm -f "$(NAME)-update-packages"

check_executables := $(foreach exec,$(executables),\$(if \
	$(shell which $(exec)),some string,$(error "No $(exec) in PATH")))
