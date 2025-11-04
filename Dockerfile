# syntax = docker/dockerfile:experimental
ARG BUILDER_IMAGE

FROM ${BUILDER_IMAGE} AS build-stage

ADD vpp /vpp-src

# starting from this point, the debug and release buffers differ
ARG BUILD_TYPE

RUN --mount=target=/vpp-src/build-root/.ccache,type=cache \
    --mount=target=/ccache,type=cache \
    PATH="/usr/lib/ccache:$PATH"; \
    case ${BUILD_TYPE} in \
        debug) \
            target="pkg-deb-debug"; \
            args="-DVPP_ENABLE_TRAJECTORY_TRACE=1 -DVPP_ENABLE_SANITIZE_ADDR=ON"; \
            ;; \
        release) \
            target="pkg-deb"; \
            args=""; \
            ;; \
        *) \
            echo >&2 "Bad BUILD_TYPE: ${BUILD_TYPE}"; \
            ;; \
    esac; \
    echo "Building target: ${target} with flags ${args}" && \
    make "-j$(nproc)" -C /vpp-src "${target}" V=1 VPP_EXTRA_CMAKE_ARGS="${args}" && \
    ccache -s && \
    mkdir -p /out/debs && \
    mv /vpp-src/build-root/*.deb /out/debs

# this stage is used to copy out the debs
FROM scratch as artifacts

COPY --from=build-stage /out/debs .

# dev image starts here
FROM ${BUILDER_IMAGE} AS dev-stage
ARG BUILDER_IMAGE
ARG BUILD_TYPE

RUN --mount=target=/var/lib/apt,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    --mount=target=/debs,source=/out/debs,from=build-stage,type=bind \
    apt-get install --no-install-recommends -yy \
        /debs/vpp_*.deb \
        /debs/vpp-dbg_*.deb \
        /debs/vpp-plugin-core_*.deb \
        /debs/vpp-plugin-devtools_*.deb \
        /debs/vpp-plugin-dpdk*.deb \
        /debs/libvppinfra_*.deb \
        /debs/python3-vpp-api_*.deb \
        /debs/vpp-dev_*.deb \
        /debs/libvppinfra-dev_*.deb && \
    if [ "${BUILD_TYPE}" = "debug" ]; then \
        # Add stdc++ as dependency to vpp, so ASAN can intercept c++ stuff (like hyperscan)
        apt-get update && \
        apt-get install --no-install-recommends -yy patchelf && \
        patchelf --add-needed $(realpath -s $(clang -print-file-name=libstdc++.so)) $(which vpp) && true; \
    fi

# use clean vpp source so as not to make the image too bloated
ADD vpp /vpp-src
# provide symlinks needed for running the Pythonic integration tests
RUN mkdir -p /vpp-src/build-root/build-test/src && \
    ln -fs /vpp-src/test/* /vpp-src/build-root/build-test/src/&& \
    # fix git repo ownership issue
    git config --global --add safe.directory /src

# final image starts here
FROM ubuntu:22.04 AS final-stage
ARG BUILD_TYPE
WORKDIR /

ENV VPP_INSTALL_SKIP_SYSCTL=1
RUN --mount=target=/var/lib/apt,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get dist-upgrade -yy && \
    apt-get install --no-install-recommends -yy \
        liblz4-tool tar gdb gdbserver strace apt-utils \
        libhyperscan5 libmbedcrypto7 libmbedtls-dev libmbedx509-1 \
        python3 python3-minimal libpython3-stdlib \
        python3-cffi python3-cffi-backend libnuma1 \
        libnl-3-200 libnl-route-3-200 libpcap0.8

RUN --mount=target=/var/lib/apt,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    --mount=target=/debs,source=/out/debs,from=build-stage,type=bind \
    extra_debs=; \
    if [ "${BUILD_TYPE}" = "debug" ]; then \
        extra_debs="${extra_debs} /debs/vpp-dev_*.deb"; \
        extra_debs="${extra_debs} /debs/libvppinfra-dev_*.deb"; \
        # libasan8 compatible with clang-14/gcc-12
        extra_debs="${extra_debs} libasan8"; \
        # Add stdc++ as dependency to vpp, so ASAN can intercept c++ stuff
        extra_debs="${extra_debs} patchelf"; \
        extra_debs="${extra_debs} libstdc++-12-dev"; \
    fi && \
    apt-get install --no-install-recommends -yy \
        /debs/vpp_*.deb \
        /debs/vpp-dbg_*.deb \
        /debs/vpp-plugin-core_*.deb \
        /debs/vpp-plugin-devtools_*.deb \
        /debs/vpp-plugin-dpdk*.deb \
        /debs/libvppinfra_*.deb \
        /debs/python3-vpp-api_*.deb \
        ${extra_debs} && \
    if [ "${BUILD_TYPE}" = "debug" ]; then \
        # Add stdc++ as dependency to vpp, so ASAN can intercept c++ stuff
        patchelf --add-needed /usr/lib/gcc/x86_64-linux-gnu/12/libstdc++.so $(which vpp) && true; \
    fi

ENTRYPOINT /usr/bin/vpp
