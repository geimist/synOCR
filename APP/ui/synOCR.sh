#!/bin/bash
# shellcheck disable=SC1090,SC1091,SC2001,SC2009,SC2181

#################################################################################
#   description:    main script for running synOCR                              #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/synOCR.sh          #
#   © 2026 by geimist                                                           #
#################################################################################


    # read out and change into the working directory:
    # ---------------------------------------------------------------------
    APPDIR=$(cd "$(dirname "$0")" || exit 1;pwd)
    export SYNOCR_APP_HOME="${APPDIR}"
    cd "${APPDIR}" || exit 1

    source ./includes/functions.sh

    cleanup_lockfile() {
        if [ -d "${LOCKFILE}" ]; then
            rm -rf "${LOCKFILE}"
            echo "Lock file removed"
        fi
    }

    synocr_exit_cleanup() {
        if [ -n "${work_tmp_main:-}" ] && [ -d "${work_tmp_main}" ]; then
            rm -rf "${work_tmp_main}"
        fi
        cleanup_lockfile
    }

    synocr_on_exit() {
        local ec=$?
        if (( ec != 0 )) && [[ -z "${_SYNOCR_ABORT_LOGGED:-}" ]]; then
            log_error_at "synOCR aborted with exit code ${ec}"
        fi
        synocr_processing_job_abort_open
        synocr_exit_cleanup
    }

    trap synocr_on_exit EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM


    echo "    -----------------------------------"
    echo "    |    ==> installation info <==    |"
    echo "    -----------------------------------"
    echo -e


# ---------------------------------------------------------------------------------
#           BASIC CONFIGURATIONS / INDIVIDUAL ADAPTATIONS / Default values        |
# ---------------------------------------------------------------------------------
    IFSsaved=$IFS
    workprofile="$1"            # the profile submitted by the start script
    current_logfile="$2"        # current logfile / is submitted by start script
    shopt -s globstar           # enable 'globstar' shell option (to use ** for directionary wildcard)
    shopt -s expand_aliases     # store & call aliases in an array
    date_start_all=$(date +%s)
    # hard coded setting to enable / disable metadata integration
    # /usr/syno/bin/synosetkeyvalue "/usr/syno/synoman/webman/3rdparty/synOCR/synOCR.sh" enablePyMetaData 0
    enablePyMetaData=1

    python3_env="${APPDIR}/python3_env"
    LOCKFILE="${APPDIR}/etc/synOCR.lock"
    python_check=ok             # will be set to failed if the test fails
    # synOCR_python_module_list is defined in includes/functions.sh (pinned, Py>=3.8)


# Lockfile check & creation
# ---------------------------------------------------------------------
    if ! mkdir "${LOCKFILE}" 2>/dev/null; then
        if [ -d "${LOCKFILE}" ]; then
            lock_pid=$(cat "${LOCKFILE}/pid" 2>/dev/null)
            if [ -n "${lock_pid}" ] && kill -0 "${lock_pid}" 2>/dev/null; then
                synocr_fail_fatal "synOCR is already running (PID: ${lock_pid})"
            else
                echo "Removing stale lock file"
                rm -rf "${LOCKFILE}"
                mkdir "${LOCKFILE}" || synocr_fail_fatal "Failed to recreate lock file"
            fi
        else
            synocr_fail_fatal "Failed to create lock file"
        fi
    fi

    echo $$ > "${LOCKFILE}/pid"
    echo "Lock file created for PID $$"

    if [ -n "${SYNOCR_PROGRESS_TOTAL:-}" ]; then
        synocr_status_begin_run "${SYNOCR_PROGRESS_TOTAL}"
    fi


# to which user/group the DSM notification should be sent:
# ---------------------------------------------------------------------
    synOCR_user=$(whoami); log_kv "synOCR-user" "${synOCR_user}"
    if grep administrators </etc/group | grep -q "${synOCR_user}" || [ "${synOCR_user}" = root ] ; then
        isAdmin=yes
    else
        isAdmin=no
    fi
    log_kv "synOCR-user is admin" "${isAdmin}"


# check DSM version:
# -------------------------------------
    if [ "$(synogetkeyvalue /etc.defaults/VERSION majorversion)" -ge 7 ]; then
        dsm_version=7
    else
        dsm_version=6
    fi


# load configuration:
# ---------------------------------------------------------------------
    config_json=$(synocr_config_json_by_id "${workprofile}")
    synocr_jq_load_row "${config_json}" 0

    [ -z "${MessageTo}" ] || [ "${MessageTo}" == "-" ] && MessageTo="@administrators" # group administrators (default)
    ignoredDate=$(echo "${ignoredDate}" | sed -e 's/2021-02-29//g;s/2020-11-31//g;s/^ *//g') # remove (invalid) example dates
    pagecount_profile="${pagecount}"
    ocrcount_profile="${ocrcount}"
    [ -z "${backup_clean_orphaned}" ] && backup_clean_orphaned=false
    adjustColorBWabsoluteThreshold=96 # optional GUI candidate: keeps very dark filled areas black in BW mode (0 disables)

# read global values:
    dockerimageupdate=$(synocr_sqlite "SELECT value_1 FROM system WHERE key='dockerimageupdate' ")
    count_start_date=$(synocr_sqlite "SELECT value_1 FROM system WHERE key='count_start_date'")
    global_pagecount=$(synocr_sqlite "SELECT value_1 FROM system WHERE key='global_pagecount'")
    global_ocrcount=$(synocr_sqlite "SELECT value_1 FROM system WHERE key='global_ocrcount'")
    online_version=$(synocr_sqlite "SELECT value_1 FROM system WHERE key='online_version'")
    # Delay in seconds
    delay=$(synocr_sqlite "SELECT value_1 FROM system WHERE key='inotify_delay'" )

# Preset variables for correct calculation in the loop:
    global_pagecount_new="${global_pagecount}"
    global_ocrcount_new="${global_ocrcount}"
    pagecount_profile_new="${pagecount_profile}"
    ocrcount_profile_new="${ocrcount_profile}"


# System Information and log settings:
# ---------------------------------------------------------------------
    source "./lang/lang_${notify_lang}.txt"

    local_version=$(grep "^version" /var/packages/synOCR/INFO | cut -d '"' -f2)
    highest_version=$(printf "%s\n" "${online_version}" "${local_version}" | sort -V | tail -n1)
    log_kv "synOCR-version" "${local_version}"
    if [[ "${local_version}" != "${highest_version}" ]] ; then
        log_kv "UPDATE AVAILABLE" "online version: ${online_version}"
        log_continue "please visit https://geimist.eu/synOCR/ or check your pakage center"
    fi

    machinetyp=$(uname --machine); log_kv "Architecture" "${machinetyp}"
    dsmbuild=$(uname -v | awk '{print $1}' | sed "s/#//g"); log_kv "DSM-build" "${dsmbuild}"
    device=$(uname -a | awk -F_ '{print $NF}' | sed "s/+/plus/g")

# docker shm-size calculation with Synology-optimized values:
    calculate_shm() {
      local mem=$1
      case $(uname -m) in
#        *arm*)
#          [ $mem -le 2048 ] && echo 128m || echo 256m
#          ;;
        *aarch64*)
          echo $(( mem < 4096 ? 256 : 512 ))m
          ;;
        *)
          echo $(( mem < 8192 ? 256 : 1024 ))m
          ;;
      esac
    }
    total_mem=$(free -m | awk '/^Mem:/ {print $2}')
    shm_size="$(calculate_shm $total_mem)"

    log_kv "Device" "${device}"
    log_kv "current Profil" "${profile}"
    if ps aux | grep -qE "[i]notifywait.*--fromfile.*inotify.list"; then
        log_kv "monitor is running?" "yes"
    else
        log_kv "monitor is running?" "no"
    fi
    log_kv "DB-version" "$(synocr_sqlite "SELECT value_1 FROM system WHERE key='db_version'")"
    log_kv "system-ID" "$(synocr_sqlite "SELECT value_1 FROM system WHERE key='UUID'")"
    log_kv "used image (created)" "${dockercontainer} ($(docker inspect -f '{{ .Created }}' "${dockercontainer}" 2>/dev/null | awk -F. '{print $1}'))"
    log_kv "ContainerManager" "$(synopkg version ContainerManager)"
    log_kv "docker version" "$(docker --version)"

    [ ${delay:-0} -ne 0 ] && log_kv "OCR delay" "${delay:-0} seconds"

    documentAuthor=$(awk -F'[ ]-' '{for(i=1;i<=NF;i++){if($i)print "-"$i}}' <<<" ${ocropt}" | grep "\-\-author" | sed -e 's/--author //')
#   documentAuthor=$(grep -oP -- '--author(=\S+)?\s*\K.*?(?=\s+--|\s*$)' <<<"${ocropt}")
    log_kv "document author" "${documentAuthor}"

    documentTitle=$(awk -F'[ ]-' '{for(i=1;i<=NF;i++){if($i)print "-"$i}}' <<<" ${ocropt}" | grep "\-\-title" | sed -e 's/--title //')
    log_kv "document title" "${documentTitle}"

    log_kv "used ocr-parameter (raw)" "${ocropt}"

    # check of non-ocrmypdf parameter --keep_hash.
    if [[ "${ocropt}" == *"--keep_hash"* ]]; then
        keep_hash=true
        ocropt="${ocropt//--keep_hash/}"  # remove --keep_hash to make the parameters OCRmyPDF compatible
        log_continue "--keep_hash is set – the source file will not be modified"
    else
        keep_hash=false
    fi

    # arguments with spaces must be submit as array (https://github.com/ocrmypdf/OCRmyPDF/issues/878)
    # for loop split all parameters, which start with > -<:
    c=0
    ocropt_arr=()

    # shellcheck disable=SC2162  # Don't warn about "read without -r will mangle backslashes."
    while read value ; do
        c=$((c+1))
        # now, split parameters with additional arguments:
        if [[ $(awk -F'[ ]' '{print NF}' <<< "${value}") -gt 1 ]]; then
            value_1=$(awk -F'[ ]' '{print $1}' <<< "${value}")
            log_debug "OCR-arg ${c}: ${value_1}"
            c=$((c+1))
            value_2=${value//${value_1} /}
            log_debug "OCR-arg ${c}: ${value_2}"
            ocropt_arr+=( "${value_1}" "${value_2}" )
        else
            log_debug "OCR-arg ${c}: ${value}"
            ocropt_arr+=( "${value}" )
        fi
    done <<< "$(awk -F'[ ]-' '{for(i=1;i<=NF;i++){if($i)print "-"$i}}' <<<" ${ocropt#"${ocropt%%[^ ]*}"}")"
    unset c

    log_kv "ocropt_array" "${ocropt_arr[*]}"
    log_kv "shm-size" "${shm_size}"
    log_kv "search prefix" "${SearchPraefix}"
    log_kv "replace search prefix" "${delSearchPraefix}"
    log_kv "renaming syntax" "${NameSyntax}"
    log_kv "Symbol for tag marking" "${tagsymbol}"
    tagsymbol="${tagsymbol// /%20}"   # mask spaces
    if [[ "${img2pdf}" = "true" ]] && [[ "${keep_hash}" = "true" ]]; then
        img2pdf="false"
        log_kv "convert images to PDF" "false (disabled, because --keep_hash is defined!)"
    else
        log_kv "convert images to PDF" "${img2pdf}"
    fi

    log_kv "adjust color" ""
    log_kv "  BW threshold" "${adjustColorBWthreshold}"
    log_kv "  BW absolute threshold" "${adjustColorBWabsoluteThreshold}"
    log_kv "  DPI" "${adjustColorDPI}"
    log_kv "  contrast" "${adjustColorContrast}"
    log_kv "  sharpness" "${adjustColorSharpness}"

    log_kv "target file handling" "${moveTaggedFiles}"
    if [[ -n "${documentSplitPattern}" ]] && [[ "${keep_hash}" = "true" ]]; then
        documentSplitPattern=""
        log_kv "Document split pattern" "(disabled, because --keep_hash is defined!)"
    else
        log_kv "Document split pattern" "${documentSplitPattern}"
    fi

    if [[ "${documentSplitPattern}" = "<split each page>" ]]; then
        splitpagehandling="isFirstPage"
        log_kv "split page handling" "${splitpagehandling} (because, <split each page> is set)"
    else
        log_kv "split page handling" "${splitpagehandling}"
    fi
#    echo "delete blank pages:       ${blank_page_detection_switch}" && [[ "${blank_page_detection_switch}" = "true" ]] && [[ "${keep_hash}" = "true" ]] && blank_page_detection_switch="false" && echo " (disabled, because --keep_hash is defined!)"
    if [[ "${blank_page_detection_switch}" = "true" && "${keep_hash}" = "true" ]]; then
        blank_page_detection_switch="false"
        log_kv "delete blank pages" "false (disabled, because --keep_hash is defined!)"
    else
        log_kv "delete blank pages" "${blank_page_detection_switch}"
    fi

    if [ "${blank_page_detection_switch}" = true ]; then
        log_kv "  ignore text" "${blank_page_detection_ignoreText}"
        log_kv "  main threshold" "${blank_page_detection_mainThreshold}"
        log_kv "  width cropping" "${blank_page_detection_widthCropping}"
        log_kv "  hight cropping" "${blank_page_detection_hightCropping}"
        log_kv "  interf. max filter" "${blank_page_detection_interferenceMaxFilter}"
        log_kv "  interf. min filter" "${blank_page_detection_interferenceMinFilter}"
        log_kv "  thresh. black pxl" "${blank_page_detection_black_pixel_ratio}"
    fi
    log_kv "clean up spaces" "${clean_up_spaces}"

    synocr_status_write \
        profile "${profile}" \
        profile_id "${profile_ID}"
    if [ -n "${SYNOCR_PROGRESS_TOTAL:-}" ]; then
        synocr_status_begin_run "${SYNOCR_PROGRESS_TOTAL}"
    fi
    if [ -n "${SYNOCR_PROGRESS_STARTED_AT:-}" ]; then
        synocr_status_write started_at "${SYNOCR_PROGRESS_STARTED_AT}"
    fi

    if [ "${date_search_method}" = python ] ; then
        log_kv "Date search method" "use Python"
    else
        log_kv "Date search method" "use standard search via RegEx"
    fi
    log_kv "date found order" "${search_nearest_date}"
    log_kv "source for filedate" "${filedate}"
    log_kv "ignored dates by search" "${ignoredDate}"

    validate_date_range() {
        # filter special characters
        local year
        local length
        local functionType
        year="$( echo "${1}" | tr -cd '[:alnum:]' )"
        length=$( printf "%s" "${year}" | wc -c )
        functionType="${2}"

        if [ "${year}" = 0 ] || [ -z "${year}" ]; then
            # value is zero or not set
            printf 0
            return
        elif grep -Eq "^[[:digit:]]+$" <<< "${year}"; then
            # value is a digit
            if [ "${length}" -eq 4 ]; then
                # is absolute year
                printf "%s" "${year}"
                return
            elif [ "${length}" -lt 4 ]; then
                printf "%s" $(($(date +%Y)${functionType}$year))
                return
            else
                # more than 4 digits not supported
                printf 0
                return
            fi
        else
            # value is not a digit
            printf 0
            return
        fi
    }

    minYear=$( validate_date_range "${DateSearchMinYear}" "-" )
    log_kv "date range in past" "${DateSearchMinYear} [absolute: ${minYear}]"
    maxYear=$( validate_date_range "${DateSearchMaxYear}" "+" )
    log_kv "date range in future" "${DateSearchMaxYear} [absolute: ${maxYear}]"

    # Extract the OCR language code passed to Tesseract via -l (e.g. "deu+eng").
    # It is forwarded to find_dates.py as a locale hint for international date parsing.
    # ocropt_arr is already built above, so we reuse its parsed -l/value pairs.
    # Note: only the spaced form "-l deu+eng" (as suggested by the GUI) is matched;
    # the compact form "-ldeu" is not recognized.
    ocr_lang_raw=""
    for ((i=0; i<${#ocropt_arr[@]}; i++)); do
        if [ "${ocropt_arr[$i]}" = "-l" ] && [ $((i+1)) -lt ${#ocropt_arr[@]} ]; then
            ocr_lang_raw="${ocropt_arr[$((i+1))]}"
            break
        fi
    done
    log_kv "OCR language hint" "${ocr_lang_raw}"

    log_debug "PATH-Variable: ${PATH}"
    if docker --version 2>/dev/null | grep -q "version"  ; then
        log_kv "Docker test" "OK"
    else
        log_warn "Docker could not be found. Please check if the Docker package has been installed!"
    fi
    log_kv "DSM notify to user" "${MessageTo}"
    log_kv "apprise notify service" "${apprise_call}"
    log_kv "apprise attachment" "${apprise_attachment}"
    log_kv "notify language" "${notify_lang}"


# Configuration for LogLevel:
# ---------------------------------------------------------------------
    # LOGlevel:     0 ➜ logging disable / 1 ➜ normal / 2 ➜ debug
    if [ "${loglevel}" = 1 ] ; then
        log_kv "Loglevel" "normal"
        rm_log_level=""
    elif [ "${loglevel}" = 2 ] ; then
        log_kv "Loglevel" "debug"
        # set -x
        ocropt_arr+=( "-v2" )
        rm_log_level="v"
    fi
    log_kv "max. count of logfiles" "${LOGmax}"
    if [ -z "${backup_max}" ] || [ "${backup_max}" == 0 ]; then
        log_kv "rotate backupfiles after" "(purge backup deactivated)"
    else
        log_kv "rotate backupfiles after" "${backup_max} ${backup_max_type}"
    fi


# Check or create and adjust directories:
# ---------------------------------------------------------------------
    # Adjust variable correction for older "Konfiguration.txt" and slash:
    INPUTDIR="${INPUTDIR%/}/"
    if [ -d "${INPUTDIR}" ] ; then
        log_kv "Source directory" "${INPUTDIR}"
    else
        synocr_fail_fatal "Source directory invalid or not set: ${INPUTDIR}"
    fi

    OUTPUTDIR="${OUTPUTDIR%/}/"
    log_kv "Target directory" "${OUTPUTDIR}"

    BACKUPDIR="${BACKUPDIR%/}/"
    if [ -d "${BACKUPDIR}" ] && echo "${BACKUPDIR}" | grep -q "/volume" ; then
        log_kv "BackUp directory" "${BACKUPDIR}"
        backup=true
    elif echo "${BACKUPDIR}" | grep -q "/volume" ; then
        if /usr/syno/sbin/synoshare --enum ENC | grep -q "$(echo "${BACKUPDIR}" | awk -F/ '{print $3}')" ; then
            synocr_fail_fatal "BackUP folder not mounted: ${BACKUPDIR}"
        fi
        mkdir -p "${BACKUPDIR}"
        log_kv "BackUp directory was created" "[${BACKUPDIR}]"
        backup=true
    else
        log_kv "Files are deleted immediately!" "/ No valid directory [${BACKUPDIR}]"
        backup=false
    fi

    LOGDIR="${LOGDIR%/}/"

#################################################################################################
#        _______________________________________________________________________________        #
#       |                                                                               |       #
#       |                           BEGINNING OF THE FUNCTIONS                          |       #
#       |_______________________________________________________________________________|       #
#                                                                                               #
#################################################################################################


update_dockerimage()
{
#########################################################################################
# this function checks for image update and purge dangling images                       #
#########################################################################################

    check_date=$(date +%Y-%m-%d)

    if synocr_needs_dockerimage_update; then
        log_subsection "checks for ocrmypdf image update"
        log_item_n "update image [${dockercontainer}]: "
        updatelog=$(docker pull "${dockercontainer}" 2>/dev/null)

    # purge only untaged ocrmypdf images:
        if docker images -f "dangling=true" --format "{{.ID}}:{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "ocrmypdf"; then 
            log_purge=$(docker rmi -f "$(docker images -f "dangling=true" --format "{{.ID}}:{{.Repository}}:{{.Tag}}" 2>/dev/null | grep "ocrmypdf" | awk -F: '{print $1}')" 2>/dev/null)
        else
            log_purge="nothing to do ..."
        fi

        if [ -z "$(synocr_sqlite  "SELECT * FROM dockerupdate WHERE image='${dockercontainer}'")" ]; then
            synocr_sqlite "INSERT INTO dockerupdate ( image, date_checked ) VALUES  ( '${dockercontainer}', '${check_date}' )"
        else
            synocr_sqlite "UPDATE dockerupdate SET date_checked='${check_date}' WHERE image='${dockercontainer}' "
        fi

        if echo "${updatelog}" | grep -q "Image is up to date"; then
            echo "image is up to date"  # inline continuation
        elif echo "${updatelog}" | grep -q "Downloaded newer image"; then
            echo "updated successfully"
        fi

        log_item "Update-Log:"
        echo "${updatelog}" | log_block
        log_item "docker purge Log:"
        echo "${log_purge}" | log_block

        log_runtime $(( $(date +%s) - date_start_file ))
    fi

}


sec_to_time()
{
#########################################################################################
# this function converts a second value to hh:mm:ss                                     #
# call: sec_to_time "string"                                                            #
# https://blog.jkip.de/in-bash-sekunden-umrechnen-in-stunden-minuten-und-sekunden/      #
#########################################################################################

    local seconds=$1
    local sign=""
    if [[ ${seconds:0:1} == "-" ]]; then
        seconds=${seconds:1}
        sign="-"
    fi
    local hours=$(( seconds / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    seconds=$(( seconds % 60 ))
    printf "%s%02d:%02d:%02d" "${sign}" ${hours} ${minutes} ${seconds}
}


file_processing_log() 
{
#########################################################################################
# This function logs every source file where “unsuccessful” is initially set as the     #
# destination. Each successfully moved destination file is also logged and the          #
# placeholder “unsuccessful” is deleted.                                                #
# call: mode (1,2) "file"                                                               #
#########################################################################################

    local mode="$1"
    local file="$2"
    local log_file="${LOGDIR}file_processing.log"
    local temp_line="                      ➜ unsuccessful"
    local last_line

    case "${mode}" in
        1)  # Source-Log with unsuccessful warning
            if (( ${loglevel:-0} == 1 || ${loglevel:-0} == 2 )); then
                echo "[$(date +%Y-%m-%d_%H-%M-%S)] SOURCE: ${file}" >> "${log_file}"
                echo "${temp_line}" >> "${log_file}"
            fi
            ;;
        2)  # Target-Log replace unsuccessful warning with target file
            [[ -s "${file}" ]] && process_error=0

            # Log only when log level is enabled
            if (( ${loglevel:-0} == 1 || ${loglevel:-0} == 2 )); then
                if [[ -s "${log_file}" ]]; then
                    last_line=$(tail -n 1 "${log_file}")
                    [[ "${last_line}" == "${temp_line}" ]] && sed -i '$d' "${log_file}"
                fi
                echo "                      ➜ ${file}" >> "${log_file}"
            fi
            ;;
    esac

}


OCRmyPDF()
{
    # shellcheck disable=SC2002  # Don't warn about "Useless cat" in this function
    # https://www.synology-forum.de/showthread.html?99516-Container-Logging-in-Verbindung-mit-stdin-und-stdout

    if [[ "${adjustColorSuccess}" = true ]]; then
        OCRinput="${color_adjustment_target}"
    else
        OCRinput="${input1}"
    fi

    # Docker-local copy only (source file handling: backup, --keep_hash, etc. stays on OCRinput/input1).
    # Shared-folder ACLs and missing supplementary groups inside the container block direct mounts.
    ocr_docker_input="${work_tmp_step1%/}/docker_input.pdf"
    if ! cp -f "${OCRinput}" "${ocr_docker_input}"; then
        log_error_at "Docker OCR input copy failed: ${OCRinput} -> ${ocr_docker_input}"
        return 1
    fi
    chmod a+rw "${ocr_docker_input}"
    chmod a+rwx "${outputtmp%/*}"

    run_and_log() {
        log_debug "$*"
        "$@"
    }

    # Match container UID/GID to synOCR.sh so /output is writable (OCRmyPDF 17+ runs as non-root).
    run_and_log docker run \
        --rm \
        --name synOCR \
        --user "$(id -u):$(id -g)" \
        --network none \
        --shm-size="${shm_size}" \
        -v "${ocr_docker_input}:/input.pdf" \
        -v "${outputtmp%/*}:/output" \
        "${dockercontainer}" \
        "${ocropt_arr[@]}" \
        /input.pdf \
        "/output/${outputtmp##*/}"

}


# tag_search() — rule engine (two-pass, JSON-contract based)
#
# Storage seam: consume ONLY normalized JSON variables (rules_json,
# groups_json, raw_state_json). Do NOT depend on file paths such as
# ${taglist} or ${taglisttmp}. Today the JSON is produced from a YAML file by
# the loader; in the future the same JSON will come from a SQLite query
# (WebGUI-managed rules). Keeping this seam clean keeps the storage migration
# localized to the loader.
#
# Two passes:
#   Pass 1 — evaluate every rule's subrules (condition any/all/none, unchanged)
#            and record raw_state_json {rule: {match, last_source}}.
#            Side-effect-free; no actions here. Actionless rules are evaluated
#            too so they can act as `requires` predicates.
#   Pass 2 — sort surviving rules by priority (asc; key-desc tiebreaker = the
#            legacy `sort -r` order), filter by `requires` (fail-closed) AND
#            `excludes` (fail-open) against the FULL raw_state_json (order-
#            independent), reload action data per rule from rules_json, apply
#            the action block, and honor on_match.action == "break" /
#            on_match.result == "exclusive" to stop the action loop.
#            on_match.result: merge (default, cumulative) | replace (this rule's
#            tag/folder wins) | exclusive (replace + break).
#
# Groups: `groups:` and a rule's `group:` field are read and validated, but have
# NO runtime effect yet (reserved for a future phase). Mutual-exclusion use cases
# are covered today via `excludes` chains + `priority`.
#
# Backward compatibility: legacy flat YAML (top-level keys = rules) stays valid
# and keeps its default ordering. `rules`/`groups` are reserved only in the new
# wrapped format.
tag_search()
{
unset renameTag
unset renameCat

# is it an external text file for the tags or a YAML rules file?
# standard rules or advanced rules (YAML file)
type_of_rule=standard

# --- Loader: storage -> normalized JSON (rules_json / groups_json) ----------
# Two storage backends feed the SAME engine below via `tag_rule_content`:
#   1) DB ruleset  — when config.ruleset_id is set, the JSON blob is loaded
#      from the `ruleset` table and wrapped into {"rules":...,"groups":...}.
#   2) YAML file   — legacy `taglist` path (file or inline GUI list), auto-
#      detected (legacy flat vs. wrapped `rules:`/`groups:`), validated and
#      converted to JSON. yaml_validate is the import-time validator; the
#      storage-agnostic yaml_validate_json doubles as the shape check.
# The engine (auto-detect, Pass 1, Pass 2) is storage-agnostic and unchanged.
if [ -n "${ruleset_id}" ] && [ "${ruleset_id}" != "0" ]; then
    # DB ruleset branch — no silent fallback to taglist (would apply wrong rules).
    log_item "source for tags is ruleset (DB) [id=${ruleset_id}]"
    _ruleset_row=$(synocr_sqlite -json "SELECT rules_json, groups_json FROM ruleset WHERE id='${ruleset_id}'")
    if [ -z "${_ruleset_row}" ] || [ "${_ruleset_row}" = "[]" ]; then
        log_error_at "ruleset id ${ruleset_id} not found in DB — aborting (no fallback to taglist)"
        return 1
    fi
    if ! tag_rule_content=$(printf '%s' "${_ruleset_row}" | jq -c '.[0] | {rules: ((.rules_json // "{}") | fromjson), groups: ((.groups_json // "{}") | fromjson)}' 2>/dev/null); then
        log_error_at "ruleset id ${ruleset_id}: stored JSON could not be parsed — aborting (no fallback to taglist)"
        return 1
    fi
    type_of_rule=advanced
elif [ -z "${taglist}" ]; then
    log_item "no tags defined"
    return
elif [ -f "${taglist}" ]; then
    if grep -q "synOCR_YAMLRULEFILE" "${taglist}" ; then
        log_item "source for tags is yaml based tag rule file [${taglist}]"

        # copy YAML file into the TMP folder, because the file can only be read incorrectly in ACL folders
        taglisttmp="${work_tmp_step2}/tmprulefile.txt"
        [ -f "${taglisttmp}" ] && rm -f "${taglisttmp}"
        cp "${taglist}" "${taglisttmp}"

        # convert DOS to Unix:
        sed -i $'s/\r$//' "${taglisttmp}"
        # remove trailing spaces and tabs:
        sed -i 's/[ \t]*$//' "${taglisttmp}"

        type_of_rule=advanced

        yaml_validate

        if [ "${python_check}" = "ok" ]; then
            log_debug "check and convert yaml 2 json with python"
            tag_rule_content=$( python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read()), indent=2, sort_keys=False))' < "${taglisttmp}" 2>&1)
            rc=$?
            if [ "${rc}" -ne 0 ]; then
                log_command_error "YAML parse failed (python3) for rule file [${taglist}]" "${rc}" "${tag_rule_content}"
                return 1  # file not further processable
                # ToDo: cancel run to preserve PDF source file / possibly move to Errorfiles? (rather not)
            fi
        else
            log_debug "check and convert yaml 2 json with yq_bin"
            yamlcheck=$(yq_bin v "${taglist}" 2>&1)
            rc=$?
            if [ "${rc}" -ne 0 ]; then
                log_command_error "YAML validate failed (yq_bin) for rule file [${taglist}]" "${rc}" "${yamlcheck}"
                return 1  # file not further processable
                # ToDo: cancel run to preserve PDF source file / possibly move to Errorfiles? (rather not)
            fi
            tag_rule_content=$(yq_bin read "${taglisttmp}" -jP 2>&1)
            echo "${tag_rule_content}" > "${LOGDIR}${taglist}.yq_bin.json"
        fi

        # Structured validation of the parsed JSON (new cross-rule fields).
        # Storage-agnostic: operates on tag_rule_content, not on a file path.
        yaml_validate_json
    else
        log_item "source for tags is file [${taglist}]"
        sed -i $'s/\r$//' "${taglist}"                    # convert DOS to Unix
        taglist=$(< "${taglist}")
    fi
else
    log_item "source for tags is the list from the GUI"
fi

if [ "${type_of_rule}" = advanced ]; then
# process complex tag rules (two-pass engine, see header above):

    # --- Auto-Detect top-level structure ----------------------------------------
    # Wrapped (.rules is an object whose values are all objects) -> rules_json=.rules,
    # groups_json=.groups. Legacy flat -> rules_json=<top-level>, groups_json={}.
    # The "all values are objects" guard prevents a legacy rule literally named
    # `rules` (whose value is a single rule object) from being misdetected as the
    # wrapped block, preserving backward compatibility.
    # NOTE: groups_json is loaded for validation only; it has no runtime effect
    # in this phase. A rule's `group:` field is likewise ignored by the engine.
    if echo "${tag_rule_content}" | jq -e 'has("rules") and (.rules | type == "object") and (all(.rules[]; type == "object"))' >/dev/null 2>&1; then
        rules_json=$(echo "${tag_rule_content}" | jq -c '.rules')
        groups_json=$(echo "${tag_rule_content}" | jq -c '.groups // {}')
        rule_format="wrapped"
    else
        rules_json=$(echo "${tag_rule_content}" | jq -c '.')
        groups_json='{}'
        rule_format="legacy"
    fi

    # --- ordered rules by priority (asc; key-desc tiebreaker = legacy sort -r) -
    ordered_rules_json=$(jq -n -c --argjson rules "${rules_json}" '
        $rules
        | to_entries
        | sort_by(.key)
        | reverse
        | sort_by((.value.priority // 100))
    ')

    # === Pass 1: subrule evaluation -> raw_state_json ==========================
    log_subsection "Pass 1: subrule match detection"
    # Iterate rules (priority-sorted for readable logs; correctness is order-
    # independent). For each rule run the existing subrule grep/condition logic
    # and store its raw match. No actions here. Actionless rules are evaluated
    # too (needed as `requires` predicates). Record last_search_source so Pass 2
    # can reproduce the legacy VARsearchfile behavior for RegEx actions.
    raw_state_json='{}'
    while read -r tagrule; do
        [ -z "${tagrule}" ] && continue
        found=0
        last_search_source="content"

        log_rule "${tagrule}"

        condition=$(echo "${rules_json}" | jq -r --arg k "${tagrule}" '.[$k].condition' | tr '[:upper:]' '[:lower:]')
        if [ "${condition}" = null ] ; then
            log_rule_note "[value for condition must not be empty - fallback to any]"
            condition=any
        fi

        # Rule-level fields are read here for logging only; Pass 2 re-reads the
        # action fields fresh from rules_json (never reuses Pass 1 variables).
        searchtag=$(echo "${rules_json}" | jq -r --arg k "${tagrule}" '.[$k].tagname' | sed 's%\/\|\\\|\:\|\?%_%g' ) # filtered: \ / : ?
        targetfolder=$(echo "${rules_json}" | jq -r --arg k "${tagrule}" '.[$k].targetfolder' )
        tagname_RegEx=$(echo "${rules_json}" | jq -r --arg k "${tagrule}" '.[$k].tagname_RegEx' )
        dirname_RegEx=$(echo "${rules_json}" | jq -r --arg k "${tagrule}" '.[$k].dirname_RegEx' )
        tagname_multiline_RegEx=$(echo "${rules_json}" | jq -r --arg k "${tagrule}" '.[$k].multilineregex' )
        dirname_multiline_RegEx=$(echo "${rules_json}" | jq -r --arg k "${tagrule}" '.[$k].dirname_multilineregex' )

        if [[ "${targetfolder}" = null ]]; then
            targetfolder=""
        fi

        if [[ "${searchtag}" = null ]]; then
            searchtag=""
        fi

        log_rule_field "condition" "${condition}"
        log_rule_field "tag" "${searchtag}"
        log_rule_field "destination" "${targetfolder}"
        if [[ "${tagname_RegEx}" != null ]] ; then
            log_rule_field "RegEx for tag" "${tagname_RegEx}"
            if [ "${tagname_multiline_RegEx}" = null ] ; then
                log_rule_field_l2 "multilineregex" "[value for multilineregex is empty - \"false\" is used]"
                tagname_multiline_RegEx=false
            else
                log_rule_field "multilineregex" "${tagname_multiline_RegEx}"
            fi
        fi
        if [[ "${dirname_RegEx}" != null ]] ; then
            log_rule_field "RegEx for dir" "${dirname_RegEx}"
            if [ "${dirname_multiline_RegEx}" = null ] ; then
                log_rule_field_l2 "dirname_multilineregex" "[value for dirname_multilineregex is empty - \"false\" is used]"
                dirname_multiline_RegEx=false
            else
                log_rule_field "dirname_multilineregex" "${dirname_multiline_RegEx}"
            fi
        fi

        log_rule_sub
        # Subrule matching — condition any/all/none logic unchanged; the result
        # feeds raw_state_json instead of triggering actions directly.
        # execute subrules:
        for subtagrule in $(echo "${rules_json}" | jq -c --arg k "${tagrule}" '(.[$k].subrules // [])[] | @base64 ') ; do
            grepresult=0
            sub_jq_value="${subtagrule}"  # universal parameter name for function sub_jq

            VARsearchstring=$(sub_jq '.searchstring')
            if [ "${VARsearchstring}" = null ] ; then
                log_rule_sub_note "[value for searchstring must not be empty - continue]"
                continue
            fi

            VARisRegEx=$(sub_jq '.isRegEx' | tr '[:upper:]' '[:lower:]')
            if [ "${VARisRegEx}" = null ] ; then
                log_rule_sub_note "[value for isRegEx is empty - \"false\" is used]"
                VARisRegEx=false
            fi

            VARsearchtype=$(sub_jq '.searchtyp' | tr '[:upper:]' '[:lower:]')
            if [ "${VARsearchtype}" = null ] ; then
                # correct spelling of searchtype with ending e (workarround because of wrong doc):
                VARsearchtype=$(sub_jq '.searchtype' | tr '[:upper:]' '[:lower:]')
                if [ "${VARsearchtype}" = null ] ; then
                    log_rule_sub_note "[value for searchtype is empty - \"contains\" is used]"
                    VARsearchtype=contains
                fi
            fi

            VARsource=$(sub_jq '.source' | tr '[:upper:]' '[:lower:]')
            if [ "${VARsource}" = null ] ; then
                log_rule_sub_note "[value for source is empty - \"content\" is used]"
                VARsource=content
            fi

            VARcasesensitive=$(sub_jq '.casesensitive' | tr '[:upper:]' '[:lower:]')
            if [ "${VARcasesensitive}" = null ] ; then
                log_rule_sub_note "[value for casesensitive is empty - \"false\" is used]"
                VARcasesensitive=false
            fi

            VARmultilineregex=$(sub_jq '.multilineregex' | tr '[:upper:]' '[:lower:]')
            if [ "${VARmultilineregex}" = null ] ; then
                log_rule_sub_note "[value for multilineregex is empty - \"false\" is used]"
                VARmultilineregex=false
            fi

        # Ignore upper and lower case if necessary:
            if [ "${VARcasesensitive}" = true ] ;then
                grep_opt=""
            else
                grep_opt="i"
            fi

        # treat the file as one huge string (Parameter -z):
            if [ "${VARmultilineregex}" = true ] ;then
                grep_opt="${grep_opt}z"
            fi

        # define search area:
            if [ "${VARsource}" = content ] ;then
                VARsearchfile="${searchfile}"
            else
                VARsearchfile="${searchfilename}"
            fi
            last_search_source="${VARsource}"

            log_rule_sub_search "${VARsearchstring}"
            log_rule_sub_field "isRegEx" "${VARisRegEx}"
            log_rule_sub_field "searchtype" "${VARsearchtype}"
            log_rule_sub_field "source" "${VARsource}"
            log_rule_sub_field "casesensitive" "${VARcasesensitive}"
            log_rule_sub_field "multilineregex" "${VARmultilineregex}"
            log_rule_sub_field "grep parameter" "${grep_opt}"

        # search … :
#                if [ "${VARisRegEx}" = true ] ;then
            # no additional restriction via 'searchtype' for regex search
#                    echo "                          searchtype:       [ignored - RegEx based]"
#                    if grep -qP${grep_opt} "${VARsearchstring}" "${VARsearchfile}" ;then
#                        grepresult=1
#                    fi
#                else
            case "${VARsearchtype}" in
                is)
                    if [ "${VARisRegEx}" = true ] ;then
                        if grep -qwP${grep_opt} "${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        if grep -qwF${grep_opt} "${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
                "is not")
                    if [ "${VARisRegEx}" = true ] ;then
                        if ! grep -qwP${grep_opt} "${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        if ! grep -qwF${grep_opt} "${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
                contains)
                    if [ "${VARisRegEx}" = true ] ;then
                        if grep -qP${grep_opt} "${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        if grep -qF${grep_opt} "${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
                "does not contain")
                    if [ "${VARisRegEx}" = true ] ;then
                        if ! grep -qP${grep_opt} "${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        if ! grep -qF${grep_opt} "${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
                "starts with")
                    if [ "${VARisRegEx}" = true ] ;then
                        if grep -qP${grep_opt} "\<${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        tmp_result=$(grep -oE${grep_opt} "\<${VARsearchstring}" "${VARsearchfile}")     # temporary hit list with RegEx
                        if echo "${tmp_result}" | grep -qF${grep_opt} "${VARsearchstring}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
                "does not starts with")
                    if [ "${VARisRegEx}" = true ] ;then
                        if ! grep -qP${grep_opt} "\<${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        tmp_result=$(grep -oE${grep_opt} "\<${VARsearchstring}" "${VARsearchfile}")     # temporary hit list with RegEx
                        if ! echo "${tmp_result}" | grep -qF${grep_opt} "${VARsearchstring}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
                "ends with")
                    if [ "${VARisRegEx}" = true ] ;then
                        if grep -qP${grep_opt} "${VARsearchstring}\>" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        tmp_result=$(grep -oE${grep_opt} "${VARsearchstring}\>" "${VARsearchfile}")     # temporary hit list with RegEx
                        if echo "${tmp_result}" | grep -qF${grep_opt} "${VARsearchstring}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
                "does not ends with")
                    if [ "${VARisRegEx}" = true ] ;then
                        if ! grep -qP${grep_opt} "${VARsearchstring}\>" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        tmp_result=$(grep -oE${grep_opt} "${VARsearchstring}\>" "${VARsearchfile}")     # temporary hit list with RegEx
                        if ! echo "${tmp_result}" | grep -qF${grep_opt} "${VARsearchstring}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
            esac
#                fi

            [ "${loglevel}" = 2 ] && [ "${grepresult}" = "1" ] && log_rule_sub_match "Subrule matched"
            [ "${loglevel}" = 2 ] && [ ! "${grepresult}" = "1" ] && log_rule_sub_match "Subrule don't matched"

        # Check condition:
            case "${condition}" in
                any)
                    if [ "${grepresult}" -eq 1 ] ; then
                        # cancel search when 1st found
                        found=1
                        break
                    fi
                    ;;
                all)
                    if [ "${grepresult}" -eq 0 ] ; then
                        # Cancel search during 1st negative search run
                        found=0
                        break
                    elif [ "${grepresult}" -eq 1 ] ; then
                        found=1
                    fi
                    ;;
                none)
                    if [ "${grepresult}" -eq 1 ] ; then
                        # cancel search when 1st found
                        found=0 # null, because condition not met
                        break
                    elif [ "${grepresult}" -eq 0 ] ; then
                        found=1
                    fi
                    ;;
            esac
    done

        if [ "${found}" -eq 1 ] ; then
            log_rule_result ">>> raw match (Pass 1 only)"
        else
            log_rule_result ">>> no raw match (Pass 1 only)"
        fi

        # record raw match + last search source for Pass 2 (JSON state, no assoc arrays)
        raw_state_json=$(jq -n -c \
            --arg k "${tagrule}" \
            --argjson m "${found:-0}" \
            --arg s "${last_search_source}" \
            --argjson acc "${raw_state_json}" \
            '$acc | .[$k] = {match: $m, last_source: $s}')

        printf "\n"

    done <<< "$(echo "${ordered_rules_json}" | jq -r '.[].key')"

    # === Pass 2: priority sort + requires/excludes filter -> surviving_rules_json
    pass2_filtered=0
    pass2_applied=0
    pass2_break_stopped=0
    pass2_break_rule=""
    pass2_apply_candidates=0

    log_subsection "Pass 2: action selection and apply"

    # --- Pass 2 filter log: skipped rules only (bash loop — portable on all jq) -
    while read -r p2_rule; do
        [ -z "${p2_rule}" ] && continue
        p2_prio=$(echo "${rules_json}" | jq -r --arg k "${p2_rule}" '.[$k].priority // 100' 2>/dev/null)
        p2_match=$(echo "${raw_state_json}" | jq -r --arg k "${p2_rule}" '.[$k].match // 0' 2>/dev/null)
        p2_skip_reason=""
        p2_skip_ref=""

        if [ "${p2_match}" != "1" ] ; then
            p2_skip_reason="subrules_not_matched"
        else
            p2_skip_ref=$(echo "${rules_json}" | jq -r --arg k "${p2_rule}" --argjson raw "${raw_state_json}" '
                def as_rule_list:
                    if . == null then [] elif type == "string" then [.]
                    elif type == "array" then . else [] end;
                (.[$k].requires | as_rule_list) | map(select(($raw[.].match // 0) != 1)) | .[0] // empty
            ' 2>/dev/null)
            if [ -n "${p2_skip_ref}" ] ; then
                p2_skip_reason="requires_not_satisfied"
            else
                p2_skip_ref=$(echo "${rules_json}" | jq -r --arg k "${p2_rule}" --argjson raw "${raw_state_json}" '
                    def as_rule_list:
                        if . == null then [] elif type == "string" then [.]
                        elif type == "array" then . else [] end;
                    (.[$k].excludes | as_rule_list) | map(select(($raw[.].match // 0) == 1)) | .[0] // empty
                ' 2>/dev/null)
                if [ -n "${p2_skip_ref}" ] ; then
                    p2_skip_reason="excludes_matched"
                fi
            fi
        fi

        if [ -n "${p2_skip_reason}" ] ; then
            pass2_filtered=$(( pass2_filtered + 1 ))
            log_rule_pass2 "${p2_rule}" "${p2_prio}"
            case "${p2_skip_reason}" in
                subrules_not_matched)
                    log_rule_pass2_verdict "skip: subrules not matched"
                    [ "${loglevel}" = 2 ] && log_rule_pass2_detail "raw match in Pass 1: no"
                    ;;
                requires_not_satisfied)
                    log_rule_pass2_verdict "skip: requires not satisfied"
                    [ "${loglevel}" = 2 ] && log_rule_pass2_detail "unmet requires: ${p2_skip_ref}"
                    ;;
                excludes_matched)
                    log_rule_pass2_verdict "skip: excludes matched"
                    [ "${loglevel}" = 2 ] && log_rule_pass2_detail "blocking exclude: ${p2_skip_ref} (matched in Pass 1)"
                    ;;
            esac
            printf "\n"
        else
            pass2_apply_candidates=$(( pass2_apply_candidates + 1 ))
        fi
    done <<< "$(echo "${ordered_rules_json}" | jq -r '.[].key' 2>/dev/null)"

    # Order-independent: `requires`/`excludes` are checked against the FULL
    # raw_state_json of all rules (filled in Pass 1), not against already-applied
    # rules. `requires` is fail-closed (unknown ref -> 0 -> not satisfied);
    # `excludes` is fail-open (unknown ref -> 0 -> cannot have matched -> does not
    # block). groups/on_match.result.result-handling: groups still passive;
    # on_match.result (merge/replace/exclusive) is handled in the action loop below.
    surviving_rules_json=$(jq -n -c \
        --argjson ordered "${ordered_rules_json}" \
        --argjson raw "${raw_state_json}" '
        def as_rule_list:
            if . == null then []
            elif type == "string" then [.]
            elif type == "array" then .
            else [] end;
        $ordered
        | map(select(
            (($raw[.key].match // 0) == 1)
            and ((.value.requires | as_rule_list) | all(. as $required | (($raw[$required].match // 0) == 1)))
            and ((.value.excludes | as_rule_list) | all(. as $excluded | (($raw[$excluded].match // 0) == 0)))
          ))
    ')

    # --- Pass 2 action loop -----------------------------------------------------
    # Action fields are reloaded fresh from rules_json per rule. The action block
    # below is the legacy block (synOCR.sh 908-995), moved here and fed with
    # per-rule values. After applying actions, on_match.action == "break" stops
    # the action loop (NOT the Pass 1 match detection).
    while read -r tagrule; do
        [ -z "${tagrule}" ] && continue
        p2_prio=$(echo "${rules_json}" | jq -r --arg k "${tagrule}" '.[$k].priority // 100' 2>/dev/null)
        log_rule_pass2 "${tagrule}" "${p2_prio}"

        rule_json=$(echo "${rules_json}" | jq -c --arg k "${tagrule}" '.[$k]')
        on_match_action=$(echo "${rule_json}" | jq -r '.on_match.action // empty')
        # on_match.result: merge (default) | replace | exclusive.
        # exclusive implies break (this rule wins and stops the action loop);
        # replace/exclusive clear the accumulated tag/folder buffers so this
        # rule's own tag/folder wins (per-field, only if this rule sets them).
        on_match_result=$(echo "${rule_json}" | jq -r '.on_match.result // "merge"')
        [ "${on_match_result}" = "exclusive" ] && on_match_action="break"

        searchtag=$(echo "${rule_json}" | jq -r '.tagname' | sed 's%\/\|\\\|\:\|\?%_%g' )   # filtered: \ / : ?
        targetfolder=$(echo "${rule_json}" | jq -r '.targetfolder' )
        tagname_RegEx=$(echo "${rule_json}" | jq -r '.tagname_RegEx' )
        dirname_RegEx=$(echo "${rule_json}" | jq -r '.dirname_RegEx' )
        tagname_multiline_RegEx=$(echo "${rule_json}" | jq -r '.multilineregex' )
        VARapprise_call=$(echo "${rule_json}" | jq -r '.apprise_call' )
        VARapprise_attachment=$(echo "${rule_json}" | jq -r '.apprise_attachment' )
        VARnotify_lang=$(echo "${rule_json}" | jq -r '.notify_lang' )
        postscript=$(echo "${rule_json}" | jq -r '.postscript' )

        # skip action block for rules without tag/folder/postscript (e.g. pure
        # `requires` predicates), but still honor on_match.action == "break"
        if [[ "${searchtag}" = null ]] && [[ "${targetfolder}" = null ]] && [[ "${postscript}" = null ]] ; then
            log_rule_pass2_verdict "skip: predicate only (no tag/folder/postscript)"
            [ "${loglevel}" = 2 ] && [ -n "${on_match_action}" ] && log_rule_pass2_detail "on_match.action: ${on_match_action}"
            if [ "${on_match_action}" = "break" ] ; then
                pass2_break_rule="${tagrule}"
                log_rule_pass2_action "on_match.action == break -> stop action loop"
                break
            fi
            continue
        fi

        log_rule_pass2_verdict "apply"
        if [ "${loglevel}" = 2 ] ; then
            p2_requires=$(echo "${rules_json}" | jq -r --arg k "${tagrule}" '
                def as_rule_list:
                    if . == null then [] elif type == "string" then [.]
                    elif type == "array" then . else [] end;
                (.[$k].requires | as_rule_list) | if length == 0 then "-" else join(", ") end
            ' 2>/dev/null)
            p2_excludes=$(echo "${rules_json}" | jq -r --arg k "${tagrule}" '
                def as_rule_list:
                    if . == null then [] elif type == "string" then [.]
                    elif type == "array" then . else [] end;
                (.[$k].excludes | as_rule_list) | if length == 0 then "-" else join(", ") end
            ' 2>/dev/null)
            p2_om_action=$(echo "${rule_json}" | jq -r '.on_match.action // "-"' 2>/dev/null)
            p2_om_result=$(echo "${rule_json}" | jq -r '.on_match.result // "merge"' 2>/dev/null)
            log_rule_pass2_detail "requires: ${p2_requires}"
            log_rule_pass2_detail "excludes: ${p2_excludes}"
            log_rule_pass2_detail "on_match.action: ${p2_om_action}  on_match.result: ${p2_om_result}"
        fi

        if [[ "${targetfolder}" = null ]]; then
            targetfolder=""
        fi

        if [[ "${searchtag}" = null ]]; then
            searchtag=""
        fi

        # reconstruct VARsearchfile from the rule's last subrule source (Pass 1),
        # preserving the legacy behavior for tagname_RegEx / dirname_RegEx actions
        last_src=$(echo "${raw_state_json}" | jq -r --arg k "${tagrule}" '.[$k].last_source // "content"')
        if [ "${last_src}" = filename ] ;then
            VARsearchfile="${searchfilename}"
        else
            VARsearchfile="${searchfile}"
        fi

        # dirname_multilineregex: separate field from multilineregex (tag).
        # Default false if absent — preserves legacy behavior for existing rules.
        dirname_multiline_RegEx=$(echo "${rule_json}" | jq -r '.dirname_multilineregex' )
        if [ "${dirname_multiline_RegEx}" = null ] ; then
            dirname_multiline_RegEx=false
        fi
        if [ "${tagname_multiline_RegEx}" = null ] ; then
            tagname_multiline_RegEx=false
        fi

        pass2_applied=$(( pass2_applied + 1 ))

        # ---------------------------------------------------------------------
        # modify (global) settings with yaml rules:
        # apprise_call
        if [[ "${VARapprise_call}" != null ]] ; then
            apprise_call="${VARapprise_call} ${apprise_call}"
            log_rule_pass2_action "add apprise_call ${VARapprise_call}"
        fi

        # apprise_attachment
        if [[ "${VARapprise_attachment}" != null ]] ; then
            apprise_attachment="${VARapprise_attachment}"
            log_rule_pass2_action "set apprise_attachment to ${VARapprise_attachment}"
        fi

        # notify_lang
        if [[ "${VARnotify_lang}" != null ]] ; then
            notify_lang="${VARnotify_lang}"
            log_rule_pass2_action "set notify_lang to ${VARnotify_lang}"
        fi

        # ---------------------------------------------------------------------
        # store user defined (YAML) post scripts; eval at runtime so variables
        # like ${output}/${input1} expand after rename (not at rule-match time):
        if [[ "${postscript}" != null ]] ; then
            postscriptarray+=( "${postscript}" )
            log_rule_pass2_action "activate post script: ${postscript}"
        fi
        # ---------------------------------------------------------------------
        # tagname_RegEx
        if [[ "${tagname_RegEx}" != null ]] ; then
            log_rule_pass2_action_n "search RegEx for tag ➜ "
            # treat the file as one huge string (Parameter -z). With -oPz GNU grep
            # emits each match NUL-delimited and keeps internal newlines, so
            # tr '\n\0' ' \n' turns internal newlines into spaces and the NUL
            # record separator into a newline — head -n1 then yields the first
            # complete (possibly multi-line) match instead of only its first
            # physical line (and avoids concatenating multiple matches).
            if [ "${tagname_multiline_RegEx}" = true ] ;then
                tagname_RegEx_result=$( grep -oPz "${tagname_RegEx}" "${VARsearchfile}" \
                    | tr '\n\0' ' \n' | head -n1 \
                    | sed 's%\/\|\\\|\:\|\?%_%g' )
            else
                tagname_RegEx_result=$( grep -oP "${tagname_RegEx}" "${VARsearchfile}" \
                    | tr -d '\0' | head -n1 \
                    | sed 's%\/\|\\\|\:\|\?%_%g' )
            fi
            if [ -n "${tagname_RegEx_result}" ] ; then
                if echo "${searchtag}" | grep -q "§tagname_RegEx" ; then
                    searchtag="${searchtag//§tagname_RegEx/${tagname_RegEx_result}}"
                else
                    searchtag="${tagname_RegEx_result}"
                fi
                printf "%s\n\n" "${searchtag}"
            else
                if echo "${searchtag}" | grep -q "§tagname_RegEx" ; then
                    searchtag="${searchtag//§tagname_RegEx/}"
                    printf "%s\n\n" "RegEx not found (§tagname_RegEx cleared)"
                else
                    printf "%s\n\n" "RegEx not found (fallback to ${searchtag})"
                fi
            fi
        fi
        # ---------------------------------------------------------------------
        # dirname_RegEx
        if [[ "${dirname_RegEx}" != null ]] ; then
            log_rule_pass2_action_n "search RegEx for dir ➜ "
            # treat the file as one huge string (Parameter -z); see tagname_RegEx
            # above for why tr '\n\0' ' \n' is needed to keep multi-line matches.
            if [ "${dirname_multiline_RegEx}" = true ] ;then
                dirname_RegEx_result=$( grep -oPz "${dirname_RegEx}" "${VARsearchfile}" \
                    | tr '\n\0' ' \n' | head -n1 \
                    | sed 's%\/\|\\\|\:\|\?%_%g' )
            else
                dirname_RegEx_result=$( grep -oP "${dirname_RegEx}" "${VARsearchfile}" \
                    | tr -d '\0' | head -n1 \
                    | sed 's%\/\|\\\|\:\|\?%_%g' )
            fi
            if [ -n "${dirname_RegEx_result}" ] ; then

                # Ensure path compatibility: Replace unwanted characters with underscore
                sanitized=$(sed 's/[^A-Za-z0-9_. -]/_/g' <<< "${dirname_RegEx_result}")
                # Remove leading/trailing dots or hyphens
                sanitized=${sanitized%%[.-]}
                sanitized=${sanitized##[.-]}

                targetfolder="${targetfolder//§dirname_RegEx/${sanitized}}"
                printf "%s\n\n" "${targetfolder}"
            else
                targetfolder="${targetfolder//§dirname_RegEx/-}"
                printf "%s\n\n" "RegEx not found (§dirname_RegEx → -)"
            fi
        fi

        # --- on_match.result: replace/exclusive clear prior tags/folders --------
        # Per-field: only clear a buffer when THIS rule contributes that field,
        # so a pure apprise/postscript rule with result:replace cannot silently
        # wipe previously collected tags. apprise/notify/postscript stay cumulative.
        if [ "${on_match_result}" = "replace" ] || [ "${on_match_result}" = "exclusive" ]; then
            [ -n "${searchtag}" ]    && { renameTag=""; log_rule_pass2_action "on_match.result ${on_match_result} -> reset tags"; }
            [ -n "${targetfolder}" ] && { renameCat=""; log_rule_pass2_action "on_match.result ${on_match_result} -> reset folders"; }
        fi

        [ -n "${searchtag}" ] && renameTag="${tagsymbol}${searchtag// /%20} ${renameTag}" # with temporary space separator to finally check tags for uniqueness
        [ -n "${targetfolder}" ] && renameCat="${targetfolder// /%20} ${renameCat}"

        [ -n "${searchtag}" ] && log_rule_pass2_action "add tag: ${searchtag//%20/ }"
        [ -n "${targetfolder}" ] && log_rule_pass2_action "add folder: ${targetfolder//%20/ }"
        pass2_tags_now=$(echo "${renameTag}" | tr ' ' '\n' | awk '!x[$0]++' | sed -e "s/^%20//g;s/^${tagsymbol}//g;s/%20/ /g" | tr '\n' ' ' | sed -e 's/ $//')
        pass2_folders_now=$(echo "${renameCat}" | sed -e 's/%20/ /g;s/^ //;s/ $//')
        [ -n "${pass2_tags_now}" ] && log_rule_pass2_action "tags now: ${pass2_tags_now}" || log_rule_pass2_action "tags now: (empty)"
        [ -n "${pass2_folders_now}" ] && log_rule_pass2_action "folders now: ${pass2_folders_now}"
        [ "${loglevel}" = 2 ] && [ -n "${on_match_result}" ] && [ "${on_match_result}" != "merge" ] && log_rule_pass2_detail "on_match.result: ${on_match_result}"

        # --- on_match.action == "break" stops the Pass 2 action loop ------------
        # `break` only halts further ACTION application; all subrules were already
        # evaluated in Pass 1, so `requires` predicates stay consistent regardless
        # of order. Reached here also when on_match.result == exclusive (mapped to
        # break above). Actionless predicate rules with break are handled before
        # the skip above.
        if [ "${on_match_action}" = "break" ] ; then
            pass2_break_rule="${tagrule}"
            log_rule_pass2_action "on_match.action == break -> stop action loop"
            break
        fi

        printf "\n"

    done <<< "$(echo "${surviving_rules_json}" | jq -r '.[].key')"

    # --- Pass 2: rules skipped because break stopped the action loop ------------
    if [ -n "${pass2_break_rule}" ] ; then
        while read -r p2_remain; do
            [ -z "${p2_remain}" ] && continue
            p2_remain_prio=$(echo "${rules_json}" | jq -r --arg k "${p2_remain}" '.[$k].priority // 100' 2>/dev/null)
            pass2_break_stopped=$(( pass2_break_stopped + 1 ))
            log_rule_pass2 "${p2_remain}" "${p2_remain_prio}"
            log_rule_pass2_verdict "skip: break stopped loop"
            [ "${loglevel}" = 2 ] && log_rule_pass2_detail "stopped after: ${pass2_break_rule}"
            printf "\n"
        done <<< "$(echo "${surviving_rules_json}" | jq -r --arg br "${pass2_break_rule}" '
            . as $all
            | ($all | map(.key) | index($br)) as $ix
            | if $ix == null then empty else $all[$ix + 1:][] | .key end
        ')"
    fi

    log_rule_pass2_summary "pass 2 summary: ${pass2_applied} applied, ${pass2_filtered} filtered, ${pass2_break_stopped} stopped by break"
    if [ "${loglevel}" = 2 ] ; then
        log_rule_pass2_detail "rule format: ${rule_format}  rules total: $(echo "${rules_json}" | jq 'length' 2>/dev/null)  eligible: ${pass2_apply_candidates}"
    fi
    printf "\n"

    # meta_keyword_list: unique / without tagsymbol / separated with comma and space >, <:
    meta_keyword_list=$(echo "${renameTag}" | tr ' ' '\n' | awk '!x[$0]++' | sed -e "s/^%20//g;s/^${tagsymbol}//g" | tr '\n' ' ' | sed -e "s/ /, /g;s/%20/ /g;s/, $//g" | sed -e "s/, $//g")
    # ranameTag: unique / spaces masked with %20:
    renameTag=$(echo "${renameTag}" | tr ' ' '\n' | awk '!x[$0]++' | tr '\n' ' ' | sed -e "s/ //g" )
else
# process simple tag rules:
    taglist2=$( echo "${taglist}" | sed -e "s/ /%20/g" | sed -e "s/;/ /g" )   # encode spaces in tags and convert semicolons to spaces (for array)
    IFS=" " read -r -a tagarray <<< "${taglist2}" ; IFS="${IFSsaved}"

    i=0
    maxID=${#tagarray[*]}
    log_detail "tag count: ${maxID}"

    # ToDo: possibly change loop …
    #    for i in ${tagarray[@]}; do
    #        echo $a
    #    done
    while (( i < maxID )); do
        log_runtime $(( $(date +%s) - date_start_file ))

        if echo "${tagarray[$i]}" | grep -q "=" ;then
            # for combination of tag and category
            if echo "${tagarray[$i]}" | awk -F'=' '{print $1}' | grep -q  "^§" ;then
               grep_opt="-qiw" # find single tag
            else
                grep_opt="-qi"
            fi

            # shellcheck disable=SC2004  # Don't warn about "$/${} is unnecessary on arithmetic variables" in this function
            tagarray[$i]="${tagarray[$i]#§}"

            searchtag=$(awk -F'=' '{gsub(/%20/, " "); print $1}' <<< "${tagarray[$i]}")
            categorietag=$(echo "${tagarray[$i]}" | awk -F'=' '{print $2}' | sed -e "s/%20/ /g")
            log_item_n "Search by tag: \"${searchtag}\": "
            if grep $grep_opt "${searchtag}" "${searchfile}" ;then
                echo "OK (Cat: \"${categorietag}\")"
                renameTag="${tagsymbol}${searchtag// /%20}${renameTag}"
                renameCat="${categorietag// /%20} ${renameCat}"
            else
                echo "-"
            fi
        else
            if [[ "${tagarray[$i]//%20/ }" == §* ]]; then
                grep_opt="-qiw" # find single tag
            else
                grep_opt="-qi"
            fi
            # shellcheck disable=SC2004  # Don't warn about "$/${} is unnecessary on arithmetic variables" in this function
            tagarray[$i]="${tagarray[$i]#§}"
            log_item_n "Search by tag: \"${tagarray[$i]//%20/ }\": "
            if grep "${grep_opt}" "$(echo "${tagarray[$i]}" | sed -e "s/%20/ /g;s/^§//g")" "${searchfile}" ; then
                echo "OK"
                renameTag="${tagsymbol}${tagarray[$i]}${renameTag}"
            else
                echo "-"
            fi
        fi
        i=$((i + 1))
    done

    # meta_keyword_list: without tagsymbol / separated with comma and space >, <:
    meta_keyword_list=$(echo "${renameTag}" | sed -e "s/^${tagsymbol}//g;s/${tagsymbol}/, /g;s/%20/ /g")
fi

# remove last whitespace:
    renameTag=${renameTag% }

# remove starting and ending spaces, or all spaces if no destination folder is defined:
    renameCat=$(echo "${renameCat}" | sed 's/^ *//;s/ *$//')
    if [ -n "${renameCat}" ] && [ "${moveTaggedFiles}" != useCatDir ] ; then
        log_warn "! ! ! ATTENTION ! ! !"
        log_warn "You have defined rule-based directories, but defined the GUI setting is: ${moveTaggedFiles}"
        log_warn "Please change the GUI-setting, if you want to use the rule based directories."
        log_blank
    fi

# unmodified for tag folder / tag folder with spaces otherwise not possible:
    renameTag_raw="${renameTag}"


    log_note "rename tag is: \"${renameTag//%20/ /}\""
    log_blank

}


sub_jq()
{
#########################################################################################
# This function extract yaml-values                                                     #
# https://starkandwayne.com/blog/bash-for-loop-over-json-array-using-jq/                #
#                                                                                       #
#########################################################################################

    echo "${sub_jq_value}" | base64 -i --decode | jq -r "${1}"

}


# yaml_validate() — text-based preflight on the temporary YAML file.
#
# Backward compatible: legacy flat YAML (rule names as top-level keys) stays
# fully valid and is the default. `rules:`/`groups:` are reserved only in the
# new wrapped format (auto-detected in tag_search).
#
# This pass is intentionally loose about NEW cross-rule fields (priority,
# requires, excludes, on_match, group, groups.condition). Those are validated
# structurally by yaml_validate_json() on the parsed JSON, which is
# storage-agnostic (works for YAML files today and SQLite rows tomorrow). The
# text pass here only relaxes the legacy `condition` allow-list to also accept
# `first_match` so the new wrapped/grouped format is not rejected pre-parse.
yaml_validate()
{
#########################################################################################
# This function validate the integrity of yaml-file                                     #
#########################################################################################


# check & adjust the rule names (only numbers and letters / no number at the beginning):
# ---------------------------------------------------------------------
    rulenames=$(grep -Ev '^[[:space:]]|^#|^$' "${taglisttmp}" | grep -E ':[[:space:]]?$')
    while read -r i; do
        i2="${i//[^a-zA-Z0-9_:]/_}"    # replace all nonconfom chars / only latin letters!
        if echo "${i2}" | grep -Eq '^[^a-zA-Z]' ; then
            i2="_${i2}"   # currently it is not checked if there are duplicates of the rule name due to the adjustment
        fi

        if [[ "${i}" != "${i2}" ]] ; then
            log_item "rule name ${i2} was adjusted"
            sed -i "s/${i}/${i2}/" "${taglisttmp}"
        fi
    done <<< "${rulenames}"


# check uniqueness of parent nodes:
# ---------------------------------------------------------------------
    if [ "$(grep "^[a-zA-Z0-9_].*[: *]$" "${taglisttmp}" | sed 's/ *$//' | sort | uniq -d | wc -l )" -ge 1 ] ; then # check for the number of duplicate lines
        log_item "main keywords are not unique!"
        log_item "dublicats are: $(grep "^[a-zA-Z0-9_].*[: *]$" "${taglisttmp}" | sed 's/ *$//' | sort | uniq -d)"
    fi


# check parameter validity:
# ---------------------------------------------------------------------
    # check, if value of condition is "all" OR "any" OR "none" (OR "first_match"):
    # NOTE: `first_match` is a group-level condition (see yaml_validate_json for
    # the context-sensitive check). The text preflight accepts it here so the
    # new wrapped/grouped format is not rejected before JSON parsing. Legacy
    # rule-level condition remains all|any|none (enforced in yaml_validate_json).
    if grep -q '^[[:space:]]*condition' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(all|any|none|first_match)$' > /dev/null  2>&1 ; then
               log_error_at "YAML rule syntax (row $(echo "${line}" | awk -F: '{print $1}')): value '${value}' invalid for 'condition' — expected all, any, none, or first_match"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^condition:")"
    fi

    # check, if value of isRegEx is "true" OR "false":
    if grep -q '^[[:space:]]*isRegEx' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
               log_error_at "YAML rule syntax (row $(echo "${line}" | awk -F: '{print $1}')): value '${value}' invalid for 'isRegEx' — expected true or false"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^isRegEx:")"
    fi

    # check, if value of source is "content" OR "filename":
    if grep -q '^[[:space:]]*source' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(content|filename)$' > /dev/null  2>&1 ; then
               log_error_at "YAML rule syntax (row $(echo "${line}" | awk -F: '{print $1}')): value '${value}' invalid for 'source' — expected content or filename"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^source:")"
    fi

    # check of corect value of searchtype:
    if grep -q '^[[:space:]]*searchtyp|^[[:space:]]*searchtype' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | sed 's/^ *//;s/ *$//' | tr -cd '[:alnum:][:blank:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(is|is not|contains|does not contain|starts with|does not starts with|ends with|does not ends with|matches|does not match)$' > /dev/null  2>&1 ; then
               log_error_at "YAML rule syntax (row $(echo "${line}" | awk -F: '{print $1}')): value '${value}' invalid for 'searchtype' — expected is, is not, contains, does not contain, starts with, does not starts with, ends with, does not ends with, matches, or does not match"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wnE "^searchtyp:|^searchtype:")"
    fi

    # check, if value of casesensitive is "true" OR "false":
    if grep -q '^[[:space:]]*casesensitive' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
               log_error_at "YAML rule syntax (row $(echo "${line}" | awk -F: '{print $1}')): value '${value}' invalid for 'casesensitive' — expected true or false"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^casesensitive:")"
    fi

    # check, if value of multilineregex is "true" OR "false":
    if grep -q '^[[:space:]]*multilineregex' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
               log_error_at "YAML rule syntax (row $(echo "${line}" | awk -F: '{print $1}')): value '${value}' invalid for 'multilineregex' — expected true or false"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^multilineregex:")"
    fi

    # check, if value of dirname_multilineregex is "true" OR "false":
    if grep -q '^[[:space:]]*dirname_multilineregex' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
               log_error_at "YAML rule syntax (row $(echo "${line}" | awk -F: '{print $1}')): value '${value}' invalid for 'dirname_multilineregex' — expected true or false"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^dirname_multilineregex:")"
    fi

    # check apprise_call:
    # ToDo: which regex can check this?
#    if grep -q "apprise_call" "${taglisttmp}"; then
#       while read -r line ; do
#           if ! echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
#              log_item "syntax error in row $(echo "${line}" | awk -F: '{print $1}') [value of apprise_call must be only ... ]"
#           fi
#       done <<<"$(cat "${taglisttmp}" | sed 's/^ *//;s/ *$//' | grep -n "^apprise_call:")"
#      done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^apprise_call:")"
#   fi

    # check, if value of apprise_attachment is "true" OR "false":
    if grep -q '^[[:space:]]*apprise_attachment' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
               log_error_at "YAML rule syntax (row $(echo "${line}" | awk -F: '{print $1}')): value '${value}' invalid for 'apprise_attachment' — expected true or false"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^apprise_attachment:")"
    fi

    # check, if value of notify_lang is a valid language:
    if grep -q '^[[:space:]]*notify_lang' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(chs|cht|csy|dan|enu|fre|ger|hun|ita|jpn|krn|nld|nor|plk|ptb|ptg|rus|spn|sve|tha|trk)$' > /dev/null  2>&1 ; then
               log_error_at "YAML rule syntax (row $(echo "${line}" | awk -F: '{print $1}')): value '${value}' invalid for 'notify_lang' — expected one of chs, cht, csy, dan, enu, fre, ger, hun, ita, jpn, krn, nld, nor, plk, ptb, ptg, rus, spn, sve, tha, trk"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^notify_lang:")"
    fi

    echo -e

}


# yaml_validate_json() — structural validation of the parsed rule JSON.
#
# Storage-agnostic: operates on the global `tag_rule_content` JSON variable,
# NOT on a file path. Today that JSON comes from YAML conversion; tomorrow it
# will come from a SQLite query (WebGUI-managed rules). The same validator
# therefore doubles as the import-time check for the future DB import function.
#
# Handles the NEW cross-rule fields the text pass cannot see context-sensitively:
#   - rule.condition          must be all|any|none            (NOT first_match)
#   - group.condition         may be all|any|first_match      (groups only)
#   - priority                number (optional; default 100)
#   - requires / excludes     array of existing rule names
#   - on_match.action         continue | break
#   - on_match.result         merge | replace | exclusive
#   - group                   reference into top-level `groups`
#
# Backward compatibility: every new field is optional. A legacy flat YAML has
# no `groups`, so the group checks are skipped entirely, and rules without the
# new fields pass unchanged. Unknown `requires`/`excludes` targets are logged
# as warnings (fail-closed at runtime: missing refs evaluate to not-matched).
yaml_validate_json()
{
    # normalize: rules_json = .rules (wrapped) or . (legacy flat); groups_json
    local rules_json groups_json
    if echo "${tag_rule_content}" | jq -e 'has("rules") and (.rules | type == "object") and (all(.rules[]; type == "object"))' >/dev/null 2>&1; then
        rules_json=$(echo "${tag_rule_content}" | jq -c '.rules')
        groups_json=$(echo "${tag_rule_content}" | jq -c '.groups // {}')
    else
        rules_json=$(echo "${tag_rule_content}" | jq -c '.')
        groups_json='{}'
    fi

    # known rule names (for requires/excludes/group reference checks)
    local known_rules
    known_rules=$(echo "${rules_json}" | jq -r 'keys[]')

    # --- rule-level checks -----------------------------------------------------
    # Use "-" placeholder for unset on_match fields (bash IFS=tab skips empty
    # fields, which would shift merge from result into action).
    echo "${rules_json}" | jq -r 'to_entries[] | "\(.key)\t\(.value.condition // "any")\t\(.value.priority // 100)\t\(.value.on_match.action // "-")\t\(.value.on_match.result // "-")\t\(.value.dirname_multilineregex // "-")"' 2>/dev/null | \
    while IFS=$'\t' read -r rname rcond rprio raction rresult rdml; do
        # condition: rules allow all|any|none only (first_match is group-only)
        if [ -n "${rcond}" ] && [ "${rcond}" != "null" ]; then
            if ! echo "${rcond}" | grep -Eiw '^(all|any|none)$' >/dev/null 2>&1; then
                log_error_at "YAML rule syntax: rule '${rname}' has condition '${rcond}' — expected all, any, or none (first_match is valid for groups only)"
            fi
        fi
        # priority: must be numeric if present
        if [ -n "${rprio}" ] && [ "${rprio}" != "null" ] && [ "${rprio}" != "100" ]; then
            if ! echo "${rprio}" | grep -Eq '^-?[0-9]+$' >/dev/null 2>&1; then
                log_error_at "YAML rule syntax: rule '${rname}' has non-numeric priority '${rprio}' — expected an integer (smaller = higher priority)"
            fi
        fi
        # on_match.action: continue (default) or break; "-" = unset (implicit continue)
        if [ -n "${raction}" ] && [ "${raction}" != "null" ] && [ "${raction}" != "-" ]; then
            if ! echo "${raction}" | grep -Eiw '^(continue|break)$' >/dev/null 2>&1; then
                log_error_at "YAML rule syntax: rule '${rname}' has on_match.action '${raction}' — expected continue or break"
            fi
        fi
        # on_match.result: merge (default) | replace | exclusive; "-" = unset (implicit merge)
        if [ -n "${rresult}" ] && [ "${rresult}" != "null" ] && [ "${rresult}" != "-" ]; then
            if ! echo "${rresult}" | grep -Eiw '^(merge|replace|exclusive)$' >/dev/null 2>&1; then
                log_error_at "YAML rule syntax: rule '${rname}' has on_match.result '${rresult}' — expected merge, replace, or exclusive"
            fi
        fi
        # dirname_multilineregex: true | false; "-" = unset (implicit false)
        if [ -n "${rdml}" ] && [ "${rdml}" != "null" ] && [ "${rdml}" != "-" ]; then
            if ! echo "${rdml}" | grep -Eiw '^(true|false)$' >/dev/null 2>&1; then
                log_error_at "YAML rule syntax: rule '${rname}' has dirname_multilineregex '${rdml}' — expected true or false"
            fi
        fi
    done

    # --- requires / excludes: type + reference checks --------------------------
    # Accepts array or single string (runtime normalizes string -> [string]).
    echo "${rules_json}" | jq -r '
        def as_rule_list:
            if . == null then []
            elif type == "string" then [.]
            elif type == "array" then .
            else empty end;
        to_entries[]
        | .key as $k
        | (.value.requires) as $r
        | (.value.excludes) as $e
        | if $r != null and ($r | type | IN("array","string") | not) then
            "\($k)\trequires\t\($r | type)"
          elif $e != null and ($e | type | IN("array","string") | not) then
            "\($k)\texcludes\t\($e | type)"
          else empty end
    ' 2>/dev/null | while IFS=$'\t' read -r rname field rtype; do
        log_error_at "YAML rule syntax: rule '${rname}' has ${field} of type '${rtype}' — expected array or string"
    done

    echo "${rules_json}" | jq -r '
        def as_rule_list:
            if . == null then []
            elif type == "string" then [.]
            elif type == "array" then .
            else [] end;
        to_entries[]
        | .key as $k
        | ((.value.requires | as_rule_list)[]? | "\($k)\trequires\t\(.)"),
          ((.value.excludes | as_rule_list)[]? | "\($k)\texcludes\t\(.)")
    ' 2>/dev/null | while IFS=$'\t' read -r rname field ref; do
        [ -z "${ref}" ] && continue
        if ! echo "${known_rules}" | grep -qxF "${ref}"; then
            log_warn_at "YAML rule syntax: rule '${rname}' references unknown rule '${ref}' in ${field} (runtime: requires fail-closed / excludes fail-open)"
        fi
    done

    # --- group-level checks (only for the wrapped format) ---------------------
    if [ "${groups_json}" != "{}" ]; then
        echo "${groups_json}" | jq -r 'to_entries[] | "\(.key)\t\(.value.condition // "first_match")"' 2>/dev/null | \
        while IFS=$'\t' read -r gname gcond; do
            if [ -n "${gcond}" ] && [ "${gcond}" != "null" ]; then
                if ! echo "${gcond}" | grep -Eiw '^(all|any|first_match)$' >/dev/null 2>&1; then
                    log_error_at "YAML rule syntax: group '${gname}' has condition '${gcond}' — expected all, any, or first_match"
                fi
            fi
        done
    fi
}


prepare_python()
{
#########################################################################################
# This function check the python3 & pip installation and the necessary modules          #
#                                                                                       #
#########################################################################################

    local min_py_version="3.8"
    local python_env_path env_version py_version module moduleName modulePinnedVer moduleInstalledVer tmp_log1 tmp_log2

    # Newest suitable interpreter (x86_64 >=3.8, aarch64 >=3.9); see synocr_resolve_python_path
    # aarch64 min 3.9: dateparser / backports.zoneinfo incompatibility on older Python
    synocr_resolve_python_path
    if [ "${machinetyp}" = aarch64 ]; then
        min_py_version="3.9"
    fi

    log_debug "  Check Python:"
    if [ -z "${python_path}" ]; then
        log_error_at "No suitable Python version (>=${min_py_version}) found on ${machinetyp:-unknown} — fallback to regex date search"
        log_item "  for more precise search results Python >=${min_py_version} is required"
        python_check=failed
        return 1
    fi

    py_version=$("${python_path}" -c "import sys; print('.'.join(map(str, sys.version_info[:2])))" 2>/dev/null)
    log_item "selected Python interpreter: ${python_path} (${py_version})"

    # Recreate venv only when interpreter changed or env is broken.
    # Normal synOCR upgrades only sync pins (below) — no trash, no recreate.
    # Prefer venv --clear; fallback: same-dir rename (DSM @eaDir-safe), then create.
    # ---------------------------------------------------------------------
    if [ -d "${python3_env}" ]; then
        python_env_path=${python3_env}/bin/python3
        if [ -x "${python_env_path}" ]; then
            env_version=$("${python_env_path}" -c "import sys; print('.'.join(map(str, sys.version_info[:2])))" 2>/dev/null)
            if [[ "${env_version}" != "${py_version}" ]]; then
                log_warn_at "virtual Python environment does not match selected interpreter (${env_version} != ${py_version}) — recreating ${python3_env}"
                if ! synocr_remove_python_env "${python3_env}"; then
                    log_error_at "failed to reset Python environment at ${python3_env} — aborting"
                    python_check=failed
                    return 1
                fi
            fi
        else
            log_warn_at "virtual Python environment incomplete — recreating ${python3_env}"
            if ! synocr_remove_python_env "${python3_env}"; then
                log_error_at "failed to reset incomplete Python environment at ${python3_env} — aborting"
                python_check=failed
                return 1
            fi
        fi
    fi

    if [ ! -x "${python3_env}/bin/python3" ] || [ ! -f "${python3_env}/bin/activate" ]; then
        if [ -e "${python3_env}" ]; then
            if ! synocr_remove_python_env "${python3_env}"; then
                log_error_at "failed to clear ${python3_env} before venv create — aborting"
                python_check=failed
                return 1
            fi
        fi
        # synocr_remove_python_env may already have created a fresh venv via --clear
        if [ ! -x "${python3_env}/bin/python3" ] || [ ! -f "${python3_env}/bin/activate" ]; then
            log_item_n "create virtual Python environment (${python_path}): "
            if "${python_path}" -m venv "${python3_env}"; then
                echo "ok"
            else
                log_error_at "python venv creation failed with ${python_path}"
                python_check=failed
                return 1
            fi
        fi
    fi

    if [ ! -f "${python3_env}/bin/activate" ]; then
        log_error_at "Python environment activate script missing at ${python3_env}/bin/activate"
        python_check=failed
        return 1
    fi
    # shellcheck disable=SC1091
    source "${python3_env}/bin/activate"

    if [ "$(head -n1 "${python3_env}/synOCR_python_env_version" 2>/dev/null)" != "${local_version}" ]; then
        log_debug "python3 already installed (${python_path}) — sync pinned modules for synOCR ${local_version}"

        # check / install pip:
        # ---------------------------------------------------------------------
        log_debug "  Check pip:"
        if ! python3 -m pip --version > /dev/null  2>&1 ; then
            log_item_n "Python3 pip was not found and will be now installed: "
            tmp_log1=$(python3 -m ensurepip --default-pip)
            tmp_log2=$(python3 -m pip install --upgrade pip)
            if python3 -m pip --version > /dev/null  2>&1 ; then
                echo "ok"
            else
                log_error_at "pip install failed for ${python_path} — please install Python3 pip manually"
                log_item "  install log:"
                echo "${tmp_log1}" | log_block "${_LOG_INDENT}  "
                echo "${tmp_log2}" | log_block "${_LOG_INDENT}  "
                python_check=failed
                return 1
            fi
        else
            if python3 -m pip list 2>&1 | grep -q "version.*is available" ; then
                log_note "pip already installed ($(python3 -m pip --version)) / upgrade available ..."
                python3 -m pip install --upgrade pip | log_block "${_LOG_INDENT}  "
            else
                log_debug "pip already installed ($(python3 -m pip --version))"
            fi
        fi

        if _synocr_log_ge2; then
            log_debug "installed python modules (before pin sync):"
            python3 -m pip list 2>/dev/null | log_block "${_LOG_INDENT}  "
        fi

        # Force pinned versions on every synOCR upgrade (pip install -U):
        # ---------------------------------------------------------------------
        echo -e
        for module in "${synOCR_python_module_list[@]}"; do
            moduleName=$(echo "${module}" | awk -F'=' '{print $1}')
            modulePinnedVer=$(echo "${module}" | awk -F'==' '{print $2}')

            unset tmp_log1
            log_item_n "sync python module \"${module}\": "
            tmp_log1=$(python3 -m pip install -U "${module}" 2>&1)
            moduleInstalledVer=$(python3 -m pip show "${moduleName}" 2>/dev/null | awk -F': ' '/^Version:/{print $2; exit}')

            if [ -n "${moduleInstalledVer}" ] && { [ -z "${modulePinnedVer}" ] || [ "${moduleInstalledVer}" = "${modulePinnedVer}" ]; }; then
                echo "ok (${moduleInstalledVer})"
            else
                log_error_at "Python module '${module}' install/upgrade failed — please install manually"
                log_item "  install log:" && echo "${tmp_log1}" | log_block "${_LOG_INDENT}  "
                python_check=failed
                return 1
            fi
        done

        # Remove obsolete dependency left from older synOCR versions:
        if python3 -m pip show pypdf >/dev/null 2>&1; then
            log_item_n "remove obsolete python module pypdf: "
            if python3 -m pip uninstall -y pypdf >/dev/null 2>&1; then
                echo "ok"
            else
                echo "skipped"
            fi
        fi

        if [ "${python_check}" = ok ]; then
            echo "${local_version}" > "${python3_env}/synOCR_python_env_version"
        else
            echo "0" > "${python3_env}/synOCR_python_env_version"
        fi

        if [ "${dsm_version}" = "7" ] && [ "${synOCR_user}" = root ]; then
            chown -R synOCR:administrators "${python3_env}"
            chmod -R 755 "${python3_env}"
        fi

        printf "\n"
    fi

    if _synocr_log_ge2; then
        log_debug "module list:"
        python3 -m pip list | log_block "${_LOG_INDENT}  "
        printf "\n"
    fi

    return 0
}


# shellcheck disable=SC2046,SC2219
find_date()
{
#########################################################################################
# This function search for a valid daten in ocr text                                    #
#                                                                                       #
# run with python3 - if this impossible, use fallback to search with regex              #
#                                                                                       #
#########################################################################################

founddatestr=""
format=$1   # for regex search: 1 = dd[./-]mm[./-](yy|yyyy)
            #                   2 = (yy|yyyy)[./-]mm[./-]dd
            #                   3 = mm[./-]dd[./-]yy(yy) american

# python search and set regex fallback, if needed:
# ---------------------------------------------------------------------
    if [ "${tmp_date_search_method}" = python ] && [ "${python_check}" = ok ]; then
        format=2
        if [ "${search_nearest_date}" = nearest ]; then
            arg_searchnearest="-searchnearest=on"
        else
            arg_searchnearest="-searchnearest=off"
        fi

        log_debug "call find_dates.py: -fileWithTextFindings \"${searchfile}\"  \"${arg_searchnearest}\" -dateBlackList \"${ignoredDate}\" -dbg_file \"${current_logfile}\" -dbg_lvl \"${loglevel}\" -minYear \"${minYear}\" -maxYear \"${maxYear}\" -lang \"${ocr_lang_raw}\""

        founddatestr=$( python3 ./includes/find_dates.py -fileWithTextFindings "${searchfile}" \
                                                            "${arg_searchnearest}" \
                                                            -dateBlackList "${ignoredDate}" \
                                                            -dbg_file "${current_logfile}" \
                                                            -dbg_lvl "${loglevel}" \
                                                            -minYear "${minYear}" \
                                                            -maxYear "${maxYear}" \
                                                            -lang "${ocr_lang_raw}" 2>&1)

        if _synocr_log_ge2; then
            log_debug "find_dates.py result:"
            echo "${founddatestr}" | log_block
        fi

# RegEx search:
# ---------------------------------------------------------------------
    elif [ "${tmp_date_search_method}" = "regex" ]; then
        # by DeeKay1 https://www.synology-forum.de/threads/synocr-gui-fuer-ocrmypdf.99647/post-906195
        # ToDo – alphanum example:
        # (?i)\b(([0-9]?[0-9])[. ][ ]?([0-9]?[0-9][. ]|Jan.*|Feb.*|Mär.*|Apr.*|Mai|Jun.*|Jul.*|Aug.*|Sep.*|Okt.*|Nov.*|Dez.*)[ ]?([0-9]?[0-9]?[0-9][0-9]))\b
        
        log_item "run RegEx date search - search for date format: ${format} (1 = dd mm [yy]yy; 2 = [yy]yy mm dd; 3 = mm dd [yy]yy)"
        if [ "${format}" -eq 1 ]; then
            # search by format: dd[./-]mm[./-]yy(yy)
            founddatestr=$( grep -Eo "\b([1-9]|[012][0-9]|3[01])[\./-]([1-9]|[01][0-9])[\./-](19[0-9]{2}|20[0-9]{2}|[0-9]{2})\b" <<< "${content}" | head )
        elif [ "${format}" -eq 2 ]; then
            # search by format: yy(yy)[./-]mm[./-]dd
            founddatestr=$( grep -Eo "\b(19[0-9]{2}|20[0-9]{2}|[0-9]{2})[\./-]([1-9]|[01][0-9])[\./-]([1-9]|[012][0-9]|3[01])\b" <<< "${content}" | head )
        elif  [ "${format}" -eq 3 ]; then
            # search by format: mm[./-]dd[./-]yy(yy) american
            founddatestr=$( grep -Eo "\b([1-9]|[01][0-9])[\./-]([1-9]|[012][0-9]|3[01])[\./-](19[0-9]{2}|20[0-9]{2}|[0-9]{2})\b" <<< "${content}" | head )
        fi
    fi


# Select and separate date:
# (the loop to filter & check multiple results is obsolete 
# in the current version)
# --------------------------------------------------------------------- 
    if [ -n "${founddatestr}" ] && [ "${founddatestr}" != None  ]; then
        readarray -t founddates <<<"${founddatestr}"
        cntDatesFound=${#founddates[@]}
        log_item "  Dates found: ${cntDatesFound}"
    
        for currentFoundDate in "${founddates[@]}" ; do
            if [ "${format}" -eq 1 ]; then
                log_item "  check date (dd mm [yy]yy): ${currentFoundDate}"
                date_dd=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $1}' | grep -o '[0-9]*')"; echo $((n)) ) )
                date_mm=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $2}')"; echo $((n)) ) )
                date_yy=$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')
            elif [ "${format}" -eq 2 ]; then
                log_item "  check date ([yy]yy mm dd): ${currentFoundDate}"
                date_dd=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')"; echo $((n)) ) )
                date_mm=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $2}')"; echo $((n)) ) )
                date_yy=$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $1}' | grep -o '[0-9]*')
            elif  [ "${format}" -eq 3 ]; then
                log_item "  check date (mm dd [yy]yy): ${currentFoundDate}"
                date_dd=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $2}' | grep -o '[0-9]*')"; echo $((n)) ) )
                date_mm=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $1}')"; echo $((n)) ) )
                date_yy=$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')
            fi
    
        # check century:
            if ! synocr_is_integer "${date_yy}"; then
                log_error_at "invalid year value for date comparison: expected integer, got [${date_yy}] (source: OCR text, format ${format})"
                log_detail "invalid format"
                continue
            fi
            if ! synocr_is_integer "${date_dd}" || ! synocr_is_integer "${date_mm}"; then
                log_error_at "invalid day/month value for date comparison: day=[${date_dd}] month=[${date_mm}] (source: OCR text, format ${format})"
                log_detail "invalid format"
                continue
            fi
            if [ "$(echo -n "${date_yy}" | wc -m)" -eq 2 ]; then
                if [ "${date_yy}" -gt "$(date +%y)" ]; then
                    date_yy="$(($(date +%C) - 1))${date_yy}"
                    log_item "  Date is most probably in the last century. Setting year to ${date_yy}"
                else
                    date_yy="$(date +%C)${date_yy}"
                fi
            fi
    
            date "+%d/%m/%Y" -d "${date_mm}"/"${date_dd}"/"${date_yy}" > /dev/null  2>&1    # valid date? https://stackoverflow.com/questions/18731346/validate-date-format-in-a-shell-script
            if [ $? -eq 0 ]; then
                if grep -q "${date_yy}-${date_mm}-${date_dd}" <<< "${ignoredDate}" ; then
                    log_item "  Date ${date_yy}-${date_mm}-${date_dd} is on ignore list. Skipping this date."
                    continue
                else
                    log_detail "valid"
                    log_item "      day:  ${date_dd}"
                    log_item "      month:${date_mm}"
                    log_item "      year: ${date_yy}"
                    dateIsFound=yes
                    break
                fi
            else
                log_detail "invalid format"
            fi
        done
    fi

# not found in regex search? Next loop with other schema:
# ---------------------------------------------------------------------
    if [ "${dateIsFound}" = no ] && [ "${tmp_date_search_method}" = regex ]; then
        if [ "${format}" -eq 1 ]; then
            find_date 2
        elif [ "${format}" -eq 2 ]; then
            find_date 3
        fi
    fi

}


adjust_attributes()
{
#########################################################################################
# This function adjusts the attributes of the target file                               #
#########################################################################################

    log_subsection "adjusts the attributes of the target file:"

    local source_file="${1}"
    local target_file="${2}"


# adjust file permissions;
# ---------------------------------------------------------------------
    cp --attributes-only -p "${source_file}" "${target_file}"
    chmod 664 "${target_file}"
    synoacltool -enforce-inherit "${target_file}"


# adjust file date;
# ---------------------------------------------------------------------
    log_item_n "Adapt file date (Source: "

    if [ "${filedate}" = ocr ]; then
        if [ "${dateIsFound}" = no ]; then
            echo "Source file [OCR selected but not found])"
            touch --reference="${source_file}" "${target_file}"
        else
            echo "OCR)"
            TZ=UTC touch -t "${date_yy}""${date_mm}""${date_dd}"0000 "${target_file}"
        fi
    elif [ "${filedate}" = now ]; then
        echo "NOW)"
        #TZ=$(date +%Z)
        touch --time=modify "${target_file}"
    else
        echo "Source file)"
        touch --reference="${source_file}" "${target_file}"
    fi


# File permissions-Log:
# ---------------------------------------------------------------------
    if _synocr_log_ge2; then
        log_debug "File permissions target file: $(ls -l "${target_file}")"
    fi

}


copy_attributes()
{
#########################################################################################
# This function copy the attributes from source to target file                          #
#########################################################################################

    local source_file="${1}"
    local target_file="${2}"

# adjust file permissions and date;
# ---------------------------------------------------------------------
    cp --attributes-only -p "${source_file}" "${target_file}"
    touch --reference="${source_file}" "${target_file}"
    chmod 664 "${target_file}"
    synoacltool -enforce-inherit "${target_file}"

}


replace_variables()
{
#########################################################################################
# fill the renaming syntax with values                                                  #
#########################################################################################

    echo "$1" | sed "s~§dsource~${date_dd_source}~g;s~§msource~${date_mm_source}~g;s~§ysource2~${date_yy_source:2}~g;s~§ysource4~${date_yy_source}~g" \
     | sed "s~§ysource~${date_yy_source}~g;s~§hhsource~${date_houre_source}~g;s~§mmsource~${date_min_source}~g;s~§sssource~${date_sek_source}~g;s~§dnow~$(date +%d)~g" \
     | sed "s~§mnow~$(date +%m)~g;s~§ynow2~$(date +%y)~g;s~§ynow4~$(date +%Y)~g;s~§ynow~$(date +%Y)~g;s~§hhnow~$(date +%H)~g;s~§mmnow~$(date +%M)~g;s~§ssnow~$(date +%S)~g" \
     | sed "s~§pagecount~${pagecount_latest}~g;s~§pagecounttotal~${global_pagecount_new}~g;s~§filecounttotal~${global_ocrcount_new}~g;s~§pagecountprofile~${pagecount_profile_new}~g;s~§filecountprofile~${ocrcount_profile_new}~g" \
     | sed "s~§docr~${date_dd}~g;s~§mocr~${date_mm}~g;s~§yocr2~${date_yy:2}~g;s~§yocr4~${date_yy}~g;s~§yocr~${date_yy}~g" 

}


rename()
{
# rename target file:
# ---------------------------------------------------------------------
    log_item "renaming:"
    outputtmp="${output}"
    
    if [ -z "${NameSyntax}" ]; then
        # if no renaming syntax was specified by the user, the source filename will be used
        NameSyntax="§tit"
    fi
    log_item_n "apply renaming syntax: "
    
    # encode special characters for sed compatibility:
    title=$(urlencode "${title}")

    # replace parameters with values (rulenames can contain placeholders, which are replaced here):
    renameTag=$(replace_variables "${renameTag}")

    # decode %20 before renew encoding
#   renameTag=$(urlencode "$(urldecode "${renameTag}")")
    # re-code only whitespaces:
    renameTag="$( echo  "${renameTag}" | sed -e "s~%20~ ~g;s~ ~%20~g")"

# replace parameters with values:
# ---------------------------------------------------------------------
    NewName=$(replace_variables "${NameSyntax}")

    # parameters without replace_variables function:
    # Escape sed replacement metacharacters so '&' is treated literally.
    renameTag_sed="${renameTag//\\/\\\\}"
    renameTag_sed="${renameTag_sed//&/\\&}"
    renameTag_sed="${renameTag_sed//~/\\~}"
    title_sed="${title//\\/\\\\}"
    title_sed="${title_sed//&/\\&}"
    title_sed="${title_sed//~/\\~}"
    NewName=$( echo "${NewName}" | sed "s~§tag~${renameTag_sed}~g;s~§tit~${title_sed}~g;s~%20~ ~g" )

    # fallback to old  parameters:    
    NewName="${NewName//§d/${date_dd}}"
    NewName="${NewName//§m/${date_mm}}"
    NewName="${NewName//§y/${date_yy}}"

    # decode special characters:
    NewName=$(urldecode "${NewName}")
    renameTag=$(urldecode "${renameTag}")
    
    # Fallback, if no variables were found for renaming:
    if [ -z "${NewName}" ]; then
        NewName="${NewName:-$(date +%Y-%m-%d_%H-%M)_$(urldecode "${title}")}"
        log_warn "! WARNING ! – No variables were found for renaming. A fallback is used to prevent an empty file name: ${NewName}"
    else
        # all non-alphanumeric characters will be compressed
        NewName=$(sed -E 's/([^[:alnum:]])\1+/\1/g' <<< "$NewName")
        log_item "${NewName}"
    fi

    log_runtime $(( $(date +%s) - date_start_file ))


# set metadata:
# ---------------------------------------------------------------------
    if [[ "${keep_hash}" != "true" ]]; then
        log_item_n "insert metadata "

        if [ "${python_check}" = ok ] && [ "${enablePyMetaData}" -eq 1 ]; then
            echo "(use python pikepdf)"
            unset py_meta

            # replace parameters with values (rulenames can contain placeholders, which are replaced here)
            meta_keyword_list=$(replace_variables "${meta_keyword_list}")
            documentAuthor=$(replace_variables "${documentAuthor}")
            documentTitle=$(replace_variables "${documentTitle}")

            py_meta="'/Author': '${documentAuthor}',"
            py_meta="$(printf "${py_meta}\n'/Title': \'${documentTitle}\',")"
            # shellcheck disable=SC2059  # Don't warn about "variables in the printf format string" in this function
            py_meta="$(printf "${py_meta}\n'/Keywords': \'$( echo "${meta_keyword_list}" | sed -e "s/^${tagsymbol}//g" )\',")"
            # shellcheck disable=SC2059  # Don't warn about "variables in the printf format string" in this function
            py_meta="$(printf "${py_meta}\n'/CreationDate': \'D:${date_yy}${date_mm}${date_dd}\',")"
            # shellcheck disable=SC2059  # Don't warn about "variables in the printf format string" in this function
            py_meta="$(printf "${py_meta}\n'/CreatorTool': \'synOCR ${local_version}\'")"

            log_item "used metadata:"
            echo "${py_meta}" | log_block

            outputtmpMeta="${outputtmp}_meta.pdf"

            log_debug "call handlePdf.py -dbg_lvl ${loglevel} -dbg_file ${current_logfile} -task metadata -inputFile ${outputtmp} -outputFile ${outputtmpMeta}"

            python3 ./includes/handlePdf.py -dbg_lvl "${loglevel}" \
                                            -dbg_file "${current_logfile}" \
                                            -task metadata \
                                            -inputFile "${outputtmp}" \
                                            -metaData "{$py_meta}"  \
                                            -outputFile "${outputtmpMeta}"
            handlePdf_rc=$?
            meta_size=$(stat -c %s "${outputtmpMeta}" 2>/dev/null || echo 0)

            if [ "${handlePdf_rc}" -ne 0 ] || [ "${meta_size}" -eq 0 ] || [ ! -f "${outputtmpMeta}" ]; then
                log_error_at "handlePdf.py metadata failed (exit ${handlePdf_rc}) for ${outputtmp}"
            else
                mv "${outputtmpMeta}" "${outputtmp}"
            fi
            unset outputtmpMeta

        # Fallback for exiftool DSM6.2, if needed:
        elif which exiftool > /dev/null  2>&1 ; then
            echo -n "(exiftool ok) "
            exiftool -overwrite_original -time:all="${date_yy}:${date_mm}:${date_dd} 00:00:00" -sep ", " -Keywords="$( echo "${renameTag}" | sed -e "s/^${tagsymbol}//g;s/${tagsymbol}/, /g" )" "${outputtmp}"
        else
            log_error_at "exiftool not found — Python-check failed or enablePyMetaData disabled; metadata not written"
        fi

        log_runtime $(( $(date +%s) - date_start_file ))
    fi


# move target files:
# ---------------------------------------------------------------------
    i=0
    if [ "${moveTaggedFiles}" = useYearDir ] ; then
    # move to folder each year:
    # ---------------------------------------------------------------------
        log_item "move to folder each year ( …/target/YYYY/file.pdf)"
        subOUTPUTDIR="${OUTPUTDIR}${date_yy}/"
        log_item_n "target directory \".../${date_yy}/\" exists? "
        if [ -d "${subOUTPUTDIR}" ] ;then
            echo "OK"
        else
            mkdir -p "${subOUTPUTDIR}"
            echo "created"
        fi

        prepare_target_path "${subOUTPUTDIR}" "${NewName}.pdf"

        log_item "  target file: ${output}"

        if [[ "${keep_hash}" = "true" ]]; then
            cp -a "${keep_hash_input}" "${output}"
        else
            mv "${outputtmp}" "${output}"
            adjust_attributes "${keep_hash_input}" "${output}"
        fi
        file_processing_log 2 "${output}"
        synocr_processing_job_add_target "${output}"

    elif [ "${moveTaggedFiles}" = useYearMonthDir ] ; then
    # move to folder each year & month:
    # ---------------------------------------------------------------------
        log_item "move to folder each year & month ( …/target/YYYY/MM/file.pdf)"
        subOUTPUTDIR="${OUTPUTDIR}${date_yy}/${date_mm}/"
        log_item_n "target directory \".../${date_yy}/${date_mm}/\" exists? "
        if [ -d "${subOUTPUTDIR}" ] ;then
            echo "OK"
        else
            mkdir -p "${subOUTPUTDIR}"
            echo "created"
        fi

        prepare_target_path "${subOUTPUTDIR}" "${NewName}.pdf"

        log_item "  target file: ${output}"

        if [[ "${keep_hash}" = "true" ]]; then
            cp -a "${keep_hash_input}" "${output}"
        else
            mv "${outputtmp}" "${output}"
            adjust_attributes "${keep_hash_input}" "${output}"
        fi
        file_processing_log 2 "${output}"
        synocr_processing_job_add_target "${output}"

    elif [ -n "${renameCat}" ] && [ "${moveTaggedFiles}" = useCatDir ] ; then
    # use sorting in category folder:
    # ---------------------------------------------------------------------
        log_item "move to category directory"

        # replace date parameters:
        renameCat=$(replace_variables "${renameCat}")

        # define target folder as array and purge duplicates:
##      IFS=" " read -r -a tagarray <<< "${renameCat}" ; IFS="${IFSsaved}"
        IFS=" " read -r -a tagarray <<< "$(echo "${renameCat}" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' ')" ; IFS="${IFSsaved}"

        # temp. list of used destination folders to avoid file duplicates (different tags, but one category):
        DestFolderList=""
        maxID=${#tagarray[*]}

        while (( i < maxID )); do
            tagdir="${tagarray[$i]//%20/ }"

            log_item_n "tag directory \"${tagdir}\" exists? "

            if echo "${tagdir}"| grep -q "^/volume*" ; then
                subOUTPUTDIR="${tagdir%/}/"
                if [ -d "${subOUTPUTDIR}" ] ;then
                    echo "OK [absolute path]"
                else
                    mkdir -p "${subOUTPUTDIR}"
                    echo "created [absolute path]"
                fi
            else
                # if path is not absolute, then remove special characters
                # tagdir=$(echo ${tagdir} | sed 's%\/\|\\\|\:\|\?%_%g' ) # filtered: \ / : ?
                subOUTPUTDIR="${OUTPUTDIR%/}/${tagdir%/}/"
                if [ -d "${subOUTPUTDIR}" ] ;then
                    echo "OK [subfolder target dir]"
                else
                    mkdir -p "${subOUTPUTDIR}"
                    echo "created [subfolder target dir]"
                fi
            fi

            prepare_target_path "${subOUTPUTDIR}" "${NewName}.pdf"

            log_item "  target:   ${subOUTPUTDIR%/}/${output##*/}"

            # check if the same file has already been sorted into this category (different tags, but same category)
            if echo -e "${DestFolderList}" | grep -q "^${tagarray[$i]}$" ; then
                log_item "  same file has already been copied into target folder (${tagarray[$i]}) and is skipped!"
            else
                if [[ $(echo "${outputtmp}" | awk -F/ '{print $2}') != $(echo "${output}" | awk -F/ '{print $2}') ]]; then
                    log_item "  do not set a hard link when copying across volumes"
                    # do not set a hardlink when copying across volumes:
                    if [[ "${keep_hash}" = "true" ]]; then
                        cp -a "${keep_hash_input}" "${output}"
                    else
                        cp "${outputtmp}" "${output}"
                    fi
                   file_processing_log 2 "${output}"
        synocr_processing_job_add_target "${output}"
                else
                    log_item "  set a hard link"
                    if [[ "${keep_hash}" = "true" ]]; then
                        commandlog=$(cp -al "${keep_hash_input}" "${output}" 2>&1 )
                    else
                        commandlog=$(cp -l "${outputtmp}" "${output}" 2>&1 )
                    fi
                    commandlog_rc=$?

                    # check: - creating hard link don't fails / - target file is valid (not empty)
                    if [ "${commandlog_rc}" -ne 0 ] || [ "$(stat -c %s "${output}")" -eq 0 ] || [ ! -f "${output}" ];then
                        log_item "  ${commandlog}"
                        log_warn_at "hard link failed for ${output}, using file copy"
                        if _synocr_log_ge2; then
                            log_debug "list of mounted volumes:"
                            df -h --output=source,target | log_block "${_LOG_INDENT}      "
                            log_blank
                        fi
                        if [[ "${keep_hash}" = "true" ]]; then
                            cp -fa "${keep_hash_input}" "${output}"
                        else
                            cp -f "${outputtmp}" "${output}"
                        fi
                    fi
                    file_processing_log 2 "${output}"
        synocr_processing_job_add_target "${output}"
                fi
                [[ "${keep_hash}" != "true" ]] && adjust_attributes "${keep_hash_input}" "${output}"
            fi

            DestFolderList="${tagarray[$i]}\n${DestFolderList}"
            i=$((i + 1))
            echo -e
        done
    
        rm "${outputtmp}"
    elif [ -n "${renameTag}" ] && [ "${moveTaggedFiles}" = useTagDir ] ; then
    # use sorting in tag folder:
    # ---------------------------------------------------------------------
        log_item "move to tag directory"
    
        if [ -n "${tagsymbol}" ]; then
            renameTag="${renameTag_raw//${tagsymbol}/ }"
        else
            renameTag="${renameTag_raw}"
        fi

        # define tags as array
        IFS=" " read -r -a tagarray <<< "${renameTag}" ; IFS="${IFSsaved}"
        maxID=${#tagarray[*]}
    
        while (( i < maxID )); do
            tagdir="${tagarray[$i]//%20/ }"

            log_item_n "tag directory \"${tagdir}\" exists? "

            if [ -d "${OUTPUTDIR}${tagdir}" ] ;then
                echo "OK"
            else
                mkdir "${OUTPUTDIR}${tagdir}"
                echo "created"
            fi

            prepare_target_path "${OUTPUTDIR}${tagdir}" "${NewName}.pdf"

            log_item "  target:   ./${tagdir}/${output##*/}"

            if [[ $(echo "${outputtmp}" | awk -F/ '{print $2}') != $(echo "${output}" | awk -F/ '{print $2}') ]]; then
                log_item "  do not set a hard link when copying across volumes"
                # do not set a hardlink when copying across volumes:
                if [[ "${keep_hash}" = "true" ]]; then
                    cp -a "${keep_hash_input}" "${output}"
                else
                    cp "${outputtmp}" "${output}"
                fi
                file_processing_log 2 "${output}"
        synocr_processing_job_add_target "${output}"
            else
                log_item "  set a hard link"
                if [[ "${keep_hash}" = "true" ]]; then
                    commandlog=$(cp -al "${keep_hash_input}" "${output}" 2>&1 )
                else
                    commandlog=$(cp -l "${outputtmp}" "${output}" 2>&1 )
                fi
                commandlog_rc=$?
                # check: - creating hard link don't fails / - target file is valid (not empty)
                if [ "${commandlog_rc}" -ne 0 ] || [ "$(stat -c %s "${output}")" -eq 0 ] || [ ! -f "${output}" ];then
                    log_item "  ${commandlog}"
                    log_warn_at "hard link failed for ${output}, using file copy"
                    if _synocr_log_ge2; then
                        log_debug "list of mounted volumes:"
                        df -h --output=source,target | log_block "${_LOG_INDENT}      "
                        log_blank
                    fi

                    if [[ "${keep_hash}" = "true" ]]; then
                        cp -af "${keep_hash_input}" "${output}"
                    else
                        cp -f "${outputtmp}" "${output}"
                    fi
                fi
                file_processing_log 2 "${output}"
        synocr_processing_job_add_target "${output}"
            fi

            [[ "${keep_hash}" != "true" ]] && adjust_attributes "${keep_hash_input}" "${output}"

            i=$((i + 1))
        done
    
        log_item "delete temp. target file"
        rm "${outputtmp}"
    else
    # no rule fulfilled - use the target folder:
    # ---------------------------------------------------------------------
        prepare_target_path "${OUTPUTDIR}" "${NewName}.pdf"

        log_item "  target file: ${output}"

        if [[ "${keep_hash}" = "true" ]]; then
            cp -af "${keep_hash_input}" "${output}"
        else
            mv "${outputtmp}" "${output}"
            adjust_attributes "${keep_hash_input}" "${output}"
        fi
        file_processing_log 2 "${output}"
        synocr_processing_job_add_target "${output}"
    fi

}


purge_log()
{
#########################################################################################
# This function cleans up older log files                                               #
#########################################################################################

    if [ -z "${LOGmax}" ]; then
        log_subsection "purge_log deactivated!"
        return
    fi

    log_subsection "purge log files ..."


# delete surplus logs:
# ---------------------------------------------------------------------
    count2del=$(( $(find "${LOGDIR}" -maxdepth 1 -type f -name 'synOCR*.log' -printf '.' | wc -c) - LOGmax ))
    [ "${count2del}" -lt 0 ] && count2del=0
    log_item "delete ${count2del} log files ( > ${LOGmax} files)"

    if [ "${count2del}" -gt 0 ]; then
        while read -r line ; do
            [ -z "${line}" ] && continue
            [ -f "${line}" ] && rm "${line}"
        done <<< "$(find "${LOGDIR}" -maxdepth 1 -type f -name 'synOCR*.log' -printf '%T@ %p\n' | sort -n | cut -d ' ' -f 2- | head -n${count2del} )"
    fi


# delete surplus search text files:
# ---------------------------------------------------------------------
    count2del=$(( $(find "${LOGDIR}" -maxdepth 1 -type f -name 'synOCR_searchfile*.txt' -printf '.' | wc -c) - LOGmax ))
    [ "${count2del}" -lt 0 ] && count2del=0
    log_item "delete ${count2del} search files ( > ${LOGmax} files)"

    if [ "${count2del}" -gt 0 ]; then
        while read -r line ; do
            [ -z "${line}" ] && continue
            [ -f "${line}" ] && rm "${line}"
        done <<< "$(find "${LOGDIR}" -maxdepth 1 -type f -name 'synOCR_searchfile*.txt' -printf '%T@ %p\n' | sort -n | cut -d ' ' -f 2- | head -n${count2del} )"
    fi

}


sql_escape()
{
#########################################################################################
# This function escapes strings for single quoted SQLite values                          #
#########################################################################################

    printf "%s" "$1" | sed "s/'/''/g"

}


register_backup_file()
{
#########################################################################################
# This function stores the backup file path and processing timestamp in the DB           #
#########################################################################################

    local backup_file_path="$1"
    local backup_dir_path="${backup_file_path%/*}/"
    local backup_filename="${backup_file_path##*/}"
    local backup_dir_sql backup_filename_sql sqlite3log

    if [ ! -f "${backup_file_path}" ]; then
        log_debug "backup DB entry skipped (file not found): ${backup_file_path}"
        return
    fi

    if ! synocr_sqlite "SELECT 1 FROM backup_dirs LIMIT 1;" >/dev/null 2>&1 \
       || ! synocr_sqlite "SELECT 1 FROM backup_files LIMIT 1;" >/dev/null 2>&1; then
        log_item "backup DB entry skipped (backup tables missing)"
        return
    fi

    backup_dir_sql=$(sql_escape "${backup_dir_path}")
    backup_filename_sql=$(sql_escape "${backup_filename}")

    sqlite3log=$(synocr_sqlite "BEGIN;
        INSERT OR IGNORE INTO backup_dirs (backup_dir) VALUES ('${backup_dir_sql}');
        DELETE FROM backup_files
            WHERE backup_dir_ID=(SELECT backup_dir_ID FROM backup_dirs WHERE backup_dir='${backup_dir_sql}')
              AND filename='${backup_filename_sql}';
        INSERT INTO backup_files (backup_dir_ID, profile_ID, filename, processing_timestamp)
            VALUES (
                (SELECT backup_dir_ID FROM backup_dirs WHERE backup_dir='${backup_dir_sql}'),
                '${profile_ID}',
                '${backup_filename_sql}',
                datetime('now','localtime')
            );
        COMMIT;" 2>&1)
    sqlite3rc=$?

    if [ "${sqlite3rc}" -ne 0 ]; then
        log_error_at "backup DB insert failed for ${backup_filename}"
        echo "${sqlite3log}" | log_block
    elif _synocr_log_ge2; then
        log_debug "backup DB entry created: ${backup_file_path}"
    fi

}


purge_backup_db_entries()
{
#########################################################################################
# This function deletes backup files selected from the DB and cleans up DB entries       #
#########################################################################################

    local entries_json="$1"
    local row backup_file_ID backup_file_path backup_file_dir rm_output rm_status

    while IFS= read -r row; do
        backup_file_ID=$(synocr_jq_row_field "${row}" backup_file_ID)
        backup_file_path=$(synocr_jq_row_field "${row}" backup_file_path)
        [ -z "${backup_file_ID}" ] && continue

        backup_file_dir="${backup_file_path%/*}"

        if [ -f "${backup_file_path}" ]; then
            rm_output=$(rm -f"${rm_log_level}" "${backup_file_path}" 2>&1)
            rm_status=$?
            [ -n "${rm_output}" ] && echo "${rm_output}" | log_block

            if [ "${rm_status}" -eq 0 ]; then
                synocr_sqlite "DELETE FROM backup_files WHERE backup_file_ID='${backup_file_ID}';"
            else
                log_item "backup file could not be removed, DB entry kept: ${backup_file_path}"
            fi
        elif [ -d "${backup_file_dir}" ]; then
            log_item "backup file already missing, remove DB entry: ${backup_file_path}"
            synocr_sqlite "DELETE FROM backup_files WHERE backup_file_ID='${backup_file_ID}';"
        else
            log_item "backup path not available, DB entry kept: ${backup_file_path}"
        fi
    done < <(synocr_jq_rows "${entries_json}")

}


check_orphaned_backup_entries()
{
#########################################################################################
# This function checks orphaned backup DB entries once per day for the current profile #
#########################################################################################

    local orphan_system_key="backup_orphan_check_${profile_ID}"
    local last_check_date orphan_entries orphan_checked=0 orphan_count=0 orphan_deleted=0
    local backup_file_ID backup_file_path orphan_id_batch batch_size=500 id_count_in_batch

    if ! synocr_sqlite "SELECT 1 FROM backup_dirs LIMIT 1;" >/dev/null 2>&1 \
       || ! synocr_sqlite "SELECT 1 FROM backup_files LIMIT 1;" >/dev/null 2>&1; then
        return
    fi

    last_check_date=$(synocr_sqlite "SELECT substr(value_1,1,10) FROM system WHERE key='${orphan_system_key}';")
    if [ "${last_check_date}" = "$(date +%F)" ]; then
        log_debug "orphaned backup check skipped (already done today)"
        return
    fi

    log_subsection "check orphaned backup DB entries ..."

    orphan_entries=$(synocr_sqlite -json "SELECT
            bf.backup_file_ID AS backup_file_ID,
            (bd.backup_dir || bf.filename) AS backup_file_path
        FROM backup_files bf
        JOIN backup_dirs bd ON bf.backup_dir_ID=bd.backup_dir_ID
        WHERE bf.profile_ID='${profile_ID}'
        ORDER BY bf.backup_file_ID;")

    orphan_id_batch=""
    id_count_in_batch=0

    while IFS= read -r row; do
        backup_file_ID=$(synocr_jq_row_field "${row}" backup_file_ID)
        backup_file_path=$(synocr_jq_row_field "${row}" backup_file_path)
        [ -z "${backup_file_ID}" ] && continue
        orphan_checked=$(( orphan_checked + 1 ))

        if [ ! -e "${backup_file_path}" ]; then
            orphan_count=$(( orphan_count + 1 ))

            if [ "${backup_clean_orphaned}" = true ]; then
                if [ -n "${orphan_id_batch}" ]; then
                    orphan_id_batch="${orphan_id_batch},${backup_file_ID}"
                else
                    orphan_id_batch="${backup_file_ID}"
                fi
                id_count_in_batch=$(( id_count_in_batch + 1 ))

                if [ "${id_count_in_batch}" -ge "${batch_size}" ]; then
                    synocr_sqlite "DELETE FROM backup_files WHERE backup_file_ID IN (${orphan_id_batch});"
                    orphan_deleted=$(( orphan_deleted + id_count_in_batch ))
                    orphan_id_batch=""
                    id_count_in_batch=0
                fi
            fi
        fi
    done < <(synocr_jq_rows "${orphan_entries}")

    if [ "${backup_clean_orphaned}" = true ] && [ -n "${orphan_id_batch}" ]; then
        synocr_sqlite "DELETE FROM backup_files WHERE backup_file_ID IN (${orphan_id_batch});"
        orphan_deleted=$(( orphan_deleted + id_count_in_batch ))
    fi

    if [ "$(synocr_sqlite "SELECT COUNT(*) FROM system WHERE key='${orphan_system_key}';")" -eq 0 ]; then
        synocr_sqlite "INSERT INTO system (key, value_1, value_2)
            VALUES ('${orphan_system_key}', datetime('now','localtime'), '${orphan_count}');"
    else
        synocr_sqlite "UPDATE system
            SET value_1=datetime('now','localtime'), value_2='${orphan_count}'
            WHERE key='${orphan_system_key}';"
    fi

    log_item "checked ${orphan_checked} backup DB entries, found ${orphan_count} orphaned"
    if [ "${backup_clean_orphaned}" = true ]; then
        log_item "removed ${orphan_deleted} orphaned backup DB entries"
    fi

}


purge_backup()
{
#########################################################################################
# This function cleans up older backup files                                            #
#########################################################################################

    if [ -z "${backup_max}" ] || [ "${backup_max}" = 0 ]; then
        log_subsection "purge backup deactivated!"
        return
    fi

    if ! synocr_is_integer "${backup_max}"; then
        log_warn_at "purge backup skipped — invalid backup_max: expected integer, got [${backup_max}]"
        return
    fi

    log_subsection "purge backup files ..."

    if ! synocr_sqlite "SELECT 1 FROM backup_dirs LIMIT 1;" >/dev/null 2>&1 \
       || ! synocr_sqlite "SELECT 1 FROM backup_files LIMIT 1;" >/dev/null 2>&1; then
        log_item "backup rotation skipped (backup tables missing)"
        return
    fi

    if [ "${img2pdf}" = true ]; then
        source_file_type4sql="(
            LOWER(bf.filename) GLOB '*.jpg' OR
            LOWER(bf.filename) GLOB '*.jpeg' OR
            LOWER(bf.filename) GLOB '*.png' OR
            LOWER(bf.filename) GLOB '*.tiff' OR
            LOWER(bf.filename) GLOB '*.pdf'
        )"
    else
        source_file_type4sql="(LOWER(bf.filename) GLOB '*.pdf')"
    fi

# delete surplus backup files:
# ---------------------------------------------------------------------
    if [[ "${backup_max_type}" == days ]]; then
        count2del=$(synocr_sqlite "SELECT COUNT(*)
            FROM backup_files bf
            WHERE bf.profile_ID='${profile_ID}'
              AND ${source_file_type4sql}
              AND datetime(bf.processing_timestamp) < datetime('now','localtime','-${backup_max} days');")
        backup_files2del=$(synocr_sqlite -json "SELECT
                bf.backup_file_ID AS backup_file_ID,
                (bd.backup_dir || bf.filename) AS backup_file_path
            FROM backup_files bf
            JOIN backup_dirs bd ON bf.backup_dir_ID=bd.backup_dir_ID
            WHERE bf.profile_ID='${profile_ID}'
              AND ${source_file_type4sql}
              AND datetime(bf.processing_timestamp) < datetime('now','localtime','-${backup_max} days')
            ORDER BY datetime(bf.processing_timestamp), bf.backup_file_ID;")
        log_item "delete ${count2del} backup files ( > ${backup_max} days)"
        purge_backup_db_entries "${backup_files2del}"
    else
        backup_file_count=$(synocr_sqlite "SELECT COUNT(*)
            FROM backup_files bf
            WHERE bf.profile_ID='${profile_ID}'
              AND ${source_file_type4sql};")
        count2del=$(( backup_file_count - backup_max ))
        [ "${count2del}" -lt 0 ] && count2del=0
        log_item "delete ${count2del} backup files ( > ${backup_max} files)"

        if [ "${count2del}" -gt 0 ]; then
            backup_files2del=$(synocr_sqlite -json "SELECT
                    bf.backup_file_ID AS backup_file_ID,
                    (bd.backup_dir || bf.filename) AS backup_file_path
                FROM backup_files bf
                JOIN backup_dirs bd ON bf.backup_dir_ID=bd.backup_dir_ID
                WHERE bf.profile_ID='${profile_ID}'
                  AND ${source_file_type4sql}
                ORDER BY datetime(bf.processing_timestamp), bf.backup_file_ID
                LIMIT ${count2del};")
            purge_backup_db_entries "${backup_files2del}"
        fi
    fi

}


py_page_count()
{
#########################################################################################
# This function receives a PDF file path and give back number of pages                  #
#########################################################################################

    python3 -c "import sys, os, fitz; \
                path = os.path.abspath(sys.argv[1]); \
                print(fitz.open(path).page_count)" "$1"
}


collect_input_files()
{
#########################################################################################
# This function search for valid files in input folder, which fit the current profile   #
#########################################################################################

    source_dir="${1%/}/"
    if [ "${2}" = "image" ]; then # image or pdf
        source_file_type="\(JPG\|jpg\|PNG\|png\|TIFF\|tiff\|JPEG\|jpeg\)"
    else
        source_file_type="\(PDF\|pdf\)"
    fi

    exclusion=false
    SearchPraefix_tmp="${SearchPraefix}"
    unset SearchSuffix     # defined in next step to correct rename splitted files
    unset files

    if [[ "${SearchPraefix_tmp}" =~ ^! ]]; then
        # is the prefix / suffix an exclusion criteria?
        exclusion=true
        SearchPraefix_tmp="${SearchPraefix_tmp#!}"
    fi

    if [[ "${SearchPraefix_tmp}" =~ \$+$ ]]; then
        SearchPraefix_tmp="${SearchPraefix_tmp%?}"
        if [ "${exclusion}" = false ] ; then
            # is suffix
            files=$(find "${source_dir}" -maxdepth 1 -regex "${source_dir}.*${SearchPraefix_tmp}\.${source_file_type}$" )
            SearchSuffix="${SearchPraefix_tmp}"
        elif [ "${exclusion}" = true ] ; then
            # is exclusion suffix
            files=$(find "${source_dir}" -maxdepth 1 -regex "${source_dir}.*\.${source_file_type}$" -not -iname "*${SearchPraefix_tmp}.*" -type f )
        fi
    else
        SearchPraefix_tmp="${SearchPraefix_tmp%%\$}"
        if [ "${exclusion}" = false ] ; then
            # is prefix
            files=$(find "${source_dir}" -maxdepth 1 -regex "${source_dir}${SearchPraefix_tmp}.*\.${source_file_type}$" )
        elif [ "${exclusion}" = true ] ; then
            # is exclusion prefix
            files=$(find "${source_dir}" -maxdepth 1 -regex "${source_dir}.*\.${source_file_type}$" -not -iname "${SearchPraefix_tmp}*" -type f )
        fi
    fi

}


prepare_target_path()
{
#########################################################################################
# This function prepares the variable $output for a given file in the target folder,    #
# modifying it if necessary to avoid duplicates by appending an incrementing counter.   #
#                                                                                       #
#   $1  ➜ target path                                                                   #
#   $2  ➜ target filename                                                               #
#                                                                                       #
#   The variable $output will be set for subsequent use.                                #
#########################################################################################


    local target_dir_path="${1%/}/"
    local target_filename="$2"
    local base ext source_counter=0

    # Parse source filename
    if [[ "$target_filename" =~ ^(.*)\ \(([0-9]+)\)\.([^.]*)$ ]]; then
        base="${BASH_REMATCH[1]}"
        source_counter="${BASH_REMATCH[2]}"
        ext="${BASH_REMATCH[3]}"
    elif [[ "$target_filename" =~ ^(.*)\.([^.]*)$ ]]; then
        base="${BASH_REMATCH[1]}"
        ext="${BASH_REMATCH[2]}"
    else
        base="$target_filename"
        ext=""
    fi

    # Check whether the source counter can be used directly
    if ((source_counter > 0)); then
        local source_counter_file="${target_dir_path}${base} (${source_counter}).${ext}"
        if [ ! -f "$source_counter_file" ]; then
            output="$source_counter_file"
            log_item "Using source counter: ${source_counter}"
            log_blank
            return
        fi
    fi

    # Collect existing counters (including the base file)
    local existing_counters=()
    [ -f "${target_dir_path}${base}.${ext}" ] && existing_counters+=(0)
    while IFS= read -r -d '' file; do
        if [[ "$(basename "$file")" =~ \ \(([0-9]+)\)\.${ext}$ ]]; then
            existing_counters+=("${BASH_REMATCH[1]}")
        fi
    done < <(find "${target_dir_path}" -maxdepth 1 -type f -name "${base} (*).${ext}" -print0 2>/dev/null)

    # No files found ➜ Use base name
    if [ ${#existing_counters[@]} -eq 0 ]; then
        output="${target_dir_path}${base}.${ext}"
        return
    fi

    # Determine the highest counter
    local existing_max=0
    for n in "${existing_counters[@]}"; do
        ((n > existing_max)) && existing_max=$n
    done

    # Set the starting counter
    local start_counter=$((existing_max + 1))

    # Find the next available counter
    local counter=$start_counter
    while [ -f "${target_dir_path}${base} (${counter}).${ext}" ]; do
        counter=$((counter + 1))
    done

    # Always set the output path with a counter if files exist
    output="${target_dir_path}${base} (${counter}).${ext}"
    log_item "New counter: (${counter})"
    log_blank

}


py_img2pdf()
{
#########################################################################################
# This function convert images to pdf                                                   #
# https://datatofish.com/images-to-pdf-python/                                          #
#########################################################################################

log_subsection "convert images to pdf"

collect_input_files "${INPUTDIR}" "image"

[ -z "${files}" ] && log_item "nothing to do ..." && return 0

file_total=$(printf '%s\n' "${files}" | sed '/^$/d' | wc -l | tr -d ' ')
file_index=0

while read -r input ; do
    [ ! -f "${input}" ] && continue
    file_index=$((file_index + 1))
    log_blank
    filename="${input##*/}"
    title="${filename%.*}"
    log_file "${filename} (source)" "${file_index}" "${file_total}"
    synocr_status_update_step img2pdf "${filename}"
#    date_start=$(date +%s)


# convert file
# ---------------------------------------------------------------------
    prepare_target_path "${INPUTDIR}" "${title}${SearchSuffix}.pdf"
    log_item "target: ${output}"
    {   echo 'import  PIL as pillow'
        echo 'from PIL import Image'
        echo 'image_1 = Image.open(r"'"${input}"'")'
        echo "im_1 = image_1.convert('RGB')"
        echo 'im_1.save(r"'"${output}"'")'
        echo 'exit()'
    } | python3 


# backup source
# ---------------------------------------------------------------------
   if [ "$(stat -c %s "${output}")" -ne 0 ] && [ -f "${output}" ];then
        if [ "${backup}" = true ]; then
            log_item "backup source file" # to $output"
            prepare_target_path "${BACKUPDIR}" "${filename}"
            if mv "${input}" "${output}"; then
                register_backup_file "${output}"
            else
                log_error_at "backup copy failed: ${input}"
            fi
        else
            log_item "delete source file (${filename})"
            rm -f "${input}"
        fi
    else
        log_error_at "img2pdf failed — target empty or missing: ${output}"
    fi

done <<<"${files}"

}


main_1st_step()
{
#########################################################################################
# This function passes the files to docker / split files / …                            #
#########################################################################################

log_section "STEP 1 - RUN OCR / SPLIT FILES, IF NEEDED:"

collect_input_files "${INPUTDIR}" "pdf"
files_step1="${files}"
file_total=$(printf '%s\n' "${files_step1}" | sed '/^$/d' | wc -l | tr -d ' ')
file_index=0

while read -r input1 ; do
    [ ! -f "${input1}" ] && continue
    file_index=$((file_index + 1))


# use delay for permanent writing scanners
# (some scanners write each page individually and reopen the file. The delay
#  ensures we only start when the file has been quiet for ${delay}s AND at
#  least ${delay}s have passed since we first noticed the file. mtime values
#  far in the future, e.g. due to scanner clock skew or wrong time zones,
#  are capped so the loop cannot block indefinitely.)
# ---------------------------------------------------------------------
    if [[ ${delay:-0} -ne 0 ]]; then
        synocr_status_update_step delay "${filename}"
        delay_loop_start=$(date +%s)
        while true; do
            current_time=$(date +%s)
            file_time=$(stat -c %Y "${input1}")

            # cap mtime that lies more than ${delay}s in the future
            if [ "${file_time}" -gt $((delay_loop_start + delay)) ]; then
                effective_mtime=${delay_loop_start}
                future_note=" [mtime ${file_time} more than ${delay}s in the future, capped to loop start]"
            else
                effective_mtime=${file_time}
                future_note=""
            fi

            # condition 1: at least ${delay}s elapsed since loop start
            # condition 2: file (effective) mtime is at least ${delay}s old
            if [ "${current_time}" -ge $((delay_loop_start + delay)) ] \
               && [ "${current_time}" -ge $((effective_mtime + delay)) ]; then
                log_note "delayed processing started (waited $((current_time - delay_loop_start))s, delay=${delay}s${future_note})"
                break
            fi
            sleep 1
        done
    fi


# create temporary working directory
# ---------------------------------------------------------------------
    work_tmp_step1="${work_tmp_main%/}/step1_tmp_$(uuidgen)/"
    mkdir -p "${work_tmp_step1}"

    log_blank
    source_filename="${input1##*/}"
    filename="${source_filename}"
    title="${filename%.*}"
    keep_hash_input="${input1}"
    log_file "${filename}" "${file_index}" "${file_total}"
    file_processing_log 1 "${filename}"
    synocr_processing_job_start "${filename}"
    synocr_status_file_pipeline_start "${filename}"
    date_start_file=$(date +%s)
    was_splitted=0
    split_output_count=0
    split_error=0
    process_error=1 # is set to 0 in the file_processing_log() function when the target file is successfully created

    outputtmp="${work_tmp_step1%/}/${title}.pdf"
    log_item "  temp. target file: ${outputtmp}"


# adjust color
# ---------------------------------------------------------------------
    # Initialize array for additional arguments
    args=()
    adjustColor=false
    unset adjustColorSuccess

    # Add --threshold only when adjustColorBWthreshold is not empty
    if [ "${adjustColorBWthreshold}" != "0" ]; then
        args+=(--threshold "${adjustColorBWthreshold}")
        if [ "${adjustColorBWabsoluteThreshold}" != "0" ]; then
            args+=(--absolute-threshold "${adjustColorBWabsoluteThreshold}")
        fi
        adjustColor=true
    fi

    # Add --dpi only when adjustColorDPI is not empty
    if [ "${adjustColorDPI}" != "0" ]; then
        # 0, 72, 75, 100, 150, 200, 300, 400, 450, 600
        args+=(--dpi "$adjustColorDPI")
#        adjustColor=true
    fi

    # --contrast nur hinzufügen, wenn nicht 1 und nicht 1.0
    if [ "${adjustColorContrast}" != "1" ] && [ "${adjustColorContrast}" != "1.0" ]; then
        args+=(--contrast "${adjustColorContrast}")
        adjustColor=true
    fi

    # Add --sharpness only when not 1 and not 1.0
    if [ "${adjustColorSharpness}" != "1" ] && [ "${adjustColorSharpness}" != "1.0" ]; then
        args+=(--sharpness "${adjustColorSharpness}")
        adjustColor=true
    fi

    if [ "${adjustColor}" = true ] && [[ "${keep_hash}" = "true" ]]; then
        log_note "adjustColor is disabled because --keep_hash is set"
        log_blank
    elif [ "${adjustColor}" = true ] && [ "${python_check}" = "ok" ]; then
        synocr_status_update_step color_adjust "${filename}"
        log_subsection " adjust color"
        log_item "used parameter: ${args[*]}"

        mkdir "${work_tmp_step1%/}/pdf2bw"
        color_adjustment_target="${work_tmp_step1%/}/pdf2bw/${outputtmp##*/}"
        [ -s "${color_adjustment_target}" ] && rm -f "${color_adjustment_target}" # Delete previous file
        unset input_bw

        adjustColorLOG=$(python3 ./includes/color_adjustment.py "${input1}" "${color_adjustment_target}" "${args[@]}" )
        exit_code=$?

        if [ "${exit_code}" -eq 0 ] && [ -s "${color_adjustment_target}" ]; then
            log_item "PDF successfully adjust color"
            adjustColorSuccess=true
        else
            log_error_at "color_adjustment.py failed (exit ${exit_code}) for ${input1}"
            [ -n "${adjustColorLOG}" ] && printf '%s\n' "${adjustColorLOG}" | log_block "${_LOG_INDENT_DETAIL}  "
        fi
        log_debug "adjustColorLOG: $adjustColorLOG"
        unset exit_code
    fi

    unset args

    log_runtime $(( $(date +%s) - date_start_file ))

# OCRmyPDF:
# ---------------------------------------------------------------------
    synocr_status_update_step ocr "${filename}"
    log_subsection "processing PDF @ OCRmyPDF:"

    dockerlog=$(OCRmyPDF 2>&1)

    log_item "OCRmyPDF-LOG:"
    echo "${dockerlog}" | log_block "${_LOG_INDENT}  "
    log_note "← OCRmyPDF-LOG-END"
    log_blank

    # check if target file is valid (not empty), otherwise continue / 
    # defective source files are moved to ERROR including LOG:
    # ---------------------------------------------------------------------
    if [ ! -f "${outputtmp}" ] || [ "$(stat -c %s "${outputtmp}" 2>/dev/null)" -eq 0 ]; then
        log_error_at "OCR target empty or missing: ${outputtmp}"
        rm -f "${outputtmp}"
        if echo "${dockerlog}" | grep -iq ERROR ;then
            if [ ! -d "${INPUTDIR}ERRORFILES" ] ; then
                log_item "                  ERROR-Directory [${INPUTDIR}ERRORFILES] will be created!"
                mkdir "${INPUTDIR}ERRORFILES"
            fi

            prepare_target_path "${INPUTDIR}ERRORFILES" "${filename}"

            mv "${input1}" "${output}"
            [ "${loglevel}" != 0 ] && cp "${current_logfile}" "${output}.log"
            log_item_deep "move to ERRORFILES"
        fi
        # Always close the history job as failed when OCR produced no usable output
        # (do not gate status on OCRmyPDF log text).
        synocr_processing_job_fail
        rm -rf "${work_tmp_step1}"
        continue
    else
        log_item "target file (OK): ${outputtmp}"
        log_blank
    fi

    log_runtime $(( $(date +%s) - date_start_file ))

# detect & remove blank pages with scanrep (https://pypi.org/project/scanprep/):
# ---------------------------------------------------------------------
    if [ "${blank_page_detection_switch}" = true ] && [ "${python_check}" = "ok" ]; then
        synocr_status_update_step blank_pages "${filename}"
        log_subsection "detect & remove blank pages:"

        pagePreCount=$( py_page_count "${outputtmp}" )
        mkdir "${work_tmp_step1%/}/scanrep"

        ignore_text_param=""
        [ "${blank_page_detection_ignoreText}" = "true" ] && ignore_text_param="--ignore_text"

        python3 ./includes/blank_page_detection.py "${outputtmp}" "${work_tmp_step1%/}/scanrep" \
            --threshold "${blank_page_detection_mainThreshold}" \
            --width-crop "${blank_page_detection_widthCropping}" \
            --height-crop "${blank_page_detection_hightCropping}" \
            --max-filter "${blank_page_detection_interferenceMaxFilter}" \
            --min-filter "${blank_page_detection_interferenceMinFilter}" \
            --black-pixel-ratio "${blank_page_detection_black_pixel_ratio}" \
            ${ignore_text_param}
        wait

        scanrep_out=("${work_tmp_step1%/}/scanrep/"*.pdf)
        if [ -f "${scanrep_out[0]}" ]; then
            mv -f "${scanrep_out[0]}" "${outputtmp}"

            # Set to zero in case of error to avoid calculation errors
            pagePreCount=${pagePreCount:-0}
            pagePostCount=${pagePostCount:-0}

            pagePostCount=$( py_page_count "${outputtmp}" )
            log_item "$((pagePreCount - pagePostCount)) (blank pages) out of ${pagePreCount} pages removed."
            log_blank
        else
            log_error_at "blank page detection failed — no valid target PDF after scanrep for ${outputtmp}"
            log_blank
        fi
        log_runtime $(( $(date +%s) - date_start_file ))
    fi


# document split handling
# ---------------------------------------------------------------------
    if [ -n "${documentSplitPattern}" ] && [ "${python_check}" = "ok" ]; then
        synocr_status_update_step split "${filename}"
        log_subsection "document split handling:"

    # identify split pages / write to an array:
    # ---------------------------------------------------------------------
        pageCount=$( py_page_count "${outputtmp}" )

        if [[ "${pageCount}" =~ ^[0-9]+$ ]]; then
            p=1
            splitPages=( )
            if [[ "${documentSplitPattern}" = "<split each page>" ]]; then
                while [ "${p}" -le "${pageCount}" ]; do
                    splitPages+=( "${p}" )
                    p=$((p+1))
                done
            else
                while [ "${p}" -le "${pageCount}" ]; do
                    if pdftotext "${outputtmp}" -f $p -l $p -layout - | grep -q "${documentSplitPattern}" ; then
                        splitPages+=( "${p}" )
                    fi
                    p=$((p+1))
                done
            fi
        else
            log_error_at "invalid page count for split handling: expected integer, got [${pageCount}] (tool: py_page_count)"
        fi

    # split document:
    # ---------------------------------------------------------------------
        unset splitJob

        split_pages(){

            log_item "part:            ${1}"
            log_item "first page:      ${2}"
            log_item "last page:       ${3}"
#           log_item "splitted file:   $4"

            pageRange=$(seq -s ", " "${2}" 1 "${3}" )
            log_item "used pages:      ${pageRange}"

            #######################################################################
            #  Split pdf files to separate pages
            #  parameter:
            #  -task:         split, writeMetadata(not implemented)
            #  -inputFile:    input pdf filename (with path)
            #  -outputFile:   output pdf filename (with path)
            #  -startPage:    first page from inputfile transfered to outputfile (1 based)
            #  -endPage:      last page ( 1 based )
            #  -dbg_file:     filename to write debug info
            #  -dbg_lvl:      debug level (1=info, 2=debug, 0=0ff)

            log_debug "call handlePdf.py: -dbg_lvl ${loglevel} -dbg_file ${current_logfile} -task split -inputFile ${outputtmp} -startPage ${2} -endPage ${3} -outputFile ${4}"

            python3 ./includes/handlePdf.py -dbg_lvl "${loglevel}" \
                                            -dbg_file "${current_logfile}" \
                                            -task split \
                                            -inputFile "${outputtmp}" \
                                            -startPage "${2}"  \
                                            -endPage "${3}"  \
                                            -outputFile "${4}"
        }

    # calculate site ranges for splitting
    # ---------------------------------------------------------------------
        SplitPageCount=${#splitPages[@]}
        log_item "splitpage count: ${SplitPageCount}"
        log_blank

        if (( "${SplitPageCount}" > 0 )) && (( "${pageCount}" > 1 )); then
            currentPart=0
            startPage=1
            page=1
            unset arrayIndex

            getIndex() {
                # to calculate the end point of current range we need the current index in array:
                local page="${1}"

                for i in "${!splitPages[@]}"; do
                    if [[ "${splitPages[$i]}" = "${page}" ]]; then
                        echo "${i}"
                        break
                   fi
                done
            }

            if [ "${splitpagehandling}" = isFirstPage ]; then
                # method for 'FirstPage':
                while (( page <= pageCount )); do
                    arrayIndex=$( getIndex ${page} )
    
                    # page is 1 OR (ArrayIndex is not empty AND page corresponds to splitpage with corresponding index)
                    if { [ -n "${arrayIndex}" ] && [ "${page}" -eq "${splitPages[$arrayIndex]}"  ]; } || [ "${page}" -eq 1 ]; then
                        currentPart=$((currentPart+1))

                        # set startPage:
                        startPage=${page}

                        # set endpage:
                        if [ "${arrayIndex}" = $(( SplitPageCount - 1)) ]; then
                            # if last splitpage:
                            endPage=${pageCount}
                        elif [ -z "${arrayIndex}" ]; then
                            # e.g. the first page is not a split page
                            endPage=$((splitPages[0]-1))
                        else
                            endPage=$((splitPages[arrayIndex+1]-1))
                        fi
                        splitJob=$(printf '%s %s %s\n%s' "${currentPart}" "${startPage}" "${endPage}" "${splitJob}")
                    fi

                    page=$((page+1))
                done
            else
                # method for 'lastPage' & 'discard':
                for splitPage in "${splitPages[@]}"; do
                    if [ "${splitpagehandling}" = discard ]; then
                        [ "${splitPage}" -eq 1 ] && startPage=$((splitPage+1)) && continue  # continue, if first page a splitPage
                        currentPart=$((currentPart+1))
                        endPage=$((splitPage-1))
                        splitJob=$(printf '%s %s %s\n%s' "${currentPart}" "${startPage}" "${endPage}" "${splitJob}")
                    elif [ "${splitpagehandling}" = isLastPage ]; then
                        currentPart=$((currentPart+1))
                        endPage=${splitPage}
                        splitJob=$(printf '%s %s %s\n%s' "${currentPart}" "${startPage}" "${endPage}" "${splitJob}")
                    fi

                    # startPage for next range:
                    if [ "${splitpagehandling}" = discard ]; then
                        startPage=$((splitPage+1))
                    elif [ "${splitpagehandling}" = isLastPage ]; then
                        startPage=$((endPage+1))
                    fi
                done

                # last range behind last splitPage:
                if (( "${pageCount}" > ${splitPages[@]:(-1)} )); then

                    if [ "${splitpagehandling}" = discard ]; then
                        currentPart=$((currentPart+1))
                        startPage=$((splitPages[${#splitPages[@]}-1]+1))
                        endPage=${pageCount}

                        splitJob=$(printf '%s %s %s\n%s' "${currentPart}" "${startPage}" "${endPage}" "${splitJob}")
                    elif [ "${splitpagehandling}" = isLastPage ]; then
                        currentPart=$((currentPart+1))
                        startPage=$((endPage+1))
                        endPage=${pageCount}

                        splitJob=$(printf '%s %s %s\n%s' "${currentPart}" "${startPage}" "${endPage}" "${splitJob}")
                    fi
                fi
            fi

            # run splitting:
            while read -r line; do
                currentPart=$(echo "${line}" | awk -F' ' '{print $1}')
                startPage=$(echo "${line}" | awk -F' ' '{print $2}')
                endPage=$(echo "${line}" | awk -F' ' '{print $3}')

                # if two separation pages follow each other, this will result in an empty PDF file. This case will be skipped:
                [ "${startPage}" -gt "${endPage}" ] && [ "${splitpagehandling}" = discard ] && continue

                # split pages:
                splitted_file_name="${title}_${currentPart}${SearchSuffix}.pdf"
                splitted_file="${work_tmp_step1}/${splitted_file_name}"
                split_pages "${currentPart}" "${startPage}" "${endPage}" "${splitted_file}"


                # move splitted file to work_tmp_main with override protection
                if [ -f "${splitted_file}" ]; then
                    prepare_target_path "${work_tmp_main}" "${splitted_file_name}"
                    mv "${splitted_file}" "${output}"
                    copy_attributes "${input1}" "${output}"
                    log_item "move the split file to: ${output}"
                    was_splitted=1
                    split_output_count=$((split_output_count + 1))
                else
                    log_error_at "split failed — output file missing: ${splitted_file} (pages ${startPage}-${endPage})"
                    split_error=1
                fi
            done <<<"$(sort <<<"${splitJob}")"
        else
            log_item "no separator sheet found, or number of pages too small"
        fi
    else
        log_item "no split pattern defined or splitting not possible"
    fi

    if [[ ("${was_splitted}" = 0 || "${split_error}" = 1) && "${keep_hash}" != "true" ]]; then
        copy_attributes "${input1}" "${outputtmp}"
    fi

    if [ "${was_splitted}" = 0 ] || [ "${split_error}" = 1 ]; then
        mv "${outputtmp}" "${work_tmp_main}"
    fi

    # Keep the GUI total aligned with split output files.
    if [ "${was_splitted}" = 1 ] && [ "${split_error}" = 0 ] && [ "${split_output_count}" -gt 1 ]; then
        additional_files=$((split_output_count - 1))
        status_file="$(synocr_status_file_path)"
        current_progress_total=0
        if [ -s "${status_file}" ]; then
            current_progress_total=$(jq -r '.files_total // 0' "${status_file}" 2>/dev/null)
        fi
        current_progress_total=${current_progress_total:-0}
        synocr_status_write_monotonic_int files_total "$((current_progress_total + additional_files))"
        log_item "GUI progress total increased by ${additional_files} split output file(s)."
    fi

    log_runtime $(( $(date +%s) - date_start_file ))

    # 2. main loop for PDF processing:
    main_2nd_step


# delete / save source file (takes into account existing files with the same name):
# ---------------------------------------------------------------------
    log_subsection "handle source file:"

    if [ "${backup}" = true ] && [ "${process_error}" -eq 0 ]; then
        prepare_target_path "${BACKUPDIR}" "${source_filename}"
        if mv "${input1}" "${output}"; then
            log_item "backup source file to: ${output}"
            register_backup_file "${output}"
        else
            log_error_at "backup copy failed: ${input1}"
        fi
        synocr_processing_job_succeed
    elif [ "${process_error}" -eq 1 ]; then
        # target file is not valid / source files are moved to ERRORFILES including LOG:
        log_error_at "processing failed (process_error=1) for ${input1}"
        if [ ! -d "${INPUTDIR}ERRORFILES" ] ; then
            log_item "                  ERROR-Directory [${INPUTDIR}ERRORFILES] will be created!"
            mkdir "${INPUTDIR}ERRORFILES"
        fi

        prepare_target_path "${INPUTDIR}ERRORFILES" "${input1}"

        mv "${input1}" "${output}"
        [ "${loglevel}" != 0 ] && cp "${current_logfile}" "${output}.log"
        log_item_deep "move to ERRORFILES"
        rm -rf "${work_tmp_step1}"
        synocr_processing_job_fail
    else
        rm -f "${input1}"
        log_item "delete source file (${filename})"
        synocr_processing_job_succeed
    fi

    rm -rfv "${work_tmp_step1}" | log_block

    log_blank
done <<<"${files_step1}"

}


main_2nd_step()
{
#########################################################################################
# This function search for tags / rename / sort to target folder                        #
#########################################################################################
log_section "STEP 2 - SEARCH TAGS / RENAME / SORT:"

collect_input_files "${work_tmp_main}" "pdf"
files_step2="${files}"
file_total=$(printf '%s\n' "${files_step2}" | sed '/^$/d' | wc -l | tr -d ' ')
file_index=0

# make special characters visible if necessary
# ---------------------------------------------------------------------
    # shellcheck disable=SC2012  # Don't warn about "Use find instead of ls to better handle non-alphanumeric filenames" in this function
    if _synocr_log_ge2; then
        log_debug "list files in INPUT with transcoded special characters:"
        ls "${work_tmp_main}" | sed -ne 'l' | log_block
        log_blank
    fi

# save different global settings to be able to adjust them individually with yaml rules in each loop:
    apprise_call_saved="${apprise_call}"
    apprise_attachment_saved="${apprise_attachment}"
    notify_lang_saved="${notify_lang}"

# ---------------------------------------------------------------------
while read -r input ; do
    [ ! -f "${input}" ] && continue
    file_index=$((file_index + 1))

    # reset global settings for new file:
    apprise_call="${apprise_call_saved}"
    apprise_attachment="${apprise_attachment_saved}"
    notify_lang="${notify_lang_saved}"


# create temporary working directory
# ---------------------------------------------------------------------
    work_tmp_step2="${work_tmp_main%/}/step2_tmp_$(uuidgen)/"
    mkdir -p "${work_tmp_step2}"


# move temporary file to destination folder:
# ---------------------------------------------------------------------
    output="${work_tmp_step2%/}/tmp_$(uuidgen).pdf"
    cp "${input}" "${output}"

    log_blank
    filename="${input##*/}"
    title="${filename%.*}"
    log_file "${filename}" "${file_index}" "${file_total}"
    synocr_status_update_step pdftotext "${filename}"
    tmp_date_search_method="${date_search_method}"    # able to use a temporary fallback to regex for each file

    if [ "${delSearchPraefix}" = "yes" ] && [ -n "${SearchPraefix}" ]; then
        if [[ "${SearchPraefix}" == *\$ ]]; then
            # Suffix mode: Remove the suffix at the end of the file name
            suffix="${SearchPraefix%\$}"
            title="${title%${suffix}}"
        else
            # Prefix mode: Remove the prefix at the beginning of the file name
            title="${title#${SearchPraefix}}"
        fi
    fi


# adapt counter:
# ---------------------------------------------------------------------
    if [ "${python_check}" = ok ]; then
        pagecount_latest=$( py_page_count "${output}" ) 
        log_debug "(pages counted with python module fitz)"
    elif [ "$(which pdfinfo)" ]; then
        pagecount_latest=$(pdfinfo "${output}" 2>/dev/null | grep "Pages\:" | awk '{print $2}')
        log_debug "(pages counted with pdfinfo)"
    elif [ "$(which exiftool)" ]; then
        pagecount_latest=$(exiftool -"*Count*" "${output}" 2>/dev/null | awk -F' ' '{print $NF}')
        log_debug "(pages counted with exiftool)"
    fi

    if [ -z "${pagecount_latest}" ]; then
        pagecount_latest=0
        log_error_at "page count failed — pdfinfo/exiftool/pymupdf returned no value for ${output}"
    fi

    global_pagecount_new="$((global_pagecount_new+pagecount_latest))"
    global_ocrcount_new="$((global_ocrcount_new+1))"
    pagecount_profile_new="$((pagecount_profile_new+pagecount_latest))"
    ocrcount_profile_new="$((ocrcount_profile_new+1))"


# source file permissions-Log:
# ---------------------------------------------------------------------
    if _synocr_log_ge2; then
        log_debug "File permissions source file: $(ls -l "${keep_hash_input}")"
    fi


# exact text
# ---------------------------------------------------------------------
    searchfile="${work_tmp_step2%/}/synOCR.txt"
    searchfilename="${work_tmp_step2%/}/synOCR_filename.txt"    # for search in file name
    echo "${title}" > "${searchfilename}"


# Search in the whole documents, or only on the first page?:
# ---------------------------------------------------------------------
    if [ "${searchAll}" = no ]; then
        pdftotextOpt="-l 1"
    else
        pdftotextOpt=""
    fi

    # shellcheck disable=SC2086  # Don't warn about "Double quote to prevent globbing and word splitting" in this function (${pdftotextOpt} must be unqoutet)
    /bin/pdftotext -layout ${pdftotextOpt} "${output}" "${searchfile}"
    sed -i 's/^ *//' "${searchfile}"        # delete beginning spaces
    if [ "${clean_up_spaces}" = "true" ]; then
        sed -i 's/ \+/ /g' "${searchfile}"
    fi

    content=$(cat "${searchfile}" )   # the standard rules search in the variable / the extended rules directly in the source file
    [ "${loglevel}" = 2 ] && cp "${searchfile}" "${LOGDIR}synOCR_searchfile_${title}.txt"


# search by tags:
# ---------------------------------------------------------------------
    synocr_status_update_step tags "${filename}"
    log_subsection "search tags in ocr text:"
    tag_search
    log_runtime $(( $(date +%s) - date_start_file ))

# search by date:
# ---------------------------------------------------------------------
    synocr_status_update_step date "${filename}"
    log_subsection "search for a valid date in ocr text:"
    dateIsFound=no
    find_date 1

    date_dd_source=$(stat -c %y "${keep_hash_input}" | awk '{print $1}' | awk -F- '{print $3}')
    date_mm_source=$(stat -c %y "${keep_hash_input}" | awk '{print $1}' | awk -F- '{print $2}')
    date_yy_source=$(stat -c %y "${keep_hash_input}" | awk '{print $1}' | awk -F- '{print $1}')
    date_houre_source=$(stat -c %y "${keep_hash_input}" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $1}')
    date_min_source=$(stat -c %y "${keep_hash_input}" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $2}')
    date_sek_source=$(stat -c %y "${keep_hash_input}" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $3}')

    if [ "${dateIsFound}" = no ]; then
        log_item "  Date not found in OCR text - use file date:"
        date_dd=$date_dd_source
        date_mm=$date_mm_source
        date_yy=$date_yy_source
        log_item "  day:  ${date_dd}"
        log_item "  month:${date_mm}"
        log_item "  year: ${date_yy}"
    fi

    log_runtime $(( $(date +%s) - date_start_file ))


# compose and rename file names / move to target:
# ---------------------------------------------------------------------
    synocr_status_update_step rename "${filename}"
    log_subsection "rename and sort to target folder:"
    rename
    log_runtime $(( $(date +%s) - date_start_file ))

    log_subsection "final tasks:"

    synocr_status_update_step notify "${filename}"

# Notification:
# ---------------------------------------------------------------------
    # notify message in user/rule defined language:
    lang_notify_file_job_successful=$(synogetkeyvalue "./lang/lang_${notify_lang}.txt" lang_notify_file_job_successful)

    file_notify=$(basename "${output}")
    # DSM Message:
    if [ "${dsmtextnotify}" = "on" ] ; then
        if [ "${dsm_version}" = "7" ] ; then
            synodsmnotify -c "SYNO.SDS.synOCR.Application" "${MessageTo}" "synOCR:app:app_name" "synOCR:app:job_successful" "${lang_notify_file_job_successful} [${file_notify}]"
        else
           synodsmnotify "${MessageTo}" "synOCR" "${lang_notify_file_job_successful} [${file_notify}]"
        fi
    fi

    # Beep:
    if [ "${dsmbeepnotify}" = "on" ] && [ "${synOCR_user}" = root ] ; then
        echo 2 > /dev/ttyS1 #short beep
    fi

    # individual apprise notification:
    if [ -n "${apprise_call}" ] && [ "${python_check}" = "ok" ]; then
        # ToDo: make ${apprise_call} unique
        if [ "${apprise_attachment}" = true ]; then
            # with target file as attachment (The user must ensure that the requested service accepts attachments):
            apprise_LOG=$(apprise --interpret-escapes -vv -t 'synOCR' -b "${lang_notify_file_job_successful}\n\r${file_notify}\n\n" --attach "${output}" "${apprise_call}")
        else
            # without attachment:
            apprise_LOG=$(apprise --interpret-escapes -vv -t 'synOCR' -b "${lang_notify_file_job_successful}\n\r${file_notify}" "${apprise_call}")
        fi

        apprise_rc=$?
        if [ "${apprise_rc}" -eq 0 ]; then
            log_item "  APPRISE-LOG:"
            echo "${apprise_LOG}" | log_block "${_LOG_INDENT}  "
        elif [ "${apprise_rc}" -ne 0 ] || [ "${loglevel}" = 2 ]; then # for log level 1 only error output
            log_error_at "Apprise notification failed (exit ${apprise_rc})"
            echo "${apprise_LOG}" | log_block "${_LOG_INDENT}  "
        fi
    else
        log_item "  INFO: Notify for apprise not defined ..."
    fi

    # run user defined (YAML) post scripts:
    log_subsection "run user defined post scripts"
    for cmd in "${postscriptarray[@]}"; do
        log_item "${cmd}"
        eval "${cmd}"
    done
    unset postscriptarray

# update file count profile:
# ---------------------------------------------------------------------
    log_subsection "Stats"

    stats_sqlite3log=$(synocr_sqlite "BEGIN;
        UPDATE system SET value_1='${global_pagecount_new}' WHERE key='global_pagecount';
        UPDATE system SET value_1='${global_ocrcount_new}' WHERE key='global_ocrcount';
        UPDATE config SET pagecount='${pagecount_profile_new}' WHERE profile_ID='${profile_ID}';
        UPDATE config SET ocrcount='${ocrcount_profile_new}' WHERE profile_ID='${profile_ID}';
        COMMIT;" 2>&1)
    stats_sqlite3rc=$?
    if [ "${stats_sqlite3rc}" != 0 ]; then
        log_error_at "statistics DB update failed (exit ${stats_sqlite3rc})"
        echo "${stats_sqlite3log}" | log_block
    fi

    log_detail "runtime last file: $(sec_to_time $(( $(date +%s) - date_start_file )))"
    log_detail "pagecount last file: ${pagecount_latest}"
    log_detail "file count profile: (profile $profile) - ${ocrcount_profile_new} PDF's / ${pagecount_profile_new} Pages processed up to now"
    log_detail "file count total: ${global_ocrcount_new} PDF's / ${global_pagecount_new} Pages processed up to now since ${count_start_date}"

    log_subsection "cleanup"

    synocr_status_increment_files_completed
    synocr_status_update_step cleanup "${filename}"
    synocr_status_complete_file_progress

# delete temporary working directory:
# ---------------------------------------------------------------------
    log_item "delete tmp-files ..."
    rm -rfv "${input}" | log_block   # rm ocred version - source file is backuped after ocrmypdf processing 

done <<<"${files_step2}"

    [ -d "${work_tmp_step2}" ] && rm -rfv "${work_tmp_step2}" | log_block
    [ -d "${work_tmp_main}" ] && rm -rfv "${work_tmp_main}" | log_block
}

    log_section "RUN THE FUNCTIONS"


# prepare steps (check / install / activate python enviroment & check docker):
# --------------------------------------------------------------------
    synocr_status_update_step prepare

    synocr_build_step_list
    synocr_status_publish_steps
    synocr_status_write profile "${profile}" profile_id "${profile_ID}"

    if synocr_needs_dockerimage_update; then
        synocr_status_update_step docker_update
        update_dockerimage
    fi

    if synocr_needs_python_env_prepare; then
        synocr_status_update_step python_env
        log_subsection "check the python3 installation and the necessary modules:"
        log_runtime $(( $(date +%s) - date_start_all ))
    fi

    prepare_python_log=$(prepare_python)
    prepare_python_rc=$?
    if [ "${prepare_python_rc}" -eq 0 ]; then
        [ -n "${prepare_python_log}" ] && echo "${prepare_python_log}"
        log_item "prepare_python: OK"
        source "${python3_env}/bin/activate"
    else
        [ -n "${prepare_python_log}" ] && echo "${prepare_python_log}"
        synocr_fail_fatal "prepare_python failed (exit ${prepare_python_rc})"
    fi

    synocr_build_step_list
    synocr_status_publish_steps


# main steps:
# ---------------------------------------------------------------------
    if [ "${img2pdf}" = true ]; then
        py_img2pdf
    fi

# create temporary working directory
# ---------------------------------------------------------------------
    work_tmp_main=$(mktemp -d -t tmp.XXXXXXXXXX)
    log_kv "Target temp directory" "${work_tmp_main}"

    main_1st_step
    purge_log
    purge_backup
    check_orphaned_backup_entries
    cleanup_lockfile

    [ -d "${work_tmp_main}" ] && rmdir -v "${work_tmp_main}" | log_block "  "

    log_detail "runtime all files: $(sec_to_time $(( $(date +%s) - date_start_all )))"
    log_blank

exit 0
