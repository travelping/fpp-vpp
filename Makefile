.PHONY: image initialize

BUILD_TYPE ?= debug
CI_BUILD ?= 0

BASE_REPO ?= quay.io/travelping/fpp-vpp
BASE_TAG ?= local
BASE_HASH ?= $(shell git rev-parse HEAD)
BUILDER_REPO ?= quay.io/travelping/vpp-builder
BUILDER_HASH = $(shell build/getbuilderhash.sh)
QUAY_IO_IMAGE_EXPIRES_AFTER ?=

export DOCKER_BUILDKIT = 1

image: initialize
	BUILDER_REPO=${BUILDER_REPO} BUILDER_HASH=${BUILDER_HASH} \
	BASE_TAG=${BASE_TAG} \
	BASE_REPO=${BASE_REPO} BASE_HASH=${BASE_HASH} \
	BUILD_TYPE=${BUILD_TYPE} CI_BUILD=${CI_BUILD} \
	QUAY_IO_IMAGE_EXPIRES_AFTER=${QUAY_IO_IMAGE_EXPIRES_AFTER} \
	build/build.sh

initialize:
	build/ensure-initialized.sh

