#!/usr/bin/env bash
# Cross-compile synocr-helper for DSM 7 (linux x86_64 + aarch64), static musl.
# Output: APP/bin/helper/synocr-helper-{x86_64,aarch64}
#
# Usage:
#   ./helper/build.sh              both architectures
#   ./helper/build.sh --arch=x86_64
#   ./helper/build.sh --arch=aarch64
#   ./helper/build.sh --clean
#   ./helper/build.sh --help
#
# Toolchain (first match wins):
#   1. zig cc  — no Docker needed (macOS/Linux)
#   2. docker  — alpine:3.20 + gcc/musl, --platform linux/amd64|arm64

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit 1; pwd)
SRC="${SCRIPT_DIR}/synocr-helper.c"
OUT_DIR="${SCRIPT_DIR}/../APP/bin/helper"
CFLAGS=(-O2 -static -Wall -Wextra -Werror)
ARCHS=(x86_64 aarch64)

show_help() {
    cat <<'EOF'
Cross-build synocr-helper for DSM 7 (static musl ELF).

Usage:  ./helper/build.sh [options]

  --arch=x86_64|aarch64   build only this architecture (default: both)
  --clean                 remove built binaries and exit
  -h, --help              this help

Requires zig cc or Docker. Result:
  APP/bin/helper/synocr-helper-x86_64
  APP/bin/helper/synocr-helper-aarch64
EOF
    exit 0
}

zig_cc() {
    command -v zig
}

docker_bin() {
    command -v docker
}

need_src() {
    if [ ! -f "${SRC}" ]; then
        echo "ERROR: missing source ${SRC}" >&2
        exit 1
    fi
}

verify_elf() {
    local bin="$1" expect="$2"
    if [ ! -x "${bin}" ]; then
        echo "ERROR: binary not created: ${bin}" >&2
        exit 1
    fi
    if command -v file >/dev/null 2>&1; then
        local info
        info=$(file "${bin}")
        echo "    ${info}"
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
        echo "${info}" | grep -qi 'ELF' || {
            echo "ERROR: ${bin} is not ELF (do not ship a macOS Mach-O)" >&2
            exit 1
        }
    fi
}

build_zig() {
    local arch="$1" out="$2" target
    case "${arch}" in
        x86_64)  target=x86_64-linux-musl ;;
        aarch64) target=aarch64-linux-musl ;;
        *) echo "ERROR: unknown arch ${arch}" >&2; exit 1 ;;
    esac
    echo " - zig cc -target ${target}"
    "$(zig_cc)" cc -target "${target}" "${CFLAGS[@]}" -s -o "${out}" "${SRC}"
}

build_docker() {
    local arch="$1" out="$2" platform name
    case "${arch}" in
        x86_64)
            platform=linux/amd64
            name=synocr-helper-x86_64
            ;;
        aarch64)
            platform=linux/arm64
            name=synocr-helper-aarch64
            ;;
        *) echo "ERROR: unknown arch ${arch}" >&2; exit 1 ;;
    esac
    echo " - docker ${platform} (alpine:3.20 gcc/musl)"
    # CFLAGS as a single string inside the container
    "$(docker_bin)" run --rm --platform "${platform}" \
        -v "${SCRIPT_DIR}:/src:ro" \
        -v "${OUT_DIR}:/out" \
        -w /src alpine:3.20 \
        sh -c "apk add --no-cache gcc musl-dev >/dev/null && gcc -O2 -static -Wall -Wextra -Werror -s -o /out/${name} /src/synocr-helper.c"
    # docker writes as root sometimes
    if [ -f "${out}" ] && [ "$(id -u)" -ne 0 ]; then
        chmod 755 "${out}" 2>/dev/null || true
    fi
}

build_one() {
    local arch="$1"
    local out="${OUT_DIR}/synocr-helper-${arch}"
    echo "=== building ${arch} → ${out}"
    if [ -n "$(zig_cc)" ]; then
        build_zig "${arch}" "${out}"
    elif [ -n "$(docker_bin)" ]; then
        build_docker "${arch}" "${out}"
    else
        echo "ERROR: neither zig nor docker found in PATH." >&2
        echo "       Install zig (https://ziglang.org) or Docker." >&2
        exit 1
    fi
    chmod 755 "${out}" 2>/dev/null || true
    verify_elf "${out}" "${arch}"
}

for arg in "$@"; do
    case "${arg}" in
        -h|--help) show_help ;;
        --clean)
            rm -f "${OUT_DIR}/synocr-helper-x86_64" "${OUT_DIR}/synocr-helper-aarch64"
            echo "removed helper binaries in ${OUT_DIR}"
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

need_src
mkdir -p "${OUT_DIR}"

if [ -n "$(zig_cc)" ]; then
    echo "toolchain: zig ($(zig_cc))"
elif [ -n "$(docker_bin)" ]; then
    echo "toolchain: docker ($(docker_bin))"
else
    echo "ERROR: neither zig nor docker found in PATH." >&2
    exit 1
fi

for arch in "${ARCHS[@]}"; do
    build_one "${arch}"
done

echo
echo "done:"
ls -l "${OUT_DIR}"/synocr-helper-x86_64 "${OUT_DIR}"/synocr-helper-aarch64 2>/dev/null || \
    ls -l "${OUT_DIR}"/synocr-helper-*
