#!/bin/bash

set -o nounset

: ${BASE_REPO:="quay.io/travelping/fpp-vpp"}
: ${BASE_HASH:=$(git rev-parse HEAD)}
: ${BUILD_TYPE:=debug}

IMAGE_HASH_NAME="${BASE_REPO}:${BUILD_TYPE}-sha-${BASE_HASH}"
DEV_IMAGE_HASH_NAME="${BASE_REPO}:dev-${BUILD_TYPE}-sha-${BASE_HASH}"

SCRIPT_DIR="$(dirname "${BASH_SOURCE}")"

"${SCRIPT_DIR}/try-pull-docker-image.sh" "${IMAGE_HASH_NAME}"
PULL_RES="${?}"
if [[ "${PULL_RES}" -eq 0 ]]; then
    "${SCRIPT_DIR}/try-pull-docker-image.sh" "${DEV_IMAGE_HASH_NAME}"
    PULL_RES="${?}"
fi

case "${PULL_RES}" in
0)
    echo "image_to_retag_present=true" >> "${GITHUB_OUTPUT}"
    echo "${BUILD_TYPE}_image_to_retag_present=true" >> "${GITHUB_OUTPUT}"
    ;;
2)
    echo "image_to_retag_present=false" >> "${GITHUB_OUTPUT}"
    echo "${BUILD_TYPE}_image_to_retag_present=false" >> "${GITHUB_OUTPUT}"
    ;;
*)
    exit 1
    ;;
esac

