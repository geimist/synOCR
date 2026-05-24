#!/bin/bash
# /usr/syno/synoman/webman/3rdparty/synOCR/includes/functions.sh
# shellcheck disable=SC1090,SC1091
#,SC2001,SC2009,SC2181

synogroupmoduser() {
    # example:
    # synogroupmoduser add administrators synOCR
    # synogroupmoduser delete administrators synOCR

    local ACTION="$1"
    local GROUP="$2"
    local USER="$3"
    local CURRENTUSERS
    local -a USERLIST
    local BACKUP_FILE="/tmp/${GROUP}_members.bak"

    # check parameter
    if [[ "$ACTION" != "add" && "$ACTION" != "delete" ]] || [[ -z "$GROUP" ]] || [[ -z "$USER" ]]; then
        echo "Usage: $0 [add|delete] [group] [user]"
        return 1
    fi

    # Group existence test
    if ! synogroup --get "$GROUP" >/dev/null 2>&1; then
        echo "Error: Group $GROUP does not exist." >&2
        return 1
    fi

    # list user at group
    CURRENTUSERS=$(synogroup --get "$GROUP" | 
        awk -F'[][]' '/^[0-9]+:/ {print $2}' | 
        tr '\n' ',' | 
        sed 's/,$//'
    )

    # Backup erstellen
    echo "$CURRENTUSERS" > "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo "Error: Backup of group $GROUP failed." >&2
        return 1
    fi

    # Parse members
    IFS=',' read -ra USERLIST <<< "$CURRENTUSERS"
    local user_found=0

    # Depending on the action, process
    case "$ACTION" in
        "add")
            # Duplicate check
            for u in "${USERLIST[@]}"; do
                if [[ "$u" == "$USER" ]]; then
                    echo "User $USER already in $GROUP."
                    rm "$BACKUP_FILE"
                    return 0
                fi
            done
            USERLIST+=("$USER")
            ;;

        "delete")
            # Create new list without the user
            local -a NEWLIST=()
            for u in "${USERLIST[@]}"; do
            echo "user: $u"
                if [[ "$u" == "$USER" ]]; then
                    user_found=1
                else
                    NEWLIST+=("$u")
                fi
            done

            if [[ $user_found -eq 0 ]]; then
                echo "User $USER not in $GROUP."
                rm "$BACKUP_FILE"
                return 0
            fi
            USERLIST=("${NEWLIST[@]}")
            ;;
    esac

    # update group
    if ! synogroup --member "$GROUP" "${USERLIST[@]}"; then
        echo "CRITICAL ERROR: Group update failed! Restore from backup …" >&2

        # Restore
        IFS=',' read -ra RESTORE_LIST <<< "$(cat "$BACKUP_FILE")"
        if ! synogroup --member "$GROUP" "${RESTORE_LIST[@]}"; then
            echo "FATAL ERROR: Restore failed! Backup: $BACKUP_FILE" >&2
            return 2
        fi

        rm "$BACKUP_FILE"
        return 1
    fi

    # success message
    case "$ACTION" in
        "add") echo "User $USER successfully added to $GROUP." ;;
        "delete") echo "User $USER successfully removed from $GROUP." ;;
    esac

    rm "$BACKUP_FILE"
    return 0
}

synogroupmoddocker() {
# Check docker group and permissions

    # Create group if not existing
    if ! synogroup --get docker >/dev/null 2>&1; then
        echo -n "Creating docker group … "
        if synogroup --add docker; then
            chown root:docker /var/run/docker.sock
            synogroupmoduser add docker synOCR
            echo "OK"
        else
            echo "FAILED to create docker group!" >&2
            exit 1
        fi
    else
        # Check permissions
        if [ "$(stat -c '%G' /var/run/docker.sock)" != "docker" ]; then
            echo -n "Fixing docker socket permissions... "
            chown root:docker /var/run/docker.sock
        fi

        # Check user membership with synogroupmoduser
        if ! synogroup --get docker | grep -qw "synOCR"; then
            echo -n "Adding synOCR to docker group... "
            synogroupmoduser add docker synOCR
        else
            echo -n "OK [$(synogroup --get docker | sed -n 's/.*\[\(.*\)\].*/\1/p')]"
        fi
    fi

}

# -------------------------------------------------------------------------- #
# native URL encode & decode:
# https://gist.github.com/cdown/1163649
urlencode() {
    # urlencode <string>
    old_lc_collate="${LC_COLLATE}"
    LC_COLLATE=C

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:$i:1}"
        case $c in
            [a-zA-Z0-9._-]) printf '%s' "$c" ;;
            " ") echo -n "%20" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done

    LC_COLLATE=$old_lc_collate
}

urldecode() {
# urldecode <string>
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}


# -------------------------------------------------------------------------- #
# Remote VERSION (GitHub) and update server
# -------------------------------------------------------------------------- #
readonly SYNOCR_VERSION_JSON_URL="https://raw.githubusercontent.com/geimist/synOCR/master/VERSION"
readonly SYNOCR_PACKAGE_FEEDS_FILE="/usr/syno/etc/packages/feeds"

# Telemetry GET parameter for server_url (backend must log/evaluate):
#   package_repo = present | missing | unknown | unreadable

synocr_release_channel() {
    if [ "$(grep "^beta" /var/packages/synOCR/INFO 2>/dev/null | cut -d '"' -f2)" = yes ]; then
        printf '%s' beta
    else
        printf '%s' release
    fi
}

synocr_fetch_version_json() {
    local connect_timeout="" max_time=""
    local -a curl_args=(-s)
    while [ $# -gt 0 ]; do
        case "$1" in
            --connect-timeout)
                connect_timeout="$2"
                shift 2
                ;;
            --max-time)
                max_time="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    [ -n "${connect_timeout}" ] && curl_args+=(--connect-timeout "${connect_timeout}")
    [ -n "${max_time}" ] && curl_args+=(--max-time "${max_time}")
    local body=""
    body=$(curl "${curl_args[@]}" "${SYNOCR_VERSION_JSON_URL}" 2>/dev/null) || true
    if [ -z "${body}" ] || ! echo "${body}" | jq -e . >/dev/null 2>&1; then
        return 1
    fi
    printf '%s' "${body}"
    return 0
}

synocr_version_server_url() {
    echo "${1:-}" | jq -r '.serverURL // empty'
}

# synocr_version_parse_package_repo <json> [prefix]
# Sets ${prefix}feed_url, ${prefix}name, ${prefix}host_pattern,
# ${prefix}setup_guide_image, ${prefix}config_ready (0|1). Default prefix: repo_
synocr_version_parse_package_repo() {
    local json="$1"
    local pre="${2:-repo_}"
    local feed_url name host_pattern setup_guide_image config_ready=0

    feed_url=$(echo "${json}" | jq -r '.distribution.packageRepo.feedUrl // empty')
    name=$(echo "${json}" | jq -r '.distribution.packageRepo.name // empty')
    host_pattern=$(echo "${json}" | jq -r '.distribution.packageRepo.hostPattern // empty')
    setup_guide_image=$(echo "${json}" | jq -r '.distribution.packageRepo.setupGuideImageUrl // empty')

    if [ -z "${host_pattern}" ] && [ -n "${feed_url}" ]; then
        host_pattern=$(echo "${feed_url}" | sed -E 's#^https?://##; s#/.*$##')
    fi
    if [ -n "${feed_url}" ] && [ -n "${name}" ] && [ -n "${setup_guide_image}" ]; then
        config_ready=1
    fi

    printf -v "${pre}feed_url" '%s' "${feed_url}"
    printf -v "${pre}name" '%s' "${name}"
    printf -v "${pre}host_pattern" '%s' "${host_pattern}"
    printf -v "${pre}setup_guide_image" '%s' "${setup_guide_image}"
    printf -v "${pre}config_ready" '%s' "${config_ready}"
}

# synocr_package_repo_feed_status <feed_url> <host_pattern> <config_ready 0|1>
# Prints: present | missing | unknown | unreadable
synocr_package_repo_feed_status() {
    local feed_url="$1"
    local host_pattern="$2"
    local config_ready="${3:-0}"

    if [ "${config_ready}" -ne 1 ]; then
        printf '%s' unknown
        return 0
    fi
    if [ ! -r "${SYNOCR_PACKAGE_FEEDS_FILE}" ]; then
        printf '%s' unreadable
        return 0
    fi
    if jq -e --arg feed "${feed_url}" '.[] | select(.feed == $feed or .feed == ($feed + "/") or .feed == ($feed | sub("/$"; "")))' "${SYNOCR_PACKAGE_FEEDS_FILE}" >/dev/null 2>&1; then
        printf '%s' present
        return 0
    fi
    if [ -n "${host_pattern}" ] && grep -Fq "${host_pattern}" "${SYNOCR_PACKAGE_FEEDS_FILE}"; then
        printf '%s' present
        return 0
    fi
    printf '%s' missing
}

# synocr_server_fetch_version_info <server_url> [key=value ...]
# Without extra args: ?file=VERSION (GUI).
# With key=value pairs: telemetry query (version, arch, dsm, package_repo, …).
synocr_server_fetch_version_info() {
    local server_url="$1"
    shift
    local query="file=VERSION"
    local pair key val

    if [ -z "${server_url}" ]; then
        return 0
    fi

    while [ $# -gt 0 ]; do
        pair="$1"
        shift
        key="${pair%%=*}"
        val="${pair#*=}"
        [ -z "${key}" ] || [ "${key}" = "${pair}" ] && continue
        query="${query}&${key}=${val}"
    done

    wget --no-check-certificate --timeout=20 --tries=3 -q -O - "${server_url}?${query}" 2>/dev/null || true
}


# -------------------------------------------------------------------------- #
# Live progress (GUI status file)
# -------------------------------------------------------------------------- #
# Architecture (main page, two progress bars):
#
#   synOCR-start.sh run     -> files_total, started_at; synocr_status_clear at end
#   synOCR.sh (per profile) -> synocr_build_step_list, synocr_status_update_step
#   etc/synOCR.status.json  -> shared state (atomic write via synocr_status_write)
#   synocr_count_input_files -> live files_remaining (find over active profiles)
#   synocr_is_process_running -> etc/synOCR.lock + pid
#
#   GUI_main.sh             -> synocr_progress_compute, initial HTML + config JSON
#   index.cgi?page=main-status -> JSON for polling (synocr_render_main_status_json)
#   template/synocr-progress.js -> poll bars, #synocr-main-status-icon, open-file row
#     (outside <form>; DSM blocks inline script in forms)
#
# Status file fields (JSON): state, profile, profile_id, file, step_id, step_index,
#   step_total, step_ids, files_baseline, files_peak, files_completed, files_total, started_at
#
# GUI globals after synocr_progress_compute(): synocr_pg_show, synocr_pg_running,
#   synocr_pg_files_{remaining,done,total}, synocr_pg_percent_{files,file},
#   synocr_pg_file, synocr_pg_profile, synocr_pg_step_{id,index,total,label}
#
# Worker env (optional): SYNOCR_PROGRESS_TOTAL, SYNOCR_PROGRESS_STARTED_AT
# Status fields: files_baseline, files_peak, files_completed, files_total, started_at
# -------------------------------------------------------------------------- #

synocr_app_home() {
    if [ -n "${SYNOCR_APP_HOME:-}" ]; then
        printf '%s' "${SYNOCR_APP_HOME}"
        return 0
    fi
    if [ -n "${APPDIR:-}" ]; then
        printf '%s' "${APPDIR}"
        return 0
    fi
    local _dir
    _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    printf '%s' "${_dir}"
}

# Path to shared status file (GUI + workers).
synocr_status_file_path() {
    printf '%s/etc/synOCR.status.json' "$(synocr_app_home)"
}

synocr_count_input_files_for_profile() {
    local inputdir="$1"
    local searchpraefix="$2"
    local img2pdf_flag="$3"
    local source_file_type exclusion=false count=0

    inputdir="${inputdir%/}/"

    if [ "${img2pdf_flag}" = true ]; then
        source_file_type="\(JPG\|jpg\|PNG\|png\|TIFF\|tiff\|JPEG\|jpeg\|PDF\|pdf\)"
    else
        source_file_type="\(PDF\|pdf\)"
    fi

    if echo "${searchpraefix}" | grep -qE '^!' ; then
        exclusion=true
        searchpraefix="${searchpraefix#!}"
    fi

    if echo "${searchpraefix}" | grep -q "\$"$ ; then
        searchpraefix="${searchpraefix%?}"
        if [[ "${exclusion}" = false ]] ; then
            count=$(find "${inputdir}" -maxdepth 1 -regex "${inputdir}.*${searchpraefix}\.${source_file_type}$" -type f -printf '.' 2>/dev/null | wc -c )
        else
            count=$(find "${inputdir}" -maxdepth 1 -regex "${inputdir}.*\.${source_file_type}$" -not -iname "*${searchpraefix}.*" -type f -printf '.' 2>/dev/null | wc -c )
        fi
    else
        searchpraefix="${searchpraefix%%\$}"
        if [[ "${exclusion}" = false ]] ; then
            count=$(find "${inputdir}" -maxdepth 1 -regex "${inputdir}${searchpraefix}.*\.${source_file_type}$" -type f -printf '.' 2>/dev/null | wc -c )
        else
            count=$(find "${inputdir}" -maxdepth 1 -regex "${inputdir}.*\.${source_file_type}$" -not -iname "${searchpraefix}*" -type f -printf '.' 2>/dev/null | wc -c )
        fi
    fi

    printf '%s' "${count:-0}"
}

synocr_count_input_files() {
    local total=0 entry inputdir searchpraefix img2pdf_flag count

    while read -r entry ; do
        inputdir=$(echo "${entry}" | awk -F'\t' '{print $1}')
        searchpraefix=$(echo "${entry}" | awk -F'\t' '{print $2}')
        img2pdf_flag=$(echo "${entry}" | awk -F'\t' '{print $3}')
        count=$(synocr_count_input_files_for_profile "${inputdir}" "${searchpraefix}" "${img2pdf_flag}")
        total=$((total + count))
    done <<< "$(sqlite3 -separator $'\t' "$(synocr_app_home)/etc/synOCR.sqlite" "SELECT INPUTDIR, SearchPraefix, img2pdf FROM config WHERE active='1' " 2>/dev/null)"

    printf '%s' "${total}"
}

# Merge key/value pairs into synOCR.status.json (atomic replace).
synocr_status_write() {
    local status_file tmp current key val
    status_file="$(synocr_status_file_path)"
    mkdir -p "$(dirname "${status_file}")"
    tmp="${status_file}.$$.$RANDOM.tmp"
    current='{}'
    if [ -s "${status_file}" ]; then
        current=$(<"${status_file}")
    fi

    while [ $# -gt 0 ]; do
        key="$1"
        val="$2"
        shift 2
        case "${key}" in
            step_index|step_total|files_total|files_baseline|files_peak|files_completed|started_at|updated_at)
                current=$(echo "${current}" | jq --argjson v "${val}" ". + {\"${key}\": \$v}")
                ;;
            *)
                current=$(echo "${current}" | jq --arg v "${val}" ". + {\"${key}\": \$v}")
                ;;
        esac
    done

    current=$(echo "${current}" | jq --argjson t "$(date +%s)" '.updated_at=$t')
    printf '%s\n' "${current}" > "${tmp}" && mv -f "${tmp}" "${status_file}"
}

# Only increase integer status counters (queue can grow while a run is active).
synocr_status_write_monotonic_int() {
    local key="$1" new_val="$2" status_file cur=0
    status_file="$(synocr_status_file_path)"
    if [ -s "${status_file}" ]; then
        cur=$(jq -r --arg k "${key}" '.[$k] // 0' "${status_file}" 2>/dev/null)
    fi
    if [ "${new_val:-0}" -gt "${cur:-0}" ] 2>/dev/null; then
        synocr_status_write "${key}" "${new_val}"
    fi
}

synocr_status_clear() {
    rm -f "$(synocr_status_file_path)"
}

# Clear status only when no worker holds the lock and the input queue is empty.
synocr_status_clear_if_idle() {
    if synocr_is_process_running; then
        return 0
    fi
    if [ "$(synocr_count_input_files)" -gt 0 ]; then
        return 0
    fi
    synocr_status_clear
}

# Start or extend a GUI progress session (handles overlapping synOCR-start.sh runs).
synocr_status_begin_run() {
    local count_at_start="$1"
    local status_file peak=0

    [ "${count_at_start:-0}" -gt 0 ] 2>/dev/null || return 0

    status_file="$(synocr_status_file_path)"
    if [ -s "${status_file}" ]; then
        peak=$(jq -r '.files_peak // 0' "${status_file}" 2>/dev/null)
    fi

    if synocr_is_process_running || [ "${peak:-0}" -gt 0 ]; then
        synocr_status_write state running
        synocr_status_write_monotonic_int files_baseline "${count_at_start}"
        synocr_status_write_monotonic_int files_peak "${count_at_start}"
        synocr_status_write_monotonic_int files_total "${count_at_start}"
        return 0
    fi

    synocr_status_write \
        state running \
        started_at "$(date +%s)" \
        files_completed 0
    synocr_status_write_monotonic_int files_baseline "${count_at_start}"
    synocr_status_write_monotonic_int files_peak "${count_at_start}"
    synocr_status_write_monotonic_int files_total "${count_at_start}"
}

synocr_status_increment_files_completed() {
    local status_file cur=0
    status_file="$(synocr_status_file_path)"
    if [ -s "${status_file}" ]; then
        cur=$(jq -r '.files_completed // 0' "${status_file}" 2>/dev/null)
    fi
    synocr_status_write files_completed "$((cur + 1))"
}

synocr_is_process_running() {
    local lock_dir pid
    lock_dir="$(synocr_app_home)/etc/synOCR.lock"
    if [ ! -d "${lock_dir}" ]; then
        return 1
    fi
    pid=$(cat "${lock_dir}/pid" 2>/dev/null)
    if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
        return 0
    fi
    return 1
}

synocr_would_adjust_color() {
    local adjustColor=false
    [ "${adjustColorBWthreshold:-0}" != "0" ] && adjustColor=true
    if [ "${adjustColorContrast:-1}" != "1" ] && [ "${adjustColorContrast:-1}" != "1.0" ]; then
        adjustColor=true
    fi
    if [ "${adjustColorSharpness:-1}" != "1" ] && [ "${adjustColorSharpness:-1}" != "1.0" ]; then
        adjustColor=true
    fi
    [ "${adjustColor}" = true ] && [ "${keep_hash:-false}" != "true" ] && [ "${python_check:-failed}" = "ok" ]
}

# Build step list for current profile (bash 4+ arrays). Sets synocr_step_ids and synocr_step_ids_json.
synocr_build_step_list() {
    synocr_step_ids=()
    synocr_step_ids+=(prepare)

    if [ "${img2pdf:-false}" = true ] && [ "${keep_hash:-false}" != "true" ]; then
        synocr_step_ids+=(img2pdf)
    fi

    if [ "${delay:-0}" -ne 0 ] 2>/dev/null; then
        synocr_step_ids+=(delay)
    fi

    if synocr_would_adjust_color; then
        synocr_step_ids+=(color_adjust)
    fi

    synocr_step_ids+=(ocr)

    if [ "${blank_page_detection_switch:-false}" = true ] && [ "${python_check:-failed}" = "ok" ] && [ "${keep_hash:-false}" != "true" ]; then
        synocr_step_ids+=(blank_pages)
    fi

    if [ -n "${documentSplitPattern:-}" ] && [ "${python_check:-failed}" = "ok" ] && [ "${keep_hash:-false}" != "true" ]; then
        synocr_step_ids+=(split)
    fi

    synocr_step_ids+=(pdftotext tags date rename notify cleanup)

    synocr_step_ids_json=$(printf '%s\n' "${synocr_step_ids[@]}" | jq -R . | jq -s -c .)
}

synocr_step_index_for() {
    local step_id="$1" i
    for i in "${!synocr_step_ids[@]}"; do
        if [ "${synocr_step_ids[$i]}" = "${step_id}" ]; then
            printf '%s' "$((i + 1))"
            return 0
        fi
    done
    printf '0'
}

synocr_status_publish_steps() {
    local total
    total=${#synocr_step_ids[@]}
    synocr_status_write \
        step_total "${total}" \
        step_ids "${synocr_step_ids_json}"
}

synocr_status_update_step() {
    local step_id="$1"
    local file_name="${2:-}"
    local idx

    idx=$(synocr_step_index_for "${step_id}")
    [ "${idx}" -eq 0 ] && return 0

    if [ -n "${file_name}" ]; then
        synocr_status_write \
            state running \
            step_id "${step_id}" \
            step_index "${idx}" \
            file "${file_name}"
    else
        synocr_status_write \
            state running \
            step_id "${step_id}" \
            step_index "${idx}"
    fi
}

synocr_status_file_pipeline_start() {
    local file_name="$1"
    if [ "${delay:-0}" -ne 0 ] 2>/dev/null; then
        synocr_status_update_step delay "${file_name}"
    elif synocr_would_adjust_color; then
        synocr_status_update_step color_adjust "${file_name}"
    else
        synocr_status_update_step ocr "${file_name}"
    fi
}

synocr_status_init_run() {
    local profile_name="$1"
    local profile_id="$2"
    synocr_status_write \
        state running \
        profile "${profile_name}" \
        profile_id "${profile_id}" \
        file "" \
        step_id prepare \
        step_index 1
    if [ -n "${SYNOCR_PROGRESS_TOTAL:-}" ]; then
        synocr_status_write files_total "${SYNOCR_PROGRESS_TOTAL}"
    fi
    if [ -n "${SYNOCR_PROGRESS_STARTED_AT:-}" ]; then
        synocr_status_write started_at "${SYNOCR_PROGRESS_STARTED_AT}"
    fi
}

synocr_progress_step_label() {
    local step_id="$1"
    local key="" label=""

    case "${step_id}" in
        img2pdf) key=lang_edit_set2_img2pdf_title ;;
        blank_pages) key=lang_edit_set2_blank_page_detection_switch_title ;;
        color_adjust) key=lang_edit_set2_adjustColor_title ;;
        tags) key=lang_edit_set2_taglist_title ;;
        date) key=lang_edit_set2_filedate_title ;;
        rename) key=lang_edit_set2_renamesyntax_title ;;
        notify) key=lang_edit_set3_dsmtextnotify_title ;;
        prepare) key=lang_main_progress_step_prepare ;;
        delay) key=lang_main_progress_step_delay ;;
        ocr) key=lang_main_progress_step_ocr ;;
        split) key=lang_main_progress_step_split ;;
        pdftotext) key=lang_main_progress_step_pdftotext ;;
        cleanup) key=lang_main_progress_step_cleanup ;;
        *) label="${step_id}" ;;
    esac

    if [ -n "${key}" ]; then
        label="${!key:-}"
        [ -z "${label}" ] && label="${step_id}"
    fi
    printf '%s' "${label}"
}

# Sets synocr_pg_* globals (running, files_*, percent_*, step_*, show).
synocr_progress_compute() {
    local status_file json_base files_total_raw files_baseline_raw files_peak_raw files_completed_raw

    synocr_pg_files_remaining=$(synocr_count_input_files)
    synocr_pg_files_total=0
    files_baseline_raw=0
    files_peak_raw=0
    files_total_raw=0
    files_completed_raw=-1
    synocr_pg_state=idle
    synocr_pg_step_id=""
    synocr_pg_step_index=0
    synocr_pg_step_total=0
    synocr_pg_file=""
    synocr_pg_profile=""
    synocr_pg_running=0
    synocr_pg_show=0
    synocr_pg_files_done=0
    synocr_pg_percent_files=0
    synocr_pg_percent_file=0
    synocr_pg_step_label=""

    if synocr_is_process_running; then
        synocr_pg_running=1
    fi

    status_file="$(synocr_status_file_path)"
    if [ -s "${status_file}" ]; then
        json_base=$(<"${status_file}")
        synocr_pg_state=$(echo "${json_base}" | jq -r '.state // "idle"')
        synocr_pg_step_id=$(echo "${json_base}" | jq -r '.step_id // ""')
        synocr_pg_step_index=$(echo "${json_base}" | jq -r '.step_index // 0')
        synocr_pg_step_total=$(echo "${json_base}" | jq -r '.step_total // 0')
        synocr_pg_file=$(echo "${json_base}" | jq -r '.file // ""')
        synocr_pg_profile=$(echo "${json_base}" | jq -r '.profile // ""')
        files_baseline_raw=$(echo "${json_base}" | jq -r '.files_baseline // 0')
        files_peak_raw=$(echo "${json_base}" | jq -r '.files_peak // 0')
        files_total_raw=$(echo "${json_base}" | jq -r '.files_total // 0')
        if echo "${json_base}" | jq -e 'has("files_completed")' >/dev/null 2>&1; then
            files_completed_raw=$(echo "${json_base}" | jq -r '.files_completed')
        fi
    fi

    if [ "${synocr_pg_running}" -eq 1 ] || [ "${synocr_pg_files_remaining}" -gt 0 ]; then
        [ "${synocr_pg_state}" = "idle" ] && synocr_pg_state=running
        synocr_pg_show=1
    else
        synocr_pg_state=idle
        synocr_pg_show=0
    fi

    # Queue may grow after run start (inotify / second profile). Track peak, never shrink baseline.
    if [ "${synocr_pg_running}" -eq 1 ] \
        && [ "${synocr_pg_files_remaining}" -gt "${files_peak_raw:-0}" ]; then
        synocr_status_write_monotonic_int files_peak "${synocr_pg_files_remaining}"
        files_peak_raw=${synocr_pg_files_remaining}
    fi

    synocr_pg_files_total=0
    [ "${files_baseline_raw:-0}" -gt "${synocr_pg_files_total}" ] && synocr_pg_files_total=${files_baseline_raw}
    [ "${files_peak_raw:-0}" -gt "${synocr_pg_files_total}" ] && synocr_pg_files_total=${files_peak_raw}
    [ "${files_total_raw:-0}" -gt "${synocr_pg_files_total}" ] && synocr_pg_files_total=${files_total_raw}
    [ "${synocr_pg_files_remaining}" -gt "${synocr_pg_files_total}" ] && synocr_pg_files_total=${synocr_pg_files_remaining}

    if [ "${files_completed_raw}" -ge 0 ] 2>/dev/null; then
        synocr_pg_files_done=${files_completed_raw}
    else
        synocr_pg_files_done=$((synocr_pg_files_total - synocr_pg_files_remaining))
    fi
    [ "${synocr_pg_files_done}" -lt 0 ] && synocr_pg_files_done=0
    if [ "${synocr_pg_files_total}" -gt 0 ] && [ "${synocr_pg_files_done}" -gt "${synocr_pg_files_total}" ]; then
        synocr_pg_files_done=${synocr_pg_files_total}
    fi

    if [ "${synocr_pg_files_total}" -gt 0 ]; then
        synocr_pg_percent_files=$((synocr_pg_files_done * 100 / synocr_pg_files_total))
    else
        synocr_pg_percent_files=0
    fi

    if [ "${synocr_pg_step_total}" -gt 0 ] && [ "${synocr_pg_step_index}" -gt 0 ]; then
        synocr_pg_percent_file=$((synocr_pg_step_index * 100 / synocr_pg_step_total))
    else
        synocr_pg_percent_file=0
    fi

    synocr_pg_step_label=$(synocr_progress_step_label "${synocr_pg_step_id}")
}

# JSON API for index.cgi?page=main-status (jQuery polling).
synocr_render_main_status_json() {
    synocr_progress_compute

    jq -n \
        --arg state "${synocr_pg_state}" \
        --argjson running "${synocr_pg_running}" \
        --argjson files_remaining "${synocr_pg_files_remaining}" \
        --argjson files_total "${synocr_pg_files_total}" \
        --argjson files_done "${synocr_pg_files_done}" \
        --argjson percent_files "${synocr_pg_percent_files}" \
        --argjson percent_file "${synocr_pg_percent_file}" \
        --arg file "${synocr_pg_file}" \
        --arg profile "${synocr_pg_profile}" \
        --arg step_id "${synocr_pg_step_id}" \
        --arg step_label "${synocr_pg_step_label}" \
        --argjson step_index "${synocr_pg_step_index}" \
        --argjson step_total "${synocr_pg_step_total}" \
        '{
            state: $state,
            running: ($running == 1),
            files_remaining: $files_remaining,
            files_total: $files_total,
            files_done: $files_done,
            percent_files: $percent_files,
            percent_file: $percent_file,
            file: $file,
            profile: $profile,
            step_id: $step_id,
            step_label: $step_label,
            step_index: $step_index,
            step_total: $step_total
        }'
}


# -------------------------------------------------------------------------- #
language() {
    # ---------------------------------------------------------------------- #
    # Configure language settings                                            #
    # ---------------------------------------------------------------------- #
    # Load English language file
    source "lang/lang_enu.txt"

    #********************************************************************#
    #  Description: Script get the current used dsm language             #
    #  Author:      QTip from the german Synology support forum          #
    #  Copyright:   2016-2018 by QTip                                    #
    #  License:     GNU GPLv3                                            #
    #  ----------------------------------------------------------------  #
    #  Version:     0.15 - 2018-06-11                                    #
    #  Version:     0.16 - 2018-08-07                                    #
    #********************************************************************#

    # Sprachdateien konfigurieren
    # Funktion zur Ermittlung der eingestellten Sprache
    # - DSM Sprache ermitteln (aus synoinfo.conf)
    # - Browser Sprache ermitteln (aus ${HTTP_ACCEPT_LANGUAGE})
    # - wenn DSM Sprache = default, dann benutze Browser Sprache
    # - Persönliche DSM Sprache ermitteln (aus usersettings)
    # - falls Persönliche DSM Sprache = default, dann benutze weiterhin die zuvor
    #   ermittelte Sprache, ansonsten benutze die ermittelte Persönliche DSM Sprache
    # - ist DSM Sprache und Persönliche DSM Sprache = "def" und Browser Sprache nicht gesetzt, dann benutze Standard Sprache (DEFLANG)
    # Prioritäten: 1. Persönliche DSM Sprache =2. DSM Sprache =3. Browser Sprache =4. Standard Sprache
    #

# Übersetzungstabelle deklarieren
    declare -A ISO2SYNO
    ISO2SYNO=( ["de"]="ger" ["en"]="enu" ["zh"]="chs" ["cs"]="csy" ["jp"]="jpn" ["ko"]="krn" ["da"]="dan" ["fr"]="fre" ["it"]="ita" ["nl"]="nld" ["no"]="nor" ["pl"]="plk" ["ru"]="rus" ["sp"]="spn" ["sv"]="sve" ["hu"]="hun" ["tr"]="trk" ["pt"]="ptg" )
    # fehlende Sprachen: Tai, 'Portuguese Brazilian' ('ptb','PT-BR')

# DSM Sprache ermitteln
    deflang="enu"
    lang=$(grep language /etc/synoinfo.conf | sed 's/language=//;s/\"//g' | grep -Eo "^.{3}")

# Browsersprache ermitteln
    if [[ "${lang}" == "def" ]] ; then
        if [ -n "${HTTP_ACCEPT_LANGUAGE}" ] ; then
            bl=$(echo "${HTTP_ACCEPT_LANGUAGE}" | cut -d "," -f1)
            bl=${bl:0:2}
            lang=${ISO2SYNO[${bl}]}
        else
            lang=${deflang}
        fi
    fi

# Persönliche DSM Sprache ermitteln
    # shellcheck disable=SC2154
    usersettingsfile="/usr/syno/etc/preference/${login_user}/usersettings"
    if [ -f "${usersettingsfile}" ] ; then
        userlanguage=$(jq -r ".Personal.lang" "${usersettingsfile}")
        if [ -n "${userlanguage}" ] && [ "${userlanguage}" != "def" ] && [ "${userlanguage}" != "null" ]; then
            lang="${userlanguage}"
        fi
    fi

# Sprachdatei laden
    if [ -f "lang/lang_${lang}.txt" ] && [[ "${lang}" != "enu" ]]; then
        source "lang/lang_${lang}.txt"
    fi
}
