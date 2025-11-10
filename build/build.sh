#!/bin/bash

set -o nounset

: ${CI_BUILD:=}
: ${DO_PUSH:=}
: ${GITHUB_OUTPUT:=}
: ${QUAY_IO_IMAGE_EXPIRES_AFTER:=}

DOCKER_BUILD="docker build"
if [[ "${DOCKER_BUILD_DEBUG:-}" -eq 1 ]]; then
    export BUILDX_EXPERIMENTAL=1
    DOCKER_BUILD="docker buildx debug --on=error --invoke=/bin/bash build --progress=plain"
fi

BUILD_OPTS=()
if [[ "${CI_BUILD}" -eq 1 ]]; then
    if [[ -n "${QUAY_IO_IMAGE_EXPIRES_AFTER}" ]]; then
        BUILD_OPTS+=(--label "quay.expires-after=${QUAY_IO_IMAGE_EXPIRES_AFTER}")
    fi
fi

DEV_IMAGE="${BASE_REPO}:${BASE_TAG}_dev_${BUILD_TYPE}"
IMAGE="${BASE_REPO}:${BASE_TAG}_${BUILD_TYPE}"
CACHED_DEV_IMAGE="${BASE_REPO}:dev-${BUILD_TYPE}-sha-${BASE_HASH}"
CACHED_IMAGE="${BASE_REPO}:${BUILD_TYPE}-sha-${BASE_HASH}"

BUILDER_IMAGE="${BUILDER_REPO}:${BASE_TAG}"
CACHED_BUILDER_IMAGE="${BUILDER_REPO}:sha-${BUILDER_HASH}"

function tag_cached_base_images_as_local()
{
    docker tag "${CACHED_DEV_IMAGE}" "${DEV_IMAGE}"
    docker tag "${CACHED_IMAGE}" "${IMAGE}"

    if [[ -n "${GITHUB_OUTPUT}" ]]; then
        echo "registry_cache_used=vpp-base" >> $GITHUB_OUTPUT
    fi
}

function tag_cached_dep_images_as_local()
{
    docker tag "${CACHED_BUILDER_IMAGE}" "${BUILDER_IMAGE}"
    if [[ -n "${GITHUB_OUTPUT}" ]]; then
        echo "registry_cache_used=vpp-builder" >> $GITHUB_OUTPUT
    fi
}

if [[ "${CI_BUILD}" -eq 1 ]]; then
    try_pull_docker_image="$(dirname "${BASH_SOURCE}")/try-pull-docker-image.sh"

    if docker image inspect "${CACHED_DEV_IMAGE}" >/dev/null 2>&1 &&
       docker image inspect "${CACHED_IMAGE}" >/dev/null 2>&1; then
        tag_cached_base_images_as_local

        exit 0
    else
        "${try_pull_docker_image}" "${CACHED_DEV_IMAGE}"
        PULL_RES="${?}"
        if [[ "${PULL_RES}" -eq 0 ]]; then
            "${try_pull_docker_image}" "${CACHED_IMAGE}"
            PULL_RES="${?}"
        fi

        case "${PULL_RES}" in
        0)
            tag_cached_base_images_as_local
            exit 0
            ;;
        2)
            "$(dirname "${BASH_SOURCE}")/update-vpp.sh"
            ;;
        *)
            exit 1
            ;;
        esac
    fi

    if docker image inspect "${CACHED_BUILDER_IMAGE}" >/dev/null 2>&1; then
        tag_cached_dep_images_as_local
    else
        "${try_pull_docker_image}" "${CACHED_BUILDER_IMAGE}"
        PULL_RES="${?}"
        case "${PULL_RES}" in
        0)
            tag_cached_dep_images_as_local
            ;;
        2)
            if ! ${DOCKER_BUILD} \
                -t "${BUILDER_IMAGE}" \
                -f vpp-builder.Dockerfile \
                "${BUILD_OPTS[@]}" \
                .
            then
                exit 1
            fi

            docker tag "${BUILDER_IMAGE}" "${CACHED_BUILDER_IMAGE}"
            if [[ "${DO_PUSH,,}" == "y" ]]; then
                docker push "${CACHED_BUILDER_IMAGE}"
            fi

            if [[ -n "${GITHUB_OUTPUT}" ]]; then
                echo "registry_cache_used=none" >> $GITHUB_OUTPUT
            fi
            ;;
        *)
            exit 1
            ;;
        esac
    fi
fi

set -o errexit

if [[ "${CI_BUILD}" -ne 1 ]]; then
    ${DOCKER_BUILD} \
        -t "${BUILDER_IMAGE}" \
        -f vpp-builder.Dockerfile \
        "${BUILD_OPTS[@]}" \
        .
fi

${DOCKER_BUILD} \
  -t "${DEV_IMAGE}" \
  --build-arg BUILDER_IMAGE="${BUILDER_IMAGE}" \
  --build-arg BUILD_TYPE="${BUILD_TYPE}" \
  --target dev-stage \
  "${BUILD_OPTS[@]}" \
  .
if [[ "${CI_BUILD}" -eq 1 ]]; then
    docker tag "${DEV_IMAGE}" "${CACHED_DEV_IMAGE}"
    if [[ "${DO_PUSH,,}" == "y" ]]; then
        docker push "${CACHED_DEV_IMAGE}"
    fi
fi

${DOCKER_BUILD} \
  -t ${IMAGE} \
  --build-arg BUILDER_IMAGE="${BUILDER_IMAGE}" \
  --build-arg BUILD_TYPE="${BUILD_TYPE}" \
  --target final-stage \
  "${BUILD_OPTS[@]}" \
  .
if [[ "${CI_BUILD}" -eq 1 ]]; then
    docker tag "${IMAGE}" "${CACHED_IMAGE}"
    if [[ "${DO_PUSH,,}" == "y" ]]; then
        docker push "${CACHED_IMAGE}"
    fi
fi

