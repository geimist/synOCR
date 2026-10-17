#!/bin/bash

#################################################################################
#   description:    Privileged actions for DSM 7 (via setuid synocr-helper).    #
#   caller:         synocr-helper with verb selfheal | enc-enum only            #
#   path:           /var/packages/synOCR/target/ui/includes/synocr-heal.sh      #
#                                                                               #
#   Do not derive APPDIR from $0: the helper runs this script via fexecve, so   #
#   $0 is /dev/fd/N and dirname($0) is useless.                                 #
#                                                                               #
#   Stay self-contained. This file runs as root and must not source other       #
#   package files (functions.sh stays writable by the package user).            #
#                                                                               #
#   Idempotent where applicable. Intended to run as root via the helper.        #
#   Direct execution as root (Task Scheduler) is also allowed.                  #
#   © 2026 by geimist                                                           #
#################################################################################

APPDIR="/var/packages/synOCR/target/ui"
export SYNOCR_APP_HOME="${APPDIR}"
LOGDIR="/var/packages/synOCR/target/log"
LOGFILE="${LOGDIR}/selfheal.log"

log() {
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "${line}"
    mkdir -p "${LOGDIR}" 2>/dev/null || true
    # Directory must stay writable by the package user (inotify.log).
    chown synOCR:synOCR "${LOGDIR}" 2>/dev/null || true
    chmod 755 "${LOGDIR}" 2>/dev/null || true
    if [ -f "${APPDIR}/etc/selfheal.log" ] && [ ! -e "${LOGFILE}" ]; then
        mv "${APPDIR}/etc/selfheal.log" "${LOGFILE}" 2>/dev/null || true
    fi
    echo "${line}" >> "${LOGFILE}" 2>/dev/null || true
    chmod 644 "${LOGFILE}" 2>/dev/null || true
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "synocr-heal.sh: must run as root (use synocr-helper)" >&2
        exit 1
    fi
}

# The helper clears the environment. A UTF-8 locale keeps non-ASCII share
# names from synoshare aligned with the paths stored in the database.
export_locale() {
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
}

# Add one user without dropping existing members.
# synogroup --member replaces the whole list, so a failed parse must not run it.
heal_group_add_user() {
    local group="$1" user="$2" raw name
    local -a members=()

    if ! raw="$(synogroup --get "${group}" 2>&1)"; then
        log "${group}: synogroup --get failed"
        return 1
    fi

    if ! printf '%s\n' "${raw}" | grep -q "Group Members"; then
        log "${group}: unexpected synogroup output; members left unchanged"
        return 1
    fi

    if printf '%s\n' "${raw}" | awk -F'[][]' -v u="${user}" '$0 ~ /^[0-9]+:/ && $2 == u { found=1 } END { exit found ? 0 : 1 }'; then
        log "${group}: ${user} already a member"
        return 0
    fi

    while IFS= read -r name; do
        [ -n "${name}" ] || continue
        members+=("${name}")
    done < <(printf '%s\n' "${raw}" | awk -F'[][]' '/^[0-9]+:/ {print $2}')

    if [ "${#members[@]}" -eq 0 ] && printf '%s\n' "${raw}" | grep -qE '^[0-9]+:'; then
        log "${group}: member list unparsable; members left unchanged"
        return 1
    fi

    members+=("${user}")
    if ! synogroup --member "${group}" "${members[@]}"; then
        log "${group}: synogroup --member failed"
        return 1
    fi
    log "${group}: added ${user}"
    return 0
}

heal_docker() {
    local rc=0

    if ! synogroup --get docker >/dev/null 2>&1; then
        log "docker group missing; creating"
        if ! synogroup --add docker; then
            log "docker group create failed"
            return 1
        fi
    fi

    if [ -S /var/run/docker.sock ]; then
        if [ "$(stat -c '%G' /var/run/docker.sock 2>/dev/null)" != "docker" ]; then
            if chown root:docker /var/run/docker.sock; then
                log "docker.sock owner set to root:docker"
            else
                log "docker.sock chown failed"
                rc=1
            fi
        else
            log "docker.sock already group docker"
        fi
    else
        log "docker.sock absent; chown skipped"
    fi

    heal_group_add_user docker synOCR || rc=1
    return "${rc}"
}

# List encrypted shared folder names (stdout). Used before inotify start so the
# package user can wait for Key Manager / auto-mount without root itself.
do_enc_enum() {
    require_root
    export_locale
    if [ ! -x /usr/syno/sbin/synoshare ]; then
        echo "synocr-heal.sh: synoshare not found" >&2
        exit 1
    fi
    /usr/syno/sbin/synoshare --enum ENC
    exit $?
}

do_selfheal() {
    local rc=0
    local python3_env dbPath

    require_root
    export_locale

    log "synOCR selfheal (user=$(id -un) uid=$(id -u) \$0=${0})"

    if heal_docker; then
        log "docker group / socket done"
    else
        log "docker group / socket incomplete"
        rc=1
    fi

    if ! heal_group_add_user administrators synOCR; then
        log "administrators membership incomplete"
        rc=1
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

    exit "${rc}"
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
