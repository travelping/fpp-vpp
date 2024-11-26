# syntax = docker/dockerfile:experimental
FROM ubuntu:20.04 AS build-base-stage

WORKDIR /

ENV BUILDKIT_VERSION "v0.8.2"
ENV BUILDCTL_SHA256 "b64aec46fb438ea844616b3205c33b01a3a49ea7de1f8539abd0daeb4f07b9f9"
ENV INDENT_SHA256 "12185be748db620f8f7799ea839f0d10ce643b9f5ab1805c960e56eb27941236"
ENV LIBC_SHA256 "9a8caf9f33448a8f2f526e94d00c70cdbdd735caec510df57b3283413df7882a"
# Go version in ppa:longsleep/golang-backports
ENV GO_PACKAGE "golang-1.22-go"

COPY vpp/Makefile /vpp-src/Makefile
COPY vpp/build/external /vpp-src/build/external

RUN echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

# netbase is needed for Scapy
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private \
    --mount=target=/var/cache/apt,type=cache,sharing=private \
    apt-get update && \
    apt-get dist-upgrade -yy && \
    apt-get install -y software-properties-common ccache && \
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential sudo git netbase curl ca-certificates \
    ${GO_PACKAGE} iproute2 gdb tcpdump iputils-ping libpcap-dev \
    dumb-init gdbserver clang-11 && \
    curl -sSL "https://github.com/moby/buildkit/releases/download/${BUILDKIT_VERSION}/buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz" | \
    tar -xvz -C /usr/local bin/buildctl && \
    echo "${BUILDCTL_SHA256}  /usr/local/bin/buildctl" | sha256sum -c && \
    cd /vpp-src && \
    curl -sSL -O http://mirrors.kernel.org/ubuntu/pool/main/i/indent/indent_2.2.12-1_amd64.deb && \
    echo "${INDENT_SHA256} /vpp-src/indent_2.2.12-1_amd64.deb" | sha256sum -c && \
    apt-get install  -y --no-install-recommends \
    /vpp-src/indent_2.2.12-1_amd64.deb && \
    rm /vpp-src/indent_2.2.12-1_amd64.deb && \
    git config --global user.email "dummy@example.com" && \
    git config --global user.name "dummy user" && \
    git init && \
    git add Makefile && \
    git commit -m "dummy commit" && \
    git tag -a v20.05-rc0 -m "dummy tag" && \
    make UNATTENDED=yes install-dep install-ext-dep && \
    apt-get clean && \
    rm -rf /vpp-src && \
    ln -s /usr/lib/go-1.22/bin/go /usr/bin/go && \
    ln -s /usr/lib/go-1.22/bin/gofmt /usr/bin/gofmt


# Add ccache configuration
ENV PATH="/usr/lib/ccache:$PATH"
ENV CCACHE_DIR=/ccache
ENV CCACHE_MAXSIZE=400M
ENV CCACHE_COMPRESS=true
ENV CCACHE_COMPRESSLEVEL=6

ENV GOPATH /go

RUN go install github.com/onsi/ginkgo/ginkgo@v1.16.5 && \
    mv /go/bin/ginkgo /usr/local/bin

RUN go install golang.org/x/tools/gopls@v0.11.0 && \
    mv /go/bin/gopls /usr/local/bin

RUN --mount=target=/var/cache/apt,type=cache,sharing=private \
    apt-get install ccache && \
    apt-get clean

FROM build-base-stage AS build-stage

ADD vpp /vpp-src

# starting from this point, the debug and release buffers differ
ARG BUILD_TYPE

RUN --mount=target=/vpp-src/build-root/.ccache,type=cache \
    --mount=type=cache,target=/ccache,id=ccache \
    case ${BUILD_TYPE} in \
    debug) target="pkg-deb-debug"; args="-DVPP_ENABLE_TRAJECTORY_TRACE=1";; \
    release) target="pkg-deb"; args="";; \
    *) echo >&2 "Bad BUILD_TYPE: ${BUILD_TYPE}";; \
    esac; \
    echo "TARGET: ${target}" && \
    make -C /vpp-src "${target}" V=1 VPP_EXTRA_CMAKE_ARGS="${args}" && \
    ccache -s && \
    mkdir -p /out/debs && \
    mv /vpp-src/build-root/*.deb /out/debs

# this stage is used to copy out the debs
FROM scratch as artifacts

COPY --from=build-stage /out/debs .

# dev image starts here
FROM build-base-stage AS dev-stage

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
    ln -fs /vpp-src/test/* /vpp-src/build-root/build-test/src/
# fix git repo ownership issue
RUN git config --global --add safe.directory /src

# final image starts here
FROM ubuntu:20.04 AS final-stage
ARG BUILD_TYPE
WORKDIR /

ENV VPP_INSTALL_SKIP_SYSCTL=1
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private \
    --mount=target=/var/cache/apt,type=cache,sharing=private \
    apt-get update && apt-get dist-upgrade -yy && \
    apt-get install --no-install-recommends -yy liblz4-tool tar gdb gdbserver strace \
    libhyperscan5 libmbedcrypto3 libmbedtls12 libmbedx509-0 apt-utils \
    libpython3-stdlib \
    python3 python3-minimal python3.6 python3-minimal \
    python3-cffi python3-cffi-backend libnuma1 \
    libnl-3-200 libnl-route-3-200 libpcap0.8

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private \
    --mount=target=/var/cache/apt,type=cache,sharing=private \
    --mount=target=/debs,source=/out/debs,from=build-stage,type=bind \
    extra_debs=; \
    if [ "${BUILD_TYPE}" = "debug" ]; then \
    extra_debs="/debs/vpp-dev_*.deb /debs/libvppinfra-dev_*.deb"; \
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
