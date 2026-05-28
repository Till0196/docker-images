# syntax=docker/dockerfile:1.7
#
# sysbox-deploy-k8s image built from Till0196 forks, assembled from a clean
# centos7/systemd base + selective copies from the upstream Nestybox image.
# This avoids the ~200MB of duplicated layers that a `FROM upstream + COPY
# overwrite` approach leaves behind in the overlay graph.
#
# Composition:
#   - Base                 : ghcr.io/nestybox/centos7/systemd + minimal yum pkgs
#   - From upstream v0.6.5 : kubectl, dasel, crictl, /opt/shiftfs-k*, /opt/crio-deploy,
#                            /opt/sysbox/systemd, sysbox-{installer,removal}-helper.sh
#   - From sysbox v0.7.0   : sysbox-fs (Till0196/fuse), sysbox-mgr, sysbox-runc
#   - From sysbox-pkgr fork: sysbox-deploy-k8s.sh, containerd-sysbox-dropin.toml

# renovate: datasource=docker depName=registry.nestybox.com/nestybox/sysbox-deploy-k8s
ARG UPSTREAM_IMAGE=registry.nestybox.com/nestybox/sysbox-deploy-k8s:v0.6.5
ARG SYSBOX_PKGR_REPO=https://github.com/Till0196/sysbox-pkgr
ARG SYSBOX_PKGR_REF=feat/k8s-flatcar-4593-ce
ARG SYSBOX_REPO=https://github.com/nestybox/sysbox
ARG SYSBOX_REF=v0.7.0
ARG FUSE_REPO=https://github.com/Till0196/fuse
ARG FUSE_REF=56767d330b8517fc2dd343a0beb0b4cd15f73650
ARG GO_VERSION=1.26-trixie

############################################################
# Stage 1: pkgr-src — checkout Till0196/sysbox-pkgr
############################################################
FROM alpine/git:latest AS pkgr-src
ARG SYSBOX_PKGR_REPO
ARG SYSBOX_PKGR_REF
RUN git clone --depth=1 -b "${SYSBOX_PKGR_REF}" "${SYSBOX_PKGR_REPO}" /src/pkgr

############################################################
# Stage 2: sysbox-builder — build sysbox-fs/mgr/runc with Till0196/fuse fork
############################################################
FROM --platform=${BUILDPLATFORM} golang:${GO_VERSION} AS sysbox-builder
ARG SYSBOX_REPO
ARG SYSBOX_REF
ARG FUSE_REPO
ARG FUSE_REF
ARG TARGETARCH
ARG TARGETOS

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates make gcc g++ pkg-config bash \
        libseccomp-dev libgpgme-dev libapparmor-dev libcap-dev \
        protobuf-compiler libprotobuf-dev \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/include/google /usr/local/include/google

# sysbox-ipc Makefile invokes `protoc --go_out=plugins=grpc:.` which is the
# legacy protoc-gen-go syntax; v1.3.5 is the last version that supports it.
RUN GOBIN=/usr/local/bin go install github.com/golang/protobuf/protoc-gen-go@v1.3.5

RUN git clone --recurse-submodules "${SYSBOX_REPO}" /src/sysbox \
    && cd /src/sysbox \
    && git checkout "${SYSBOX_REF}" \
    && git submodule update --init --recursive

COPY scripts/apply-fuse-fork.sh /usr/local/bin/apply-fuse-fork.sh
RUN chmod +x /usr/local/bin/apply-fuse-fork.sh \
    && /usr/local/bin/apply-fuse-fork.sh /src/sysbox "${FUSE_REPO}" "${FUSE_REF}"

ENV GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=1 GOFLAGS=-mod=mod
RUN cd /src/sysbox \
    && make sysbox-static-local TARGET_ARCH=${TARGETARCH} HOST_UID=0 HOST_GID=0 \
    && mkdir -p /out/bin \
    && cp sysbox-fs/build/${TARGETARCH}/sysbox-fs     /out/bin/sysbox-fs \
    && cp sysbox-mgr/build/${TARGETARCH}/sysbox-mgr   /out/bin/sysbox-mgr \
    && cp sysbox-runc/build/${TARGETARCH}/sysbox-runc /out/bin/sysbox-runc

############################################################
# Stage 3: upstream — alias for selective copies (no extra layers in final)
############################################################
FROM ${UPSTREAM_IMAGE} AS upstream

############################################################
# Stage 4: final — clean centos7/systemd + cherry-picked artifacts
############################################################
FROM ghcr.io/nestybox/centos7/systemd

RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* \
    && sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* \
    && yum install -y curl wget git bc which epel-release \
    && yum install -y jq \
    && yum clean all \
    && rm -rf /var/cache/yum

# Tools from upstream (avoid re-downloading kubectl/dasel/crictl).
COPY --from=upstream /bin/kubectl              /bin/kubectl
COPY --from=upstream /usr/local/bin/dasel      /usr/local/bin/dasel
COPY --from=upstream /usr/local/bin/crictl     /usr/local/bin/crictl

# shiftfs-dkms sources (8 kernel branches) from upstream.
COPY --from=upstream /opt/shiftfs-k5.4  /opt/shiftfs-k5.4
COPY --from=upstream /opt/shiftfs-k5.10 /opt/shiftfs-k5.10
COPY --from=upstream /opt/shiftfs-k5.11 /opt/shiftfs-k5.11
COPY --from=upstream /opt/shiftfs-k5.13 /opt/shiftfs-k5.13
COPY --from=upstream /opt/shiftfs-k5.16 /opt/shiftfs-k5.16
COPY --from=upstream /opt/shiftfs-k5.17 /opt/shiftfs-k5.17
COPY --from=upstream /opt/shiftfs-k5.18 /opt/shiftfs-k5.18
COPY --from=upstream /opt/shiftfs-k6.1  /opt/shiftfs-k6.1

# CRI-O installation artifacts (release tars v1.27–v1.30 + patched binaries).
COPY --from=upstream /opt/crio-deploy /opt/crio-deploy

# Sysbox systemd units + helper scripts (unchanged by the fork).
COPY --from=upstream /opt/sysbox/systemd                              /opt/sysbox/systemd
COPY --from=upstream /opt/sysbox/scripts/sysbox-installer-helper.sh   /opt/sysbox/scripts/sysbox-installer-helper.sh
COPY --from=upstream /opt/sysbox/scripts/sysbox-removal-helper.sh     /opt/sysbox/scripts/sysbox-removal-helper.sh

# Sysbox binaries rebuilt from v0.7.0 with Till0196/fuse fork applied.
# sysbox-deploy-k8s.sh copies from generic/ to the host, so that path is the
# load-bearing one; we also drop them at /opt/sysbox/bin/ for symmetry with
# the upstream layout.
COPY --from=sysbox-builder /out/bin/sysbox-fs   /opt/sysbox/bin/generic/sysbox-fs
COPY --from=sysbox-builder /out/bin/sysbox-mgr  /opt/sysbox/bin/generic/sysbox-mgr
COPY --from=sysbox-builder /out/bin/sysbox-runc /opt/sysbox/bin/generic/sysbox-runc
RUN ln -sf generic/sysbox-fs   /opt/sysbox/bin/sysbox-fs \
    && ln -sf generic/sysbox-mgr  /opt/sysbox/bin/sysbox-mgr \
    && ln -sf generic/sysbox-runc /opt/sysbox/bin/sysbox-runc

# Fork-modified deploy script + new containerd drop-in config.
COPY --from=pkgr-src /src/pkgr/k8s/scripts/sysbox-deploy-k8s.sh \
                     /opt/sysbox/scripts/sysbox-deploy-k8s.sh
COPY --from=pkgr-src /src/pkgr/k8s/config/containerd-sysbox-dropin.toml \
                     /opt/sysbox/config/containerd-sysbox-dropin.toml
