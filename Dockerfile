# syntax = docker/dockerfile:experimental
FROM ubuntu:22.04 AS build-base-stage

WORKDIR /

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private \
    --mount=target=/var/cache/apt,type=cache,sharing=private \
    echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections && \
    echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections && \
    apt-get update && \
    apt-get install -y software-properties-common && \
    apt-get dist-upgrade -yy && \
    # add reporistory for newer golang releases
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common build-essential sudo git \
        # netbase is needed for Scapy
        netbase curl ca-certificates iproute2 gdb tcpdump iputils-ping \
        # use ccache for clang object files caching
        ccache libpcap-dev dumb-init gdbserver \
        # golang installed from ppa
        golang-1.24-go \
        # clang also installed in vpp Makefile, make sure to match versions
        clang \
        # llvm provides llc for xdp-tools build
        llvm \
        # gnu linker is used, add missing c++ library
        g++-12 \
    && \
    ln -s /usr/lib/go-1.24/bin/go /usr/bin/go && \
    ln -s /usr/lib/go-1.24/bin/gofmt /usr/bin/gofmt && \
    # set clang as default C and C++ compiler
    update-alternatives --set c++ /usr/bin/clang++ && \
    update-alternatives --set cc /usr/bin/clang &&\
    apt-get clean

# configure ccache, but do not provide it in path
# each RUN should provide it separately
ENV CCACHE_DIR=/ccache \
    CCACHE_MAXSIZE=600M \
    CCACHE_COMPRESS=true \
    CCACHE_COMPRESSLEVEL=6 \
    GOPATH=/go

# golang uses ccache as well
RUN --mount=target=/ccache,type=cache \
    PATH="/usr/lib/ccache:$PATH" && \
    go install github.com/onsi/ginkgo/ginkgo@v1.16.5 && \
    mv /go/bin/ginkgo /usr/local/bin && \
    go install golang.org/x/tools/gopls@v0.11.0 && \
    mv /go/bin/gopls /usr/local/bin

COPY vpp/Makefile /vpp-src/Makefile
COPY vpp/build/external /vpp-src/build/external

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private \
    --mount=target=/var/cache/apt,type=cache,sharing=private \
    --mount=target=/ccache,type=cache \
    PATH="/usr/lib/ccache:$PATH" && \
    cd /vpp-src && \
    git config --global user.email "dummy@example.com" && \
    git config --global user.name "dummy user" && \
    git init && \
    git add Makefile && \
    git commit -m "dummy commit" && \
    # version requred to have this format
    git tag -a v24.02-rc0 -m "dummy tag" && \
    make UNATTENDED=yes install-dep install-ext-dep && \
    rm -rf /vpp-src && \
    apt-get clean

FROM build-base-stage AS build-stage

ADD vpp /vpp-src

# starting from this point, the debug and release buffers differ
ARG BUILD_TYPE

RUN --mount=target=/ccache,type=cache \
    PATH="/usr/lib/ccache:$PATH" && \
    case ${BUILD_TYPE} in \
        debug) \
            target="pkg-deb-debug"; \
            args="-DVPP_ENABLE_TRAJECTORY_TRACE=1"; \
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
    make -C /vpp-src "${target}" V=1 VPP_EXTRA_CMAKE_ARGS="${args}" && \
    ccache -s && \
    mkdir -p /out/debs && \
    mv /vpp-src/build-root/*.deb /out/debs

# this stage is used to copy out the debs
FROM scratch as artifacts

COPY --from=build-stage /out/debs .

# dev image starts here
FROM build-base-stage AS dev-stage
ARG BUILD_TYPE

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private \
    --mount=target=/var/cache/apt,type=cache,sharing=private \
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
    apt-get clean

# use clean vpp source so as not to make the image too bloated
ADD vpp /vpp-src
# provide symlinks needed for running the Pythonic integration tests
RUN mkdir -p /vpp-src/build-root/build-test/src && \
    ln -fs /vpp-src/test/* /vpp-src/build-root/build-test/src/ && \
    # fix git repo ownership issue
    git config --global --add safe.directory /src

# final image starts here
FROM ubuntu:22.04 AS final-stage
ARG BUILD_TYPE
WORKDIR /

ENV VPP_INSTALL_SKIP_SYSCTL=1
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private \
    --mount=target=/var/cache/apt,type=cache,sharing=private \
    apt-get update && apt-get dist-upgrade -yy && \
    apt-get install --no-install-recommends -yy \
        liblz4-tool tar gdb gdbserver strace apt-utils \
        libhyperscan5 libmbedcrypto7 libmbedtls-dev libmbedx509-1 \
        python3 python3-minimal libpython3-stdlib \
        python3-cffi python3-cffi-backend libnuma1 \
        libnl-3-200 libnl-route-3-200 libpcap0.8

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private \
    --mount=target=/var/cache/apt,type=cache,sharing=private \
    --mount=target=/debs,source=/out/debs,from=build-stage,type=bind \
    extra_debs=; \
    if [ "${BUILD_TYPE}" = "debug" ]; then \
        extra_debs="${extra_debs} /debs/vpp-dev_*.deb"; \
        extra_debs="${extra_debs} /debs/libvppinfra-dev_*.deb"; \
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
    apt-get clean

ENTRYPOINT /usr/bin/vpp
