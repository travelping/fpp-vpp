# syntax = docker/dockerfile:experimental
FROM ubuntu:22.04

WORKDIR /

RUN echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

# netbase is needed for Scapy
RUN --mount=target=/var/lib/apt,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections && \
    echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections && \
    # install software-properties-common just to add ppa
    apt-get update && \
    apt-get install -y software-properties-common && \
    # add reporistory for newer golang releases
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential sudo git \
        netbase curl ca-certificates ccache \
        iproute2 gdb tcpdump iputils-ping libpcap-dev \
        dumb-init gdbserver \
        # golang from ppa
        golang-1.23-go \
        # clang also installed in vpp Makefile, make sure to match versions
        clang \
        # llvm provides llc for xdp-tools build
        llvm \
        # golang installs gcc-12 which clang uses via auto-detection for stdc++ library.
        # But gcc-12 omits c++ stuff, so we add it manually. libstdc++-12-dev should be enough, but entire g++ is not that heavy to add.
        g++-12 \
    && \
    ln -s /usr/lib/go-1.23/bin/go /usr/bin/go && \
    ln -s /usr/lib/go-1.23/bin/gofmt /usr/bin/gofmt && \
    # set clang as default C and C++ compiler
    update-alternatives --set c++ /usr/bin/clang++ && \
    update-alternatives --set cc /usr/bin/clang

# Configure ccache, but do not provide it in path. Each RUN should provide it separately
ENV CCACHE_DIR=/ccache \
    CCACHE_MAXSIZE=600M \
    CCACHE_COMPRESS=true \
    CCACHE_COMPRESSLEVEL=6 \
    GOPATH=/go

# golang uses ccache as well
RUN --mount=target=/ccache,type=cache \
    PATH="/usr/lib/ccache:$PATH" && \
    go install github.com/onsi/ginkgo/v2/ginkgo@v2.27.2 && \
    mv /go/bin/ginkgo /usr/local/bin/ginkgo && \
    go install golang.org/x/tools/gopls@v0.11.0 && \
    mv /go/bin/gopls /usr/local/bin

COPY vpp/Makefile /vpp-src/Makefile
COPY vpp/build/external /vpp-src/build/external

RUN --mount=target=/var/lib/apt,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    --mount=target=/ccache,type=cache \
    cd /vpp-src && \
    git config --global user.email "dummy@example.com" && \
    git config --global user.name "dummy user" && \
    git init && \
    git add Makefile && \
    git commit -m "dummy commit" && \
    # tag requred to have this format
    git tag -a v24.02-rc0 -m "dummy tag" && \
    make UNATTENDED=yes install-dep install-ext-dep && \
    ccache -s && \
    rm -rf /vpp-src 
