#!/bin/bash
# shellcheck disable=SC1090,SC1091,SC2001,SC2009,SC2181

#################################################################################
#   description:    main script for running synOCR                              #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/synOCR.sh          #
#   © 2023 by geimist                                                           #
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
    synOCR_python_module_list=( DateTime dateparser "pypdf==3.5.1" "pikepdf==7.1.2" Pillow yq PyYAML apprise )
                                # PyPDF2 manual: https://pypdf2.readthedocs.io/en/latest/
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
            blank_page_detection_switch, blank_page_detection_threshold_bw, blank_page_detection_threshold_black_pxl
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
    blank_page_detection_threshold_bw=$(echo "${sqlerg}" | awk -F'\t' '{print $40}')
    blank_page_detection_threshold_black_pxl=$(echo "${sqlerg}" | awk -F'\t' '{print $41}')


# read global values:
    dockerimageupdate=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='dockerimageupdate' ")
    count_start_date=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='count_start_date'")
    global_pagecount=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_pagecount'")
    global_ocrcount=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_ocrcount'")
    online_version=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='online_version'")

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
    devID=$(printf '%010d' "$(cksum </sys/class/net/eth0/address | awk '{print $1}')")
    device=$(uname -a | awk -F_ '{print $NF}' | sed "s/+/plus/g")

    echo "Device:                   ${device} (${devID})"
    echo "current Profil:           ${profile}"
    echo -n "monitor is running?:      "
    if ps aux | grep -qE "[i]notifywait.*--fromfile.*inotify.list"; then
        echo "yes"
    else
        echo "no"
    fi
    echo "DB-version:               $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='db_version'")"
    echo "used image (created):     ${dockercontainer} ($(docker inspect -f '{{ .Created }}' "${dockercontainer}" 2>/dev/null | awk -F. '{print $1}'))"

    documentAuthor=$(awk -F'[ ]-' '{for(i=1;i<=NF;i++){if($i)print "-"$i}}' <<<" ${ocropt}" | grep "\-\-author" | sed -e 's/--author //')
    echo "document author:          ${documentAuthor}"

    echo "used ocr-parameter (raw): ${ocropt}"
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
    done <<< "$(awk -F'[ ]-' '{for(i=1;i<=NF;i++){if($i)print "-"$i}}' <<<" ${ocropt}")"
    unset c

    echo "ocropt_array:             ${ocropt_arr[*]}"
    echo "search prefix:            ${SearchPraefix}"
    echo "replace search prefix:    ${delSearchPraefix}"
    echo "renaming syntax:          ${NameSyntax}"
    echo "Symbol for tag marking:   ${tagsymbol}"
    tagsymbol="${tagsymbol// /%20}"   # mask spaces
    echo "target file handling:     ${moveTaggedFiles}"
    echo "Document split pattern:   ${documentSplitPattern}"
    echo "split page handling:      ${splitpagehandling}"
    echo "delete blank pages:       ${blank_page_detection_switch}"
    echo "threshold black/white:    ${blank_page_detection_threshold_bw}"
    echo "threshold black pixels:   ${blank_page_detection_threshold_black_pxl}"
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
                printf "%s" $(("${year}""${functionType}""$(date +%Y)"))
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


OCRmyPDF()
{
    # shellcheck disable=SC2002  # Don't warn about "Useless cat" in this function
    # https://www.synology-forum.de/showthread.html?99516-Container-Logging-in-Verbindung-mit-stdin-und-stdout
    cat "${input}" | docker run --name synOCR --network none --rm -i -log-driver=none -a stdin -a stdout -a stderr "${dockercontainer}" "${ocropt_arr[@]}" - - | cat - > "${outputtmp}"
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
        type_of_rule=advanced

        yaml_validate

        if [ "${python_check}" = "ok" ]; then
            [ "${loglevel}" = 2 ] && echo "${log_indent}check and convert yaml 2 json with python"
            tag_rule_content=$( ${python3_env}/bin/python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read()), indent=2, sort_keys=False))' < "${taglisttmp}")
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

        [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start )))]"

        echo "${log_indent}search by tag rule: \"${tagrule}\" ➜  "

        condition=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.condition" | tr '[:upper:]' '[:lower:]')
        if [ "${condition}" = null ] ; then
            echo "${log_indent}          [value for condition must not be empty - fallback to any]"
            condition=any
        fi

        searchtag=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.tagname" | sed 's%\/\|\\\|\:\|\?%_%g' ) # filtered: \ / : ?
        targetfolder=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.targetfolder" )
        tagname_RegEx=$(echo "${tag_rule_content}" | jq -r ".${tagrule}.tagname_RegEx" )
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

                tagname_RegEx_result=$( grep -oP${grep_opt} "${tagname_RegEx}" "${VARsearchfile}" | head -n1 | sed 's%\/\|\\\|\:\|\?%_%g' )
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
        [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start )) )]"

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

if [ "${loglevel}" = 2 ] ; then
    printf "\n%s\n\n" "[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start )))]"
fi

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
    while read -r line ; do
        if ! echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(all|any|none)$' > /dev/null  2>&1 ; then
           echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') [value of condition must be only \"all\" OR \"any\" OR \"none\"]"
        fi
    done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^condition:")"

    # check, if value of isRegEx is "true" OR "false":
    while read -r line ; do
        if ! echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
           echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') [value of isRegEx must be only \"true\" OR \"false\"]"
        fi
    done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^isRegEx:")"

    # check, if value of source is "content" OR "filename":
    while read -r line ; do
        if ! echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(content|filename)$' > /dev/null  2>&1 ; then
           echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') [value of source must be only \"content\" OR \"filename\"]"
        fi
    done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^source:")"

    # check of corect value of searchtype:
    while read -r line ; do
        if ! echo "${line}" | awk -F: '{print $3}' | sed 's/^ *//;s/ *$//' | tr -cd '[:alnum:][:blank:]' | grep -Eiw '^(is|is not|contains|does not contain|starts with|does not starts with|ends with|does not ends with|matches|does not match)$' > /dev/null  2>&1 ; then
           echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') [value of searchtype must be only \"is\" OR \"is not\" OR \"contains\" OR \"does not contain\" OR \"starts with\" OR \"does not starts with\" OR \"ends with\" OR \"does not ends with\" OR \"matches\" OR \"does not match\"]"
        fi
    done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wnE "^searchtyp:|^searchtype:")"

    # check, if value of casesensitive is "true" OR "false":
    while read -r line ; do
        if ! echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
           echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') [value of casesensitive must be only \"true\" OR \"false\"]"
        fi
    done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^casesensitive:")"

    # check, if value of multilineregex is "true" OR "false":
    while read -r line ; do
        if ! echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
           echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') [value of multilineregex must be only \"true\" OR \"false\"]"
        fi
    done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^multilineregex:")"

    # check apprise_call:
    # ToDo: which regex can check this?
#    while read -r line ; do
#        if ! echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
#           echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') [value of apprise_call must be only \"true\" OR \"false\"]"
#        fi
#    done <<<"$(cat "${taglisttmp}" | sed 's/^ *//;s/ *$//' | grep -n "^apprise_call:")"
#   done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^apprise_call:")"

    # check, if value of apprise_attachment is "true" OR "false":
    while read -r line ; do
        if ! echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
           echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') [value of apprise_attachment must be only \"true\" OR \"false\"]"
        fi
    done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^apprise_attachment:")"

    # check, if value of notify_lang is a valid language:
    while read -r line ; do
        if ! echo "${line}" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(chs|cht|csy|dan|enu|fre|ger|hun|ita|jpn|krn|nld|nor|plk|ptb|ptg|rus|spn|sve|tha|trk)$' > /dev/null  2>&1 ; then
           echo "${log_indent}syntax error in row $(echo "${line}" | awk -F: '{print $1}') [notify_lang must be only one of this values \"chs\" \"cht\" \"csy\" \"dan\" \"enu\" \"fre\" \"ger\" \"hun\" \"ita\" \"jpn\" \"krn\" \"nld\" \"nor\" \"plk\" \"ptb\" \"ptg\" \"rus\" \"spn\" \"sve\" \"tha\" \"trk\"]"
        fi
    done <<< "$(sed 's/^ *//;s/ *$//' "${taglisttmp}" | grep -wn "^notify_lang:")"

    echo -e

}


prepare_python()
{
#########################################################################################
# This function check the python3 & pip installation and the necessary modules          #
#                                                                                       #
#########################################################################################


# check python3:
# ---------------------------------------------------------------------
    [ "${loglevel}" = 2 ] && printf "\n%s\n" "${log_indent}  Check Python:"
    if [ ! "$(which python3)" ]; then
        echo "${log_indent}  (Python3 is not installed / use fallback search with regex"
        echo "${log_indent}  for more precise search results Python3 is required)"
        python_check=failed
        return 1
    else
        [ ! -d "${python3_env}" ] && python3 -m venv "${python3_env}"
        source "${python3_env}/bin/activate"

        if [ "$(head -n1 "${python3_env}/synOCR_python_env_version" 2>/dev/null)" != "${local_version}" ]; then
            [ "${loglevel}" = 2 ] && printf "%s\n" "${log_indent}  python3 already installed ($(which python3))"

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

            [ "${synOCR_user}" = root ] && chown -R synOCR:administrators "${python3_env}"
            [ "${synOCR_user}" = root ] && chmod -R 755 "${python3_env}"

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
    if [ -n "${founddatestr}" ]; then
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

    [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start )))]"


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
    if [ -n "${NewName}" ]; then
        NewName="${NewName:-$(date +%Y-%m-%d_%H-%M)_$(urldecode "${title}")}"
        echo "! WARNING ! – No variables were found for renaming. A fallback is used to prevent an empty file name: ${NewName}"
    else
        echo "${NewName}"
    fi

    [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start )))]"


# set metadata:
# ---------------------------------------------------------------------
    echo -n "${log_indent}➜ insert metadata "
    
    if [ "${python_check}" = ok ] && [ "${enablePyMetaData}" -eq 1 ]; then
        echo "(use python pikepdf)"
        unset py_meta

        # replace parameters with values (rulenames can contain placeholders, which are replaced here)
        meta_keyword_list=$(replace_variables "${meta_keyword_list}")

        py_meta="'/Author': '${documentAuthor}',"
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
    
    [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start )))]"
    
    
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
    
        echo "${log_indent}  target file: ${output##*/}"

        mv "${outputtmp}" "${output}"

        adjust_attributes "${input}" "${output}"
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
    
        echo "${log_indent}  target file: $(basename "${output}")"
        mv "${outputtmp}" "${output}"
    
        adjust_attributes "${input}" "${output}"
    
    elif [ -n "${renameCat}" ] && [ "${moveTaggedFiles}" = useCatDir ] ; then
    # use sorting in category folder:
    # ---------------------------------------------------------------------
        echo "${log_indent}➜ move to category directory"
    
        # replace date parameters:
        renameCat=$(replace_variables "${renameCat}")

        # define target folder as array
        IFS=" " read -r -a tagarray <<< "${renameCat}" ; IFS="${IFSsaved}"
        
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
                subOUTPUTDIR="${OUTPUTDIR}${tagdir%/}/"
                if [ -d "${subOUTPUTDIR}" ] ;then
                    echo "OK [subfolder target dir]"
                else
                    mkdir -p "${subOUTPUTDIR}"
                    echo "created [subfolder target dir]"
                fi
            fi
    
            prepare_target_path "${subOUTPUTDIR}" "${NewName}.pdf"
    
            echo "${log_indent}  target:   ${subOUTPUTDIR}${output##*/}"
    
            # check if the same file has already been sorted into this category (different tags, but same category)
            if echo -e "${DestFolderList}" | grep -q "^${tagarray[$i]}$" ; then
                echo "${log_indent}  same file has already been copied into target folder (${tagarray[$i]}) and is skipped!"
            else
                if [[ $(echo "${outputtmp}" | awk -F/ '{print $2}') != $(echo "${output}" | awk -F/ '{print $2}') ]]; then
                    echo "${log_indent}  do not set a hard link when copying across volumes"
                    # do not set a hardlink when copying across volumes:
                    cp "${outputtmp}" "${output}"
                else
                    echo "${log_indent}  set a hard link"
                    commandlog=$(cp -l "${outputtmp}" "${output}" 2>&1 )
                    # check: - creating hard link don't fails / - target file is valid (not empty)
                    if [ $? != 0 ] || [ "$(stat -c %s "${output}")" -eq 0 ] || [ ! -f "${output}" ];then
                        echo "${log_indent}  ${commandlog}"
                        echo "${log_indent}  Creating a hard link failed! A file copy is used."
                        if [ "${loglevel}" = 2 ] ; then
                            echo "${log_indent}list of mounted volumes:"
                            df -h --output=source,target | sed -e "s/^/${log_indent}      /g"
                            echo -e
                        fi
                        cp -f "${outputtmp}" "${output}"
                    fi
                fi
    
                adjust_attributes "${input}" "${output}"
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
                cp "${outputtmp}" "${output}"
            else
                echo "${log_indent}  set a hard link"
                commandlog=$(cp -l "${outputtmp}" "${output}" 2>&1 )
                # check: - creating hard link don't fails / - target file is valid (not empty)
                if [ $? != 0 ] || [ "$(stat -c %s "${output}")" -eq 0 ] || [ ! -f "${output}" ];then
                    echo "${log_indent}  ${commandlog}"
                    echo "${log_indent}  Creating a hard link failed! A file copy is used."
                    if [ "${loglevel}" = 2 ] ; then
                        echo "${log_indent}list of mounted volumes:"
                        df -h --output=source,target | sed -e "s/^/${log_indent}      /g"
                        echo -e
                    fi
                    cp -f "${outputtmp}" "${output}"
                fi
            fi
    
            adjust_attributes "${input}" "${output}"
    
            i=$((i + 1))
        done
    
        echo "${log_indent}➜ delete temp. target file"
        rm "${outputtmp}"
    else
    # no rule fulfilled - use the target folder:
    # ---------------------------------------------------------------------
        prepare_target_path "${OUTPUTDIR}" "${NewName}.pdf"
    
        echo "${log_indent}  target file: $(basename "${output}")"
        mv "${outputtmp}" "${output}"
    
        adjust_attributes "${input}" "${output}"
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

    {   echo 'from pypdf import PdfReader'
        echo 'reader = PdfReader("'"$1"'")'
        echo 'number_of_pages = len(reader.pages)'
        echo 'print(number_of_pages)'
    } | python3
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
# This function prepare variable $output for a given file to defined targed folder      #
# and modfy it if necessary, if a file with the same name already exists                #
#                                                                                       #
#   $1  ➜ target path                                                                   #
#   $2  ➜ target filename                                                               #
#                                                                                       #
#   the variable $output will be used afterwards                                        #
#                                                                                       #
#########################################################################################

    local target_dir_path="${1%/}/"
    local target_filename="$2"
    local target_fileext="${2##*.}"

    destfilecount=$(find "${target_dir_path}" -maxdepth 1 -type f -name "${target_filename%.*}*${target_fileext}" -printf '.' | wc -c)    

    if [ "${destfilecount}" -eq 0 ]; then
        output="${target_dir_path}${target_filename%.*}.${target_fileext}"
    else
        while [ -f "${target_dir_path}${target_filename%.*} (${destfilecount}).${target_fileext}" ]; do
            destfilecount=$(( destfilecount + 1 ))
            echo "${log_indent}  ➜ continue counting … (${destfilecount})"
        done
        output="${target_dir_path}${target_filename%.*} (${destfilecount}).${target_fileext}"
        printf "%s\n\n" "${log_indent}➜ File name already exists! Add counter (${destfilecount})"
    fi

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
    date_start=$(date +%s)


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

while read -r input ; do
    [ ! -f "${input}" ] && continue

# create temporary working directory
# ---------------------------------------------------------------------
    work_tmp_step1="${work_tmp_main%/}/step1_tmp_$(date +%s)/"
    mkdir -p "${work_tmp_step1}"

    printf "\n"
    filename="${input##*/}"
    title="${filename%.*}"
    echo "${dashline2}"
    echo "CURRENT FILE:   ➜ ${filename}"
    date_start=$(date +%s)
    was_splitted=0
    split_error=0

    outputtmp="${work_tmp_step1%/}/${title}.pdf"
    echo "${log_indent}  temp. target file: ${outputtmp}"


# OCRmyPDF:
# ---------------------------------------------------------------------
    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "processing PDF @ OCRmyPDF:" "${dashline1}"
    [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start )))]"

    dockerlog=$(OCRmyPDF 2>&1)

    echo "${log_indent}➜ OCRmyPDF-LOG:"
    echo "${dockerlog}" | sed -e "s/^/${log_indent}  /g"
    printf "%s\n\n" "${log_indent}← OCRmyPDF-LOG-END"

    [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start )))]"


# check if target file is valid (not empty), otherwise continue / 
# defective source files are moved to ERROR including LOG:
# ---------------------------------------------------------------------
    if [ "$(stat -c %s "${outputtmp}")" -eq 0 ] || [ ! -f "${outputtmp}" ];then
        echo "${log_indent}  ┖➜ failed! (target file is empty or not available)"
        rm "${outputtmp}"
        if echo "${dockerlog}" | grep -iq ERROR ;then
            if [ ! -d "${INPUTDIR}ERRORFILES" ] ; then
                echo "${log_indent}                  ERROR-Directory [${INPUTDIR}ERRORFILES] will be created!"
                mkdir "${INPUTDIR}ERRORFILES"
            fi

            prepare_target_path "${INPUTDIR}ERRORFILES" "${filename}"

            mv "${input}" "${output}"
            [ "${loglevel}" != 0 ] && cp "${current_logfile}" "${output}.log"
            echo "${log_indent}              ┖➜ move to ERRORFILES"
        fi
        rm -rf "${work_tmp_step1}"
        continue
    else
        printf "%s\n\n" "${log_indent}target file (OK): ${outputtmp}"
    fi


# detect & remove blank pages:
# ---------------------------------------------------------------------
    if [ "${blank_page_detection_switch}" = true ] && [ "${python_check}" = "ok" ]; then
        printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "detect & remove blank pages:" "${dashline1}"

#        echo "delete blank pages:       ${blank_page_detection_switch}"
#        echo "threshold black/white:    ${blank_page_detection_threshold_bw}"
#        echo "threshold black pixels:   ${blank_page_detection_threshold_black_pxl}"

    # identify pages without text / write to an array:
    # ---------------------------------------------------------------------
        pageCount=$( py_page_count "${outputtmp}" )

        unset blankPages
        if grep -qwP "^[0-9]+$" <<<"${pageCount}" ; then
            p=1
            blankPages=( )
            while [ "${p}" -le "${pageCount}" ]; do
                charcount=$( pdftotext "${outputtmp}" -f $p -l $p -layout - | wc -m )
#                echo "Seite $p enthält $charcount Zeichen"
                if [ "${charcount}" -le 1 ]; then
#                if [ $( pdftotext "${outputtmp}" -f $p -l $p -layout - | wc -m ) -eq 0 ]; then
                    blankPages+=( "${p}" )
#                    echo "füge Seite $p hinzu"
                fi
                p=$((p+1))
            done
            numberBlankPages="${#blankPages[@]}"
        else
            echo "${log_indent}! ! ! error at counting PDF pages"
        fi
        echo "${log_indent}pages without text: ${numberBlankPages} [${blankPages[*]}]"

    # send pages to python for picture analysis and deletion:
    # …

        # get previous metadata - maybe for feature use:
        py_delete_blank_pages(){
            {   #echo "import pprint"
                #echo "from pypdf import PdfFileReader, PdfFileMerger"
                #echo "if __name__ == '__main__':"
                #echo "    file_in = open('${outputtmp}', 'rb')"
                #echo "    pdf_reader = PdfFileReader(file_in)"
                #echo "    metadata = pdf_reader.getDocumentInfo()"
                #echo "    pprint.pprint(metadata)"
                #echo "    file_in.close()"
                
#                echo "from PIL import Image"

                # Laden der gescannten PDF-Seite als Bild
#                echo "with Image.open('${outputtmp}') as img:"
                echo "import pikepdf"
                echo "from PIL import Image"

                # Laden der PDF-Seite als Bild
                echo "with pikepdf.open('${outputtmp}') as pdf:"
                echo "    page = pdf.pages[0]"
                echo "    page_image = page.render()"
                echo "    with open('${outputtmp}.png', 'wb') as f:"
                echo "        f.write(page_image)"

                # Anwenden des Schwellenwerts
                echo "img = Image.open('${outputtmp}.png').convert('L')"
                echo "threshold_value = 150"
                echo "img = img.point(lambda x: 255 * (x > threshold_value), mode='1')"
#                echo "    threshold_img = img.point(lambda x: 255 * (x > threshold_value), mode='1')"

#                # Ermitteln der Anzahl der nicht-weißen Pixel
#                echo "    pixel_count = threshold_img.size[0] * threshold_img.size[1]"
#                echo "    white_pixel_count = threshold_img.histogram()[255]"
#                echo "    black_pixel_count = pixel_count - white_pixel_count"
                
                # Überprüfen, ob die Seite leer ist
                echo "if img.getbbox() is None:"
                echo "    print('Die Seite ist leer.')"
                echo "else:"
                echo "    print('Die Seite ist nicht leer.')"
                
            } | python3
        }
        delete_blank_pages_result=$(py_delete_blank_pages)
        echo "${delete_blank_pages_result}"
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
            while [ "${p}" -le "${pageCount}" ]; do
                if pdftotext "${outputtmp}" -f $p -l $p -layout - | grep -q "${documentSplitPattern}" ; then
                    splitPages+=( "${p}" )
                fi
                p=$((p+1))
            done
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
                    copy_attributes "${input}" "${output}"
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


# delete / save source file (takes into account existing files with the same name):
# ---------------------------------------------------------------------
    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "handle source file:" "${dashline1}"

    if [ "${was_splitted}" = 0 ] || [ "${split_error}" = 1 ]; then
        copy_attributes "${input}" "${outputtmp}"
    fi

    if [ "${backup}" = true ]; then
        prepare_target_path "${BACKUPDIR}" "${filename}"
        mv "${input}" "${output}"
        echo "${log_indent}➜ backup source file to: ${output}"
    else
        rm -f "${input}"
        echo "${log_indent}➜ delete source file (${filename})"
    fi

    if [ "${was_splitted}" = 0 ] || [ "${split_error}" = 1 ]; then
        mv "${outputtmp}" "${work_tmp_main}"
    fi

    rm -rfv "${work_tmp_step1}" | sed -e "s/^/${log_indent}/g"


# Stats:
# ---------------------------------------------------------------------
    echo -e
    echo "Stats:"
    echo "  runtime last file:              ➜ $(sec_to_time $(( $(date +%s) - date_start )))"

done <<<"${files}"

printf "%s\n\n" "  runtime 1st step (all files):   ➜ $(sec_to_time $(( $(date +%s) - date_start_all )))"

}


main_2nd_step()
{
#########################################################################################
# This function search for tags / rename / sort to target folder                        #
#########################################################################################
printf "\n  %s\n  ● %-80s●\n  %s\n\n" "${dashline2}" "STEP 2 - SEARCH TAGS / RENAME / SORT:" "${dashline2}"

collect_input_files "${work_tmp_main}" "pdf"

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

    if [ "${python_check}" = ok ]; then
        pagecount_latest=$( py_page_count "${input}" ) 
        [ "${loglevel}" = 2 ] && echo "${log_indent}(pages counted with python module pypdf)"
    elif [ "$(which pdfinfo)" ]; then
        pagecount_latest=$(pdfinfo "${input}" 2>/dev/null | grep "Pages\:" | awk '{print $2}')
        [ "${loglevel}" = 2 ] && echo "${log_indent}(pages counted with pdfinfo)"
    elif [ "$(which exiftool)" ]; then
        pagecount_latest=$(exiftool -"*Count*" "${input}" 2>/dev/null | awk -F' ' '{print $NF}')
        [ "${loglevel}" = 2 ] && echo "${log_indent}(pages counted with exiftool)"
    fi

    [ -z "${pagecount_latest}" ] && pagecount_latest=0 && echo "${log_indent}! ! ! ERROR - with pdfinfo / exiftool / pypdf - \$pagecount was set to 0"


# adapt counter:
# ---------------------------------------------------------------------
    global_pagecount_new="$((global_pagecount_new+pagecount_latest))"
    global_ocrcount_new="$((global_ocrcount_new+1))"
    pagecount_profile_new="$((pagecount_profile_new+pagecount_latest))"
    ocrcount_profile_new="$((ocrcount_profile_new+1))"


# create temporary working directory
# ---------------------------------------------------------------------
    work_tmp_step2="${work_tmp_main%/}/step2_tmp_$(date +%s)/"
    mkdir -p "${work_tmp_step2}"

    echo -e
    filename="${input##*/}"
    title="${filename%.*}"
    echo "${dashline2}"
    echo "CURRENT FILE:   ➜ ${filename}"
    date_start=$(date +%s)
    tmp_date_search_method="${date_search_method}"    # able to use a temporary fallback to regex for each file

    if [ "${delSearchPraefix}" = "yes" ] && [ -n "${SearchPraefix}" ]; then
        # ToDo:
        # currently, SearchPraefix will be delete globally
        # check, if SearchPraefix a prefix or a suffix and delete only this
        title="${title//${SearchPraefix_tmp}/}"
    fi


############################################################################
# ToDo:    >>>>>>>>
#   - wenn es keine Probleme (z.B. mit der Übertragung der Berechtigung) gibt, kann in der gesamten 
#     Funktion möglicherweise die Variable $output durch $input ersetzt werden
#   - prüfen, ob es Probleme gibt, wenn ein keine gültige Umbennungssyntax gibt 
#     (es muss sichergestellt werden, dass die Datei im Ausgabeordner ankommt)

# temporary output destination with seconds for uniqueness 
# (otherwise there will be duplication if renaming syntax is missing)
# ---------------------------------------------------------------------
#    output="${OUTPUTDIR}temp_${title}_$(date +%s).pdf"
    output="${work_tmp_step2%/}/temp_${title}_$(date +%s).pdf"

# move temporary file to destination folder:
# ---------------------------------------------------------------------
    cp "${input}" "${output}"
#    output="${input}"

# End ToDo <<<<<<<<
############################################################################



# source file permissions-Log:
# ---------------------------------------------------------------------
    if [ "${loglevel}" = 2 ] ; then
        echo "${log_indent}➜ File permissions source file:"
        echo -n "${log_indent}  "
        ls -l "${input}"
    fi


# exact text
# ---------------------------------------------------------------------
    searchfile="${work_tmp_step2}/synOCR.txt"
    searchfilename="${work_tmp_step2}/synOCR_filename.txt"    # for search in file name
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


# search by date:
# ---------------------------------------------------------------------
    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "search for a valid date in ocr text:" "${dashline1}"
    dateIsFound=no
    find_date 1

    date_dd_source=$(stat -c %y "${input}" | awk '{print $1}' | awk -F- '{print $3}')
    date_mm_source=$(stat -c %y "${input}" | awk '{print $1}' | awk -F- '{print $2}')
    date_yy_source=$(stat -c %y "${input}" | awk '{print $1}' | awk -F- '{print $1}')
    date_houre_source=$(stat -c %y "${input}" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $1}')
    date_min_source=$(stat -c %y "${input}" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $2}')
    date_sek_source=$(stat -c %y "${input}" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $3}')

    if [ "${dateIsFound}" = no ]; then
        echo "${log_indent}  Date not found in OCR text - use file date:"
        date_dd=$date_dd_source
        date_mm=$date_mm_source
        date_yy=$date_yy_source
        echo "${log_indent}  day:  ${date_dd}"
        echo "${log_indent}  month:${date_mm}"
        echo "${log_indent}  year: ${date_yy}"
    fi


# compose and rename file names / move to target:
# ---------------------------------------------------------------------
    printf "\n  %s\n  | %-80s|\n  %s\n\n" "${dashline1}" "rename and sort to target folder:" "${dashline1}"
    rename

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

    echo "  runtime last file:    ➜ $(sec_to_time $(( $(date +%s) - date_start )))"
    echo "  pagecount last file:  ➜ ${pagecount_latest}"
    echo "  file count profile :  ➜ (profile $profile) - ${ocrcount_profile_new} PDF's / ${pagecount_profile_new} Pages processed up to now"
    echo "  file count total:     ➜ ${global_ocrcount_new} PDF's / ${global_pagecount_new} Pages processed up to now since ${count_start_date}"

    printf "\ncleanup:\n"

# delete temporary working directory:
# ---------------------------------------------------------------------
    echo "  delete tmp-files ..."
    rm -rfv "${input}" | sed -e "s/^/${log_indent}/g"   # rm ocred version - source file is backuped after ocrmypdf processing 

done <<<"${files}"

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
    [ "${loglevel}" = 2 ] && printf "\n%s\n\n" "[runtime up to now:    $(sec_to_time $(( $(date +%s) - date_start_all )))]"

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
    main_2nd_step
    purge_log
    purge_backup

    [ -d "${work_tmp_main}" ] && rmdir -v "${work_tmp_main}" | sed -e "s/^/  /g"

    printf "\n%s\n\n\n" "  runtime all files:              ➜ $(sec_to_time $(( $(date +%s) - date_start_all )))"

exit 0
