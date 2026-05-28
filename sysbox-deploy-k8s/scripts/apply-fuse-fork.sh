#!/usr/bin/env bash
#
# Swap the bundled sysbox-fs/bazil module (a vendored fork of bazil.org/fuse)
# with Till0196/fuse @ feat/direct-mount-no-fusermount, which performs a
# direct /dev/fuse mount (bypassing fusermount3) when running as root.
#
# The Till0196/fuse repo's go.mod declares
# `module github.com/nestybox/sysbox-fs/bazil`, i.e. it is a drop-in
# replacement for the in-tree ./bazil directory. sysbox-fs/go.mod already
# carries `replace bazil.org/fuse => ./bazil`, so we just overlay the
# directory contents with the fork.
#
# usage: apply-fuse-fork.sh <sysbox-src-dir> <fuse-repo-url> <fuse-ref>
#
set -euo pipefail

SYSBOX_DIR="${1:?sysbox source dir required}"
FUSE_REPO="${2:?fuse repo URL required}"
FUSE_REF="${3:?fuse ref required}"

BAZIL_DIR="${SYSBOX_DIR}/sysbox-fs/bazil"

if [ ! -d "${BAZIL_DIR}" ]; then
    echo "error: ${BAZIL_DIR} does not exist (expected vendored bazil module)" >&2
    exit 1
fi

rm -rf "${BAZIL_DIR}"
git clone "${FUSE_REPO}" "${BAZIL_DIR}"
git -C "${BAZIL_DIR}" checkout "${FUSE_REF}"

# Sanity-check: the fork must keep the same module path the in-tree directive expects.
MOD_PATH="$(awk '$1=="module"{print $2; exit}' "${BAZIL_DIR}/go.mod")"
if [ "${MOD_PATH}" != "github.com/nestybox/sysbox-fs/bazil" ]; then
    echo "error: unexpected module path in fork go.mod: ${MOD_PATH}" >&2
    exit 1
fi

echo "Replaced sysbox-fs/bazil with ${FUSE_REPO}@${FUSE_REF}"
git -C "${BAZIL_DIR}" log -1 --oneline
