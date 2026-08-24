#!/bin/bash
# shellcheck disable=SC2009,SC2086,SC2155

#############################################################################################
#   description:    start / stop monitoring with inotify                                    #
#                                                                                           #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/input_monitor.sh [start|stop]  #
#   © 2026 by geimist                                                                       #
#############################################################################################

monitored_folders="/usr/syno/synoman/webman/3rdparty/synOCR/etc/inotify.list"
ready_flag="/usr/syno/synoman/webman/3rdparty/synOCR/etc/inotify.ready"
stderr_log="/usr/syno/synoman/webman/3rdparty/synOCR/etc/inotify.stderr"
START_WAIT_SECS=10

APPDIR=$(cd "$(dirname "$0")" || exit 1;pwd)
export SYNOCR_APP_HOME="${APPDIR}"
cd "${APPDIR}" || exit 1
source "./includes/functions.sh"

# create list (array need for tee) with all active log folders:
# --------------------------------------------------------------
LOG_DIR_LIST=()
while read -r value ; do
    [ -d "${value%/*}" ] && LOG_DIR_LIST+=( "$value" )
done <<< "$(synocr_sqlite "SELECT LOGDIR FROM config WHERE active='1' AND LOGDIR IS NOT NULL AND NOT LOGDIR=''" 2>/dev/null | sort | uniq | sed -e "s~$~/inotify.log~g")"

log_monitor() {
    # shellcheck disable=SC2068
    printf '%s\n' "$@" | tee -a ${LOG_DIR_LIST[@]+"${LOG_DIR_LIST[@]}"} >/dev/null
    # also echo to caller stdout (synOCR-start captures this)
    printf '%s\n' "$@"
}

inotify_get_pids() {
    ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk '{print $2}'
}

synocr_job_running() {
    [ -n "$(/bin/pidof synOCR.sh 2>/dev/null)" ]
}

kill_inotify_watchers() {
    local pids
    pids=$(inotify_get_pids)
    if [ -z "${pids}" ]; then
        return 0
    fi
    kill ${pids} 2>/dev/null
    sleep 1
    pids=$(inotify_get_pids)
    if [ -n "${pids}" ]; then
        kill -9 ${pids} 2>/dev/null
        sleep 1
    fi
}

extension_allowed() {
    local filename="$1"
    local ext
    ext=$(printf '%s' "${filename##*.}" | tr '[:upper:]' '[:lower:]')
    case "${ext}" in
        pdf)
            return 0
            ;;
        jpg|jpeg|png|tiff)
            [ "${allow_images:-0}" -eq 1 ] && return 0
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

is_inotify_limit_error() {
    local text="$1"
    printf '%s' "${text}" | grep -qE "Couldn't initialize inotify|Too many open files|upper limit on inotify watches|max_user_watches|max_user_instances|Failed to watch"
}

handle_inotify_stderr_line() {
    local errline="$1"
    if [[ "${errline}" == "Watches established." ]]; then
        touch "${ready_flag}"
        return 0
    fi
    if [[ "${errline}" =~ ^Setting\ up\ watches\. ]]; then
        return 0
    fi
    printf "[%s] INOTIFY-ERROR: %s\n" "$(date +%Y-%m-%d_%H-%M-%S)" "${errline}" \
        | tee -a ${LOG_DIR_LIST[@]+"${LOG_DIR_LIST[@]}"} >/dev/null
    printf "%s\n" "${errline}" >> "${stderr_log}"
}

if [ ! "$(which inotifywait)" ]; then
    log_monitor "ERROR: inotify-tools are not installed"
    log_monitor "You can install the SPK from https://synocommunity.com/package/inotify-tools"
    exit 1
fi


inotify_start()
{
# start monitoring:
# --------------------------------------------------------------
    log_monitor ""
    log_monitor "[$(date +%Y-%m-%d_%H-%M-%S)] ---------------- START  MONITORING ----------"
    log_monitor "Monitoring start requested by user: $(whoami)"

    while read -r value ; do
        dir="$(echo "${value}" | awk -F'\t' '{print $1}')"
        profilename="$(echo "${value}" | awk -F'\t' '{print $2}')"
        if [ ! -d "${dir}" ]; then
            log_monitor "ERROR @ profile ${profilename}: inotify-tools cannot be started because \"${dir}\" is not a valid folder! "
            return 1
        fi
    done <<< "$(synocr_sqlite -separator $'\t' "SELECT INPUTDIR, profile FROM config WHERE active='1'" 2>/dev/null )"

    allow_images=0
    img_count=$(synocr_sqlite "SELECT COUNT(*) FROM config WHERE active='1' AND img2pdf='true'" 2>/dev/null)
    if [ "${img_count:-0}" -gt 0 ] 2>/dev/null; then
        allow_images=1
    fi
    export allow_images

    if [ ! -f "${monitored_folders}" ]; then
        synocr_sqlite "SELECT INPUTDIR FROM config WHERE active='1'" 2>/dev/null | sort | uniq > "${monitored_folders}"
    fi

    rm -f "${ready_flag}"
    : > "${stderr_log}"

    # Status messages (Watches established / Setting up watches) may go to stdout or stderr
    # depending on inotify-tools version. Handle both. Keep stderr handler output OUT of the
    # event pipe (process substitution inherits stdout of the pipeline otherwise).
    (
        inotifywait --fromfile "${monitored_folders}" -e moved_to -e close_write --monitor \
            2> >(while IFS= read -r errline; do
                    handle_inotify_stderr_line "${errline}"
                done) \
            | while IFS= read -r line; do
                if [[ "${line}" == "Watches established." ]]; then
                    touch "${ready_flag}"
                    continue
                fi

                # Status line while setting up watches (stdout variants)
                [[ "${line}" =~ ^Setting\ up\ watches\. ]] && continue

                # Only real filesystem events (never treat info/error text as OCR trigger)
                if [[ ! "${line}" =~ (CLOSE_WRITE|MOVED_TO) ]]; then
                    printf "\n%s\n" "[$(date +%Y-%m-%d_%H-%M-%S)] ---------------- EVENT SKIPPED ----------------"
                    printf "%s\n" "ignored event (not a file event): ${line}"
                    continue
                fi

                filename="${line##* }"
                if ! extension_allowed "${filename}"; then
                    printf "\n%s\n" "[$(date +%Y-%m-%d_%H-%M-%S)] ---------------- EVENT SKIPPED ----------------"
                    printf "%s\n" "ignored event (extension filter): ${line}"
                    continue
                fi

                if synocr_job_running; then
                    printf "\n%s\n" "[$(date +%Y-%m-%d_%H-%M-%S)] ---------------- EVENT SKIPPED ----------------"
                    printf "%s\n" "ignored event (synOCR already running): ${line}"
                    continue
                fi

                printf "\n%s\n" "[$(date +%Y-%m-%d_%H-%M-%S)] ---------------- EVENT ----------------------"
                printf "%s\n" "detected event: ${line}"
                printf "\n%s\n" "synOCR-start.sh Log:"
                /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh
            done
    ) | tee -a ${LOG_DIR_LIST[@]+"${LOG_DIR_LIST[@]}"} >/dev/null &

    local waited=0
    local stderr_snapshot=""
    while [ "${waited}" -lt "${START_WAIT_SECS}" ]; do
        if [ -f "${ready_flag}" ]; then
            rm -f "${ready_flag}"
            log_monitor ""
            log_monitor "[$(date +%Y-%m-%d_%H-%M-%S)] ---------------- INITIAL SCAN ---------------"
            log_monitor "Monitoring started - running initial scan"
            if synocr_job_running; then
                log_monitor "Initial scan skipped (synOCR already running)"
            else
                log_monitor ""
                log_monitor "synOCR-start.sh Log:"
                /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh | tee -a ${LOG_DIR_LIST[@]+"${LOG_DIR_LIST[@]}"} >/dev/null
            fi
            return 0
        fi

        stderr_snapshot=$(cat "${stderr_log}" 2>/dev/null)
        if is_inotify_limit_error "${stderr_snapshot}"; then
            log_monitor "ERROR: inotify failed to establish watches (user=$(whoami))"
            log_monitor "${stderr_snapshot}"
            log_monitor "Hint: check /proc/sys/fs/inotify/max_user_watches and max_user_instances"
            kill_inotify_watchers
            return 1
        fi

        sleep 1
        waited=$((waited + 1))

        if [ -z "$(inotify_get_pids)" ] && [ ! -f "${ready_flag}" ]; then
            stderr_snapshot=$(cat "${stderr_log}" 2>/dev/null)
            log_monitor "ERROR: inotifywait exited before watches were established (user=$(whoami))"
            [ -n "${stderr_snapshot}" ] && log_monitor "${stderr_snapshot}"
            log_monitor "Hint: check /proc/sys/fs/inotify/max_user_watches and max_user_instances"
            kill_inotify_watchers
            return 1
        fi
    done

    log_monitor "ERROR: timeout waiting for 'Watches established.' (user=$(whoami))"
    stderr_snapshot=$(cat "${stderr_log}" 2>/dev/null)
    [ -n "${stderr_snapshot}" ] && log_monitor "${stderr_snapshot}"
    log_monitor "Hint: check /proc/sys/fs/inotify/max_user_watches and max_user_instances"
    kill_inotify_watchers
    return 1
}


inotify_stop()
{
# stop monitoring:
# --------------------------------------------------------------
    log_monitor ""
    log_monitor "[$(date +%Y-%m-%d_%H-%M-%S)] ---------------- STOP  MONITORING -----------"
    [ -f "${monitored_folders}" ] && rm -f "${monitored_folders}"
    rm -f "${ready_flag}"

    local pids
    pids=$(inotify_get_pids)
    if [ -z "${pids}" ]; then
        log_monitor "Monitoring was not running"
        return 0
    fi

    if kill ${pids} 2>/dev/null; then
        sleep 1
        pids=$(inotify_get_pids)
        if [ -n "${pids}" ]; then
            log_monitor "Processes still alive - force kill ..."
            kill -9 ${pids} 2>/dev/null
            sleep 1
        fi
        log_monitor "Monitoring ended"
        return 0
    fi

    log_monitor "ERROR when stopping the monitoring!"
    pids=$(inotify_get_pids)
    if [ -n "${pids}" ]; then
        kill -9 ${pids} 2>/dev/null
        sleep 1
    fi
    if [ -z "$(inotify_get_pids)" ]; then
        log_monitor "Monitoring ended (forced)"
        return 0
    fi
    return 1
}


# start-stop-monitoring:
case "$1" in
    start)
        inotify_start
        exit $?
        ;;
    stop)
        inotify_stop
        exit $?
        ;;
esac

exit 0
