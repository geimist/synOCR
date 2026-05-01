#!/bin/sh
# Optional diagnostics for upgrade/getroot issues (DSM package context, usually user synOCR).
# Appends to /tmp/synOCR.upgrade-debug.log and a short pointer to lifecycle trace.
# shellcheck disable=SC2034
# Requires: SYNOPKG_PKGNAME, SYNOPKG_PKGDEST (set by Package Center).

synocr_pkg_diag() {
    _label="${1:-unknown}"
    _extra="${2:-}"
    _ts=$(date '+%Y-%m-%d %H:%M:%S')
    _log="/tmp/synOCR.upgrade-debug.log"
    _trace="/tmp/${SYNOPKG_PKGNAME}.lifecycle.trace"
    PKG_CONF="/var/packages/${SYNOPKG_PKGNAME}/conf"
    PKG_VAR="/var/packages/${SYNOPKG_PKGNAME}/var"
    WEB_CP="/usr/syno/synoman/webman/3rdparty/${SYNOPKG_PKGNAME}"
    {
        echo "======== ${_ts} synocr_pkg_diag ${_label} ========"
        echo "note=${_extra}"
        echo "SYNOPKG_PKG_STATUS=${SYNOPKG_PKG_STATUS:-}"
        echo "SYNOPKG_PKGVER=${SYNOPKG_PKGVER:-}"
        echo "SYNOPKG_OLD_PKGVER=${SYNOPKG_OLD_PKGVER:-}"
        echo "SYNOPKG_PKGDEST=${SYNOPKG_PKGDEST:-}"
        echo "SYNOPKG_TEMP_UPGRADE_FOLDER=${SYNOPKG_TEMP_UPGRADE_FOLDER:-}"
        echo "--- package flags ---"
        ls -la "/var/packages/${SYNOPKG_PKGNAME}/installing" 2>&1 || true
        ls -la "/var/packages/${SYNOPKG_PKGNAME}/enabled" 2>&1 || true
        ls -la "/var/packages/${SYNOPKG_PKGNAME}/target" 2>&1 || true
        echo "--- conf/resource (bytes + snippet) ---"
        if [ -f "${PKG_CONF}/resource" ]; then
            ls -la "${PKG_CONF}/resource" 2>&1 || true
            wc -c "${PKG_CONF}/resource" 2>&1 || true
            sed -n '1,40p' "${PKG_CONF}/resource" 2>&1 || true
        else
            echo "(missing ${PKG_CONF}/resource)"
        fi
        echo "--- conf dir ---"
        ls -la "${PKG_CONF}" 2>&1 || true
        echo "--- package var (possible docker worker artifacts) ---"
        ls -la "${PKG_VAR}" 2>&1 || true
        ls -la "${PKG_VAR}/docker-compose.yaml" 2>&1 || true
        ls -la "${PKG_VAR}/docker" 2>&1 || true
        echo "--- docker build context / host root mount under PKGDEST ---"
        ls -la "${SYNOPKG_PKGDEST}/ocr_docker" 2>/dev/null || echo "(missing)"
        if [ -L "${SYNOPKG_PKGDEST}/ocr_docker" ]; then
            echo "ocr_docker link target=$(readlink "${SYNOPKG_PKGDEST}/ocr_docker" 2>/dev/null || echo '?')"
            if command -v readlink >/dev/null 2>&1; then
                echo "ocr_docker resolved=$(readlink -f "${SYNOPKG_PKGDEST}/ocr_docker" 2>/dev/null || echo '?')"
            fi
        elif [ -e "${SYNOPKG_PKGDEST}/ocr_docker" ]; then
            echo "ocr_docker exists but is not a symlink"
        else
            echo "ocr_docker missing"
        fi
        ls -la "${SYNOPKG_PKGDEST}/ocr_docker/Dockerfile" 2>/dev/null || echo "(missing ocr_docker/Dockerfile)"
        ls -la "${SYNOPKG_PKGDEST}/host_root" 2>/dev/null || echo "(missing host_root)"
        if [ -L "${SYNOPKG_PKGDEST}/host_root" ]; then
            echo "host_root link target=$(readlink "${SYNOPKG_PKGDEST}/host_root" 2>/dev/null || echo '?')"
            if command -v readlink >/dev/null 2>&1; then
                echo "host_root resolved=$(readlink -f "${SYNOPKG_PKGDEST}/host_root" 2>/dev/null || echo '?')"
            fi
        elif [ -e "${SYNOPKG_PKGDEST}/host_root" ]; then
            echo "host_root exists but is not a symlink"
        else
            echo "host_root missing"
        fi
        echo "--- web 3rdparty dir (symlink target) ---"
        ls -la "${WEB_CP}" 2>/dev/null | head -n 15 || echo "(missing ${WEB_CP})"
        echo "--- check_permissions.sh ---"
        ls -la "${WEB_CP}/check_permissions.sh" 2>/dev/null || echo "(missing)"
        echo "--- synOCR.sqlite under PKGDEST ui/etc ---"
        for _db in "${SYNOPKG_PKGDEST}/ui/etc/synOCR.sqlite" "${SYNOPKG_PKGDEST}/etc/synOCR.sqlite"; do
            if [ -f "${_db}" ]; then
                echo "db=${_db} bytes=$(wc -c < "${_db}" 2>/dev/null || echo '?')"
            fi
        done
        echo "--- docker.sock ---"
        ls -la /var/run/docker.sock 2>/dev/null || echo "(missing)"
        echo "--- docker ps synocr_helper (may fail for non-root) ---"
        if command -v docker >/dev/null 2>&1; then
            docker ps -a --filter "name=synocr_helper" --no-trunc 2>&1 || true
            echo "--- docker image inspect synocr_helper_image ---"
            docker images --digests --no-trunc 2>&1 | sed -n '1,80p' || true
        else
            echo "(no docker in PATH)"
        fi
        echo "======== end ${_label} ========"
        echo ""
    } >> "${_log}" 2>&1
    echo "${_ts} [pkg_diag] ${_label} -> full block appended to ${_log}" >> "${_trace}" 2>&1
}
