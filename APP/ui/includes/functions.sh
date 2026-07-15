#!/bin/bash
# /usr/syno/synoman/webman/3rdparty/synOCR/includes/functions.sh
# shellcheck disable=SC1090,SC1091
#,SC2001,SC2009,SC2181

synocr_sqlite() {
    local busy_timeout="${SYNOCR_SQLITE_BUSY_TIMEOUT:-5000}"
    local db sql json_mode=0
    local -a sqlite_opts=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -json)
                json_mode=1
                shift
                ;;
            -jsonlines)
                json_mode=2
                shift
                ;;
            -separator)
                sqlite_opts+=( "$1" )
                shift
                [ $# -gt 0 ] && sqlite_opts+=( "$1" )
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                sqlite_opts+=( "$1" )
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    if [ $# -lt 1 ]; then
        echo "synocr_sqlite: missing SQL argument" >&2
        return 2
    fi

    if [ $# -eq 1 ]; then
        db="$(synocr_app_home)/etc/synOCR.sqlite"
        sql="$1"
    else
        db="$1"
        shift
        sql="$*"
    fi

    if [ "${json_mode}" -eq 1 ]; then
        sqlite3 -cmd ".timeout ${busy_timeout}" -json "${db}" "${sql}"
    elif [ "${json_mode}" -eq 2 ]; then
        # Portable jsonlines: sqlite3 -json + jq (native -jsonlines is not on all DSM sqlite3 builds).
        synocr_jq_rows "$(sqlite3 -cmd ".timeout ${busy_timeout}" -json "${db}" "${sql}")"
    else
        sqlite3 -cmd ".timeout ${busy_timeout}" "${sqlite_opts[@]}" "${db}" "${sql}"
    fi
}

# Escape a value for safe use inside a single-quoted SQLite string literal.
# Doubles single quotes (standard SQL escaping); the caller wraps the output in '...'.
# Used for JSON blobs and free-text (name, description, postscript, RegEx, paths).
sql_escape() {
    local s="${1-}"
    printf '%s' "${s//\'/\'\'}"
}

# JSON string literal for safe embedding in generated JavaScript (includes surrounding quotes).
synocr_js_json_string() {
    printf '%s' "${1-}" | jq -Rs .
}

# rules_validate_json <json>
# Hard, storage-agnostic validator for a ruleset JSON blob (wrapped
# {"rules":...,"groups":...} or legacy flat). Prints localized error messages
# (lang_rules_val_*) to stdout — one per line — and returns 1 if any error was
# found, 0 otherwise. Used by the GUI save/import paths to prevent persisting
# invalid rules. Self-contained: only jq + bash, no logging side effects.
rules_validate_json() {
    local json="${1-}"
    local _rules_json _groups_json _known _out="" _chunk
    local _idx _rname _cond _prio _act _res _field _ref _rtype _ss _st _src _gname _gcond

    # substitute %1/%2/%3 in a lang string
    _rules_fmt() {
        local s="$1" a="${2-}" b="${3-}" c="${4-}"
        s="${s//\%1/${a}}"
        s="${s//\%2/${b}}"
        s="${s//\%3/${c}}"
        printf '%s' "${s}"
    }
    # append a non-empty chunk to _out with newline separation
    _rules_add() {
        [ -z "$1" ] && return
        if [ -n "${_out}" ]; then _out="${_out}"$'\n'"$1"; else _out="$1"; fi
    }

    # 1) JSON parseable?
    if ! printf '%s' "${json}" | jq -e . >/dev/null 2>&1; then
        printf '%s\n' "${lang_rules_val_json_parse:-JSON parse error}"
        return 1
    fi

    # 2) normalize wrapped vs. legacy flat
    if printf '%s' "${json}" | jq -e 'has("rules") and (.rules | type == "object")' >/dev/null 2>&1; then
        _rules_json=$(printf '%s' "${json}" | jq -c '.rules')
        _groups_json=$(printf '%s' "${json}" | jq -c '.groups // {}')
    else
        _rules_json=$(printf '%s' "${json}" | jq -c '.')
        _groups_json='{}'
    fi
    if ! printf '%s' "${_rules_json}" | jq -e 'type == "object"' >/dev/null 2>&1; then
        printf '%s\n' "${lang_rules_val_json_parse:-rules not an object}"
        return 1
    fi
    _known=$(printf '%s' "${_rules_json}" | jq -r 'keys[]')

    # 3) rule-level: empty name / condition / priority / on_match / dirname_multilineregex
    _chunk=$(printf '%s' "${_rules_json}" | jq -r '
        [to_entries[]] | to_entries[] | .key as $i0 | .value.key as $k | .value.value as $v
        | "\($i0+1)\t\($k)\t\($v.condition // "any")\t\($v.priority // 100)\t\($v.on_match.action // "-")\t\($v.on_match.result // "-")\t\($v.dirname_multilineregex // "-")"
    ' 2>/dev/null | while IFS=$'\t' read -r _idx _rname _cond _prio _act _res _dml; do
        if [ -z "${_rname}" ] || [ "${_rname}" = "null" ]; then
            printf '%s\n' "$(_rules_fmt "${lang_rules_val_rule_no_name}" "${_idx}" "")"
            continue
        fi
        if [ -n "${_cond}" ] && [ "${_cond}" != "null" ] && ! printf '%s' "${_cond}" | grep -Eiw '^(all|any|none)$' >/dev/null 2>&1; then
            printf '%s\n' "$(_rules_fmt "${lang_rules_val_rule_condition}" "${_rname}" "${_cond}")"
        fi
        if [ -n "${_prio}" ] && [ "${_prio}" != "null" ] && [ "${_prio}" != "100" ] && ! printf '%s' "${_prio}" | grep -Eq '^-?[0-9]+$' >/dev/null 2>&1; then
            printf '%s\n' "$(_rules_fmt "${lang_rules_val_rule_priority}" "${_rname}" "${_prio}")"
        fi
        if [ -n "${_act}" ] && [ "${_act}" != "null" ] && [ "${_act}" != "-" ] && ! printf '%s' "${_act}" | grep -Eiw '^(continue|break)$' >/dev/null 2>&1; then
            printf '%s\n' "$(_rules_fmt "${lang_rules_val_rule_on_match_action}" "${_rname}" "${_act}")"
        fi
        if [ -n "${_res}" ] && [ "${_res}" != "null" ] && [ "${_res}" != "-" ] && ! printf '%s' "${_res}" | grep -Eiw '^(merge|replace|exclusive)$' >/dev/null 2>&1; then
            printf '%s\n' "$(_rules_fmt "${lang_rules_val_rule_on_match_result}" "${_rname}" "${_res}")"
        fi
        if [ -n "${_dml}" ] && [ "${_dml}" != "null" ] && [ "${_dml}" != "-" ] && ! printf '%s' "${_dml}" | grep -Eiw '^(true|false)$' >/dev/null 2>&1; then
            printf '%s\n' "$(_rules_fmt "${lang_rules_val_rule_dirname_multiline}" "${_rname}" "${_dml}")"
        fi
    done)
    _rules_add "${_chunk}"

    # 4) requires / excludes: type must be array or string (or null)
    _chunk=$(printf '%s' "${_rules_json}" | jq -r '
        to_entries[] | .key as $k | .value as $v
        | if ($v.requires != null) and ($v.requires | type | IN("array","string") | not) then "\($k)\trequires\t\($v.requires | type)"
          elif ($v.excludes != null) and ($v.excludes | type | IN("array","string") | not) then "\($k)\texcludes\t\($v.excludes | type)"
          else empty end
    ' 2>/dev/null | while IFS=$'\t' read -r _rname _field _rtype; do
        printf '%s\n' "$(_rules_fmt "${lang_rules_val_field_type}" "${_rname}" "${_field}" "${_rtype}")"
    done)
    _rules_add "${_chunk}"

    # 5) requires / excludes: references must be known rules
    _chunk=$(printf '%s' "${_rules_json}" | jq -r '
        def as_list: if . == null then [] elif type == "string" then [.] elif type == "array" then . else [] end;
        to_entries[] | .key as $k
        | (($k) + "\t" + "requires" + "\t" + ((.value.requires | as_list)[]? | tostring)),
          (($k) + "\t" + "excludes" + "\t" + ((.value.excludes | as_list)[]? | tostring))
    ' 2>/dev/null | while IFS=$'\t' read -r _rname _field _ref; do
        [ -z "${_ref}" ] && continue
        if ! printf '%s\n' "${_known}" | grep -qxF "${_ref}"; then
            if [ "${_field}" = "requires" ]; then
                printf '%s\n' "$(_rules_fmt "${lang_rules_val_requires_unknown}" "${_rname}" "${_ref}")"
            else
                printf '%s\n' "$(_rules_fmt "${lang_rules_val_excludes_unknown}" "${_rname}" "${_ref}")"
            fi
        fi
    done)
    _rules_add "${_chunk}"

    # 6) subrules: searchstring non-empty, searchtyp + source valid
    # Note: bash `read` with IFS=$'\t' collapses consecutive tabs (empty searchstring),
    # so field extraction uses awk which preserves empty columns.
    _chunk=$(printf '%s' "${_rules_json}" | jq -r '
        def st: (.searchtyp // .searchtype // "contains") | tostring | ascii_downcase;
        def src: (.source // "content") | tostring | ascii_downcase;
        to_entries[] | .key as $k | (.value.subrules // []) | .[]?
        | "\($k)\t\(.searchstring // "")\t\(. | st)\t\(. | src)"
    ' 2>/dev/null | while IFS= read -r _line; do
        [ -z "${_line}" ] && continue
        _rname=$(printf '%s' "${_line}" | awk -F'\t' '{print $1}')
        _ss=$(printf '%s' "${_line}" | awk -F'\t' '{print $2}')
        _st=$(printf '%s' "${_line}" | awk -F'\t' '{print $3}')
        _src=$(printf '%s' "${_line}" | awk -F'\t' '{print $4}')
        if [ -z "${_ss}" ] || [ "${_ss}" = "null" ]; then
            printf '%s\n' "$(_rules_fmt "${lang_rules_val_subrule_empty}" "${_rname}" "")"
        fi
        if [ -n "${_st}" ] && [ "${_st}" != "null" ] && ! printf '%s' "${_st}" | grep -Eiw '^(is|is not|contains|does not contain|starts with|does not starts with|ends with|does not ends with|matches|does not match)$' >/dev/null 2>&1; then
            printf '%s\n' "$(_rules_fmt "${lang_rules_val_subrule_searchtyp}" "${_rname}" "${_st}")"
        fi
        if [ -n "${_src}" ] && [ "${_src}" != "null" ] && ! printf '%s' "${_src}" | grep -Eiw '^(content|filename)$' >/dev/null 2>&1; then
            printf '%s\n' "$(_rules_fmt "${lang_rules_val_subrule_source}" "${_rname}" "${_src}")"
        fi
    done)
    _rules_add "${_chunk}"

    # 7) group-level: condition (only for wrapped format with groups)
    if [ "${_groups_json}" != "{}" ]; then
        _chunk=$(printf '%s' "${_groups_json}" | jq -r '
            to_entries[] | "\(.key)\t\(.value.condition // "first_match")"
        ' 2>/dev/null | while IFS=$'\t' read -r _gname _gcond; do
            if [ -n "${_gcond}" ] && [ "${_gcond}" != "null" ] && ! printf '%s' "${_gcond}" | grep -Eiw '^(all|any|first_match)$' >/dev/null 2>&1; then
                printf '%s\n' "$(_rules_fmt "${lang_rules_val_group_condition}" "${_gname}" "${_gcond}")"
            fi
        done)
        _rules_add "${_chunk}"
    fi

    if [ -n "${_out}" ]; then
        printf '%s\n' "${_out}"
        return 1
    fi
    return 0
}

# Read one field from a sqlite3 -json array result (first row by default).
synocr_jq_field() {
    local json="${1:-}"
    local field="$2"
    local idx="${3:-0}"

    [ -n "${json}" ] || return 0
    jq -r ".[${idx}].${field} // empty" <<< "${json}"
}

# Read one field from a single JSON object (one row from synocr_jq_rows).
synocr_jq_row_field() {
    local row="${1:-}"
    local field="$2"

    [ -n "${row}" ] || return 0
    jq -r ".${field} // empty" <<< "${row}"
}

# Emit one compact JSON object per result row (for while-read loops).
synocr_jq_rows() {
    local json="${1:-}"

    [ -n "${json}" ] || return 0
    jq -c '.[]' <<< "${json}"
}

# Load all columns of one row into same-named shell variables.
synocr_jq_load_row() {
    local json="${1:-}"
    local idx="${2:-0}"
    local assignment

    [ -n "${json}" ] || return 1
    jq -e ".[${idx}]" >/dev/null 2>&1 <<< "${json}" || return 1
    while IFS= read -r assignment; do
        [[ -n "${assignment}" ]] || continue
        eval "${assignment}"
    done < <(jq -r ".[${idx}] | to_entries[] | \"\(.key)=\((.value // \"\") | @sh)\"" <<< "${json}")
}

# Scalar helper: one aliased column via sqlite3 -json.
synocr_sqlite_json_field() {
    local sql="$1"
    local field="$2"

    synocr_jq_field "$(synocr_sqlite -json "${sql}")" "${field}"
}

# Column list aligned with config table schema (upgradeconfig.sh). Keep in sync when adding columns.
synocr_config_columns() {
    cat <<'EOF'
profile_ID, timestamp, profile, active, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix,
taglist, ruleset_id, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, apprise_call, apprise_attachment, notify_lang,
dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, filedate, tagsymbol, documentSplitPattern, ignoredDate,
backup_max, backup_max_type, backup_clean_orphaned, pagecount, ocrcount, search_nearest_date, date_search_method,
clean_up_spaces, img2pdf, DateSearchMinYear, DateSearchMaxYear, splitpagehandling,
blank_page_detection_switch, blank_page_detection_mainThreshold, blank_page_detection_widthCropping,
blank_page_detection_hightCropping, blank_page_detection_interferenceMaxFilter, blank_page_detection_interferenceMinFilter,
blank_page_detection_black_pixel_ratio, blank_page_detection_ignoreText,
adjustColorBWthreshold, adjustColorDPI, adjustColorContrast, adjustColorSharpness
EOF
}

synocr_config_json_by_id() {
    local profile_id="$1"
    local columns where_clause

    columns=$(synocr_config_columns)
    columns=$(echo "${columns}" | tr '\n' ' ' | sed 's/  */ /g;s/^ //;s/ $//')
    if [ -z "${profile_id}" ]; then
        where_clause="profile_ID='1'"
    else
        where_clause="profile_ID='${profile_id}'"
    fi

    synocr_sqlite -json "SELECT ${columns} FROM config WHERE ${where_clause}"
}

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
            synocr_fail_fatal "Failed to create docker group"
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
        [ -z "${val}" ] && continue
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
    local total=0 row inputdir searchpraefix img2pdf_flag count profiles_json

    profiles_json=$(synocr_sqlite -json "SELECT INPUTDIR, SearchPraefix, img2pdf FROM config WHERE active='1'" 2>/dev/null) || {
        printf '%s' 0
        return 0
    }
    while IFS= read -r row; do
        inputdir=$(synocr_jq_row_field "${row}" INPUTDIR)
        searchpraefix=$(synocr_jq_row_field "${row}" SearchPraefix)
        img2pdf_flag=$(synocr_jq_row_field "${row}" img2pdf)
        count=$(synocr_count_input_files_for_profile "${inputdir}" "${searchpraefix}" "${img2pdf_flag}")
        total=$((total + count))
    done < <(synocr_jq_rows "${profiles_json}")

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
    synocr_status_complete_file_progress
    synocr_status_clear
}

# Start or extend a GUI progress session (handles overlapping synOCR-start.sh runs).
synocr_status_begin_run() {
    local count_at_start="$1"

    [ "${count_at_start:-0}" -gt 0 ] 2>/dev/null || return 0

    # Only extend while a worker holds the lock (true overlap). peak>0 alone matched stale done snapshots.
    if synocr_is_process_running; then
        synocr_status_write state running
        synocr_status_write_monotonic_int files_baseline "${count_at_start}"
        synocr_status_write_monotonic_int files_peak "${count_at_start}"
        synocr_status_write_monotonic_int files_total "${count_at_start}"
        return 0
    fi

    synocr_status_clear
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

# Ensure per-file progress shows all steps done (step_index may lag behind step_total in status file).
synocr_status_complete_file_progress() {
    local status_file step_total cur_index
    status_file="$(synocr_status_file_path)"
    [ -s "${status_file}" ] || return 0
    step_total=$(jq -r '.step_total // 0' "${status_file}" 2>/dev/null)
    cur_index=$(jq -r '.step_index // 0' "${status_file}" 2>/dev/null)
    [ "${step_total:-0}" -gt 0 ] || return 0
    [ "${cur_index:-0}" -ge "${step_total}" ] && return 0
    synocr_status_write \
        state running \
        step_id cleanup \
        step_index "${step_total}"
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

# Same condition as update_dockerimage() in synOCR.sh (latest tag + setting + not checked today).
synocr_needs_dockerimage_update() {
    local check_date
    check_date=$(date +%Y-%m-%d)
    if echo "${dockercontainer:-}" | grep -qE "latest$" \
        && [ "${dockerimageupdate:-0}" = 1 ] \
        && [[ ! $(synocr_sqlite "SELECT date_checked FROM dockerupdate WHERE image='${dockercontainer}' " 2>/dev/null) = "${check_date}" ]]; then
        return 0
    fi
    return 1
}

# Sets global python_path (same search as prepare_python in synOCR.sh).
synocr_resolve_python_path() {
    python_path=""
    if [ "${machinetyp:-}" = aarch64 ]; then
        local python_versions py_interpreter py_version latest_py_version
        IFS=$'\n' read -d '' -ra python_versions <<< "$(find /bin /usr/bin /usr/local/bin -maxdepth 1 -name 'python3.*' 2>/dev/null)" ; IFS="${IFSsaved:-$' \t\n'}"
        latest_py_version="3.8"
        for py_interpreter in "${python_versions[@]}"; do
            py_version=$("${py_interpreter}" -c "import sys; print('.'.join(map(str, sys.version_info[:2])))" 2>/dev/null) || continue
            if [[ "${py_version}" > "${latest_py_version}" ]]; then
                latest_py_version="${py_version}"
                python_path="${py_interpreter}"
            fi
        done
        [ "${latest_py_version}" = "3.8" ] && python_path=""
    else
        python_path="$(which python3 2>/dev/null)"
    fi
}

# True when prepare_python would create/repair venv or install modules (GUI preflight step).
synocr_needs_python_env_prepare() {
    local env_version py_version module moduleName moduleList py_bin

    synocr_resolve_python_path
    [ -z "${python_path:-}" ] && return 0

    if [ ! -d "${python3_env:-}" ]; then
        return 0
    fi

    py_bin="${python3_env}/bin/python3"
    if [ ! -x "${py_bin}" ]; then
        return 0
    fi

    env_version=$("${py_bin}" -c "import sys; print('.'.join(map(str, sys.version_info[:2])))" 2>/dev/null)
    py_version=$("${python_path}" -c "import sys; print('.'.join(map(str, sys.version_info[:2])))" 2>/dev/null)
    if [[ "${env_version}" != "${py_version}" ]]; then
        return 0
    fi

    if [ "$(head -n1 "${python3_env}/synOCR_python_env_version" 2>/dev/null)" != "${local_version:-}" ]; then
        return 0
    fi

    moduleList=$("${py_bin}" -m pip list 2>/dev/null)
    for module in "${synOCR_python_module_list[@]}"; do
        moduleName=$(echo "${module}" | awk -F'=' '{print $1}')
        if ! grep -qi "${moduleName}" <<<"${moduleList}"; then
            return 0
        fi
    done

    return 1
}

# Build step list for current profile (bash 4+ arrays). Sets synocr_step_ids and synocr_step_ids_json.
synocr_build_step_list() {
    synocr_step_ids=()
    synocr_step_ids+=(prepare)

    if synocr_needs_dockerimage_update; then
        synocr_step_ids+=(docker_update)
    fi

    if synocr_needs_python_env_prepare; then
        synocr_step_ids+=(python_env)
    fi

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
    if [ "${idx}" -eq 0 ]; then
        return 0
    fi

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

# Replace DeepL-safe <x id="…"/> placeholders (same variants as fillXTags in synocr-progress.js).
synocr_lang_fill_x() {
    local tpl="$1" id val sed_args=()
    shift
    while [ $# -ge 2 ]; do
        id="$1"
        val="$2"
        shift 2
        sed_args+=(-e "s|<x id=\"${id}\"/>|${val}|g" -e "s|<x id='${id}'/>|${val}|g")
    done
    if [ ${#sed_args[@]} -gt 0 ]; then
        tpl=$(printf '%s' "$tpl" | sed "${sed_args[@]}")
    fi
    printf '%s' "$tpl"
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
        docker_update) key=lang_main_progress_step_docker_update ;;
        python_env) key=lang_main_progress_step_python_env ;;
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

        # Ignore stale completed snapshots when idle (should be cleared; guard for race windows).
        if [ "${synocr_pg_state}" != "done" ] || [ "${synocr_pg_running}" -eq 1 ]; then
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

# Escape text for safe HTML output.
synocr_html_escape() {
    local s="${1-}"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    s="${s//\"/&quot;}"
    printf '%s' "${s}"
}

# Normalize a directory path for prefix matching (trailing slash).
synocr_path_norm_dir() {
    local p="${1-}"
    [ -z "${p}" ] && return 0
    p="${p%/}/"
    printf '%s' "${p}"
}

# True when path is an absolute NAS volume path (/volumeN/...).
synocr_path_is_nas_volume() {
    local p="${1-}"
    [[ "${p}" =~ ^/volume[0-9]+/ ]]
}

# Shorten full path for display by stripping a profile directory prefix when it matches.
# Only the prefix is directory-normalized (trailing /); the file path stays as-is
# so display matches synocr-progress.js pathDisplayShort (no trailing slash on filenames).
synocr_path_display_short() {
    local full="${1-}"
    local prefix="${2-}"
    local norm_prefix rest

    [ -z "${full}" ] && return 0
    [ -z "${prefix}" ] && { printf '%s' "${full}"; return 0; }

    norm_prefix=$(synocr_path_norm_dir "${prefix}")

    case "${full}/" in
        "${norm_prefix}"*)
            rest="${full#"${norm_prefix%/}"}"
            rest="${rest#/}"
            if [ -n "${rest}" ]; then
                printf '%s' "${rest}"
            else
                printf '%s' "${full##*/}"
            fi
            ;;
        *)
            printf '%s' "${full}"
            ;;
    esac
}

# Return max retained processing-history rows (default 100).
synocr_processing_history_max() {
    local max
    max=$(synocr_sqlite "SELECT value_1 FROM system WHERE key='processing_history_max' LIMIT 1;" 2>/dev/null)
    max=${max:-100}
    if ! printf '%s' "${max}" | grep -Eq '^[0-9]+$' >/dev/null 2>&1; then
        max=100
    fi
    printf '%s' "${max}"
}

# Fail orphan jobs left 'running' by a crashed/killed synOCR (no time threshold).
synocr_processing_job_fail_orphans() {
    if ! synocr_sqlite "SELECT 1 FROM processing_jobs LIMIT 1;" >/dev/null 2>&1; then
        return 0
    fi
    synocr_sqlite "UPDATE processing_jobs
        SET status='failed', finished_at=datetime('now','localtime')
        WHERE status='running';" >/dev/null 2>&1
}

# Fail the current open job (EXIT trap / abrupt abort mid-file).
synocr_processing_job_abort_open() {
    [ -n "${SYNOCR_PROCESSING_JOB_ID:-}" ] && synocr_processing_job_fail
}

# Remove processing-history rows (scope: success | all).
synocr_processing_jobs_clear() {
    local scope="${1:-success}"
    local removed

    if ! synocr_sqlite "SELECT 1 FROM processing_jobs LIMIT 1;" >/dev/null 2>&1; then
        printf '0'
        return 0
    fi

    case "${scope}" in
        success)
            removed=$(synocr_sqlite "SELECT COUNT(*) FROM processing_jobs WHERE status='success';" 2>/dev/null)
            synocr_sqlite "DELETE FROM processing_jobs WHERE status='success';" >/dev/null 2>&1
            ;;
        all)
            removed=$(synocr_sqlite "SELECT COUNT(*) FROM processing_jobs;" 2>/dev/null)
            synocr_sqlite "DELETE FROM processing_jobs;" >/dev/null 2>&1
            ;;
        *)
            printf '0'
            return 1
            ;;
    esac
    removed=${removed:-0}
    if ! printf '%s' "${removed}" | grep -Eq '^[0-9]+$' >/dev/null 2>&1; then
        removed=0
    fi
    printf '%s' "${removed}"
}

# JSON API for index.cgi?page=main-clear-history&scope=success|all
# Scope must be passed as $1 (do not read a global "scope" — local would shadow it).
synocr_render_main_clear_history_json() {
    local scope="${1:-success}"
    local removed

    case "${scope}" in
        success|all) ;;
        *)
            jq -n '{ok:false,error:"invalid_scope"}'
            return 1
            ;;
    esac

    removed=$(synocr_processing_jobs_clear "${scope}")
    jq -n --arg scope "${scope}" --argjson removed "${removed}" '{ok:true,scope:$scope,removed:$removed}'
}

# Delete processing jobs beyond the configured retention limit.
synocr_processing_job_purge() {
    local max
    if ! synocr_sqlite "SELECT 1 FROM processing_jobs LIMIT 1;" >/dev/null 2>&1; then
        return 0
    fi
    max=$(synocr_processing_history_max)
    synocr_sqlite "DELETE FROM processing_jobs
        WHERE job_ID NOT IN (
            SELECT job_ID FROM processing_jobs ORDER BY started_at DESC LIMIT ${max}
        );" >/dev/null 2>&1
}

# Start a processing-history job (independent of loglevel).
synocr_processing_job_start() {
    local source_filename="$1"
    local source_sql profile_sql new_id sqlite3log sqlite3rc

    SYNOCR_PROCESSING_JOB_ID=""

    if ! synocr_sqlite "SELECT 1 FROM processing_jobs LIMIT 1;" >/dev/null 2>&1; then
        return 0
    fi

    synocr_processing_job_fail_orphans

    source_sql=$(sql_escape "${source_filename}")

    sqlite3log=$(synocr_sqlite "INSERT INTO processing_jobs (profile_ID, source_filename, targets_json, status)
        VALUES ('${profile_ID:-0}', '${source_sql}', '[]', 'running');
        SELECT last_insert_rowid();" 2>&1)
    sqlite3rc=$?

    if [ "${sqlite3rc}" -ne 0 ]; then
        return 1
    fi

    new_id=$(printf '%s\n' "${sqlite3log}" | tail -n 1)
    if printf '%s' "${new_id}" | grep -Eq '^[0-9]+$' >/dev/null 2>&1; then
        SYNOCR_PROCESSING_JOB_ID="${new_id}"
    fi
}

# Append a target path to the current processing-history job.
synocr_processing_job_add_target() {
    local target_path="$1"
    local job_id="${SYNOCR_PROCESSING_JOB_ID:-}"
    local current_json new_json sqlite3log sqlite3rc

    [ -z "${job_id}" ] && return 0
    if ! synocr_sqlite "SELECT 1 FROM processing_jobs LIMIT 1;" >/dev/null 2>&1; then
        return 0
    fi

    current_json=$(synocr_sqlite "SELECT targets_json FROM processing_jobs WHERE job_ID='${job_id}' LIMIT 1;" 2>/dev/null)
    current_json=${current_json:-[]}
    new_json=$(printf '%s' "${current_json}" | jq -c --arg p "${target_path}" '. + [$p]' 2>/dev/null) || new_json="[\"${target_path}\"]"
    new_json=$(sql_escape "${new_json}")

    sqlite3log=$(synocr_sqlite "UPDATE processing_jobs
        SET targets_json='${new_json}'
        WHERE job_ID='${job_id}';" 2>&1)
    sqlite3rc=$?

    if [ "${sqlite3rc}" -ne 0 ]; then
        return 1
    fi
}

# Close the current processing-history job with a terminal status.
_synocr_processing_job_close() {
    local status="$1"
    local job_id="${SYNOCR_PROCESSING_JOB_ID:-}"

    [ -z "${job_id}" ] && return 0
    if ! synocr_sqlite "SELECT 1 FROM processing_jobs LIMIT 1;" >/dev/null 2>&1; then
        SYNOCR_PROCESSING_JOB_ID=""
        return 0
    fi

    synocr_sqlite "UPDATE processing_jobs
        SET status='${status}', finished_at=datetime('now','localtime')
        WHERE job_ID='${job_id}';" >/dev/null 2>&1

    synocr_processing_job_purge
    SYNOCR_PROCESSING_JOB_ID=""
}

# Mark job successful (valid target produced).
synocr_processing_job_succeed() {
    _synocr_processing_job_close "success"
}

# Mark job failed (e.g. source moved to ERRORFILES).
synocr_processing_job_fail() {
    _synocr_processing_job_close "failed"
}

# Finalize the current processing-history job (legacy: success only).
synocr_processing_job_finalize() {
    local process_error="${1:-1}"

    [ "${process_error}" -eq 0 ] && synocr_processing_job_succeed
}

# JSON array of recent processing jobs for API / GUI.
synocr_processing_jobs_json() {
    local max jobs_json
    if ! synocr_sqlite "SELECT 1 FROM processing_jobs LIMIT 1;" >/dev/null 2>&1; then
        printf '[]'
        return 0
    fi
    max=$(synocr_processing_history_max)
    jobs_json=$(synocr_sqlite -json "SELECT
            pj.job_ID AS id,
            COALESCE(c.profile, '') AS profile,
            COALESCE(c.OUTPUTDIR, '') AS output_dir,
            pj.source_filename AS source,
            pj.targets_json AS targets,
            pj.status AS status,
            pj.started_at AS started_at
        FROM processing_jobs pj
        LEFT JOIN config c ON c.profile_ID = pj.profile_ID
        ORDER BY pj.started_at DESC
        LIMIT ${max};" 2>/dev/null)
    if [ -z "${jobs_json}" ] || [ "${jobs_json}" = "[]" ]; then
        printf '[]'
        return 0
    fi
    printf '%s' "${jobs_json}" | jq -c '[.[] | {
        id: .id,
        profile: .profile,
        output_dir: .output_dir,
        source: .source,
        targets: (try (.targets | fromjson) catch []),
        status: .status,
        started_at: .started_at
    }]' 2>/dev/null || printf '[]'
}

# Render processing-history list HTML (tbody rows).
synocr_render_processing_history_rows() {
    local jobs_json row id profile output_dir source status started_at targets_json
        local status_class status_badge status_label status_h source_h profile_h started_h target target_h target_d targets_html

    jobs_json=$(synocr_processing_jobs_json)
    if [ "${jobs_json}" = "[]" ] || [ -z "${jobs_json}" ]; then
        echo '<tr><td colspan="5" class="text-muted small">'$(synocr_html_escape "${lang_main_history_empty}")'</td></tr>'
        return 0
    fi

    while IFS= read -r row; do
        [ -z "${row}" ] && continue
        id=$(printf '%s' "${row}" | jq -r '.id // empty')
        profile=$(printf '%s' "${row}" | jq -r '.profile // ""')
        output_dir=$(printf '%s' "${row}" | jq -r '.output_dir // ""')
        source=$(printf '%s' "${row}" | jq -r '.source // ""')
        status=$(printf '%s' "${row}" | jq -r '.status // ""')
        started_at=$(printf '%s' "${row}" | jq -r '.started_at // ""')
        targets_json=$(printf '%s' "${row}" | jq -c '.targets // []')

        case "${status}" in
            success)
                status_class="synocr-job-row--success"
                status_badge="success"
                status_label="${lang_main_history_status_success}"
                ;;
            failed)
                status_class="synocr-job-row--failed"
                status_badge="failed"
                status_label="${lang_main_history_status_failed}"
                ;;
            *)
                status_class="synocr-job-row--running"
                status_badge="running"
                status_label="${lang_main_history_status_running}"
                ;;
        esac

        source_h=$(synocr_html_escape "${source}")
        profile_h=$(synocr_html_escape "${profile}")
        started_h=$(synocr_html_escape "${started_at}")
        status_h=$(synocr_html_escape "${status_label}")

        targets_html="-"
        if [ "$(printf '%s' "${targets_json}" | jq 'length' 2>/dev/null)" -gt 0 ] 2>/dev/null; then
            targets_html=""
            while IFS= read -r target; do
                [ -z "${target}" ] && continue
                target_h=$(synocr_html_escape "${target}")
                target_d=$(synocr_html_escape "$(synocr_path_display_short "${target}" "${output_dir}")")
                if synocr_path_is_nas_volume "${target}"; then
                    target_tip_h="${target_h}"
                    if [ -n "${lang_main_history_target_open_hint:-}" ]; then
                        target_tip_h="${target_h}"$'\n'"$(synocr_html_escape "${lang_main_history_target_open_hint}")"
                    fi
                    targets_html="${targets_html}<span class=\"synocr-job-target synocr-job-target--link synocr-has-tip\" role=\"link\" tabindex=\"0\" data-nas-path=\"${target_h}\" data-tip=\"${target_tip_h}\">${target_d}</span>"
                else
                    targets_html="${targets_html}<div class=\"synocr-job-target synocr-has-tip\" data-tip=\"${target_h}\">${target_d}</div>"
                fi
            done < <(printf '%s' "${targets_json}" | jq -r '.[]' 2>/dev/null)
        fi

        echo '<tr class="synocr-job-row '"${status_class}"'" data-job-id="'"${id}"'">'
        echo '  <td class="synocr-job-time small text-nowrap">'"${started_h}"'</td>'
        echo '  <td class="synocr-job-profile small">'"${profile_h}"'</td>'
        echo '  <td class="synocr-job-source small" title="'"${source_h}"'">'"${source_h}"'</td>'
        echo '  <td class="synocr-job-targets small">'"${targets_html}"'</td>'
        echo '  <td class="synocr-job-status small text-nowrap text-end"><span class="synocr-job-status-badge synocr-job-status-badge--'"${status_badge}"'">'"${status_h}"'</span></td>'
        echo '</tr>'
    done < <(printf '%s' "${jobs_json}" | jq -c '.[]' 2>/dev/null)
}

# JSON API for index.cgi?page=main-status (jQuery polling).
synocr_render_main_status_json() {
    local _global_ocr _global_pages _jobs_json

    synocr_progress_compute

    _global_ocr=$(synocr_sqlite "SELECT value_1 FROM system WHERE key='global_ocrcount'" 2>/dev/null)
    _global_pages=$(synocr_sqlite "SELECT value_1 FROM system WHERE key='global_pagecount'" 2>/dev/null)
    _global_ocr=${_global_ocr:-0}
    _global_pages=${_global_pages:-0}
    _jobs_json=$(synocr_processing_jobs_json)

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
        --argjson global_ocrcount "${_global_ocr}" \
        --argjson global_pagecount "${_global_pages}" \
        --argjson jobs "${_jobs_json:-[]}" \
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
            step_total: $step_total,
            global_ocrcount: $global_ocrcount,
            global_pagecount: $global_pagecount,
            jobs: $jobs
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


# ---------------------------------------------------------------------------
# synOCR logging API (loglevel: 0=off, 1=normal, 2=debug)
# ---------------------------------------------------------------------------
_LOG_WIDTH=80
_LOG_LABEL_WIDTH=26
_LOG_INDENT="    "
_LOG_INDENT_DETAIL="        "
_LOG_INDENT_DEEP="            "

_synocr_log_ge1() {
    (( ${loglevel:-0} >= 1 ))
}

_synocr_log_ge2() {
    (( ${loglevel:-0} >= 2 ))
}

# Logging conventions:
# - synocr_fail_fatal: abort entire script (log + exit)
# - log_error_at: per-file or recoverable error (log + return 1)
# - log_command_error: external command failed (rc + output)
# - log_warn_at: fallback, non-fatal issue
# - Config/YAML invalid values: include config line + allowed values

_log_call_site_prefix() {
    local depth="${1:-2}"
    local src_idx="${depth}"
    local func_idx="${depth}"
    local line_idx=$(( depth - 1 ))
    local file func line

    file="${BASH_SOURCE[${src_idx}]:-unknown}"
    file="${file##*/}"
    func="${FUNCNAME[${func_idx}]:-main}"
    line="${BASH_LINENO[${line_idx}]:-0}"
    printf '[%s:%s:%s]' "${file}" "${func}" "${line}"
}

_log_error_message() {
    local message="$1"
    local prefix

    prefix="$(_log_call_site_prefix 3)"
    if [ -n "${_SYNOCR_CTX_FILE:-}" ]; then
        log_error "${prefix} [file: ${_SYNOCR_CTX_FILE}] ${message}"
    else
        log_error "${prefix} ${message}"
    fi
}

log_error_at() {
    local message="$1"
    _log_error_message "${message}"
}

log_warn_at() {
    local message="$1"
    local prefix

    _synocr_log_ge1 || return 0
    prefix="$(_log_call_site_prefix 2)"
    if [ -n "${_SYNOCR_CTX_FILE:-}" ]; then
        printf "WARN  %s [file: %s] %s\n" "${prefix}" "${_SYNOCR_CTX_FILE}" "${message}" >&2
    else
        printf "WARN  %s %s\n" "${prefix}" "${message}" >&2
    fi
}

log_command_error() {
    local description="$1"
    local rc="$2"
    local output="${3:-}"

    _log_error_message "${description} (exit ${rc})"
    if [ -n "${output}" ]; then
        printf '%s\n' "${output}" | log_block "${_LOG_INDENT_DETAIL}  "
    fi
}

synocr_fail_fatal() {
    local message="$1"
    local exit_code="${2:-1}"

    _SYNOCR_ABORT_LOGGED=1
    export _SYNOCR_ABORT_LOGGED
    _log_error_message "${message}"
    exit "${exit_code}"
}

synocr_is_integer() {
    [[ "${1}" =~ ^-?[0-9]+$ ]]
}

_log_strip_leading() {
    local message="$1"
    message="${message#"${message%%[![:space:]]*}"}"
    while [[ "${message}" == ➜* ]]; do
        message="${message#➜}"
        message="${message#"${message%%[![:space:]]*}"}"
    done
    printf '%s' "${message}"
}

_synocr_sec_to_time() {
    local seconds=$1
    local sign=""
    if [[ ${seconds:0:1} == "-" ]]; then
        seconds=${seconds:1}
        sign="-"
    fi
    local hours=$(( seconds / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    seconds=$(( seconds % 60 ))
    printf "%s%02d:%02d:%02d" "${sign}" "${hours}" "${minutes}" "${seconds}"
}

log_blank() {
    _synocr_log_ge1 || return 0
    echo
}

log_section() {
    local title="$1"
    _synocr_log_ge1 || return 0
    printf "\n"
    printf '%*s\n' "${_LOG_WIDTH}" '' | tr ' ' '='
    printf ' %s\n' "${title}"
    printf '%*s\n' "${_LOG_WIDTH}" '' | tr ' ' '='
    printf "\n"
}

log_subsection() {
    local title="$1"
    local width
    local dashes

    _synocr_log_ge1 || return 0

    title="${title#"${title%%[![:space:]]*}"}"
    title="${title%"${title##*[![:space:]]}"}"
    title="${title%:}"
    title="${title%"${title##*[![:space:]]}"}"

    width=$(( ${#title} + 4 ))
    if [ "${width}" -gt 60 ]; then
        width=60
    elif [ "${width}" -lt 20 ]; then
        width=20
    fi

    dashes=$(printf '%*s' "${width}" '' | tr ' ' '-')

    printf "\n"
    printf "  %s\n" "${dashes}"
    printf "  %s\n" "${title}"
    printf "  %s\n\n" "${dashes}"
}

log_kv() {
    local label="$1"
    local value="$2"
    _synocr_log_ge1 || return 0
    printf "%-${_LOG_LABEL_WIDTH}s %s\n" "${label}:" "${value}"
}

log_continue() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "                          %s\n" "${message}"
}

log_item() {
    local message="$(_log_strip_leading "$1")"
    _synocr_log_ge1 || return 0
    printf "%s➜ %s\n" "${_LOG_INDENT}" "${message}"
}

log_item_n() {
    local message="$(_log_strip_leading "$1")"
    _synocr_log_ge1 || return 0
    printf "%s➜ %s" "${_LOG_INDENT}" "${message}"
}

log_detail() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s%s\n" "${_LOG_INDENT_DETAIL}" "${message}"
}

log_detail_deep() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s%s\n" "${_LOG_INDENT_DEEP}" "${message}"
}

log_item_deep() {
    local message="$(_log_strip_leading "$1")"
    _synocr_log_ge1 || return 0
    printf "%s➜ %s\n" "${_LOG_INDENT_DEEP}" "${message}"
}

log_item_deep_n() {
    local message="$(_log_strip_leading "$1")"
    _synocr_log_ge1 || return 0
    printf "%s➜ %s" "${_LOG_INDENT_DEEP}" "${message}"
}

log_note() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s%s\n" "${_LOG_INDENT}" "${message}"
}

log_note_n() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s%s" "${_LOG_INDENT}" "${message}"
}

log_note_deep() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s%s\n" "${_LOG_INDENT_DEEP}" "${message}"
}

log_debug() {
    local message="$1"
    _synocr_log_ge2 || return 0
    printf "%s%s\n" "${_LOG_INDENT_DETAIL}" "${message}"
}

log_warn() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "WARN  %s\n" "${message}" >&2
}

log_error() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "ERROR %s\n" "${message}" >&2
}

log_runtime() {
    local seconds="$1"
    _synocr_log_ge2 || return 0
    printf "\n%s[runtime up to now:    %s]\n\n" "${_LOG_INDENT}" "$(_synocr_sec_to_time "${seconds}")"
}

log_file() {
    local name="$1"
    local index="$2"
    local total="$3"
    _SYNOCR_CTX_FILE="${name}"
    export _SYNOCR_CTX_FILE
    _synocr_log_ge1 || return 0
    if [ -n "${index}" ] && [ -n "${total}" ]; then
        log_section "CURRENT FILE: ${name} (${index}/${total})"
    else
        log_section "CURRENT FILE: ${name}"
    fi
}

log_block() {
    local line
    local prefix="${1:-${_LOG_INDENT_DETAIL}  }"
    _synocr_log_ge1 || return 0
    while IFS= read -r line; do
        if [ -n "${line}" ]; then
            printf "%s%s\n" "${prefix}" "${line}"
        else
            echo
        fi
    done
}

log_section_end() {
    local title="$1"
    _synocr_log_ge1 || return 0
    log_section "${title}"
}


# YAML tag rule hierarchy (used in tag_search only)
log_rule() {
    local name="$1"
    _synocr_log_ge1 || return 0
    printf "%ssearch by tag rule: \"%s\" ➜  \n" "${_LOG_INDENT}" "${name}"
}

log_rule_field() {
    local label="$1"
    local value="$2"
    _synocr_log_ge1 || return 0
    printf "%s  ➜ %-18s %s\n" "${_LOG_INDENT}" "${label}:" "${value}"
}

log_rule_field_l2() {
    local label="$1"
    local value="$2"
    _synocr_log_ge2 || return 0
    printf "%s  ➜ %-18s %s\n" "${_LOG_INDENT}" "${label}:" "${value}"
}

log_rule_note() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s          %s\n" "${_LOG_INDENT}" "${message}"
}

log_rule_sub() {
    _synocr_log_ge2 || return 0
    printf "%s      [Subrule]:\n" "${_LOG_INDENT}"
}

log_rule_sub_note() {
    local message="$1"
    _synocr_log_ge2 || return 0
    printf "%s          %s\n" "${_LOG_INDENT}" "${message}"
}

log_rule_sub_search() {
    local searchstring="$1"
    _synocr_log_ge2 || return 0
    printf "%s      >>> search for:      %s\n" "${_LOG_INDENT}" "${searchstring}"
}

log_rule_sub_field() {
    local label="$1"
    local value="$2"
    _synocr_log_ge2 || return 0
    printf "%s          %-18s %s\n" "${_LOG_INDENT}" "${label}:" "${value}"
}

log_rule_sub_match() {
    local message="$1"
    _synocr_log_ge2 || return 0
    printf "%s          ➜ %s\n" "${_LOG_INDENT}" "${message}"
}

log_rule_result() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s          %s\n" "${_LOG_INDENT}" "${message}"
}

log_rule_action() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s              ➜ %s\n" "${_LOG_INDENT}" "${message}"
}

log_rule_action_n() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s              ➜ %s" "${_LOG_INDENT}" "${message}"
}

# Pass 2 rule engine logging (filter + action phases in tag_search)
log_rule_pass2() {
    local name="$1"
    local priority="$2"
    _synocr_log_ge1 || return 0
    printf "%spass 2 rule \"%s\" (priority %s) ➜\n" "${_LOG_INDENT}" "${name}" "${priority}"
}

log_rule_pass2_verdict() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s  ➜ %s\n" "${_LOG_INDENT}" "${message}"
}

log_rule_pass2_detail() {
    local message="$1"
    _synocr_log_ge2 || return 0
    printf "%s          ➜ %s\n" "${_LOG_INDENT}" "${message}"
}

# Pass 2 action lines — same depth as Pass 1 subrule match (one level under verdict)
log_rule_pass2_action() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s          ➜ %s\n" "${_LOG_INDENT}" "${message}"
}

log_rule_pass2_action_n() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s          ➜ %s" "${_LOG_INDENT}" "${message}"
}

log_rule_pass2_summary() {
    local message="$1"
    _synocr_log_ge1 || return 0
    printf "%s%s\n" "${_LOG_INDENT}" "${message}"
}
