#!/bin/bash

set -o errexit
set -o nounset

: ${BUILD_TYPE:=debug}
: ${BASE_REPO:="quay.io/travelping/fpp-vpp"}
: ${BASE_HASH:=$(git rev-parse HEAD)}

IMAGE_HASH_NAME="${BASE_REPO}:${BUILD_TYPE}-sha-${BASE_HASH}"
DEV_IMAGE_HASH_NAME="${BASE_REPO}:dev-${BUILD_TYPE}-sha-${BASE_HASH}"

SCRIPT_DIR="$(dirname "${BASH_SOURCE}")"

if [[ ! -d "${SCRIPT_DIR}/../vpp" ]]; then
    "${SCRIPT_DIR}/update-vpp.sh"
fi

RELEASE_TAG="$("${SCRIPT_DIR}/../vpp/build-root/scripts/version" | sed 's/~.*//')-$(git rev-parse HEAD|cut -c1-9)"
RELEASE_IMAGE_NAME="${BASE_REPO}:${RELEASE_TAG}_${BUILD_TYPE}"

docker tag "${IMAGE_HASH_NAME}" "${RELEASE_IMAGE_NAME}"
docker push "${RELEASE_IMAGE_NAME}"

DEV_RELEASE_IMAGE_NAME="${BASE_REPO}:${RELEASE_TAG}_dev_${BUILD_TYPE}"

docker tag "${DEV_IMAGE_HASH_NAME}" "${DEV_RELEASE_IMAGE_NAME}"
docker push "${DEV_RELEASE_IMAGE_NAME}"

