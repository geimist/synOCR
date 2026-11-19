#!/usr/bin/env bash
# Cross-build a static inotifywait for DSM (linux x86_64 + aarch64).
# Output: APP/bin/inotify/inotifywait-{x86_64,aarch64}
#
# Not invoked by helper/build.sh or build_spk.sh. Run once, and again only
# when INOTIFY_VERSION changes. Commit the resulting ELF files.
#
# Toolchain: zig cc (musl, fully static). Same choice as helper/build.sh.
#
# Usage:
#   ./thirdparty/inotify-tools/build.sh
#   ./thirdparty/inotify-tools/build.sh --arch=x86_64
#   ./thirdparty/inotify-tools/build.sh --arch=aarch64
#   ./thirdparty/inotify-tools/build.sh --clean

set -euo pipefail

INOTIFY_VERSION=4.25.9.0
INOTIFY_URL="https://github.com/inotify-tools/inotify-tools/archive/refs/tags/${INOTIFY_VERSION}.tar.gz"
INOTIFY_RELEASE_URL="https://github.com/inotify-tools/inotify-tools/releases/tag/${INOTIFY_VERSION}"

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit 1; pwd)
OUT_DIR="${SCRIPT_DIR}/../../APP/bin/inotify"
ARCHS=(x86_64 aarch64)

show_help() {
    cat <<EOF
Cross-build static inotifywait ${INOTIFY_VERSION} (musl, fully static) with zig.

Usage:  ./thirdparty/inotify-tools/build.sh [options]

  --arch=x86_64|aarch64   build only this architecture (default: both)
  --clean                 remove built binaries and exit
  -h, --help              this help

Requires zig. Result:
  APP/bin/inotify/inotifywait-x86_64
  APP/bin/inotify/inotifywait-aarch64
  APP/bin/inotify/COPYING
  APP/bin/inotify/VERSION
EOF
    exit 0
}

zig_cc() {
    command -v zig
}

verify_elf() {
    local bin="$1" expect="$2" info
    if [ ! -f "${bin}" ]; then
        echo "ERROR: binary not created: ${bin}" >&2
        exit 1
    fi
    chmod 755 "${bin}" 2>/dev/null || true
    if ! command -v file >/dev/null 2>&1; then
        echo "ERROR: file(1) is required to verify ${bin}" >&2
        exit 1
    fi
    info=$(file "${bin}")
    echo "    ${info}"
    echo "${info}" | grep -qi 'ELF' || {
        echo "ERROR: ${bin} is not ELF" >&2
        exit 1
    }
    echo "${info}" | grep -qi 'statically linked' || {
        echo "ERROR: ${bin} is not statically linked" >&2
        exit 1
    }
    case "${expect}" in
        x86_64)
            echo "${info}" | grep -qiE 'x86-64|x86_64' || {
                echo "ERROR: ${bin} is not an x86_64 ELF" >&2
                exit 1
            }
            ;;
        aarch64)
            echo "${info}" | grep -qiE 'ARM aarch64|aarch64' || {
                echo "ERROR: ${bin} is not an aarch64 ELF" >&2
                exit 1
            }
            ;;
    esac
    if ! command -v strings >/dev/null 2>&1; then
        echo "ERROR: strings(1) is required to verify ${bin}" >&2
        exit 1
    fi
    # Do not use grep -q here: with pipefail, strings dies from SIGPIPE and the check fails.
    strings "${bin}" | grep -F -- '--fromfile' >/dev/null || {
        echo "ERROR: ${bin} has no --fromfile option" >&2
        exit 1
    }
    strings "${bin}" | grep -Fx "${INOTIFY_VERSION}" >/dev/null || {
        echo "ERROR: ${bin} does not contain version ${INOTIFY_VERSION}" >&2
        exit 1
    }
}

prepare_tree() {
    local work="$1" src
    curl -fsSL -o "${work}/src.tar.gz" "${INOTIFY_URL}"
    tar -xzf "${work}/src.tar.gz" -C "${work}"
    src="${work}/inotify-tools-${INOTIFY_VERSION}"
    cat > "${src}/config.h" <<EOF
#define PACKAGE_VERSION "${INOTIFY_VERSION}"
EOF
    cat > "${src}/libinotifytools/src/inotifytools/inotify.h" <<'EOF'
#ifndef _INOTIFYTOOLS_INOTIFY_H
#define _INOTIFYTOOLS_INOTIFY_H 1
#define SYS_INOTIFY_H_EXISTS_AND_WORKS 1
#include <sys/inotify.h>
#endif
EOF
    cat > "${src}/libinotifytools/src/inotifytools/fanotify.h" <<'EOF'
#ifndef _INOTIFYTOOLS_FANOTIFY_H
#define _INOTIFYTOOLS_FANOTIFY_H 1
#define SYS_FANOTIFY_H_EXISTS_AND_WORKS 1
#include <sys/fanotify.h>
#endif
EOF
    printf '%s' "${src}"
}

build_one() {
    local arch="$1" src="$2" out="$3" target
    case "${arch}" in
        x86_64)  target=x86_64-linux-musl ;;
        aarch64) target=aarch64-linux-musl ;;
        *) echo "ERROR: unknown arch ${arch}" >&2; exit 1 ;;
    esac
    echo " - zig c++ -target ${target}"
    "$(zig_cc)" c++ -target "${target}" -static -std=c++17 -fno-exceptions -O2 -s \
        "-ffile-prefix-map=${src}=." \
        -I "${src}/libinotifytools/src" \
        -o "${out}" \
        "${src}/src/inotifywait.cpp" \
        "${src}/src/common.cpp" \
        "${src}/libinotifytools/src/inotifytools.cpp" \
        "${src}/libinotifytools/src/redblack.cpp" \
        "${src}/libinotifytools/src/stats.cpp"
    chmod 755 "${out}" 2>/dev/null || true
}

for arg in "$@"; do
    case "${arg}" in
        -h|--help) show_help ;;
        --clean)
            rm -f "${OUT_DIR}/inotifywait-x86_64" "${OUT_DIR}/inotifywait-aarch64"
            echo "removed inotifywait binaries in ${OUT_DIR}"
            exit 0
            ;;
        --arch=x86_64)  ARCHS=(x86_64) ;;
        --arch=aarch64|--arch=arm64) ARCHS=(aarch64) ;;
        *)
            echo "unknown argument: ${arg}" >&2
            show_help
            ;;
    esac
done

if [ -z "$(zig_cc)" ]; then
    echo "ERROR: zig not found in PATH." >&2
    echo "       Install zig (https://ziglang.org)." >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"
work=$(mktemp -d "${TMPDIR:-/tmp}/inotify-tools-build.XXXXXX")
trap 'rm -rf "${work}"' EXIT

echo "toolchain: zig ($(zig_cc))"
echo "upstream:  inotify-tools ${INOTIFY_VERSION}"
src=$(prepare_tree "${work}")

for arch in "${ARCHS[@]}"; do
    out="${OUT_DIR}/inotifywait-${arch}"
    echo "=== building ${arch} → ${out}"
    build_one "${arch}" "${src}" "${out}"
    verify_elf "${out}" "${arch}"
done

cp "${src}/COPYING" "${OUT_DIR}/COPYING"
chmod 644 "${OUT_DIR}/COPYING"

cat > "${OUT_DIR}/VERSION" <<EOF
${INOTIFY_VERSION}
${INOTIFY_RELEASE_URL}
Built statically with zig c++ -target {x86_64,aarch64}-linux-musl.
License: GPL-2.0. See COPYING in this directory.
EOF

echo
echo "done:"
ls -l "${OUT_DIR}/inotifywait-x86_64" "${OUT_DIR}/inotifywait-aarch64" 2>/dev/null || ls -l "${OUT_DIR}"/inotifywait-*
