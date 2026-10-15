#!/bin/bash
# shellcheck disable=SC1091

#################################################################################
#   description:    Privileged actions for DSM 7 (via setuid synocr-helper).    #
#   caller:         synocr-helper with verb selfheal | enc-enum only            #
#   path:           /var/packages/synOCR/target/ui/includes/synocr-heal.sh      #
#                                                                               #
#   Do not derive APPDIR from $0: the helper runs this script via fexecve, so   #
#   $0 is /dev/fd/N and dirname($0) is useless.                                 #
#                                                                               #
#   Idempotent where applicable. Intended to run as root via the helper.        #
#   Direct execution as root (Task Scheduler) is also allowed.                  #
#   © 2026 by geimist                                                           #
#################################################################################

APPDIR="/var/packages/synOCR/target/ui"
export SYNOCR_APP_HOME="${APPDIR}"
LOGFILE="${APPDIR}/etc/selfheal.log"

log() {
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "${line}"
    mkdir -p "${APPDIR}/etc" 2>/dev/null || true
    echo "${line}" >> "${LOGFILE}" 2>/dev/null || true
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "synocr-heal.sh: must run as root (use synocr-helper)" >&2
        exit 1
    fi
}

# List encrypted shared folder names (stdout). Used before inotify start so the
# package user can wait for Key Manager / auto-mount without root itself.
do_enc_enum() {
    require_root
    if [ ! -x /usr/syno/sbin/synoshare ]; then
        echo "synocr-heal.sh: synoshare not found" >&2
        exit 1
    fi
    /usr/syno/sbin/synoshare --enum ENC
    exit $?
}

do_selfheal() {
    require_root

    cd "${APPDIR}" || {
        log "synocr-heal.sh: cannot cd to ${APPDIR}"
        exit 1
    }

    if [ ! -f "${APPDIR}/includes/functions.sh" ]; then
        log "synocr-heal.sh: missing ${APPDIR}/includes/functions.sh"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "${APPDIR}/includes/functions.sh"

    log "synOCR selfheal (user=$(id -un) uid=$(id -u) euid=$(id -u) \$0=${0})"

    echo -n "    ➜ docker group / socket: "
    synogroupmoddocker
    echo
    log "docker group / socket done"

    echo -n "    ➜ administrators membership: "
    if grep ^administrators /etc/group | grep -q synOCR ; then
        echo "ok"
        log "administrators: already member"
    else
        synogroupmoduser add administrators synOCR
        log "administrators: add synOCR"
    fi

    python3_env="${APPDIR}/python3_env"
    if [ -d "${python3_env}" ]; then
        chown -R synOCR:administrators "${python3_env}" 2>/dev/null || true
        chmod -R 755 "${python3_env}" 2>/dev/null || true
        log "python3_env permissions adjusted"
    fi

    dbPath="${APPDIR}/etc/synOCR.sqlite"
    if [ -f "${dbPath}" ]; then
        chmod 766 "${dbPath}" 2>/dev/null || true
        log "database permissions adjusted"
    fi

    exit 0
}

case "${1:-}" in
    selfheal)
        do_selfheal
        ;;
    enc-enum)
        do_enc_enum
        ;;
    *)
        echo "synocr-heal.sh: allowed verbs: selfheal, enc-enum (got '${1:-}')" >&2
        exit 1
        ;;
esac
