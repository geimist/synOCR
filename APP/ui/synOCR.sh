#!/bin/bash
# shellcheck disable=SC1090,SC1091,SC2001,SC2009,SC2181

#################################################################################
#   description:    main script for running synOCR                              #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/synOCR.sh          #
#   © 2025 by geimist                                                           #
#################################################################################

    echo "    -----------------------------------"
    echo "    |    ==> installation info <==    |"
    echo "    -----------------------------------"
    echo -e

    set -E -o functrace     # for function failure()

    # shellcheck disable=SC2317  # Don't warn about "unreachable commands" in this function
    failure()
    {
    # this function show error line
    # --------------------------------------------------------------
        # https://unix.stackexchange.com/questions/462156/how-do-i-find-the-line-number-in-bash-when-an-error-occured
        local lineno="${1}"
        local msg="${2}"
        echo "ERROR at line ${lineno}: ${msg}"
    }
    trap 'failure ${LINENO} "${BASH_COMMAND}"' ERR

    IFSsaved=$IFS


# ---------------------------------------------------------------------------------
#           BASIC CONFIGURATIONS / INDIVIDUAL ADAPTATIONS / Default values        |
# ---------------------------------------------------------------------------------
    workprofile="$1"            # the profile submitted by the start script
    current_logfile="$2"        # current logfile / is submitted by start script
    shopt -s globstar           # enable 'globstar' shell option (to use ** for directionary wildcard)
    shopt -s expand_aliases     # store & call aliases in an array
    date_start_all=$(date +%s)
    # hard coded setting to enable / disable metadata integration
    # /usr/syno/bin/synosetkeyvalue "/usr/syno/synoman/webman/3rdparty/synOCR/synOCR.sh" enablePyMetaData 0
    enablePyMetaData=1

    python3_env="/usr/syno/synoman/webman/3rdparty/synOCR/python3_env"
    python_check=ok             # will be set to failed if the test fails
    synOCR_python_module_list=( DateTime dateparser "pypdf==3.5.1" "pikepdf==7.1.2" Pillow yq PyYAML "apprise==1.9.2" "pymupdf==1.18.6" "numpy==1.19.5" ) 
                                # "pymupdf==1.18.6" & "numpy==1.19.5" for blank page detection
                                # apprise for notification
    dashline1="-----------------------------------------------------------------------------------"
    dashline2="●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●"


# to which user/group the DSM notification should be sent:
# ---------------------------------------------------------------------
    synOCR_user=$(whoami); echo "synOCR-user:              ${synOCR_user}"
    if grep administrators </etc/group | grep -q "${synOCR_user}" || [ "${synOCR_user}" = root ] ; then
        isAdmin=yes
    else
        isAdmin=no
    fi
    echo "synOCR-user is admin:     ${isAdmin}"


# check DSM version:
# -------------------------------------
    if [ "$(synogetkeyvalue /etc.defaults/VERSION majorversion)" -ge 7 ]; then
        dsm_version=7
    else
        dsm_version=6
    fi


# read out and change into the working directory:
# ---------------------------------------------------------------------
    APPDIR=$(cd "$(dirname "$0")" || exit 1;pwd)
    cd "${APPDIR}" || exit 1

    source ./includes/functions.sh


# load configuration:
# ---------------------------------------------------------------------
    sSQL="SELECT 
            profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix,
            delSearchPraefix, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, apprise_call,
            dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, filedate, tagsymbol, documentSplitPattern, ignoredDate, 
            backup_max, backup_max_type, pagecount, ocrcount, search_nearest_date, date_search_method, clean_up_spaces, 
            img2pdf, DateSearchMinYear, DateSearchMaxYear, splitpagehandling, apprise_attachment, notify_lang, 
            blank_page_detection_switch, blank_page_detection_mainThreshold, blank_page_detection_widthCropping, 
            blank_page_detection_hightCropping, blank_page_detection_interferenceMaxFilter, 
            blank_page_detection_interferenceMinFilter, blank_page_detection_black_pixel_ratio, blank_page_detection_ignoreText, 
            adjustColorBWthreshold, adjustColorDPI, adjustColorContrast, adjustColorSharpness
        FROM 
            config 
        WHERE 
            profile_ID='${workprofile}' "

    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "${sSQL}")

    profile_ID=$(echo "${sqlerg}" | awk -F'\t' '{print $1}')
    profile=$(echo "${sqlerg}" | awk -F'\t' '{print $3}')
    INPUTDIR=$(echo "${sqlerg}" | awk -F'\t' '{print $4}')
    OUTPUTDIR=$(echo "${sqlerg}" | awk -F'\t' '{print $5}')
    BACKUPDIR=$(echo "${sqlerg}" | awk -F'\t' '{print $6}')
    LOGDIR=$(echo "${sqlerg}" | awk -F'\t' '{print $7}')
    LOGmax=$(echo "${sqlerg}" | awk -F'\t' '{print $8}')
    SearchPraefix=$(echo "${sqlerg}" | awk -F'\t' '{print $9}')
    delSearchPraefix=$(echo "${sqlerg}" | awk -F'\t' '{print $10}')
    taglist=$(echo "${sqlerg}" | awk -F'\t' '{print $11}')
    searchAll=$(echo "${sqlerg}" | awk -F'\t' '{print $12}')
    moveTaggedFiles=$(echo "${sqlerg}" | awk -F'\t' '{print $13}')
    NameSyntax=$(echo "${sqlerg}" | awk -F'\t' '{print $14}')
    ocropt=$(echo "${sqlerg}" | awk -F'\t' '{print $15}')
    dockercontainer=$(echo "${sqlerg}" | awk -F'\t' '{print $16}')
    apprise_call=$(echo "${sqlerg}" | awk -F'\t' '{print $17}')
    dsmtextnotify=$(echo "${sqlerg}" | awk -F'\t' '{print $18}')
    MessageTo=$(echo "${sqlerg}" | awk -F'\t' '{print $19}')
    [ -z "${MessageTo}" ] || [ "${MessageTo}" == "-" ] && MessageTo="@administrators" # group administrators (default)
    dsmbeepnotify=$(echo "${sqlerg}" | awk -F'\t' '{print $20}')
    loglevel=$(echo "${sqlerg}" | awk -F'\t' '{print $21}')
    filedate=$(echo "${sqlerg}" | awk -F'\t' '{print $22}')
    tagsymbol=$(echo "${sqlerg}" | awk -F'\t' '{print $23}')
    documentSplitPattern=$(echo "${sqlerg}" | awk -F'\t' '{print $24}')
    ignoredDate=$(echo "${sqlerg}" | awk -F'\t' '{print $25}' | sed -e 's/2021-02-29//g;s/2020-11-31//g;s/^ *//g') # remove (invalid) example dates
    backup_max=$(echo "${sqlerg}" | awk -F'\t' '{print $26}')
    backup_max_type=$(echo "${sqlerg}" | awk -F'\t' '{print $27}')
    pagecount_profile=$(echo "${sqlerg}" | awk -F'\t' '{print $28}')
    ocrcount_profile=$(echo "${sqlerg}" | awk -F'\t' '{print $29}')
    search_nearest_date=$(echo "${sqlerg}" | awk -F'\t' '{print $30}')
    date_search_method=$(echo "${sqlerg}" | awk -F'\t' '{print $31}')
    clean_up_spaces=$(echo "${sqlerg}" | awk -F'\t' '{print $32}')
    img2pdf=$(echo "${sqlerg}" | awk -F'\t' '{print $33}')
    DateSearchMinYear=$(echo "${sqlerg}" | awk -F'\t' '{print $34}')
    DateSearchMaxYear=$(echo "${sqlerg}" | awk -F'\t' '{print $35}')
    splitpagehandling=$(echo "${sqlerg}" | awk -F'\t' '{print $36}')
    apprise_attachment=$(echo "${sqlerg}" | awk -F'\t' '{print $37}')
    notify_lang=$(echo "${sqlerg}" | awk -F'\t' '{print $38}')
    blank_page_detection_switch=$(echo "${sqlerg}" | awk -F'\t' '{print $39}')
    blank_page_detection_mainThreshold=$(echo "${sqlerg}" | awk -F'\t' '{print $40}')
    blank_page_detection_widthCropping=$(echo "${sqlerg}" | awk -F'\t' '{print $41}')
    blank_page_detection_hightCropping=$(echo "${sqlerg}" | awk -F'\t' '{print $42}')
    blank_page_detection_interferenceMaxFilter=$(echo "${sqlerg}" | awk -F'\t' '{print $43}')
    blank_page_detection_interferenceMinFilter=$(echo "${sqlerg}" | awk -F'\t' '{print $44}')
    blank_page_detection_black_pixel_ratio=$(echo "${sqlerg}" | awk -F'\t' '{print $45}')
    blank_page_detection_ignoreText=$(echo "${sqlerg}" | awk -F'\t' '{print $46}')
    adjustColorBWthreshold=$(echo "${sqlerg}" | awk -F'\t' '{print $47}')
    adjustColorDPI=$(echo "${sqlerg}" | awk -F'\t' '{print $48}')
    adjustColorContrast=$(echo "${sqlerg}" | awk -F'\t' '{print $49}')
    adjustColorSharpness=$(echo "${sqlerg}" | awk -F'\t' '{print $50}')

# read global values:
    dockerimageupdate=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='dockerimageupdate' ")
    count_start_date=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='count_start_date'")
    global_pagecount=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_pagecount'")
    global_ocrcount=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_ocrcount'")
    online_version=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='online_version'")
    # Delay in seconds
    delay=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='inotify_delay'" )

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
    echo "synOCR-version:           ${local_version}"
    if [[ "${local_version}" != "${highest_version}" ]] ; then
        echo "UPDATE AVAILABLE:         online version: ${online_version}"
        echo "                          please visit https://geimist.eu/synOCR/ or check your pakage center"
    fi

    machinetyp=$(uname --machine); echo "Architecture:             ${machinetyp}"
    dsmbuild=$(uname -v | awk '{print $1}' | sed "s/#//g"); echo "DSM-build:                ${dsmbuild}"
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

    echo "Device:                   ${device}"
    echo "current Profil:           ${profile}"
    echo -n "monitor is running?:      "
    if ps aux | grep -qE "[i]notifywait.*--fromfile.*inotify.list"; then
        echo "yes"
    else
        echo "no"
    fi
    echo "DB-version:               $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='db_version'")"
    echo "system-ID:                $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='UUID'")"
    echo "used image (created):     ${dockercontainer} ($(docker inspect -f '{{ .Created }}' "${dockercontainer}" 2>/dev/null | awk -F. '{print $1}'))"
    echo "ContainerManager:         $(synopkg version ContainerManager)"
    echo "docker version:           $(docker --version)"

    [ ${delay:-0} -ne 0 ] && echo "OCR delay:                ${delay:-0} seconds"

    documentAuthor=$(awk -F'[ ]-' '{for(i=1;i<=NF;i++){if($i)print "-"$i}}' <<<" ${ocropt}" | grep "\-\-author" | sed -e 's/--author //')
#   documentAuthor=$(grep -oP -- '--author(=\S+)?\s*\K.*?(?=\s+--|\s*$)' <<<"${ocropt}")
    echo "document author:          ${documentAuthor}"

    documentTitle=$(awk -F'[ ]-' '{for(i=1;i<=NF;i++){if($i)print "-"$i}}' <<<" ${ocropt}" | grep "\-\-title" | sed -e 's/--title //')
    echo "document title:          ${documentTitle}"

    echo "used ocr-parameter (raw): ${ocropt}"

    # check of non-ocrmypdf parameter --keep_hash.
    if [[ "${ocropt}" == *"--keep_hash"* ]]; then
        keep_hash=true
        ocropt="${ocropt//--keep_hash/}"  # remove --keep_hash to make the parameters OCRmyPDF compatible
        echo "                          --keep_hash is set – the source file will not be modified"
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
            [ "${loglevel}" = 2 ] && echo "OCR-arg ${c}:                ${value_1}"
            c=$((c+1))
            value_2=${value//${value_1} /}
            [ "${loglevel}" = 2 ] && echo "OCR-arg ${c}:                ${value_2}"
            ocropt_arr+=( "${value_1}" "${value_2}" )
        else
            [ "${loglevel}" = 2 ] && echo "OCR-arg ${c}:                ${value}"
            ocropt_arr+=( "${value}" )
        fi
    done <<< "$(awk -F'[ ]-' '{for(i=1;i<=NF;i++){if($i)print "-"$i}}' <<<" ${ocropt#"${ocropt%%[^ ]*}"}")"
    unset c

    echo "ocropt_array:             ${ocropt_arr[*]}"
    echo "shm-size:                 ${shm_size}"
    echo "search prefix:            ${SearchPraefix}"
    echo "replace search prefix:    ${delSearchPraefix}"
    echo "renaming syntax:          ${NameSyntax}"
    echo "Symbol for tag marking:   ${tagsymbol}"
    tagsymbol="${tagsymbol// /%20}"   # mask spaces
    echo -n "convert images to PDF:    ${img2pdf}" && [[ "${img2pdf}" = "true" ]] && [[ "${keep_hash}" = "true" ]] && { img2pdf="false"; echo " (disabled, because --keep_hash is defined!)"; } || echo

    echo "adjust color:"
    echo "  BW threshold:           ${adjustColorBWthreshold}"
    echo "  DPI:                    ${adjustColorDPI}"
    echo "  contrast:               ${adjustColorContrast}"
    echo "  sharpness:              ${adjustColorSharpness}"

    echo "target file handling:     ${moveTaggedFiles}"
    echo -n "Document split pattern:   ${documentSplitPattern}" && [[ -n "${documentSplitPattern}" ]] && [[ "${keep_hash}" = "true" ]] && { documentSplitPattern=""; echo " (disabled, because --keep_hash is defined!)"; } || echo

    if [[ "${documentSplitPattern}" = "<split each page>" ]]; then
        splitpagehandling="isFirstPage"
        echo "split page handling:      ${splitpagehandling} (because, <split each page> is set)"
    else
        echo "split page handling:      ${splitpagehandling}"
    fi
#    echo "delete blank pages:       ${blank_page_detection_switch}" && [[ "${blank_page_detection_switch}" = "true" ]] && [[ "${keep_hash}" = "true" ]] && blank_page_detection_switch="false" && echo " (disabled, because --keep_hash is defined!)"
    echo -n "delete blank pages:       ${blank_page_detection_switch}" && [[ "${blank_page_detection_switch}" = "true" && "${keep_hash}" = "true" ]] && { blank_page_detection_switch="false"; echo " (disabled, because --keep_hash is defined!)"; } || echo

    if [ "${blank_page_detection_switch}" = true ]; then
        echo "  ignore text:            ${blank_page_detection_ignoreText}"
        echo "  main threshold:         ${blank_page_detection_mainThreshold}"
        echo "  width cropping:         ${blank_page_detection_widthCropping}"
        echo "  hight cropping:         ${blank_page_detection_hightCropping}"
        echo "  interf. max filter:     ${blank_page_detection_interferenceMaxFilter}"
        echo "  interf. min filter:     ${blank_page_detection_interferenceMinFilter}"
        echo "  thresh. black pxl:      ${blank_page_detection_black_pixel_ratio}"
    fi
    echo "clean up spaces:          ${clean_up_spaces}"
    echo -n "Date search method:       "
    if [ "${date_search_method}" = python ] ; then
        echo "use Python"
    else
        echo "use standard search via RegEx"
    fi
    echo "date found order:         ${search_nearest_date}"
    echo "source for filedate:      ${filedate}"
    echo "ignored dates by search:  ${ignoredDate}"

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
    echo "date range in past:       ${DateSearchMinYear} [absolute: ${minYear}]"
    maxYear=$( validate_date_range "${DateSearchMaxYear}" "+" )
    echo "date range in future:     ${DateSearchMaxYear} [absolute: ${maxYear}]"

    [ "${loglevel}" = 2 ] && \
    echo "PATH-Variable:            $PATH"
    echo -n "Docker test:              "
    if docker --version 2>/dev/null | grep -q "version"  ; then
        echo "OK"
    else
        echo "WARNING: Docker could not be found. Please check if the Docker package has been installed!"
    fi
    echo "DSM notify to user:       ${MessageTo}"
    echo "apprise notify service:   ${apprise_call}"
    echo "apprise attachment:       ${apprise_attachment}"
    echo "notify language:          ${notify_lang}"


# Configuration for LogLevel:
# ---------------------------------------------------------------------
    # LOGlevel:     0 ➜ logging disable / 1 ➜ normal / 2 ➜ debug
    log_indent="                "
    if [ "${loglevel}" = 1 ] ; then
        echo "Loglevel:                 normal"
        rm_log_level=""
    elif [ "${loglevel}" = 2 ] ; then
        echo "Loglevel:                 debug"
        # set -x
        ocropt_arr+=( "-v2" )
        rm_log_level="v"
    fi
    echo "max. count of logfiles:   ${LOGmax}"
    if [ -z "${backup_max}" ] || [ "${backup_max}" == 0 ]; then
        echo "rotate backupfiles after: (purge backup deactivated)"
    else
        echo "rotate backupfiles after: ${backup_max} ${backup_max_type}"
    fi


# Check or create and adjust directories:
# ---------------------------------------------------------------------
    # Adjust variable correction for older Konfiguration.txt and slash:
    INPUTDIR="${INPUTDIR%/}/"
    if [ -d "${INPUTDIR}" ] ; then
        echo "Source directory:         ${INPUTDIR}"
    else
        echo "Source directory invalid or not set!"
        exit 1
    fi

    OUTPUTDIR="${OUTPUTDIR%/}/"
    echo "Target directory:         ${OUTPUTDIR}"

    BACKUPDIR="${BACKUPDIR%/}/"
    if [ -d "${BACKUPDIR}" ] && echo "${BACKUPDIR}" | grep -q "/volume" ; then
        echo "BackUp directory:         ${BACKUPDIR}"
        backup=true
    elif echo "${BACKUPDIR}" | grep -q "/volume" ; then
        if /usr/syno/sbin/synoshare --enum ENC | grep -q "$(echo "${BACKUPDIR}" | awk -F/ '{print $3}')" ; then
            echo "BackUP folder not mounted    ➜    EXIT SCRIPT!"
            exit 1
        fi
        mkdir -p "${BACKUPDIR}"
        echo "BackUp directory was created [${BACKUPDIR}]"
        backup=true
    else
        echo "Files are deleted immediately! / No valid directory [${BACKUPDIR}]"
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

    if echo "${dockercontainer}" | grep -qE "latest$" && [ "${dockerimageupdate}" = 1 ] && [[ ! $(sqlite3 ./etc/synOCR.sqlite "SELECT date_checked FROM dockerupdate WHERE image='${dockercontainer}' ") = "${check_date}" ]]; then
        printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "checks for ocrmypdf image update:" "${dashline1}"
        echo -n "${log_indent}➜ update image [${dockercontainer}] ➜ "
        updatelog=$(docker pull "${dockercontainer}" 2>/dev/null)

    # purge only untaged ocrmypdf images:
        if docker images -f "dangling=true" --format "{{.ID}}:{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "ocrmypdf"; then 
            log_purge=$(docker rmi -f "$(docker images -f "dangling=true" --format "{{.ID}}:{{.Repository}}:{{.Tag}}" 2>/dev/null | grep "ocrmypdf" | awk -F: '{print $1}')" 2>/dev/null)
        else
            log_purge="nothing to do ..."
        fi

        if [ -z "$(sqlite3 "./etc/synOCR.sqlite"  "SELECT * FROM dockerupdate WHERE image='${dockercontainer}'")" ]; then
            sqlite3 "./etc/synOCR.sqlite" "INSERT INTO dockerupdate ( image, date_checked ) VALUES  ( '${dockercontainer}', '${check_date}' )"
        else
            sqlite3 "./etc/synOCR.sqlite" "UPDATE dockerupdate SET date_checked='${check_date}' WHERE image='${dockercontainer}' "
        fi

        if echo "${updatelog}" | grep -q "Image is up to date"; then
            echo "image is up to date"
        elif echo "${updatelog}" | grep -q "Downloaded newer image"; then
            echo "updated successfully"
        fi

        echo "${log_indent}Update-Log:"
        echo "${updatelog}" | sed -e "s/^/${log_indent}/g"
        echo "${log_indent}docker purge Log:"
        echo "${log_purge}" | sed -e "s/^/${log_indent}/g"

        printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )))]"
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

            # Logging nur bei aktiviertem Loglevel
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

#   cat "${OCRinput}" | docker run --name synOCR --network none --rm -i -log-driver=none -a stdin -a stdout -a stderr "${dockercontainer}" "${ocropt_arr[@]}" - - | cat - > "${outputtmp}"
# Standard v1.5.0:
#   cat "${OCRinput}" | docker run --name synOCR --network none -i --log-driver none -a stdin -a stdout -a stderr "${dockercontainer}" "${ocropt_arr[@]}" - - | cat - > "${outputtmp}"

    docker run --rm \
        --name synOCR \
        --network none \
        --shm-size="${shm_size}" \
        -v "${OCRinput}":/input.pdf \
        -v "${outputtmp%/*}":/output \
        "${dockercontainer}" \
        "${ocropt_arr[@]}" /input.pdf "/output/${outputtmp##*/}"
}


tag_search()
{
unset renameTag
unset renameCat

# is it an external text file for the tags or a YAML rules file?
# standard rules or advanced rules (YAML file)
type_of_rule=standard

if [ -z "${taglist}" ]; then
    echo "${log_indent}no tags defined"
    return
elif [ -f "${taglist}" ]; then
    if grep -q "synOCR_YAMLRULEFILE" "${taglist}" ; then
        echo "${log_indent}source for tags is yaml based tag rule file [${taglist}]"

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
            [ "${loglevel}" = 2 ] && echo "${log_indent}check and convert yaml 2 json with python"
            tag_rule_content=$( python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read()), indent=2, sort_keys=False))' < "${taglisttmp}")
            if [ $? != 0 ]; then
                printf "%s" "${log_indent}ERROR - YAML-check failed!"
                return 1  # file not further processable
                # ToDo: cancel run to preserve PDF source file / possibly move to Errorfiles? (rather not)
            fi
        else
            [ "${loglevel}" = 2 ] && echo "${log_indent}check and convert yaml 2 json with yq_bin"
            yamlcheck=$(yq_bin v "${taglist}" 2>&1)
            if [ $? != 0 ]; then
                printf "%s" "${log_indent}ERROR - YAML-check failed!\n${log_indent}ERROR-Message:"
                echo "${yamlcheck}" | sed -e "s/^/${log_indent}/g"
                return 1  # file not further processable
                # ToDo: cancel run to preserve PDF source file / possibly move to Errorfiles? (rather not)
            fi
            tag_rule_content=$(yq_bin read "${taglisttmp}" -jP 2>&1)
            echo "${tag_rule_content}" > "${LOGDIR}${taglist}.yq_bin.json"
        fi
    else
        echo "${log_indent}source for tags is file [${taglist}]"
        sed -i $'s/\r$//' "${taglist}"                    # convert DOS to Unix
        taglist=$(< "${taglist}")
    fi
else
    echo "${log_indent}source for tags is the list from the GUI"
fi

if [ "${type_of_rule}" = advanced ]; then
# process complex tag rules:
    for tagrule in $(echo "${tag_rule_content}" | jq -r ". | to_entries | .[] | .key" | sort -r); do
        found=0

        echo "${log_indent}search by tag rule: \"${tagrule}\" ➜  "

        condition=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.condition" | tr '[:upper:]' '[:lower:]')
        if [ "${condition}" = null ] ; then
            echo "${log_indent}          [value for condition must not be empty - fallback to any]"
            condition=any
        fi

        searchtag=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.tagname" | sed 's%\/\|\\\|\:\|\?%_%g' ) # filtered: \ / : ?
        targetfolder=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.targetfolder" )
        tagname_RegEx=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.tagname_RegEx" )
        dirname_RegEx=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.dirname_RegEx" )
        tagname_multiline_RegEx=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.multilineregex" )
        VARapprise_call=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.apprise_call" )
        VARapprise_attachment=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.apprise_attachment" )
        VARnotify_lang=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.notify_lang" )
        postscript=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.postscript" )

        if [[ "${searchtag}" = null ]] && [[ "${targetfolder}" = null ]] && [[ "${postscript}" = null ]] ; then
            echo "${log_indent}   [no actions defined - continue]"
            continue
        fi

        if [[ "${targetfolder}" = null ]]; then
            targetfolder=""
        fi

        if [[ "${searchtag}" = null ]]; then
            searchtag=""
        fi

        echo "${log_indent}  ➜ condition:        ${condition}"     # "all" OR "any" OR "none"
        echo "${log_indent}  ➜ tag:              ${searchtag}"
        echo "${log_indent}  ➜ destination:      ${targetfolder}"
        if [[ "${tagname_RegEx}" != null ]] ; then
            echo "${log_indent}  ➜ RegEx for tag:    ${tagname_RegEx}" # searchtag
            if [ "${tagname_multiline_RegEx}" = null ] ; then
                [ "${loglevel}" = 2 ] && echo "${log_indent}  ➜ multilineregex:   [value for multilineregex is empty - \"false\" is used]"
                tagname_multiline_RegEx=false
            else
                echo "${log_indent}  ➜ multilineregex:   ${tagname_multiline_RegEx}" # true: set parameter -z to grep
            fi
        fi
        if [[ "${dirname_RegEx}" != null ]] ; then
            echo "${log_indent}  ➜ RegEx for tag:    ${dirname_RegEx}" # searchtag
            if [ "${dirname_multiline_RegEx}" = null ] ; then
                [ "${loglevel}" = 2 ] && echo "${log_indent}  ➜ multilineregex:   [value for multilineregex is empty - \"false\" is used]"
                dirname_multiline_RegEx=false
            else
                echo "${log_indent}  ➜ multilineregex:   ${dirname_multiline_RegEx}" # true: set parameter -z to grep
            fi
        fi

        [ "${loglevel}" = 2 ] && echo "${log_indent}      [Subrule]:"
        # execute subrules:
        for subtagrule in $(echo "${tag_rule_content}" | jq -c ".${tagrule}.subrules[] | @base64 ") ; do
            grepresult=0
            sub_jq_value="${subtagrule}"  # universal parameter name for function sub_jq

            VARsearchstring=$(sub_jq '.searchstring')
            if [ "${VARsearchstring}" = null ] ; then
                echo "${log_indent}          [value for searchstring must not be empty - continue]"
                continue
            fi

            VARisRegEx=$(sub_jq '.isRegEx' | tr '[:upper:]' '[:lower:]')
            if [ "${VARisRegEx}" = null ] ; then
                [ "${loglevel}" = 2 ] && echo "${log_indent}          [value for isRegEx is empty - \"false\" is used]"
                VARisRegEx=false
            fi

            VARsearchtype=$(sub_jq '.searchtyp' | tr '[:upper:]' '[:lower:]')
            if [ "${VARsearchtype}" = null ] ; then
                # correct spelling of searchtype with ending e (workarround because of wrong doc):
                VARsearchtype=$(sub_jq '.searchtype' | tr '[:upper:]' '[:lower:]')
                if [ "${VARsearchtype}" = null ] ; then
                    [ "${loglevel}" = 2 ] && echo "${log_indent}          [value for searchtype is empty - \"contains\" is used]"
                    VARsearchtype=contains
                fi
            fi

            VARsource=$(sub_jq '.source' | tr '[:upper:]' '[:lower:]')
            if [ "${VARsource}" = null ] ; then
                [ "${loglevel}" = 2 ] && echo "${log_indent}          [value for source is empty - \"content\" is used]"
                VARsource=content
            fi

            VARcasesensitive=$(sub_jq '.casesensitive' | tr '[:upper:]' '[:lower:]')
            if [ "${VARcasesensitive}" = null ] ; then
                [ "${loglevel}" = 2 ] && echo "${log_indent}          [value for casesensitive is empty - \"false\" is used]"
                VARcasesensitive=false
            fi

            VARmultilineregex=$(sub_jq '.multilineregex' | tr '[:upper:]' '[:lower:]')
            if [ "${VARmultilineregex}" = null ] ; then
                [ "${loglevel}" = 2 ] && echo "${log_indent}          [value for multilineregex is empty - \"false\" is used]"
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

            if [ "${loglevel}" = 2 ] ; then
                echo "${log_indent}      >>> search for:      ${VARsearchstring}"
                echo "${log_indent}          isRegEx:         ${VARisRegEx}"
                echo "${log_indent}          searchtype:      ${VARsearchtype}"
                echo "${log_indent}          source:          ${VARsource}"
                echo "${log_indent}          casesensitive:   ${VARcasesensitive}"
                echo "${log_indent}          multilineregex:  ${VARmultilineregex}"
                echo "${log_indent}          grep parameter:  ${grep_opt}"
            fi

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

            [ "${loglevel}" = 2 ] && [ "${grepresult}" = "1" ] && echo "${log_indent}          ➜ Subrule matched"
            [ "${loglevel}" = 2 ] && [ ! "${grepresult}" = "1" ] && echo "${log_indent}          ➜ Subrule don't matched"

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
            echo "${log_indent}          >>> Rule is satisfied"

            # ---------------------------------------------------------------------
            # modify (global) settings with yaml rules:
            # apprise_call
            if [[ "${VARapprise_call}" != null ]] ; then
                apprise_call="${VARapprise_call} ${apprise_call}"
                echo "${log_indent}              ➜ add apprise_call ${VARapprise_call}"
            fi

            # apprise_attachment
            if [[ "${VARapprise_attachment}" != null ]] ; then
                apprise_attachment="${VARapprise_attachment}"
                echo "${log_indent}              ➜ set apprise_attachment to ${VARapprise_attachment}"
            fi

            # notify_lang
            if [[ "${VARnotify_lang}" != null ]] ; then
                notify_lang="${VARnotify_lang}"
                echo "${log_indent}              ➜ set notify_lang to ${VARnotify_lang}"
            fi

            # ---------------------------------------------------------------------
            # store user defined (YAML) post scripts as alias in an array:
            if [[ "${postscript}" != null ]] ; then
                aliasname="postscript_${tagrule}_$(date +%N)"
                postscriptarray+=( "${aliasname}" )
                # shellcheck disable=SC2139  # Don't warn about "expands when defined, not when used"
                alias "${aliasname}"="${postscript}"
                echo "${log_indent}              ➜ activate post script: ${postscript}"
            fi
            # ---------------------------------------------------------------------
            # tagname_RegEx
            if [[ "${tagname_RegEx}" != null ]] ; then
                echo -n "${log_indent}              ➜ search RegEx for tag ➜ "
                # treat the file as one huge string (Parameter -z):
                if [ "${tagname_multiline_RegEx}" = true ] ;then
                    grep_opt="z"
                else
                    grep_opt=""
                fi

                tagname_RegEx_result=$( grep -oP${grep_opt} "${tagname_RegEx}" "${VARsearchfile}" | tr -d '\0' | head -n1 | sed 's%\/\|\\\|\:\|\?%_%g' )
                if [ -n "${tagname_RegEx_result}" ] ; then
                    if echo "${searchtag}" | grep -q "§tagname_RegEx" ; then
                        searchtag="${searchtag//§tagname_RegEx/${tagname_RegEx_result}}"
                    else
                        searchtag="${tagname_RegEx_result}"
                    fi
                    printf "%s\n\n" "${searchtag}"
                else
                    printf "%s\n\n" "RegEx not found (fallback to ${searchtag})"
                fi
            fi
            # ---------------------------------------------------------------------
            # dirname_RegEx
            if [[ "${dirname_RegEx}" != null ]] ; then
                echo -n "${log_indent}              ➜ search RegEx for dir ➜ "
                # treat the file as one huge string (Parameter -z):
                if [ "${dirname_multiline_RegEx}" = true ] ;then
                    grep_opt="z"
                else
                    grep_opt=""
                fi

                dirname_RegEx_result=$( grep -oP${grep_opt} "${dirname_RegEx}" "${VARsearchfile}" | tr -d '\0' | head -n1 | sed 's%\/\|\\\|\:\|\?%_%g' )
                if [ -n "${dirname_RegEx_result}" ] ; then

                    # Ensure path compatibility: Replace unwanted characters with underscore
                    sanitized=$(sed 's/[^A-Za-z0-9_.- ]/_/g' <<< "${dirname_RegEx_result}")
                    # Remove leading/trailing dots or hyphens
                    sanitized=${sanitized%%[.-]}
                    sanitized=${sanitized##[.-]}

                    targetfolder="${targetfolder//§dirname_RegEx/${sanitized}}"
                        
                    printf "%s\n\n" "${targetfolder}"
                else
                    printf "%s\n\n" "RegEx not found (fallback to ${targetfolder})"
                fi
            fi

            [ -n "${searchtag}" ] && renameTag="${tagsymbol}${searchtag// /%20} ${renameTag}" # with temporary space separator to finally check tags for uniqueness
            [ -n "${targetfolder}" ] && renameCat="${targetfolder// /%20} ${renameCat}"
        else
            echo "${log_indent}          >>> Rule is not satisfied"
        fi

        printf "\n"

    done

    # meta_keyword_list: unique / without tagsymbol / separated with komma and space >, <:
    meta_keyword_list=$(echo "${renameTag}" | tr ' ' '\n' | awk '!x[$0]++' | sed -e "s/^%20//g;s/^${tagsymbol}//g" | tr '\n' ' ' | sed -e "s/ /, /g;s/%20/ /g;s/, $//g" | sed -e "s/, $//g")
    # ranameTag: unique / spaces masked with %20:
    renameTag=$(echo "${renameTag}" | tr ' ' '\n' | awk '!x[$0]++' | tr '\n' ' ' | sed -e "s/ //g" )
else
# process simple tag rules:
    taglist2=$( echo "${taglist}" | sed -e "s/ /%20/g" | sed -e "s/;/ /g" )   # encode spaces in tags and convert semicolons to spaces (for array)
    IFS=" " read -r -a tagarray <<< "${taglist2}" ; IFS="${IFSsaved}"

    i=0
    maxID=${#tagarray[*]}
    echo "${log_indent}tag count:       ${maxID}"

    # ToDo: possibly change loop …
    #    for i in ${tagarray[@]}; do
    #        echo $a
    #    done
    while (( i < maxID )); do
        [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )) )]"

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
            echo -n "${log_indent}  Search by tag:   \"${searchtag}\" ➜  "
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
            printf "%s" "${log_indent}  Search by tag:   \"${tagarray[$i]//%20/ }\" ➜  "
            if grep "${grep_opt}" "$(echo "${tagarray[$i]}" | sed -e "s/%20/ /g;s/^§//g")" "${searchfile}" ; then
                echo "OK"
                renameTag="${tagsymbol}${tagarray[$i]}${renameTag}"
            else
                echo "-"
            fi
        fi
        i=$((i + 1))
    done

    # meta_keyword_list: without tagsymbol / separated with komma and space >, <:
    meta_keyword_list=$(echo "${renameTag}" | sed -e "s/^${tagsymbol}//g;s/${tagsymbol}/, /g;s/%20/ /g")
fi

# remove last whitespace:
    renameTag=${renameTag% }

# remove starting and ending spaces, or all spaces if no destination folder is defined:
    renameCat=$(echo "${renameCat}" | sed 's/^ *//;s/ *$//')
    if [ -n "${renameCat}" ] && [ "${moveTaggedFiles}" != useCatDir ] ; then
        printf "\n%s\n" "${log_indent}! ! ! ATTENTION ! ! !"
        printf "%s\n" "${log_indent}You have defined rule-based directories, but defined the GUI setting is: ${moveTaggedFiles}"
        printf "%s\n\n" "${log_indent}Please change the GUI-setting, if you want to use the rule based directories."
    fi

# unmodified for tag folder / tag folder with spaces otherwise not possible:
    renameTag_raw="${renameTag}"


    printf "\n%s\n\n" "${log_indent}rename tag is: \"${renameTag//%20/ /}\""

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
            echo "${log_indent}rule name ${i2} was adjusted"
            sed -i "s/${i}/${i2}/" "${taglisttmp}"
        fi
    done <<< "${rulenames}"


# check uniqueness of parent nodes:
# ---------------------------------------------------------------------
    if [ "$(grep "^[a-zA-Z0-9_].*[: *]$" "${taglisttmp}" | sed 's/ *$//' | sort | uniq -d | wc -l )" -ge 1 ] ; then # check for the number of duplicate lines
        echo "${log_indent}main keywords are not unique!"
        echo "${log_indent}dublicats are: $(grep "^[a-zA-Z0-9_].*[: *]$" "${taglisttmp}" | sed 's/ *$//' | sort | uniq -d)"
    fi


# check parameter validity:
# ---------------------------------------------------------------------
    # check, if value of condition is "all" OR "any" OR "none":
    if grep -q '^[[:space:]]*condition' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(all|any|none)$' > /dev/null  2>&1 ; then
               echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') (wrong value: >${value}<) [value of condition must be only \"all\" OR \"any\" OR \"none\"]"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^condition:")"
    fi

    # check, if value of isRegEx is "true" OR "false":
    if grep -q '^[[:space:]]*isRegEx' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
               echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') (wrong value: >${value}<) [value of isRegEx must be only \"true\" OR \"false\"]"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^isRegEx:")"
    fi

    # check, if value of source is "content" OR "filename":
    if grep -q '^[[:space:]]*source' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(content|filename)$' > /dev/null  2>&1 ; then
               echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') (wrong value: >${value}<) [value of source must be only \"content\" OR \"filename\"]"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^source:")"
    fi

    # check of corect value of searchtype:
    if grep -q '^[[:space:]]*searchtyp|^[[:space:]]*searchtype' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | sed 's/^ *//;s/ *$//' | tr -cd '[:alnum:][:blank:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(is|is not|contains|does not contain|starts with|does not starts with|ends with|does not ends with|matches|does not match)$' > /dev/null  2>&1 ; then
               echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') (wrong value: >${value}<) [value of searchtype must be only \"is\" OR \"is not\" OR \"contains\" OR \"does not contain\" OR \"starts with\" OR \"does not starts with\" OR \"ends with\" OR \"does not ends with\" OR \"matches\" OR \"does not match\"]"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wnE "^searchtyp:|^searchtype:")"
    fi

    # check, if value of casesensitive is "true" OR "false":
    if grep -q '^[[:space:]]*casesensitive' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
               echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') (wrong value: >${value}<) [value of casesensitive must be only \"true\" OR \"false\"]"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^casesensitive:")"
    fi

    # check, if value of multilineregex is "true" OR "false":
    if grep -q '^[[:space:]]*multilineregex' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
               echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') (wrong value: >${value}<) [value of multilineregex must be only \"true\" OR \"false\"]"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^multilineregex:")"
    fi

    # check apprise_call:
    # ToDo: which regex can check this?
#    if grep -q "apprise_call" "${taglisttmp}"; then
#       while read -r line ; do
#           if ! echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
#              echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') [value of apprise_call must be only ... ]"
#           fi
#       done <<<"$(cat "${taglisttmp}" | sed 's/^ *//;s/ *$//' | grep -n "^apprise_call:")"
#      done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^apprise_call:")"
#   fi

    # check, if value of apprise_attachment is "true" OR "false":
    if grep -q '^[[:space:]]*apprise_attachment' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
               echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') (wrong value: >${value}<) [value of apprise_attachment must be only \"true\" OR \"false\"]"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^apprise_attachment:")"
    fi

    # check, if value of notify_lang is a valid language:
    if grep -q '^[[:space:]]*notify_lang' "${taglisttmp}"; then
        while read -r line ; do
            value="$(echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]')"
            if [ -n "${value}" ] && ! echo "${value}" | grep -Eiw '^(chs|cht|csy|dan|enu|fre|ger|hun|ita|jpn|krn|nld|nor|plk|ptb|ptg|rus|spn|sve|tha|trk)$' > /dev/null  2>&1 ; then
               echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') (wrong value: >${value}<) [notify_lang must be only one of this values \"chs\" \"cht\" \"csy\" \"dan\" \"enu\" \"fre\" \"ger\" \"hun\" \"ita\" \"jpn\" \"krn\" \"nld\" \"nor\" \"plk\" \"ptb\" \"ptg\" \"rus\" \"spn\" \"sve\" \"tha\" \"trk\"]"
            fi
        done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^notify_lang:")"
    fi

    echo -e

}


prepare_python()
{
#########################################################################################
# This function check the python3 & pip installation and the necessary modules          #
#                                                                                       #
#########################################################################################

python_path=""

# check python for aarch64:
# ---------------------------------------------------------------------
# Reason for the check: dateparser cannot be installed due to an incompatibility of the backports.zoneinfo dependency. This dependency no longer exists as of Python3.9
if [ "${machinetyp}" = aarch64 ]; then
    echo -n "check if aarch64 has at least Python 3.9 installed ➜ "
    # Search for available Python versions and store them in an array
    IFS=$'\n' read -d '' -ra python_versions <<< "$(find /bin /usr/bin /usr/local/bin -maxdepth 1 -name 'python3.*')" ; IFS="${IFSsaved}"

    # Loop over the found versions to determine the latest version
    latest_py_version="3.8"
    for py_interpreter in "${python_versions[@]}"; do
        # Extract the version number from the interpreter:
        py_version=$("${py_interpreter}" -c "import sys; print('.'.join(map(str, sys.version_info[:2])))" )

        # Compare the version with the highest version so far
        if [[ "${py_version}" > "${latest_py_version}" ]]; then
            # Check if this version is 3.9 or higher by reading it from the interpreter
            latest_py_version="${py_version}"
            python_path="${py_interpreter}"
        fi
    done

    # Check if a suitable version was found
    if [ "${latest_py_version}" != "3.8" ]; then
        echo "Python 3.9 or higher found: ${latest_py_version}"
    else
        echo "No suitable Python version (>=3.9) found. Please install at least Python 3.9"
        exit 1
    fi
else
    python_path="$(which python3)"
fi

# Does the virtual Python environment match the chosen interpreter? Otherwise delete the environment:
# ---------------------------------------------------------------------
if [ -d "${python3_env}" ]; then
    local python_env_path=${python3_env}/bin/python3
    local env_version
    local py_version
    env_version=$("${python_env_path}" -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
    py_version=$("${python_path}" -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
    # Compare the version with the highest version so far
    if [[ "${env_version}" != "${py_version}" ]]; then
        echo "the virtual Python environment does not match the selected interpreter and is therefore deleted"
        rm -r "${python3_env}"
    fi
fi

# check python3 environment:
# ---------------------------------------------------------------------
    [ "${loglevel}" = 2 ] && printf "\n%s\n" "${log_indent}  Check Python:"
    if [ -z "${python_path}" ]; then
##    if [ ! "$(which python3)" ]; then
        echo "${log_indent}  (Python3 is not installed / use fallback search with regex"
        echo "${log_indent}  for more precise search results Python3 is required)"
        python_check=failed
        return 1
    else
        [ ! -d "${python3_env}" ] && "${python_path}" -m venv "${python3_env}"
        source "${python3_env}/bin/activate"

        if [ "$(head -n1 "${python3_env}/synOCR_python_env_version" 2>/dev/null)" != "${local_version}" ]; then
            [ "${loglevel}" = 2 ] && printf "%s\n" "${log_indent}  python3 already installed (${python_path})"

        # check / install pip:
        # ---------------------------------------------------------------------
            [ "${loglevel}" = 2 ] && printf "\n%s\n" "${log_indent}  Check pip:"
            if ! python3 -m pip --version > /dev/null  2>&1 ; then
                printf "%s" "${log_indent}  Python3 pip was not found and will be now installed ➜ "
                # install pip:
                tmp_log1=$(python3 -m ensurepip --default-pip)
                # upgrade pip:
                tmp_log2=$(python3 -m pip install --upgrade pip)
                # check install:
                if python3 -m pip --version > /dev/null  2>&1 ; then
                    echo "ok"
                else
                    echo "failed ! ! ! (please install Python3 pip manually)"
                    echo "${log_indent}  install log:"
                    echo "${tmp_log1}" | sed -e "s/^/${log_indent}  /g"
                    echo "${tmp_log2}" | sed -e "s/^/${log_indent}  /g"
                    python_check=failed
                    return 1
                fi
            else
                if python3 -m pip list 2>&1 | grep -q "version.*is available" ; then
                    printf "%s\n" "${log_indent}  pip already installed ($(python3 -m pip --version)) / upgrade available ..."
                    python3 -m pip install --upgrade pip | sed -e "s/^/${log_indent}  /g"
                else
                    [ "${loglevel}" = 2 ] && printf "%s\n" "${log_indent}  pip already installed ($(python3 -m pip --version))"
                fi
            fi

            [ "${loglevel}" = 2 ] && printf "\n%s\n" "${log_indent}  read installed python modules:"

            moduleList=$(python3 -m pip list 2>/dev/null)

            [ "${loglevel}" = 2 ] && echo "${moduleList}" | sed -e "s/^/${log_indent}  /g"

            # check / install python modules:
            # ---------------------------------------------------------------------
            echo -e
            for module in "${synOCR_python_module_list[@]}"; do
                moduleName=$(echo "${module}" | awk -F'=' '{print $1}' )

                unset tmp_log1
                printf "%s" "${log_indent}➜ check python module \"${module}\": ➜ "
                if !  grep -qi "${moduleName}" <<<"${moduleList}"; then
                    printf "%s" "${module} was not found and will be installed ➜ "

                    # install module:
                    tmp_log1=$(python3 -m pip install "${module}")

                    # check install:
                    if grep -qi "${moduleName}" <<<"$(python3 -m pip list 2>/dev/null)" ; then
                        echo "ok"
                    else
                        echo "failed ! ! ! (please install ${module} manually)"
                        echo "${log_indent}  install log:" && echo "${tmp_log1}" | sed -e "s/^/${log_indent}  /g"
                        python_check=failed
                        return 1
                    fi
                else
                    printf "ok\n"
                fi
            done

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
    fi

    [ "${loglevel}" = 2 ] && printf "\n%s\n" "${log_indent}  module list:" && python3 -m pip list | sed -e "s/^/${log_indent}  /g" && printf "\n"

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

        [ "${loglevel}" = 2 ] && printf "\n%s\n" "${log_indent}call find_dates.py: -fileWithTextFindings \"${searchfile}\"  \"${arg_searchnearest}\" -dateBlackList \"${ignoredDate}\" -dbg_file \"${current_logfile}\" -dbg_lvl \"${loglevel}\" -minYear \"${minYear}\" -maxYear \"${maxYear}\""

        founddatestr=$( python3 ./includes/find_dates.py -fileWithTextFindings "${searchfile}" \
                                                            "${arg_searchnearest}" \
                                                            -dateBlackList "${ignoredDate}" \
                                                            -dbg_file "${current_logfile}" \
                                                            -dbg_lvl "${loglevel}" \
                                                            -minYear "${minYear}" \
                                                            -maxYear "${maxYear}" 2>&1)

        [ "${loglevel}" = 2 ] && echo "${log_indent}find_dates.py result:" && echo "${founddatestr}" | sed -e "s/^/${log_indent}/g"

# RegEx search:
# ---------------------------------------------------------------------
    elif [ "${tmp_date_search_method}" = "regex" ]; then
        # by DeeKay1 https://www.synology-forum.de/threads/synocr-gui-fuer-ocrmypdf.99647/post-906195
        # ToDo – alphanum example:
        # (?i)\b(([0-9]?[0-9])[. ][ ]?([0-9]?[0-9][. ]|Jan.*|Feb.*|Mär.*|Apr.*|Mai|Jun.*|Jul.*|Aug.*|Sep.*|Okt.*|Nov.*|Dez.*)[ ]?([0-9]?[0-9]?[0-9][0-9]))\b
        
        echo "${log_indent}run RegEx date search - search for date format: ${format} (1 = dd mm [yy]yy; 2 = [yy]yy mm dd; 3 = mm dd [yy]yy)"
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
        echo "${log_indent}  Dates found: ${cntDatesFound}"
    
        for currentFoundDate in "${founddates[@]}" ; do
            if [ "${format}" -eq 1 ]; then
                echo "${log_indent}  check date (dd mm [yy]yy): ${currentFoundDate}"
                date_dd=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $1}' | grep -o '[0-9]*')"; echo $((n)) ) )
                date_mm=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $2}')"; echo $((n)) ) )
                date_yy=$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')
            elif [ "${format}" -eq 2 ]; then
                echo "${log_indent}  check date ([yy]yy mm dd): ${currentFoundDate}"
                date_dd=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')"; echo $((n)) ) )
                date_mm=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $2}')"; echo $((n)) ) )
                date_yy=$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $1}' | grep -o '[0-9]*')
            elif  [ "${format}" -eq 3 ]; then
                echo "${log_indent}  check date (mm dd [yy]yy): ${currentFoundDate}"
                date_dd=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $2}' | grep -o '[0-9]*')"; echo $((n)) ) )
                date_mm=$(printf '%02d' $(let "n=10#$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $1}')"; echo $((n)) ) )
                date_yy=$(echo "${currentFoundDate}" | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')
            fi
    
        # check century:
            if [ "$(echo -n "${date_yy}" | wc -m)" -eq 2 ]; then
                if [ "${date_yy}" -gt "$(date +%y)" ]; then
                    date_yy="$(($(date +%C) - 1))${date_yy}"
                    echo "${log_indent}  Date is most probably in the last century. Setting year to ${date_yy}"
                else
                    date_yy="$(date +%C)${date_yy}"
                fi
            fi
    
            date "+%d/%m/%Y" -d "${date_mm}"/"${date_dd}"/"${date_yy}" > /dev/null  2>&1    # valid date? https://stackoverflow.com/questions/18731346/validate-date-format-in-a-shell-script
            if [ $? -eq 0 ]; then
                if grep -q "${date_yy}-${date_mm}-${date_dd}" <<< "${ignoredDate}" ; then
                    echo "${log_indent}  Date ${date_yy}-${date_mm}-${date_dd} is on ignore list. Skipping this date."
                    continue
                else
                    echo "${log_indent}  ➜ valid"
                    echo "${log_indent}      day:  ${date_dd}"
                    echo "${log_indent}      month:${date_mm}"
                    echo "${log_indent}      year: ${date_yy}"
                    dateIsFound=yes
                    break
                fi
            else
                echo "${log_indent}  ➜ invalid format"
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

    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "adjusts the attributes of the target file:" "${dashline1}"

    local source_file="${1}"
    local target_file="${2}"


# adjust file permissions;
# ---------------------------------------------------------------------
    cp --attributes-only -p "${source_file}" "${target_file}"
    chmod 664 "${target_file}"
    synoacltool -enforce-inherit "${target_file}"


# adjust file date;
# ---------------------------------------------------------------------
    echo -n "${log_indent}➜ Adapt file date (Source: "

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
    if [ "${loglevel}" = 2 ] ; then
        echo "${log_indent}➜ File permissions target file:"
        echo "${log_indent}  $(ls -l "${target_file}")"
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
    echo "${log_indent}➜ renaming:"
    outputtmp="${output}"
    
    if [ -z "${NameSyntax}" ]; then
        # if no renaming syntax was specified by the user, the source filename will be used
        NameSyntax="§tit"
    fi
    echo -n "${log_indent}  apply renaming syntax ➜ "
    
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
    NewName=$( echo "${NewName}" | sed "s~§tag~${renameTag}~g;s~§tit~${title}~g;s~%20~ ~g" )
    
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
        echo "! WARNING ! – No variables were found for renaming. A fallback is used to prevent an empty file name: ${NewName}"
    else
        # all non-alphanumeric characters will be compressed
        NewName=$(sed -E 's/([^[:alnum:]])\1+/\1/g' <<< "$NewName")
        echo "${NewName}"
    fi

    [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )))]"


# set metadata:
# ---------------------------------------------------------------------
    if [[ "${keep_hash}" != "true" ]]; then
        echo -n "${log_indent}➜ insert metadata "

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

            echo "${log_indent}used metadata:" && echo "${py_meta}" | sed -e "s/^/${log_indent}➜ /g"

            # get previous metadata - maybe for feature use:
    #        get_previous_meta(){
    #            {   echo "import pprint"
    #                echo "from pypdf import PdfFileReader, PdfFileMerger"
    #                echo "if __name__ == '__main__':"
    #                echo "    file_in = open('${outputtmp}', 'rb')"
    #                echo "    pdf_reader = PdfFileReader(file_in)"
    #                echo "    metadata = pdf_reader.getDocumentInfo()"
    #                echo "    pprint.pprint(metadata)"
    #                echo "    file_in.close()"
    #            } | python3
    #        }
    #       previous_meta=$(get_previous_meta)

            outputtmpMeta="${outputtmp}_meta.pdf"

            [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "${log_indent}call handlePdf.py -dbg_lvl \"${loglevel}\" -dbg_file \"${current_logfile}\" -task metadata -inputFile \"${outputtmp}\" -metaData \"{$py_meta}\" -outputFile \"${outputtmpMeta}\""

            python3 ./includes/handlePdf.py -dbg_lvl "${loglevel}" \
                                            -dbg_file "${current_logfile}" \
                                            -task metadata \
                                            -inputFile "${outputtmp}" \
                                            -metaData "{$py_meta}"  \
                                            -outputFile "${outputtmpMeta}"

            if [ $? != 0 ] || [ "$(stat -c %s "${outputtmpMeta}")" -eq 0 ] || [ ! -f "${outputtmpMeta}" ];then
                echo "${log_indent}  ⚠️ ERROR with writing metadata ... "
            else
                mv "${outputtmpMeta}" "${outputtmp}"
            fi
            unset outputtmpMeta

        # Fallback for exiftool DSM6.2, if needed:
        elif which exiftool > /dev/null  2>&1 ; then
            echo -n "(exiftool ok) "
            exiftool -overwrite_original -time:all="${date_yy}:${date_mm}:${date_dd} 00:00:00" -sep ", " -Keywords="$( echo "${renameTag}" | sed -e "s/^${tagsymbol}//g;s/${tagsymbol}/, /g" )" "${outputtmp}"
        else
            echo "FAILED! - exiftool not found / Python-check failed or enablePyMetaData was set to false manualy! Please install it when you need it and when you want to insert metadata"
        fi

        [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )))]"
    fi


# move target files:
# ---------------------------------------------------------------------
    i=0
    if [ "${moveTaggedFiles}" = useYearDir ] ; then
    # move to folder each year:
    # ---------------------------------------------------------------------
        echo "${log_indent}➜ move to folder each year ( …/target/YYYY/file.pdf)"
        subOUTPUTDIR="${OUTPUTDIR}${date_yy}/"
        echo -n "${log_indent}  target directory \".../${date_yy}/\" exists? ➜  "
        if [ -d "${subOUTPUTDIR}" ] ;then
            echo "OK"
        else
            mkdir -p "${subOUTPUTDIR}"
            echo "created"
        fi

        prepare_target_path "${subOUTPUTDIR}" "${NewName}.pdf"

        echo "${log_indent}  target file: ${output}"

        if [[ "${keep_hash}" = "true" ]]; then
            cp -a "${keep_hash_input}" "${output}"
        else
            mv "${outputtmp}" "${output}"
            adjust_attributes "${keep_hash_input}" "${output}"
        fi
        file_processing_log 2 "${output}"

    elif [ "${moveTaggedFiles}" = useYearMonthDir ] ; then
    # move to folder each year & month:
    # ---------------------------------------------------------------------
        echo "${log_indent}➜ move to folder each year & month ( …/target/YYYY/MM/file.pdf)"
        subOUTPUTDIR="${OUTPUTDIR}${date_yy}/${date_mm}/"
        echo -n "${log_indent}  target directory \".../${date_yy}/${date_mm}/\" exists? ➜  "
        if [ -d "${subOUTPUTDIR}" ] ;then
            echo "OK"
        else
            mkdir -p "${subOUTPUTDIR}"
            echo "created"
        fi

        prepare_target_path "${subOUTPUTDIR}" "${NewName}.pdf"

        echo "${log_indent}  target file: ${output}"

        if [[ "${keep_hash}" = "true" ]]; then
            cp -a "${keep_hash_input}" "${output}"
        else
            mv "${outputtmp}" "${output}"
            adjust_attributes "${keep_hash_input}" "${output}"
        fi
        file_processing_log 2 "${output}"

    elif [ -n "${renameCat}" ] && [ "${moveTaggedFiles}" = useCatDir ] ; then
    # use sorting in category folder:
    # ---------------------------------------------------------------------
        echo "${log_indent}➜ move to category directory"

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

            echo -n "${log_indent}  tag directory \"${tagdir}\" exists? ➜  "

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
                # tagdir=$(echo ${tagdir} | sed 's%\/\|\\\|\:\|\?%_%g' ) # gefiltert wird: \ / : ?
                subOUTPUTDIR="${OUTPUTDIR%/}/${tagdir%/}/"
                if [ -d "${subOUTPUTDIR}" ] ;then
                    echo "OK [subfolder target dir]"
                else
                    mkdir -p "${subOUTPUTDIR}"
                    echo "created [subfolder target dir]"
                fi
            fi

            prepare_target_path "${subOUTPUTDIR}" "${NewName}.pdf"

            echo "${log_indent}  target:   ${subOUTPUTDIR%/}/${output##*/}"

            # check if the same file has already been sorted into this category (different tags, but same category)
            if echo -e "${DestFolderList}" | grep -q "^${tagarray[$i]}$" ; then
                echo "${log_indent}  same file has already been copied into target folder (${tagarray[$i]}) and is skipped!"
            else
                if [[ $(echo "${outputtmp}" | awk -F/ '{print $2}') != $(echo "${output}" | awk -F/ '{print $2}') ]]; then
                    echo "${log_indent}  do not set a hard link when copying across volumes"
                    # do not set a hardlink when copying across volumes:
                    if [[ "${keep_hash}" = "true" ]]; then
                        cp -a "${keep_hash_input}" "${output}"
                    else
                        cp "${outputtmp}" "${output}"
                    fi
                   file_processing_log 2 "${output}"
                else
                    echo "${log_indent}  set a hard link"
                    if [[ "${keep_hash}" = "true" ]]; then
                        commandlog=$(cp -al "${keep_hash_input}" "${output}" 2>&1 )
                    else
                        commandlog=$(cp -l "${outputtmp}" "${output}" 2>&1 )
                    fi

                    # check: - creating hard link don't fails / - target file is valid (not empty)
                    if [ $? != 0 ] || [ "$(stat -c %s "${output}")" -eq 0 ] || [ ! -f "${output}" ];then
                        echo "${log_indent}  ${commandlog}"
                        echo "${log_indent}  Creating a hard link failed! A file copy is used."
                        if [ "${loglevel}" = 2 ] ; then
                            echo "${log_indent}list of mounted volumes:"
                            df -h --output=source,target | sed -e "s/^/${log_indent}      /g"
                            echo -e
                        fi
                        if [[ "${keep_hash}" = "true" ]]; then
                            cp -fa "${keep_hash_input}" "${output}"
                        else
                            cp -f "${outputtmp}" "${output}"
                        fi
                    fi
                    file_processing_log 2 "${output}"
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
        echo "${log_indent}➜ move to tag directory"
    
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

            echo -n "${log_indent}  tag directory \"${tagdir}\" exists? ➜  "

            if [ -d "${OUTPUTDIR}${tagdir}" ] ;then
                echo "OK"
            else
                mkdir "${OUTPUTDIR}${tagdir}"
                echo "created"
            fi

            prepare_target_path "${OUTPUTDIR}${tagdir}" "${NewName}.pdf"

            echo "${log_indent}  target:   ./${tagdir}/${output##*/}"

            if [[ $(echo "${outputtmp}" | awk -F/ '{print $2}') != $(echo "${output}" | awk -F/ '{print $2}') ]]; then
                echo "${log_indent}  do not set a hard link when copying across volumes"
                # do not set a hardlink when copying across volumes:
                if [[ "${keep_hash}" = "true" ]]; then
                    cp -a "${keep_hash_input}" "${output}"
                else
                    cp "${outputtmp}" "${output}"
                fi
                file_processing_log 2 "${output}"
            else
                echo "${log_indent}  set a hard link"
                if [[ "${keep_hash}" = "true" ]]; then
                    commandlog=$(cp -al "${keep_hash_input}" "${output}" 2>&1 )
                else
                    commandlog=$(cp -l "${outputtmp}" "${output}" 2>&1 )
                fi
                # check: - creating hard link don't fails / - target file is valid (not empty)
                if [ $? != 0 ] || [ "$(stat -c %s "${output}")" -eq 0 ] || [ ! -f "${output}" ];then
                    echo "${log_indent}  ${commandlog}"
                    echo "${log_indent}  Creating a hard link failed! A file copy is used."
                    if [ "${loglevel}" = 2 ] ; then
                        echo "${log_indent}list of mounted volumes:"
                        df -h --output=source,target | sed -e "s/^/${log_indent}      /g"
                        echo -e
                    fi

                    if [[ "${keep_hash}" = "true" ]]; then
                        cp -af "${keep_hash_input}" "${output}"
                    else
                        cp -f "${outputtmp}" "${output}"
                    fi
                fi
                file_processing_log 2 "${output}"
            fi

            [[ "${keep_hash}" != "true" ]] && adjust_attributes "${keep_hash_input}" "${output}"

            i=$((i + 1))
        done
    
        echo "${log_indent}➜ delete temp. target file"
        rm "${outputtmp}"
    else
    # no rule fulfilled - use the target folder:
    # ---------------------------------------------------------------------
        prepare_target_path "${OUTPUTDIR}" "${NewName}.pdf"

        echo "${log_indent}  target file: ${output}"

        if [[ "${keep_hash}" = "true" ]]; then
            cp -af "${keep_hash_input}" "${output}"
        else
            mv "${outputtmp}" "${output}"
            adjust_attributes "${keep_hash_input}" "${output}"
        fi
        file_processing_log 2 "${output}"
    fi

}


purge_log()
{
#########################################################################################
# This function cleans up older log files                                               #
#########################################################################################

    if [ -z "${LOGmax}" ]; then
        printf "\n  purge_log deactivated!\n"
        return
    fi

    printf "\n  purge log files ...\n"


# delete surplus logs:
# ---------------------------------------------------------------------
    count2del=$(( $(find "${LOGDIR}" -maxdepth 1 -type f -name 'synOCR*.log' -printf '.' | wc -c) - LOGmax ))
    [ "${count2del}" -lt 0 ] && count2del=0
    echo "  delete ${count2del} log files ( > ${LOGmax} files)"

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
    echo "  delete ${count2del} search files ( > ${LOGmax} files)"

    if [ "${count2del}" -gt 0 ]; then
        while read -r line ; do
            [ -z "${line}" ] && continue
            [ -f "${line}" ] && rm "${line}"
        done <<< "$(find "${LOGDIR}" -maxdepth 1 -type f -name 'synOCR_searchfile*.txt' -printf '%T@ %p\n' | sort -n | cut -d ' ' -f 2- | head -n${count2del} )"
    fi

}


purge_backup()
{
#########################################################################################
# This function cleans up older backup files                                            #
#########################################################################################

    if [ -z "${backup_max}" ] || [ "${backup_max}" = 0 ]; then
        printf "\n%s\n" "  purge backup deactivated!"
        return
    fi

    printf "\n%s\n" "  purge backup files ..."

    if [ "${img2pdf}" = true ]; then
        source_file_type4find="\(JPG\|jpg\|PNG\|png\|TIFF\|tiff\|JPEG\|jpeg\|PDF\|pdf\)"
    else
        source_file_type4find="\(PDF\|pdf\)"
    fi


# delete surplus backup files:
# ---------------------------------------------------------------------
    if [[ "${backup_max_type}" == days ]]; then
        echo "  delete $(find "${BACKUPDIR}" -maxdepth 1 -regex ".*\.${source_file_type4find}$" -mtime +"${backup_max}" | wc -l) backup files ( > ${backup_max} days)"
        find "${BACKUPDIR}" -maxdepth 1 -regex ".*\.${source_file_type4find}$" -mtime +"${backup_max}" -exec rm -f"${rm_log_level}" {} \; | sed -e "s/^/${log_indent}/g"
    else
        count2del=$(( $(find "${BACKUPDIR}" -maxdepth 1 -type f -regex ".*\.${source_file_type4find}$" -printf '.' | wc -c) - backup_max ))
        [ "${count2del}" -lt 0 ] && count2del=0
        echo "  delete ${count2del} backup files ( > ${backup_max} files)"

        if [ "${count2del}" -gt 0 ]; then
            while read -r line ; do
                [ -z "${line}" ] && continue
                [ -f "${line}" ] && rm -fv "${line}" | sed -e "s/^/${log_indent}/g"
            done <<< "$(find "${BACKUPDIR}" -maxdepth 1 -type f -regex ".*\.${source_file_type4find}$" -printf '%T@ %p\n' | sort -n | cut -d ' ' -f 2- | head -n${count2del} )"
        fi
    fi

}


py_page_count()
{
#########################################################################################
# This function receives a PDF file path and give back number of pages                  #
#########################################################################################

# Die Version 1.18.6 verwendet die alte CamelCase-Notation:
    python3 -c "import sys, os, fitz; \
                path = os.path.abspath(sys.argv[1]); \
                doc = fitz.open(path); \
                print(doc.pageCount)" "$1"
                

# Ab Version 1.19.0 (März 2022) wurde die PEP8-konforme Schreibweise eingeführt:
#    python3 -c "import sys, os, fitz; \
#                path = os.path.abspath(sys.argv[1]); \
#                print(fitz.open(path).page_count)" "$1"

#    python3 -c "import sys, os, pypdf; \
#                path = os.path.abspath(sys.argv[1]); \
#                print(len(pypdf.PdfReader(path).pages))" "$1"
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

    # Quelldateinamen parsen
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

    # Prüfen, ob der Quellzähler direkt verwendet werden kann
    if ((source_counter > 0)); then
        local source_counter_file="${target_dir_path}${base} (${source_counter}).${ext}"
        if [ ! -f "$source_counter_file" ]; then
            output="$source_counter_file"
            printf "%s\n\n" "${log_indent}➜ Verwende Quellzähler: ${source_counter}"
            return
        fi
    fi

    # Existierende Zähler sammeln (inkl. Basisdatei)
    local existing_counters=()
    [ -f "${target_dir_path}${base}.${ext}" ] && existing_counters+=(0)
    while IFS= read -r -d '' file; do
        if [[ "$(basename "$file")" =~ \ \(([0-9]+)\)\.${ext}$ ]]; then
            existing_counters+=("${BASH_REMATCH[1]}")
        fi
    done < <(find "${target_dir_path}" -maxdepth 1 -type f -name "${base} (*).${ext}" -print0 2>/dev/null)

    # Keine Dateien vorhanden ➜ Basisname verwenden
    if [ ${#existing_counters[@]} -eq 0 ]; then
        output="${target_dir_path}${base}.${ext}"
        return
    fi

    # Höchsten Zähler ermitteln
    local existing_max=0
    for n in "${existing_counters[@]}"; do
        ((n > existing_max)) && existing_max=$n
    done

    # Startzähler festlegen
    local start_counter=$((existing_max + 1))

    # Nächsten verfügbaren Zähler finden
    local counter=$start_counter
    while [ -f "${target_dir_path}${base} (${counter}).${ext}" ]; do
        counter=$((counter + 1))
    done

    # Ausgabepfad immer mit Zähler setzen, wenn Dateien existieren
    output="${target_dir_path}${base} (${counter}).${ext}"
    printf "%s\n\n" "${log_indent}➜ Neuer Zähler: (${counter})"

}


py_img2pdf()
{
#########################################################################################
# This function convert images to pdf                                                   #
# https://datatofish.com/images-to-pdf-python/                                          #
#########################################################################################

printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "convert images to pdf" "${dashline1}"

collect_input_files "${INPUTDIR}" "image"

[ -z "${files}" ] && echo "${log_indent}nothing to do ..." && return 0

while read -r input ; do
    [ ! -f "${input}" ] && continue
    printf "\n"
    filename="${input##*/}"
    title="${filename%.*}"
    echo "CURRENT FILE:   ➜ source: ${filename}"
#    date_start=$(date +%s)


# convert file
# ---------------------------------------------------------------------
    prepare_target_path "${INPUTDIR}" "${title}${SearchSuffix}.pdf"
    echo "${log_indent}➜ target: ${output}"
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
            echo "${log_indent}➜ backup source file" # to $output"
            prepare_target_path "${BACKUPDIR}" "${filename}"
            mv "${input}" "${output}"
        else
            echo "${log_indent}➜ delete source file (${filename})"
            rm -f "${input}"
        fi
    else
        echo "${log_indent}➜ ERROR with ${output}"
    fi

done <<<"${files}"

}


main_1st_step()
{
#########################################################################################
# This function passes the files to docker / split files / …                            #
#########################################################################################

printf "\n\n  %s\n  ● %-80s●\n  %s\n\n" "${dashline2}" "STEP 1 - RUN OCR / SPLIT FILES, IF NEEDED:" "${dashline2}"

collect_input_files "${INPUTDIR}" "pdf"
files_step1="${files}"

while read -r input1 ; do
    [ ! -f "${input1}" ] && continue


# use delay for permanent writing scanners
# ---------------------------------------------------------------------
    if [[ ${delay:-0} -ne 0 ]]; then
        while true; do
            current_time=$(date +%s)
            file_time=$(stat -c %Y "${input1}")
            if [ $((current_time - file_time)) -ge ${delay} ]; then
                printf "%s\n" "${log_indent}delayed processing started (file older than ${delay}s)"
                break
            fi
            sleep 1
        done
    fi


# create temporary working directory
# ---------------------------------------------------------------------
    work_tmp_step1="${work_tmp_main%/}/step1_tmp_$(uuidgen)/"
    mkdir -p "${work_tmp_step1}"

    printf "\n"
    filename="${input1##*/}"
    title="${filename%.*}"
    keep_hash_input="${input1}"
    echo "${dashline2}"
    echo "CURRENT FILE:   ➜ ${filename}"
    file_processing_log 1 "${filename}"
    date_start_file=$(date +%s)
    was_splitted=0
    split_error=0
    process_error=1 # is set to 0 in the file_processing_log() function when the target file is successfully created

    outputtmp="${work_tmp_step1%/}/${title}.pdf"
    echo "${log_indent}  temp. target file: ${outputtmp}"


# adjust color
# ---------------------------------------------------------------------
    # Array für zusätzliche Argumente initialisieren
    args=()
    adjustColor=false
    unset adjustColorSuccess

    # --threshold nur hinzufügen, wenn adjustColorBWthreshold nicht leer ist
    if [ "${adjustColorBWthreshold}" != "0" ]; then
        args+=(--threshold "${adjustColorBWthreshold}")
        adjustColor=true
    fi

    # --dpi nur hinzufügen, wenn adjustColorDPI nicht leer ist
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

    # --sharpness nur hinzufügen, wenn nicht 1 und nicht 1.0
    if [ "${adjustColorSharpness}" != "1" ] && [ "${adjustColorSharpness}" != "1.0" ]; then
        args+=(--sharpness "${adjustColorSharpness}")
        adjustColor=true
    fi

    if [ "${adjustColor}" = true ] && [[ "${keep_hash}" = "true" ]]; then
        printf "%s\n\n" "${log_indent}adjustColor is disabled because --keep_hash is set"
    elif [ "${adjustColor}" = true ] && [ "${python_check}" = "ok" ]; then
        printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" " adjust color" "${dashline1}"
        printf "${log_indent}used parameter: %s\n" "${args[*]}"

        mkdir "${work_tmp_step1%/}/pdf2bw"
        color_adjustment_target="${work_tmp_step1%/}/pdf2bw/${outputtmp##*/}"
        [ -s "${color_adjustment_target}" ] && rm -f "${color_adjustment_target}" # Delete previous file
        unset input_bw

        adjustColorLOG=$(python3 ./includes/color_adjustment.py "${input1}" "${color_adjustment_target}" "${args[@]}" )
        wait
        exit_code=$?

        if [ $exit_code -eq 0 ]; then
            printf "%s\n" "${log_indent}PDF successfully adjust color"
            adjustColorSuccess=true
        else
            printf "%s\n" "${log_indent}ERROR – No valid target PDF file found or file does not exist."
        fi
        [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "${log_indent}adjustColorLOG: $adjustColorLOG"
        unset exit_code
    fi

    unset args

    printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )))]"

# OCRmyPDF:
# ---------------------------------------------------------------------
    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "processing PDF @ OCRmyPDF:" "${dashline1}"

    dockerlog=$(OCRmyPDF 2>&1)

    echo "${log_indent}➜ OCRmyPDF-LOG:"
    echo "${dockerlog}" | sed -e "s/^/${log_indent}  /g"
    printf "%s\n\n" "${log_indent}← OCRmyPDF-LOG-END"

    # check if target file is valid (not empty), otherwise continue / 
    # defective source files are moved to ERROR including LOG:
    # ---------------------------------------------------------------------
    if [ ! -f "${outputtmp}" ] || [ "$(stat -c %s "${outputtmp}" 2>/dev/null)" -eq 0 ]; then
        echo "${log_indent}  ┖➜ failed! (target file is empty or not available)"
        rm "${outputtmp}"
        if echo "${dockerlog}" | grep -iq ERROR ;then
            if [ ! -d "${INPUTDIR}ERRORFILES" ] ; then
                echo "${log_indent}                  ERROR-Directory [${INPUTDIR}ERRORFILES] will be created!"
                mkdir "${INPUTDIR}ERRORFILES"
            fi

            prepare_target_path "${INPUTDIR}ERRORFILES" "${filename}"

            mv "${input1}" "${output}"
            [ "${loglevel}" != 0 ] && cp "${current_logfile}" "${output}.log"
            echo "${log_indent}              ┖➜ move to ERRORFILES"
        fi
        rm -rf "${work_tmp_step1}"
        continue
    else
        printf "%s\n\n" "${log_indent}target file (OK): ${outputtmp}"
    fi

    printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )))]"

# detect & remove blank pages with scanrep (https://pypi.org/project/scanprep/):
# ---------------------------------------------------------------------
    if [ "${blank_page_detection_switch}" = true ] && [ "${python_check}" = "ok" ]; then
        printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "detect & remove blank pages:" "${dashline1}"

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
            printf "%s\n\n" "${log_indent}$((pagePreCount - pagePostCount)) (blank pages) out of ${pagePreCount} pages removed."
        else
            printf "%s\n\n" "${log_indent}ERROR – No valid target PDF file found or file does not exist."
        fi
        printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )))]"
    fi


# document split handling
# ---------------------------------------------------------------------
    if [ -n "${documentSplitPattern}" ] && [ "${python_check}" = "ok" ]; then
        printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "document split handling:" "${dashline1}"

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
            echo "${log_indent}! ! ! error at counting PDF pages"
        fi

    # split document:
    # ---------------------------------------------------------------------
        unset splitJob

        split_pages(){

            echo "${log_indent}part:            ${1}"
            echo "${log_indent}first page:      ${2}"
            echo "${log_indent}last page:       ${3}"
#           echo "${log_indent}splitted file:   $4"

            pageRange=$(seq -s ", " "${2}" 1 "${3}" )
            echo "${log_indent}used pages:      ${pageRange}"

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

            [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "${log_indent}call handlePdf.py: -dbg_lvl \"${loglevel}\" -dbg_file \"${current_logfile}\" -task split -inputFile \"${outputtmp}\" -startPage \"${2}\" -endPage \"${3}\" -outputFile \"${4}\""

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
        printf "%s\n\n" "${log_indent}splitpage count: ${SplitPageCount}"

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
                    echo "${log_indent}➜ move the split file to: ${output}"
                    was_splitted=1
                else
                    echo "${log_indent}! ! ! ERROR with splitting file"
                    split_error=1
                fi
            done <<<"$(sort <<<"${splitJob}")"
        else
            echo "${log_indent}no separator sheet found, or number of pages too small"
        fi
    else
        echo "${log_indent}no split pattern defined or splitting not possible"
    fi

    if [[ ("${was_splitted}" = 0 || "${split_error}" = 1) && "${keep_hash}" != "true" ]]; then
        copy_attributes "${input1}" "${outputtmp}"
    fi

    if [ "${was_splitted}" = 0 ] || [ "${split_error}" = 1 ]; then
        mv "${outputtmp}" "${work_tmp_main}"
    fi

    printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )))]"

    # 2. main loop for PDF processing:
    main_2nd_step


# delete / save source file (takes into account existing files with the same name):
# ---------------------------------------------------------------------
    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "handle source file:" "${dashline1}"

    if [ "${backup}" = true ] && [ "${process_error}" -eq 0 ]; then
        prepare_target_path "${BACKUPDIR}" "${filename}"
        mv "${input1}" "${output}"
        echo "${log_indent}➜ backup source file to: ${output}"
    elif [ "${process_error}" -eq 1 ]; then
        # target file is not valid / source files are moved to ERRORFILES including LOG:
        echo "${log_indent}  ┖➜ failed! (process_error flag is 1)"
        if [ ! -d "${INPUTDIR}ERRORFILES" ] ; then
            echo "${log_indent}                  ERROR-Directory [${INPUTDIR}ERRORFILES] will be created!"
            mkdir "${INPUTDIR}ERRORFILES"
        fi

        prepare_target_path "${INPUTDIR}ERRORFILES" "${input1}"

        mv "${input1}" "${output}"
        [ "${loglevel}" != 0 ] && cp "${current_logfile}" "${output}.log"
        echo "${log_indent}              ┖➜ move to ERRORFILES"
        rm -rf "${work_tmp_step1}"
    else
        rm -f "${input1}"
        echo "${log_indent}➜ delete source file (${filename})"
    fi

    rm -rfv "${work_tmp_step1}" | sed -e "s/^/${log_indent}/g"

    echo -e
done <<<"${files_step1}"

}


main_2nd_step()
{
#########################################################################################
# This function search for tags / rename / sort to target folder                        #
#########################################################################################
printf "\n  %s\n  ● %-80s●\n  %s\n\n" "${dashline2}" "STEP 2 - SEARCH TAGS / RENAME / SORT:" "${dashline2}"

collect_input_files "${work_tmp_main}" "pdf"
files_step2="${files}"

# make special characters visible if necessary
# ---------------------------------------------------------------------
    # shellcheck disable=SC2012  # Don't warn about "Use find instead of ls to better handle non-alphanumeric filenames" in this function
    [ "${loglevel}" = 2 ] && printf "\n%s\n" "${log_indent}list files in INPUT with transcoded special characters:" && ls "${work_tmp_main}" | sed -ne 'l' | sed -e "s/^/${log_indent}➜ /g" && echo -e

# save different global settings to be able to adjust them individually with yaml rules in each loop:
    apprise_call_saved="${apprise_call}"
    apprise_attachment_saved="${apprise_attachment}"
    notify_lang_saved="${notify_lang}"

# ---------------------------------------------------------------------
while read -r input ; do
    [ ! -f "${input}" ] && continue

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

    echo -e
    filename="${input##*/}"
    title="${filename%.*}"
    echo "${dashline2}"
    echo "CURRENT FILE:   ➜ ${filename}"
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
        [ "${loglevel}" = 2 ] && echo "${log_indent}(pages counted with python module fitz)"
    elif [ "$(which pdfinfo)" ]; then
        pagecount_latest=$(pdfinfo "${output}" 2>/dev/null | grep "Pages\:" | awk '{print $2}')
        [ "${loglevel}" = 2 ] && echo "${log_indent}(pages counted with pdfinfo)"
    elif [ "$(which exiftool)" ]; then
        pagecount_latest=$(exiftool -"*Count*" "${output}" 2>/dev/null | awk -F' ' '{print $NF}')
        [ "${loglevel}" = 2 ] && echo "${log_indent}(pages counted with exiftool)"
    fi

    [ -z "${pagecount_latest}" ] && pagecount_latest=0 && echo "${log_indent}! ! ! ERROR - with pdfinfo / exiftool / pypdf - \$pagecount was set to 0"

    global_pagecount_new="$((global_pagecount_new+pagecount_latest))"
    global_ocrcount_new="$((global_ocrcount_new+1))"
    pagecount_profile_new="$((pagecount_profile_new+pagecount_latest))"
    ocrcount_profile_new="$((ocrcount_profile_new+1))"


# source file permissions-Log:
# ---------------------------------------------------------------------
    if [ "${loglevel}" = 2 ] ; then
        echo "${log_indent}➜ File permissions source file:"
        echo -n "${log_indent}  "
#       ls -l "${input}"
        ls -l "${keep_hash_input}"
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
    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "search tags in ocr text:" "${dashline1}"
    tag_search
    printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )))]"

# search by date:
# ---------------------------------------------------------------------
    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "search for a valid date in ocr text:" "${dashline1}"
    dateIsFound=no
    find_date 1

    date_dd_source=$(stat -c %y "${keep_hash_input}" | awk '{print $1}' | awk -F- '{print $3}')
    date_mm_source=$(stat -c %y "${keep_hash_input}" | awk '{print $1}' | awk -F- '{print $2}')
    date_yy_source=$(stat -c %y "${keep_hash_input}" | awk '{print $1}' | awk -F- '{print $1}')
    date_houre_source=$(stat -c %y "${keep_hash_input}" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $1}')
    date_min_source=$(stat -c %y "${keep_hash_input}" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $2}')
    date_sek_source=$(stat -c %y "${keep_hash_input}" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $3}')

    if [ "${dateIsFound}" = no ]; then
        echo "${log_indent}  Date not found in OCR text - use file date:"
        date_dd=$date_dd_source
        date_mm=$date_mm_source
        date_yy=$date_yy_source
        echo "${log_indent}  day:  ${date_dd}"
        echo "${log_indent}  month:${date_mm}"
        echo "${log_indent}  year: ${date_yy}"
    fi

    printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )))]"


# compose and rename file names / move to target:
# ---------------------------------------------------------------------
    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "rename and sort to target folder:" "${dashline1}"
    rename
    printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_file )))]"

    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "final tasks:" "${dashline1}"


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

        if [ "$?" -eq 0 ] ; then
            echo "${log_indent}  APPRISE-LOG:"
            echo "${apprise_LOG}" | sed -e "s/^/${log_indent}  /g"
        elif [ "$?" -ne 0 ] || [ "${loglevel}" = 2 ]; then # for log level 1 only error output
            echo -n "${log_indent}  APPRISE-Error: "
            echo "${apprise_LOG}" | sed -e "s/^/${log_indent}  /g"
        fi
    else
        echo "${log_indent}  INFO: Notify for apprise not defined ..."
    fi

    # run user defined (YAML) post scripts:
    printf "\nrun user defined post scripts:\n"
    for cmd in "${postscriptarray[@]}"; do
        echo " ➜ ${cmd}"
        eval "${cmd}"
        unalias "${cmd}"
    done
    unset postscriptarray

# update file count profile:
# ---------------------------------------------------------------------
    printf "\nStats:\n"

    sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET value_1='${global_pagecount_new}' WHERE key='global_pagecount'"
    sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET value_1='${global_ocrcount_new}' WHERE key='global_ocrcount'"

    sqlite3 "./etc/synOCR.sqlite" "UPDATE config SET pagecount='${pagecount_profile_new}' WHERE profile_ID='${profile_ID}'"
    sqlite3 "./etc/synOCR.sqlite" "UPDATE config SET ocrcount='${ocrcount_profile_new}' WHERE profile_ID='${profile_ID}'"

    echo "  runtime last file:    ➜ $(sec_to_time $(( $(date +%s) - date_start_file )))"
    echo "  pagecount last file:  ➜ ${pagecount_latest}"
    echo "  file count profile :  ➜ (profile $profile) - ${ocrcount_profile_new} PDF's / ${pagecount_profile_new} Pages processed up to now"
    echo "  file count total:     ➜ ${global_ocrcount_new} PDF's / ${global_pagecount_new} Pages processed up to now since ${count_start_date}"

    printf "\ncleanup:\n"

# delete temporary working directory:
# ---------------------------------------------------------------------
    echo "  delete tmp-files ..."
    rm -rfv "${input}" | sed -e "s/^/${log_indent}/g"   # rm ocred version - source file is backuped after ocrmypdf processing 

done <<<"${files_step2}"

    [ -d "${work_tmp_step2}" ] && rm -rfv "${work_tmp_step2}" | sed -e "s/^/${log_indent}/g"
    [ -d "${work_tmp_main}" ] && rm -rfv "${work_tmp_main}" | sed -e "s/^/${log_indent}/g"
}

    printf "\n\n\n"
    echo "  ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●"
    echo "  ● ---------------------------------- ●"
    echo "  ● |    ==> RUN THE FUNCTIONS <==   | ●"
    echo "  ● ---------------------------------- ●"
    echo "  ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●"


# prepare steps (check / install / activate python enviroment & check docker):
# --------------------------------------------------------------------
    update_dockerimage

    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "check the python3 installation and the necessary modules:" "${dashline1}"
    [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "${log_indent}[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_all )))]"

    prepare_python_log=$(prepare_python)
    if [ "$?" -eq 0 ]; then
        [ -n "${prepare_python_log}" ] && echo "${prepare_python_log}"
        printf "%s\n" "${log_indent}prepare_python: OK"
        source "${python3_env}/bin/activate"
    else
        [ -n "${prepare_python_log}" ] && echo "${prepare_python_log}"
        printf "%s\n" "${log_indent}prepare_python: ! ! ! ERROR ! ! ! "
    fi


# main steps:
# ---------------------------------------------------------------------
    if [ "${img2pdf}" = true ]; then
        py_img2pdf
    fi

# create temporary working directory
# ---------------------------------------------------------------------
    work_tmp_main=$(mktemp -d -t tmp.XXXXXXXXXX)
    trap '[ -d "${work_tmp_main}" ] && rm -rf "${work_tmp_main}"; exit' EXIT
    echo "Target temp directory:    ${work_tmp_main}"

    main_1st_step
    purge_log
    purge_backup

    [ -d "${work_tmp_main}" ] && rmdir -v "${work_tmp_main}" | sed -e "s/^/  /g"

    printf "\n%s\n\n\n" "  runtime all files:              ➜ $(sec_to_time $(( $(date +%s) - date_start_all )))"

exit 0
