#!/bin/sh
# /usr/syno/synoman/webman/3rdparty/synOCR/synOCR.sh

###################################################################################

    echo "    -----------------------------------"
    echo "    |    ==> installation info <==    |"
    echo "    -----------------------------------"
    echo -e

    DevChannel="BETA"     # "Release"    # BETA
    set -E -o functrace     # for function failure()

    failure()
    {
    # this function show error line
    # --------------------------------------------------------------
        # https://unix.stackexchange.com/questions/462156/how-do-i-find-the-line-number-in-bash-when-an-error-occured
        local lineno=$1
        local msg=$2
        echo "ERROR at line $lineno: $msg"
    }
    trap 'failure ${LINENO} "$BASH_COMMAND"' ERR


# ---------------------------------------------------------------------------------
#           BASIC CONFIGURATIONS / INDIVIDUAL ADAPTATIONS / Default values        |
# ---------------------------------------------------------------------------------
    niceness=15                 # The priority is in the range from -20 to +19 (in integer steps), where -20 is the highest priority (=most computing power) and 19 is the lowest priority (=lowest computing power). The default priority is 0. NEGATIVE VALUES SHOULD NEVER BE DEFAULTED!
    workprofile="$1"            # the profile submitted by the start script
    LOGFILE="$2"                # current logfile / is submitted by start script
    shopt -s globstar           # enable 'globstar' shell option (to use ** for directionary wildcard)

#    if ! echo "$PATH" | grep -q '/usr/local/bin\|/opt/usr/bin' ; then
#        PATH=$PATH:/usr/local/bin:/opt/usr/bin
#    fi

# to which user/group the DSM notification should be sent:
# ---------------------------------------------------------------------
    synOCR_user=$(whoami); echo "synOCR-user:              $synOCR_user"
    if cat /etc/group | grep administrators | grep -q "$synOCR_user" || [ "$synOCR_user" = root ] ; then
        isAdmin=yes
    else
        isAdmin=no
    fi
    echo "synOCR-user is admin:     $isAdmin"


# check DSM version:
# ---------------------------------------------------------------------
dsm_version=6
if [ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -ge 7 ]; then
    dsm_version=7
fi

# read out and change into the working directory:
# ---------------------------------------------------------------------
    OLDIFS=$IFS                 # Save original field separator
    APPDIR=$(cd $(dirname $0);pwd)
    cd ${APPDIR}

    source ./includes/functions.sh

# load configuration:
# ---------------------------------------------------------------------
    sSQL="SELECT profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix,
        delSearchPraefix, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN,
        dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, filedate, tagsymbol, documentSplitPattern, ignoredDate, 
        backup_max, backup_max_type, pagecount, ocrcount FROM config WHERE profile_ID='$workprofile' "

    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL")
#   sqlerg=$(urldecode "$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL" | sed -e 's/+/%2B/g')")  # replace encoded values which can't insert with GUI directly (e.g. ' ")

    profile_ID=$(echo "$sqlerg" | awk -F'\t' '{print $1}')
    profile=$(echo "$sqlerg" | awk -F'\t' '{print $3}')
    INPUTDIR=$(echo "$sqlerg" | awk -F'\t' '{print $4}')
    OUTPUTDIR=$(echo "$sqlerg" | awk -F'\t' '{print $5}')
    BACKUPDIR=$(echo "$sqlerg" | awk -F'\t' '{print $6}')
    LOGDIR=$(echo "$sqlerg" | awk -F'\t' '{print $7}')
    LOGmax=$(echo "$sqlerg" | awk -F'\t' '{print $8}')
    SearchPraefix=$(echo "$sqlerg" | awk -F'\t' '{print $9}')
    delSearchPraefix=$(echo "$sqlerg" | awk -F'\t' '{print $10}')
    taglist=$(echo "$sqlerg" | awk -F'\t' '{print $11}')
    searchAll=$(echo "$sqlerg" | awk -F'\t' '{print $12}')
    moveTaggedFiles=$(echo "$sqlerg" | awk -F'\t' '{print $13}')
    NameSyntax=$(echo "$sqlerg" | awk -F'\t' '{print $14}')
    ocropt=$(echo "$sqlerg" | awk -F'\t' '{print $15}')
    dockercontainer=$(echo "$sqlerg" | awk -F'\t' '{print $16}')
    PBTOKEN=$(echo "$sqlerg" | awk -F'\t' '{print $17}')
    dsmtextnotify=$(echo "$sqlerg" | awk -F'\t' '{print $18}')
    MessageTo=$(echo "$sqlerg" | awk -F'\t' '{print $19}')
    [[ -z $MessageTo ]] || [[ $MessageTo == "-" ]] && MessageTo="@administrators" # group administrators (standard)
    dsmbeepnotify=$(echo "$sqlerg" | awk -F'\t' '{print $20}')
    loglevel=$(echo "$sqlerg" | awk -F'\t' '{print $21}')
    filedate=$(echo "$sqlerg" | awk -F'\t' '{print $22}')
    tagsymbol=$(echo "$sqlerg" | awk -F'\t' '{print $23}')
    documentSplitPattern=$(echo "$sqlerg" | awk -F'\t' '{print $24}')
    ignoredDate=$(echo "$sqlerg" | awk -F'\t' '{print $25}')
    backup_max=$(echo "$sqlerg" | awk -F'\t' '{print $26}')
    backup_max_type=$(echo "$sqlerg" | awk -F'\t' '{print $27}')
    pagecount_profile=$(echo "$sqlerg" | awk -F'\t' '{print $28}')
    ocrcount_profile=$(echo "$sqlerg" | awk -F'\t' '{print $29}')

# read global values:
    dockerimageupdate=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='dockerimageupdate' ")
    count_start_date=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='count_start_date'")
    global_pagecount=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_pagecount'")
    global_ocrcount=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_ocrcount'")
    online_version=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='online_version'")

# System Information:
# ---------------------------------------------------------------------
    local_version=$(grep "^version" /var/packages/synOCR/INFO | awk '-F=' '{print $2}' | sed -e 's/"//g')
    highest_version=$(printf "$online_version\n$local_version" | sort -V | tail -n1)
    echo "synOCR-version:           $local_version"
    if [[ $local_version != $highest_version ]] ; then
        echo "UPDATE AVAILABLE:         online version: $online_version"
        echo "                          please visit cphub.net / geimist.eu/synOCR/ or check your pakage center"
    fi

    machinetyp=$(uname --machine); echo "Architecture:             $machinetyp"
    dsmbuild=$(uname -v | awk '{print $1}' | sed "s/#//g"); echo "DSM-build:                $dsmbuild"
    read MAC </sys/class/net/eth0/address
    sysID=$(echo $MAC | cksum | awk '{print $1}'); sysID="$(printf '%010d' $sysID)"
    device=$(uname -a | awk -F_ '{print $NF}' | sed "s/+/plus/g")

    echo "Device:                   $device ($sysID)"
    echo "current Profil:           $profile"
    echo "DB-version:               $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='db_version'")"
    echo "used image (created):     $dockercontainer ($(docker inspect -f '{{ .Created }}' "$dockercontainer" | awk -F. '{print $1}'))"

    echo "used ocr-parameter (raw): $ocropt"
    # arguments with spaces must be submit as array (https://github.com/ocrmypdf/OCRmyPDF/issues/878)
    # for loop split all parameters, which start with > -<:
    c=0
    ocropt_arr=()
    IFS=$'\012'  # corresponds to a $'\n' newline
    for value in $(awk -F'[ ]-' '{for(i=1;i<=NF;i++){if($i)print "-"$i}}' <<<" $ocropt"); do
        IFS=$OLDIFS
        c=$((c+1))
        # now, split parameters with additional arguments:
        if [[ $(awk -F'[ ]' '{print NF}' <<<"$value") -gt 1 ]]; then
            value_1=$(awk -F'[ ]' '{print $1}' <<<"$value")
            [[ $loglevel = "2" ]] && echo "OCR-arg $c:               $value_1"
            c=$((c+1))
            value_2=$(echo "$value" | sed "s/$value_1 //g")
            [[ $loglevel = "2" ]] && echo "OCR-arg $c:               $value_2"
            ocropt_arr+=( "$value_1" "$value_2" )
        else
            [[ $loglevel = "2" ]] && echo "OCR-arg $c:               $value"
            ocropt_arr+=( "$value" )
        fi
    done
    unset c
    echo "ocropt_array:             ${ocropt_arr[@]}"

    echo "search prefix:            $SearchPraefix"
    echo "replace search prefix:    $delSearchPraefix"
    echo "renaming syntax:          $NameSyntax"
    echo "Symbol for tag marking:   ${tagsymbol}"
    tagsymbol=$(echo "${tagsymbol}" | sed -e "s/ /%20/g")   # mask spaces
    echo "Document split pattern:   ${documentSplitPattern}"

    enhanced_date_search=no
    echo -n "Date search method:       "
    if [[ $enhanced_date_search = "yes" ]] ; then
        echo "use Python (BETA)"
#       echo "                          to use standard search via RegEx, you must change the settings with this command:"
#       echo "                          synosetkeyvalue $(echo $0) enhanced_date_search no"
    else
        echo "use standard search via RegEx"
#       echo "                          to use enhanced search via Python, you must change the settings with this command:"
#       echo "                          synosetkeyvalue $(echo $0) enhanced_date_search yes"
    fi

    echo "source for filedate:      ${filedate}"
    echo "ignored dates by search:  ${ignoredDate}"
    [[ $loglevel = "2" ]] && \
    echo "PATH-Variable:            $PATH"
    echo -n "Docker Test:              "
    if docker --version | grep -q "version"  ; then
        echo "OK"
    else
        echo "WARNING: Docker could not be found. Please check if the Docker package has been installed!"
    fi
    echo "DSM notify to user:       ${MessageTo}"

# Configuration for LogLevel:
# ---------------------------------------------------------------------
    # LOGlevel:     0 ➜ logging disable / 1 ➜ normal / 2 ➜ debug
    if [[ $loglevel = "1" ]] ; then
        echo "Loglevel:                 normal"
        cURLloglevel="-s"
        wgetloglevel="-q"
#        dockerlogLeftSpace="               "
        dockerlogLeftSpace="                "
    elif [[ $loglevel = "2" ]] ; then
        echo "Loglevel:                 debug"
        # set -x
        cURLloglevel="-v"
        wgetloglevel="-v"
        dockerlogLeftSpace="                    "
        ocropt_arr+=( "-v2" )
    fi

    echo "max. count of logfiles:   ${LOGmax}"

# Check or create and adjust directories:
# ---------------------------------------------------------------------

    # Adjust variable correction for older Konfiguration.txt and slash:
    INPUTDIR="${INPUTDIR%/}/"
    if [ -d "$INPUTDIR" ] ; then
        echo "Source directory:         $INPUTDIR"
    else
        echo "Source directory invalid or not set!"
        exit 1
    fi

    OUTPUTDIR="${OUTPUTDIR%/}/"
    echo "Target directory:         ${OUTPUTDIR}"

    BACKUPDIR="${BACKUPDIR%/}/"
    if [ -d "$BACKUPDIR" ] && echo "$BACKUPDIR" | grep -q "/volume" ; then
        echo "BackUp directory:         $BACKUPDIR"
        backup=true
    elif echo "$BACKUPDIR" | grep -q "/volume" ; then
        if /usr/syno/sbin/synoshare --enum ENC | grep -q $(echo "$BACKUPDIR" | awk -F/ '{print $3}') ; then
            echo "BackUP folder not mounted    ➜    EXIT SCRIPT!"
            exit 1
        fi
        mkdir -p "$BACKUPDIR"
        echo "BackUp directory was created [$BACKUPDIR]"
        backup=true
    else
        echo "Files are deleted immediately! / No valid directory [$BACKUPDIR]"
        backup=false
    fi

    echo "rotate backupfiles after: $backup_max $backup_max_type"


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
# this function checks for image update
# --------------------------------------------------------------
    check_date=$(date +%Y-%m-%d)
    if echo $dockercontainer | grep -qE "latest$" && [[ $dockerimageupdate = 1 ]] && [[ ! $(sqlite3 ./etc/synOCR.sqlite "SELECT date_checked FROM dockerupdate WHERE image='$dockercontainer' ") = "$check_date" ]];then
        echo -n "              ➜ update image [$dockercontainer] ➜ "
        updatelog=$(docker pull $dockercontainer)

    # purge only untaged ocrmypdf images:
        log_purge=$([[ $(docker images -f "dangling=true" --format "{{.ID}}:{{.Repository}}:{{.Tag}}" | grep "ocrmypdf") ]] && docker rmi -f $(docker images -f "dangling=true" --format "{{.ID}}:{{.Repository}}:{{.Tag}}" | grep "ocrmypdf" | awk -F: '{print $1}'))

        if [ -z $(sqlite3 "./etc/synOCR.sqlite"  "SELECT * FROM dockerupdate WHERE image='$dockercontainer'") ]; then
            sqlite3 "./etc/synOCR.sqlite" "INSERT INTO dockerupdate ( image, date_checked ) VALUES  ( '$dockercontainer', '$check_date' )"
        else
            sqlite3 "./etc/synOCR.sqlite" "UPDATE dockerupdate SET date_checked='$check_date' WHERE image='$dockercontainer' "
        fi

        if echo "$updatelog" | grep -q "Image is up to date"; then
            echo "image is up to date"
        elif echo "$updatelog" | grep -q "Downloaded newer image"; then
            echo "updated successfully"
        fi

        if [[ $loglevel = "2" ]] ; then
            echo "$updatelog" | sed -e "s/^/                          /g"
            echo "$log_purge" | sed -e "s/^/                          /g"
        fi
    fi
}


sec_to_time()
{
# this function converts a second value to hh:mm:ss
# call: sec_to_time "string"
# https://blog.jkip.de/in-bash-sekunden-umrechnen-in-stunden-minuten-und-sekunden/
# --------------------------------------------------------------
    local seconds=$1
    local sign=""
    if [[ ${seconds:0:1} == "-" ]]; then
        seconds=${seconds:1}
        sign="-"
    fi
    local hours=$(( seconds / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    seconds=$(( seconds % 60 ))
    printf "%s%02d:%02d:%02d" "$sign" $hours $minutes $seconds
}


OCRmyPDF()
{
    # https://www.synology-forum.de/showthread.html?99516-Container-Logging-in-Verbindung-mit-stdin-und-stdout
    cat "$input" | docker run --name synOCR --network none --rm -i -log-driver=none -a stdin -a stdout -a stderr $dockercontainer "${ocropt_arr[@]}" - - | cat - > "$outputtmp"
}


tag_search()
{
echo "              ➜ search tags and date:"
renameTag=""
renameCat=""

# is it an external text file for the tags or a YAML rules file?
type_of_rule=standard   # standard rules or advanced rules (YAML file)

if [ -z "$taglist" ]; then
    echo "                no tags defined"
    return
elif [ -f "$taglist" ]; then
    if grep -q "synOCR_YAMLRULEFILE" "$taglist" ; then
        echo "                source for tags is yaml based tag rule file [$taglist]"
        cp "$taglist" "${work_tmp}/tmprulefile.txt"     # copy YAML file into the TMP folder, because the file can only be read incorrectly in ACL folders
        taglisttmp="${work_tmp}/tmprulefile.txt"
        sed -i $'s/\r$//' "$taglisttmp"                 # convert DOS to Unix
# sed 's/^M$//'              # with bash/tcsh: Ctrl-V then Ctrl-M
        type_of_rule=advanced
        yaml_validate
        tag_rule_content=$(yq read "$taglisttmp" -jP 2>&1)
    else
        echo "                source for tags is file [$taglist]"
        sed -i $'s/\r$//' "$taglist"                    # convert DOS to Unix
        taglist=$(cat "$taglist")
    fi
else
    echo "                source for tags is the list from the GUI"
fi

if [ $type_of_rule = advanced ]; then
# process complex tag rules:
    # list tagrules:
    for tagrule in $(echo "$tag_rule_content" | jq -r ". | to_entries | .[] | .key" | sort -r) ; do
        found=0

        [[ $loglevel = "2" ]] && printf "\n                [runtime up to now:    $(sec_to_time $(( $(date +%s) - ${date_start} )))]\n\n"

        echo "                search by tag rule: \"${tagrule}\" ➜  "

        condition=$(echo "$tag_rule_content" | jq -r ".${tagrule}.condition" | tr '[:upper:]' '[:lower:]')
        if [[ $condition = null ]] ; then
            echo "                  [value for condition must not be empty - continue]"
            continue
        fi

        searchtag=$(echo "$tag_rule_content" | jq -r ".${tagrule}.tagname" | sed 's%\/\|\\\|\:\|\?%_%g' ) # filtered: \ / : ?
        targetfolder=$(echo "$tag_rule_content" | jq -r ".${tagrule}.targetfolder" )
        tagname_RegEx=$(echo "$tag_rule_content" | jq -r ".${tagrule}.tagname_RegEx" )
        if [[ "$searchtag" = null ]] && [[ "$targetfolder" = null ]] ; then
            echo "                  [no actions defined - continue]"
            continue
        fi
        if [[ "$targetfolder" = null ]] ; then
            targetfolder=""
        fi

        echo "                  ➜ condition:        $condition"     # "all" OR "any" OR "none"
        echo "                  ➜ tag:              $searchtag"
        echo "                  ➜ destination:      $targetfolder"
        if [[ "$tagname_RegEx" != null ]] ; then
            echo "                  ➜ RegEx for tag:    $tagname_RegEx" # searchtag
        fi

        [[ $loglevel = "2" ]] && echo "                      [Subrule]:"
        # execute subrules:
        for subtagrule in $(echo "$tag_rule_content" | jq -c ".$tagrule.subrules[] | @base64 ") ; do
            grepresult=0
            sub_jq_value="$subtagrule"  # universal parameter name for function sub_jq

            VARisRegEx=$(sub_jq '.isRegEx' | tr '[:upper:]' '[:lower:]')
            if [[ $VARisRegEx = null ]] ; then
                echo "                  [value for isRegEx is empty - \"false\" is used]"
                VARisRegEx=false
            fi

            VARsearchstring=$(sub_jq '.searchstring')
            if [[ $VARsearchstring = null ]] ; then
                echo "                  [value for searchstring must not be empty - continue]"
                continue
            fi

            VARsearchtyp=$(sub_jq '.searchtyp' | tr '[:upper:]' '[:lower:]')
            if [[ $VARsearchtyp = null ]] ; then
                echo "                  [value for searchtyp is empty - \"contains\" is used]"
                VARsearchtyp=contains
            fi

            VARsource=$(sub_jq '.source' | tr '[:upper:]' '[:lower:]')
            if [[ $VARsource = null ]] ; then
                echo "                  [value for source is empty - \"content\" is used]"
                VARsource=content
            fi

            VARcasesensitive=$(sub_jq '.casesensitive' | tr '[:upper:]' '[:lower:]')
            if [[ $VARcasesensitive = null ]] ; then
                echo "                  [value for casesensitive is empty - \"false\" is used]"
                VARcasesensitive=false
            fi
            if [[ $loglevel = "2" ]] ; then
                echo "                      >>> search for:      $VARsearchstring"
                echo "                          isRegEx:         $VARisRegEx"
                echo "                          searchtyp:       $VARsearchtyp"
                echo "                          source:          $VARsource"
                echo "                          casesensitive:   $VARcasesensitive"
            fi

        # Ignore upper and lower case if necessary:
            if [[ $VARcasesensitive = true ]] ;then
                grep_opt=""
            else
                grep_opt="i"
            fi

        # define search area:
            if [[ $VARsource = content ]] ;then
                VARsearchfile="${searchfile}"
            else
                VARsearchfile="${searchfilename}"
            fi

        # search … :
#                if [[ $VARisRegEx = true ]] ;then
            # no additional restriction via 'searchtyp' for regex search
#                    echo "                          searchtyp:       [ignored - RegEx based]"
#                    if grep -qP${grep_opt} "${VARsearchstring}" "${VARsearchfile}" ;then
#                        grepresult=1
#                    fi
#                else
            case "$VARsearchtyp" in
                is)
                    if [[ $VARisRegEx = true ]] ;then
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
                    if [[ $VARisRegEx = true ]] ;then
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
                    if [[ $VARisRegEx = true ]] ;then
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
                    if [[ $VARisRegEx = true ]] ;then
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
                    if [[ $VARisRegEx = true ]] ;then
                        if grep -qP${grep_opt} "\<${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        tmp_result=$(grep -oE${grep_opt} "\<${VARsearchstring}" "${VARsearchfile}")     # temporary hit list with RegEx
                        if echo "$tmp_result" | grep -qF${grep_opt} "${VARsearchstring}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
                "does not starts with")
                    if [[ $VARisRegEx = true ]] ;then
                        if ! grep -qP${grep_opt} "\<${VARsearchstring}" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        tmp_result=$(grep -oE${grep_opt} "\<${VARsearchstring}" "${VARsearchfile}")     # temporary hit list with RegEx
                        if ! echo "$tmp_result" | grep -qF${grep_opt} "${VARsearchstring}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
                "ends with")
                    if [[ $VARisRegEx = true ]] ;then
                        if grep -qP${grep_opt} "${VARsearchstring}\>" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        tmp_result=$(grep -oE${grep_opt} "${VARsearchstring}\>" "${VARsearchfile}")     # temporary hit list with RegEx
                        if echo "$tmp_result" | grep -qF${grep_opt} "${VARsearchstring}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
                "does not ends with")
                    if [[ $VARisRegEx = true ]] ;then
                        if ! grep -qP${grep_opt} "${VARsearchstring}\>" "${VARsearchfile}" ;then
                            grepresult=1
                        fi
                    else
                        tmp_result=$(grep -oE${grep_opt} "${VARsearchstring}\>" "${VARsearchfile}")     # temporary hit list with RegEx
                        if ! echo "$tmp_result" | grep -qF${grep_opt} "${VARsearchstring}" ;then
                            grepresult=1
                        fi
                    fi
                    ;;
            esac
#                fi

            [[ $loglevel = "2" ]] && [ $grepresult = "1" ] && echo "                          ➜ Subrule matched"
            [[ $loglevel = "2" ]] && [ ! $grepresult = "1" ] && echo "                          ➜ Subrule don't matched"

        # Check condition:
            case "$condition" in
                any)
                    if [[ $grepresult -eq 1 ]] ; then
                        # cancel search when 1st found
                        found=1
                        break
                    fi
                    ;;
                all)
                    if [[ $grepresult -eq 0 ]] ; then
                        # Cancel search during 1st negative search run
                        found=0
                        break
                    elif [[ $grepresult -eq 1 ]] ; then
                        found=1
                    fi
                    ;;
                none)
                    if [[ $grepresult -eq 1 ]] ; then
                        # cancel search when 1st found
                        found=0 # null, because condition not met
                        break
                    elif [[ $grepresult -eq 0 ]] ; then
                        found=1
                    fi
                    ;;
            esac
        done

        if [[ $found -eq 1 ]] ; then
            echo "                          >>> Rule is satisfied" ; echo -e

            if [[ "$tagname_RegEx" != null ]] ; then
                echo -n "                              ➜ search RegEx for tag ➜ "
                tagname_RegEx_result=$( grep -oP "$tagname_RegEx" "${VARsearchfile}" | head -n1 )
                if [[ ! -z "$tagname_RegEx_result" ]] ; then
                    searchtag=$(echo "$tagname_RegEx_result" | sed 's%\/\|\\\|\:\|\?%_%g') # filtered: \ / : ?
                    echo "$searchtag"
                else
                    echo "RegEx not found (fallback to $searchtag)"
                fi
                echo -e
            fi

            renameTag="${tagsymbol}$(echo "${searchtag}" | sed -e "s/ /%20/g") ${renameTag}" # with temporary space separator to finally check tags for uniqueness
            renameCat="$(echo "${targetfolder}" | sed -e "s/ /%20/g") ${renameCat}"
        else
            echo "                          >>> Rule is not satisfied" ; echo -e
        fi

    done
    # make tags unique:
    renameTag=$(echo "$renameTag" | tr ' ' '\n' | uniq | tr '\n' ' ' | sed -e "s/ //g" )
else
# process simple tag rules:
    taglist2=$( echo "$taglist" | sed -e "s/ /%20/g" | sed -e "s/;/ /g" )   # encode spaces in tags and convert semicolons to spaces (for array)
    tagarray=( $taglist2 )   # define tags as array
    i=0
    maxID=${#tagarray[*]}
    echo "                          tag count:       $maxID"

    # possibly change loop …
    #    for i in ${tagarray[@]}; do
    #        echo $a
    #    done
    while (( i < maxID )); do

        [[ $loglevel = "2" ]] && printf "\n                [runtime up to now:    $(sec_to_time $(( $(date +%s) - ${date_start} )))]\n\n"

        if echo "${tagarray[$i]}" | grep -q "=" ;then
        # for combination of tag and category
            if echo $(echo "${tagarray[$i]}" | awk -F'=' '{print $1}') | grep -q  "^§" ;then
               grep_opt="-qiw" # find single tag
            else
                grep_opt="-qi"
            fi
            tagarray[$i]=$(echo ${tagarray[$i]} | sed -e "s/^§//g")
            searchtag=$(echo "${tagarray[$i]}" | awk -F'=' '{print $1}' | sed -e "s/%20/ /g")
            categorietag=$(echo "${tagarray[$i]}" | awk -F'=' '{print $2}' | sed -e "s/%20/ /g")
            echo -n "                  Search by tag:   \"${searchtag}\" ➜  "
            if grep $grep_opt "${searchtag}" "$searchfile" ;then
                echo "OK (Cat: \"${categorietag}\")"
                renameTag="${tagsymbol}$(echo "${searchtag}" | sed -e "s/ /%20/g")${renameTag}"
                renameCat="$(echo "${categorietag}" | sed -e "s/ /%20/g") ${renameCat}"
            else
                echo "-"
            fi
        else
            if echo $(echo ${tagarray[$i]} | sed -e "s/%20/ /g") | grep -q  "^§" ;then
                grep_opt="-qiw" # find single tag
            else
                grep_opt="-qi"
            fi
            tagarray[$i]=$(echo ${tagarray[$i]} | sed -e "s/^§//g")
            echo -n "                  Search by tag:   \"$(echo ${tagarray[$i]} | sed -e "s/%20/ /g")\" ➜  "
            if grep $grep_opt "$(echo ${tagarray[$i]} | sed -e "s/%20/ /g" | sed -e "s/^§//g")" "$searchfile" ;then
                echo "OK"
                renameTag="${tagsymbol}${tagarray[$i]}${renameTag}"
            else
                echo "-"
            fi
        fi
        i=$((i + 1))
    done
fi

renameTag=${renameTag% }
renameCat=$(echo "${renameCat}" | sed 's/^ *//;s/ *$//')    # remove starting and ending spaces, or all spaces if no destination folder is defined
renameTag_raw="$renameTag"                                  # unmodified for tag folder / tag folder with spaces otherwise not possible
echo "                rename tag is: \"$(echo "$renameTag" | sed -e "s/%20/ /g")\""

echo -e

if [[ $loglevel = "2" ]] ; then
    printf "\n                [runtime up to now:    $(sec_to_time $(( $(date +%s) - ${date_start} )))]\n\n"
fi

}


sub_jq()
{
#########################################################################################
# This function extract yaml-values                                                     #
#########################################################################################

# https://starkandwayne.com/blog/bash-for-loop-over-json-array-using-jq/
    echo "${sub_jq_value}" | base64 -i --decode | jq -r ${1}
}


yaml_validate()
{
#########################################################################################
# This function validate the integrity of yaml-file                                     #
#########################################################################################

    echo "                validate the integrity of yaml-file:"
    yamlcheck=$(yq v "${taglist}" 2>&1)

    if [ $? != 0 ]; then
        echo "ERROR-Message: $yamlcheck"
        exit 1  # file not further processable
        # ToDo: cancel run to preserve PDF source file / possibly move to Errorfiles? (rather not)
    fi

# check & adjust the rule names (only numbers and letters / no number at the beginning):
# ---------------------------------------------------------------------
    rulenames=$(cat "${taglisttmp}" | egrep -v '^[[:space:]]|^#|^$' | egrep ':[[:space:]]?$')
    for i in ${rulenames} ; do
        i2=$(echo "${i}" | sed -e 's/[^a-zA-Z0-9_:]/_/g')    # replace all nonconfom chars / only latin letters!
        if echo "${i2}" | egrep -q '^[^a-zA-Z]' ; then
            i2="_${i2}"   # currently it is not checked if there are duplicates of the rule name due to the adjustment
        fi

        if [[ "${i}" != "${i2}" ]] ; then
            echo "                rule name ${i2} was adjusted"
            sed -i "s/${i}/${i2}/" "${taglisttmp}"
        fi
    done

# check uniqueness of parent nodes:
# ---------------------------------------------------------------------
    if [ $(cat "${taglisttmp}" | grep "^[a-zA-Z0-9_].*[: *]$" | sed 's/ *$//' | sort | uniq -d | wc -l ) -ge 1 ] ; then # check for the number of duplicate lines
        echo "main keywords are not unique!"
        echo "dublicats are: $(cat "${taglisttmp}" | grep "^[a-zA-Z0-9_].*[: *]$" | sed 's/ *$//' | sort | uniq -d)"
    fi

# check parameter validity:
# ---------------------------------------------------------------------
    # check, if value of condition is "all" OR "any" OR "none":
    IFS=$'\012'
    for i in $(cat "${taglisttmp}" | sed 's/^ *//;s/ *$//' | grep -n "^condition:") ; do
        IFS=$OLDIFS
        if ! echo "$i" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(all|any|none)$' > /dev/null  2>&1 ; then
           echo "syntax error in row $(echo $i | awk -F: '{print $1}') [value must be only \"all\" OR \"any\" OR \"none\"]"
        fi
    done

    # check, if value of isRegEx is "true" OR "false":
    IFS=$'\012'
    for i in $(cat "${taglisttmp}" | sed 's/^ *//;s/ *$//' | grep -n "^isRegEx:") ; do
        IFS=$OLDIFS
        if ! echo "$i" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
           echo "syntax error in row $(echo $i | awk -F: '{print $1}') [value must be only \"true\" OR \"false\"]"
        fi
    done

    # check, if value of source is "content" OR "filename":
    IFS=$'\012'
    for i in $(cat "${taglisttmp}" | sed 's/^ *//;s/ *$//' | grep -n "^source:") ; do
        IFS=$OLDIFS
        if ! echo "$i" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(content|filename)$' > /dev/null  2>&1 ; then
           echo "syntax error in row $(echo $i | awk -F: '{print $1}') [value must be only \"content\" OR \"filename\"]"
        fi
    done

    # check of corect value of searchtyp:
    IFS=$'\012'
    for i in $(cat "${taglisttmp}" | sed 's/^ *//;s/ *$//' | grep -n "^searchtyp:") ; do
        IFS=$OLDIFS
        if ! echo "$i" | awk -F: '{print $3}' | sed 's/^ *//;s/ *$//' | tr -cd '[:alnum:][:blank:]' | grep -Eiw '^(is|is not|contains|does not contain|starts with|does not starts with|ends with|does not ends with|matches|does not match)$' > /dev/null  2>&1 ; then
           echo "syntax error in row $(echo $i | awk -F: '{print $1}') [value must be only \"is\" OR \"is not\" OR \"contains\" OR \"does not contain\" OR \"starts with\" OR \"does not starts with\" OR \"ends with\" OR \"does not ends with\" OR \"matches\" OR \"does not match\"]"
        fi
    done

    # check, if value of casesensitive is "true" OR "false":
    IFS=$'\012'
    for i in $(cat "${taglisttmp}" | sed 's/^ *//;s/ *$//' | grep -n "^casesensitive:") ; do
        IFS=$OLDIFS
        if ! echo "$i" | awk -F: '{print $3}' | tr -cd '[:alnum:]' | grep -Eiw '^(true|false)$' > /dev/null  2>&1 ; then
           echo "syntax error in row $(echo $i | awk -F: '{print $1}') [value must be only \"true\" OR \"false\"]"
        fi
    done
    echo -e
}


adjust_python()
{
#########################################################################################
# This function check the python3 installation and the necessary modules                #
#                                                                                       #
#########################################################################################

# >>>>>>>>>>> DEV-PART
    return 1    # deactivated
#   return 0    # deactivated
# <<<<<<<<<<< DEV-PART

    if [ ! $(which python3) ]; then
        echo "                  (Python3 is not installed / use fallback search with regex"
        echo "                  for more precise search results Python3 is required)"
        return 1
    else
        [[ $loglevel = "2" ]] && printf "                  python3 already installed ($(which python3))\n"

    # check / install pip:
        if ! python3 -m pip --version > /dev/null  2>&1 ; then
            printf "                  Python3 pip was not found and will be now installed ➜ "
            # install pip:
            tmp_log1=$(python3 -m ensurepip --default-pip)
            # upgrade pip:
            tmp_log2=$(python3 -m pip install --upgrade pip)

            # check install:
            if python3 -m pip --version > /dev/null  2>&1 ; then
                echo "ok"
            else
                echo "failed ! ! ! (please install Python3 pip manually)"
                #[[ $loglevel = "2" ]] && 
                echo "install log:" && echo "$tmp_log1" && echo "$tmp_log2"
                return 1
            fi
        fi

        modul_list=$(/var/packages/py3k/target/usr/local/bin/pip list)

    # check / install dateutil (dateparser)
        unset tmp_log1
        if !  grep -q dateutil <<<"$modul_list"; then
            printf "                  Python3 module dateutil was not found and will be installed ➜ "
            # install dateutil:
            tmp_log1=$(/var/packages/py3k/target/usr/local/bin/pip3 install python-dateutil)

            # check install:
            if grep -q dateutil <<<"$(/var/packages/py3k/target/usr/local/bin/pip list)" ; then
                echo "ok"
            else
                echo "failed ! ! ! (please install python-dateutil manually)"
                #[[ $loglevel = "2" ]] && 
                echo "install log:" && echo "$tmp_log1"
                return 1
            fi
        fi

    # check / install datefinder
    # https://github.com/akoumjian/datefinder
#        unset tmp_log1
#        if ! grep -q datefinder <<<"$modul_list" ; then
#            printf "                  Python3 module datefinder was not found and will be installed ➜ "
            # install datefinder:
#            tmp_log1=$(/var/packages/py3k/target/usr/local/bin/pip3 install datefinder)

            # check install:
#            if grep -q datefinder <<<"$(/var/packages/py3k/target/usr/local/bin/pip list)" ; then
#                echo "ok"
#            else
#                echo "failed ! ! ! (please install python datefinder manually)"
#                #[[ $loglevel = "2" ]] && 
#                echo "install log:" && echo "$tmp_log1"
#                return 1
#            fi
#        fi

    # check / install pandas:
#        unset tmp_log1
#        if ! grep -q pandas <<<"$modul_list" ; then
#            printf "                  Python3 module pandas was not found and will be installed ➜ "
            # install pandas:
#            tmp_log1=$(/var/packages/py3k/target/usr/local/bin/pip3 install pandas)

            # check install:
#            if grep -q pandas <<<"$(/var/packages/py3k/target/usr/local/bin/pip list)" ; then
#                echo "ok"
#            else
#                echo "failed ! ! ! (please install python pandas manually)"
                #[[ $loglevel = "2" ]] && 
#                echo "install log:" && echo "$tmp_log1"
#                return 1
#            fi
#        fi
    fi

    return 0
}


find_date()
{
#########################################################################################
# This function search for a valid daten in ocr text                                    #
#                                                                                       #
# run with python3 and dateutil - if this impossible, use fallback to search with regex #
#                                                                                       #
#########################################################################################

founddatestr=""
format=$1   # for regex search: 1 = dd mm [yy]yy
            #                   2 = [yy]yy mm dd
            #                   3 = mm dd [yy]yy

    ordinary_date_example_search_DEV(){
        echo -e
        echo ">>>>>>>>>>> DEV-PART - example matches for RegEx search:"
            echo -n "search by RegEx format: dd[./-]mm[./-]yy(yy) ➜ "
            founddatestr_DEV=$( egrep -o "\b([1-9]|[012][0-9]|3[01])[\./-]([1-9]|[01][0-9])[\./-](19[0-9]{2}|20[0-9]{2}|[0-9]{2})\b" <<< "$content" | head )
            echo "$founddatestr_DEV"
            echo -n "search by RegEx format: yy(yy)[./-]mm[./-]dd ➜ "
            founddatestr_DEV=$( egrep -o "\b(19[0-9]{2}|20[0-9]{2}|[0-9]{2})[\./-]([1-9]|[01][0-9])[\./-]([1-9]|[012][0-9]|3[01])\b" <<< "$content" | head )
            echo "$founddatestr_DEV"
            echo -n "search by RegExformat: mm[./-]dd[./-]yy(yy) ➜ "
            founddatestr_DEV=$( egrep -o "\b([1-9]|[01][0-9])[\./-]([1-9]|[012][0-9]|3[01])[\./-](19[0-9]{2}|20[0-9]{2}|[0-9]{2})\b" <<< "$content" | head )
            echo "$founddatestr_DEV"
        echo "<<<<<<<<<<< DEV-PART"
        echo -e
    }

    enhanced_date_example_search_DEV(){
        echo -e
        echo ">>>>>>>>>>> DEV-PART - example match for enhanced Pytho search:"
            sed -i 's/  */ /g' "$searchfile"
            founddatestr_DEV=$( egrep -o "\b(19[0-9]{2}|20[0-9]{2}|[0-9]{2})[\./-]([1-9]|[01][0-9])[\./-]([1-9]|[012][0-9]|3[01])\b" <<< "$(./includes/parse_date.py "$searchfile" | grep -v "ERROR" | sed '/^$/d' )" | head )
            echo "$founddatestr_DEV"
        echo "<<<<<<<<<<< DEV-PART"
        echo -e
    }

if [[ $(adjust_python) -eq 0 ]] && [[ $enhanced_date_search = "yes" ]]; then
#adjust_python
#if [ $? -eq 10000 ]; then
    # reduce multible spaces to one in source file (for better results):
    sed -i 's/  */ /g' "$searchfile"

#   founddatestr=$(./includes/parse_date.py "$searchfile" | grep -v "ERROR" | sed '/^$/d' )
    founddatestr=$( egrep -o "\b(19[0-9]{2}|20[0-9]{2}|[0-9]{2})[\./-]([1-9]|[01][0-9])[\./-]([1-9]|[012][0-9]|3[01])\b" <<< "$(./includes/parse_date.py "$searchfile" | grep -v "ERROR" | sed '/^$/d' )" | head)
    format=2
else
    echo "fallback RegEx search"

    # by DeeKay1 https://www.synology-forum.de/threads/synocr-gui-fuer-ocrmypdf.99647/post-906195
    echo "                  Using date format: ${format} (1 = dd mm [yy]yy; 2 = [yy]yy mm dd; 3 = mm dd [yy]yy)"
    if [ $format -eq 1 ]; then
        # search by format: dd[./-]mm[./-]yy(yy)
        founddatestr=$( egrep -o "\b([1-9]|[012][0-9]|3[01])[\./-]([1-9]|[01][0-9])[\./-](19[0-9]{2}|20[0-9]{2}|[0-9]{2})\b" <<< "$content" | head )
    elif [ $format -eq 2 ]; then
        # search by format: yy(yy)[./-]mm[./-]dd
        founddatestr=$( egrep -o "\b(19[0-9]{2}|20[0-9]{2}|[0-9]{2})[\./-]([1-9]|[01][0-9])[\./-]([1-9]|[012][0-9]|3[01])\b" <<< "$content" | head )
    elif  [ $format -eq 3 ]; then
        # search by format: mm[./-]dd[./-]yy(yy) amerikanisch
        founddatestr=$( egrep -o "\b([1-9]|[01][0-9])[\./-]([1-9]|[012][0-9]|3[01])[\./-](19[0-9]{2}|20[0-9]{2}|[0-9]{2})\b" <<< "$content" | head )
    fi
fi

if [[ ! -z $founddatestr ]]; then
    readarray -t founddates <<<"$founddatestr"
    cntDatesFound=${#founddates[@]}
    echo "                  Dates found: ${cntDatesFound}"

    for currentFoundDate in "${founddates[@]}" ; do
        if [ $format -eq 1 ]; then
            echo "                  check date (dd mm [yy]yy): $currentFoundDate"
            date_dd=$(printf '%02d' $(( 10#$(echo $currentFoundDate | awk -F'[./-]' '{print $1}' | grep -o '[0-9]*') ))) # https://ubuntuforums.org/showthread.php?t=1402291&s=ea6c4468658e97610c038c97b4796b78&p=8805742#post8805742
            date_mm=$(printf '%02d' $(( 10#$(echo $currentFoundDate | awk -F'[./-]' '{print $2}') )))
            date_yy=$(echo $currentFoundDate | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')
        elif [ $format -eq 2 ]; then
            echo "                  check date ([yy]yy mm dd): $currentFoundDate"
            date_dd=$(printf '%02d' $(( 10#$(echo $currentFoundDate | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*') )))
            date_mm=$(printf '%02d' $(( 10#$(echo $currentFoundDate | awk -F'[./-]' '{print $2}') )))
            date_yy=$(echo $currentFoundDate | awk -F'[./-]' '{print $1}' | grep -o '[0-9]*')
        elif  [ $format -eq 3 ]; then
            echo "                  check date (mm dd [yy]yy): $currentFoundDate"
            date_dd=$(printf '%02d' $(( 10#$(echo $currentFoundDate | awk -F'[./-]' '{print $2}' | grep -o '[0-9]*') )))
            date_mm=$(printf '%02d' $(( 10#$(echo $currentFoundDate | awk -F'[./-]' '{print $1}') )))
            date_yy=$(echo $currentFoundDate | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')
        fi

    # check century:
        if [ $(echo -n $date_yy | wc -m) -eq 2 ]; then
            if [ $date_yy -gt $(date +%y) ]; then
                date_yy="$(($(date +%C) - 1))${date_yy}"
                echo "                  Date is most probably in the last century. Setting year to ${date_yy}"
            else
                date_yy="$(date +%C)${date_yy}"
            fi
        fi

        date "+%d/%m/%Y" -d ${date_mm}/${date_dd}/${date_yy} > /dev/null  2>&1    # valid date? https://stackoverflow.com/questions/18731346/validate-date-format-in-a-shell-script
        if [ $? -eq 0 ]; then
            if grep -q "${date_yy}-${date_mm}-${date_dd}" <<< "$ignoredDate" ; then
                echo "                  Date ${date_yy}-${date_mm}-${date_dd} is on ignore list. Skipping this date."
                continue
            else
                echo "                  ➜ valid"
                echo "                      day:  ${date_dd}"
                echo "                      month:${date_mm}"
                echo "                      year: ${date_yy}"
                dateIsFound=yes
                break
            fi
        else
            echo "                  ➜ invalid format"
        fi
    done
fi

if [[ $dateIsFound = no ]]; then
    if [ $format -eq 1 ]; then
        find_date 2
    elif [ $format -eq 2 ]; then
        find_date 3
    fi
fi

# >>>>>>>>>>> DEV-PART
[[ $enhanced_date_search == "yes" ]] && enhanced_date_example_search_DEV
[[ $enhanced_date_search == "yes" ]] && ordinary_date_example_search_DEV
# <<<<<<<<<<< DEV-PART

}


adjust_attributes()
{
#########################################################################################
# This function adjusts the attributes of the target file                               #
#########################################################################################

# Dateirechte anpassen;
# ---------------------------------------------------------------------
    cp --attributes-only -p "${input}" "${output}"
    chmod 664 "${output}"
    synoacltool -enforce-inherit "${output}"

# Dateidatum anpassen:
# ---------------------------------------------------------------------
    echo -n "              ➜ Adapt file date (Source: "

    if [[ "$filedate" == "ocr" ]]; then
        if [ $dateIsFound = no ]; then
            echo "Source file [OCR selected but not found])"
            touch --reference="$input" "$output"
        else
            echo "OCR)"
            TZ=UTC touch -t ${date_yy}${date_mm}${date_dd}0000 "$output"
        #   TZ=$(date +%Z) touch -t ${date_yy}${date_mm}${date_dd}0000 "$output"
        fi
    elif [[ "$filedate" == "now" ]]; then
        echo "NOW)"
        #TZ=$(date +%Z)
        touch --time=modify "$output"
    else
        echo "Source file)"
        touch --reference="$input" "$output"
    fi

# File permissions-Log:
# ---------------------------------------------------------------------
    if [[ $loglevel = "2" ]] ; then
        echo "              ➜ File permissions target file:"
        echo "                  $(ls -l "$output")"
    fi
}


replace_variables(){
    echo "$1" | sed "s~§dsource~${date_dd_source}~g;s~§msource~${date_mm_source}~g;s~§ysource2~${date_yy_source:2}~g;s~§ysource4~${date_yy_source}~g" \
     | sed "s~§ysource~${date_yy_source}~g;s~§hhsource~${date_houre_source}~g;s~§mmsource~${date_min_source}~g;s~§sssource~${date_sek_source}~g;s~§dnow~$(date +%d)~g" \
     | sed "s~§mnow~$(date +%m)~g;s~§ynow2~$(date +%y)~g;s~§ynow4~$(date +%Y)~g;s~§ynow~$(date +%Y)~g;s~§hhnow~$(date +%H)~g;s~§mmnow~$(date +%M)~g;s~§ssnow~$(date +%S)~g" \
     | sed "s~§pagecounttotal~${global_pagecount_new}~g;s~§filecounttotal~${global_ocrcount_new}~g;s~§pagecountprofile~${pagecount_profile_new}~g;s~§filecountprofile~${ocrcount_profile_new}~g" \
     | sed "s~§docr~${date_dd}~g;s~§mocr~${date_mm}~g;s~§yocr2~${date_yy:2}~g;s~§yocr4~${date_yy}~g;s~§yocr~${date_yy}~g;s~%20~ ~g" 
}


rename()
{

[[ $loglevel = "2" ]] && printf "\n                [runtime up to now:    $(sec_to_time $(( $(date +%s) - ${date_start} )))]\n\n"

# rename target file:
# ---------------------------------------------------------------------
echo "              ➜ renaming:"
outputtmp=${output}

if [ -z "$NameSyntax" ]; then
    # if no renaming syntax was specified by the user, the source filename will be used
    NameSyntax="§tit"
fi

echo -n "                  apply renaming syntax ➜ "

# encode special characters for sed compatibility:
title=$(urlencode "${title}")
renameTag=$(urlencode "$(urldecode "${renameTag}")")    # decode %20 before renew encoding

# replace parameters with values:
# ---------------------------------------------------------------------
NewName=$(replace_variables "$NameSyntax")

NewName=$( echo "$NewName" | sed "s~§tag~${renameTag}~g;s~§tit~${title}~g" )

# fallback to old  parameters:
NewName=$( echo "$NewName" | sed "s/§d/${date_dd}/g" )
NewName=$( echo "$NewName" | sed "s/§m/${date_mm}/g" )
NewName=$( echo "$NewName" | sed "s/§y/${date_yy}/g" )

# decode special characters:
NewName=$(urldecode "$NewName")
renameTag=$(urldecode "${renameTag}")

echo "$NewName"

[[ $loglevel = "2" ]] && printf "\n                [runtime up to now:    $(sec_to_time $(( $(date +%s) - ${date_start} )))]\n\n"

# set metadata:
# ---------------------------------------------------------------------
echo -n "              ➜ edit metadata "
if which exiftool > /dev/null  2>&1 ; then
    echo -n "(exiftool ok) "
    exiftool -overwrite_original -time:all="${date_yy}:${date_mm}:${date_dd} 00:00:00" -sep ", " -Keywords="$( echo $renameTag | sed -e "s/^${tagsymbol}//g;s/${tagsymbol}/, /g" )" "${outputtmp}"
else
    echo "FAILED! - exiftool not found! Please install it over cphub.net if you need it"
fi

[[ $loglevel = "2" ]] && printf "\n                [runtime up to now:    $(sec_to_time $(( $(date +%s) - ${date_start} )))]\n\n"


# move target files:
# ---------------------------------------------------------------------
i=0
if [ $moveTaggedFiles = useYearDir ] ; then
    # move to folder each year:
    # ---------------------------------------------------------------------
    echo "              ➜ move to folder each year ( …/target/YYYY/file.pdf)"
    subOUTPUTDIR="${OUTPUTDIR}${date_yy}/"
    echo -n "                  target directory \".../${date_yy}/\" exists? ➜  "
    if [ -d "${subOUTPUTDIR}" ] ;then
        echo "OK"
    else
        mkdir -p "${subOUTPUTDIR}"
        echo "created"
    fi
    destfilecount=$(ls -t "${subOUTPUTDIR}" | grep -o "^${NewName}.*" | wc -l)
    if [ $destfilecount -eq 0 ]; then
        output="${subOUTPUTDIR}${NewName}.pdf"
    else
        while [ -f "${subOUTPUTDIR}${NewName} ($destfilecount).pdf" ]; do
            destfilecount=$(( $destfilecount + 1 ))
            echo "                  continue counting … ($destfilecount)"
        done

        output="${subOUTPUTDIR}${NewName} ($destfilecount).pdf"
        echo "                  File name already exists! Add counter ($destfilecount)"
    fi
    echo "                  target file: $(basename "${output}")"
    mv "${outputtmp}" "${output}"

    adjust_attributes

elif [ $moveTaggedFiles = useYearMonthDir ] ; then
    # move to folder each year & month:
    # ---------------------------------------------------------------------
    echo "              ➜ move to folder each year & month ( …/target/YYYY/MM/file.pdf)"
    subOUTPUTDIR="${OUTPUTDIR}${date_yy}/${date_mm}/"
    echo -n "                  target directory \".../${date_yy}/${date_mm}/\" exists? ➜  "
    if [ -d "${subOUTPUTDIR}" ] ;then
        echo "OK"
    else
        mkdir -p "${subOUTPUTDIR}"
        echo "created"
    fi
    destfilecount=$(ls -t "${subOUTPUTDIR}" | grep -o "^${NewName}.*" | wc -l)
    if [ $destfilecount -eq 0 ]; then
        output="${subOUTPUTDIR}${NewName}.pdf"
    else
        while [ -f "${subOUTPUTDIR}${NewName} ($destfilecount).pdf" ]; do
            destfilecount=$(( $destfilecount + 1 ))
            echo "                  continue counting … ($destfilecount)"
        done

        output="${subOUTPUTDIR}${NewName} ($destfilecount).pdf"
        echo "                  File name already exists! Add counter ($destfilecount)"
    fi
    echo "                  target file: $(basename "${output}")"
    mv "${outputtmp}" "${output}"

    adjust_attributes

elif [ ! -z "$renameCat" ] && [ $moveTaggedFiles = useCatDir ] ; then
    # use sorting in category folder:
    # ---------------------------------------------------------------------
    echo "              ➜ move to category directory"

    # replace date parameters:
    renameCat=$(replace_variables "$renameCat")

    tagarray=( $renameCat )   # define target folder as array
    DestFolderList=""   # temp. list of used destination folders to avoid file duplicates (different tags, but one category)
    maxID=${#tagarray[*]}

    while (( i < maxID )); do
        tagdir=$(echo ${tagarray[$i]} | sed -e "s/%20/ /g")

        echo -n "                  tag directory \"${tagdir}\" exists? ➜  "

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

        destfilecount=$(ls -t "${subOUTPUTDIR}" | grep -o "^${NewName}.*" | wc -l)

        if [ $destfilecount -eq 0 ]; then
            output="${subOUTPUTDIR}${NewName}.pdf"
        else
            while [ -f "${subOUTPUTDIR}${NewName} ($destfilecount).pdf" ]
                do
                    destfilecount=$(( $destfilecount + 1 ))
                    echo "                  continue counting … ($destfilecount)"
                done
            output="${subOUTPUTDIR}${NewName} ($destfilecount).pdf"
            echo "                  File name already exists! Add counter ($destfilecount)"
        fi

        echo "                  target:   ${subOUTPUTDIR}$(basename "${output}")"

        # check if the same file has already been sorted into this category (different tags, but same category)
        if $(echo -e "${DestFolderList}" | grep -q "^${tagarray[$i]}$") ; then
            echo "                  same file has already been copied into target folder (${tagarray[$i]}) and is skipped!"
        else
            if [[ $(echo "${outputtmp}" | awk -F/ '{print $2}') != $(echo "${output}" | awk -F/ '{print $2}') ]]; then
                echo "                  do not set a hard link when copying across volumes"
                cp "${outputtmp}" "${output}"   # do not set a hardlink when copying across volumes
            else
                echo "                  set a hard link"
                commandlog=$(cp -l "${outputtmp}" "${output}" 2>&1 )
                # check: - creating hard link don't fails / - target file is valid (not empty)
                if [ $? != 0 ] || [ $(stat -c %s "${output}") -eq 0 ] || [ ! -f "${output}" ];then
                    echo "                  $commandlog"
                    echo "                  Creating a hard link failed! A file copy is used."
                    if [[ $loglevel = "2" ]] ; then
                        echo "                list of mounted volumes:"
                        df -h --output=source,target | sed -e "s/^/                      /g"
                        echo -e
                    fi
                    cp -f "${outputtmp}" "${output}"
                fi
            fi

            adjust_attributes
        fi

        DestFolderList="${tagarray[$i]}\n${DestFolderList}"
        i=$((i + 1))
        echo -e
    done

    rm "${outputtmp}"
elif [ ! -z "$renameTag" ] && [ $moveTaggedFiles = useTagDir ] ; then
    # use sorting in tag folder:
    # ---------------------------------------------------------------------
    echo "              ➜ move to tag directory"

    if [ ! -z "$tagsymbol" ]; then
        renameTag=$( echo $renameTag_raw | sed -e "s/${tagsymbol}/ /g" )
    else
        renameTag="$renameTag_raw"
    fi

    tagarray=( $renameTag )   # define tags as array
    maxID=${#tagarray[*]}

    while (( i < maxID )); do
        tagdir=$(echo ${tagarray[$i]} | sed -e "s/%20/ /g")
        echo -n "                  tag directory \"${tagdir}\" exists? ➜  "

        if [ -d "${OUTPUTDIR}${tagdir}" ] ;then
            echo "OK"
        else
            mkdir "${OUTPUTDIR}${tagdir}"
            echo "created"
        fi

        destfilecount=$(ls -t "${OUTPUTDIR}${tagdir}" | grep -o "^${NewName}.*" | wc -l)

        if [ $destfilecount -eq 0 ]; then
            output="${OUTPUTDIR}${tagdir}/${NewName}.pdf"
        else
            while [ -f "${OUTPUTDIR}${tagdir}/${NewName} ($destfilecount).pdf" ]; do
                destfilecount=$(( $destfilecount + 1 ))
                echo "                  continue counting … ($destfilecount)"
            done
            output="${OUTPUTDIR}${tagdir}/${NewName} ($destfilecount).pdf"
            echo "                  File name already exists! Add counter ($destfilecount)"
        fi

        echo "                  target:   ./${tagdir}/$(basename "${output}")"

        if [[ $(echo "${outputtmp}" | awk -F/ '{print $2}') != $(echo "${output}" | awk -F/ '{print $2}') ]]; then
            echo "                  do not set a hard link when copying across volumes"
            cp "${outputtmp}" "${output}"   # do not set a hardlink when copying across volumes
        else
            echo "                  set a hard link"
            commandlog=$(cp -l "${outputtmp}" "${output}" 2>&1 )
            # check: - creating hard link don't fails / - target file is valid (not empty)
            if [ $? != 0 ] || [ $(stat -c %s "${output}") -eq 0 ] || [ ! -f "${output}" ];then
                echo "                  $commandlog"
                echo "                  Creating a hard link failed! A file copy is used."
                if [[ $loglevel = "2" ]] ; then
                    echo "                list of mounted volumes:"
                    df -h --output=source,target | sed -e "s/^/                      /g"
                    echo -e
                fi
                cp -f "${outputtmp}" "${output}"
            fi
        fi

        adjust_attributes

        i=$((i + 1))
    done

    echo "              ➜ delete temp. target file"
    rm "${outputtmp}"
else
    # no rule fulfilled - use the target folder:
    # ---------------------------------------------------------------------
    destfilecount=$(ls -t "${OUTPUTDIR}" | grep -o "^${NewName}.*" | wc -l)
    if [ $destfilecount -eq 0 ]; then
        output="${OUTPUTDIR}${NewName}.pdf"
    else
        while [ -f "${OUTPUTDIR}${NewName} ($destfilecount).pdf" ]; do
            destfilecount=$(( $destfilecount + 1 ))
            echo "                  continue counting … ($destfilecount)"
        done

        output="${OUTPUTDIR}${NewName} ($destfilecount).pdf"
        echo "                  File name already exists! Add counter ($destfilecount)"
    fi
    echo "                  target file: $(basename "${output}")"
    mv "${outputtmp}" "${output}"

    adjust_attributes

fi
}


purge_log()
{
#########################################################################################
# This function cleans up older log files                                               #
#########################################################################################

if [ -z $LOGmax ]; then
    echo "purge_log deactivated"
    return
fi

echo "              ➜ purge logfiles:"

# Delete empty logs:
# ---------------------------------------------------------------------
# (sshould no longer be needed by query in start script / synOCR will not be started with empty queue)
IFS=$'\012'  # corresponds to a $'\n' newline
for i in $(ls -tr "${LOGDIR}" | egrep -o '^synOCR.*.log$') ; do
    IFS=$OLDIFS
    if [ $( cat "${LOGDIR}$i" | sed -n "/Funktionsaufrufe/,/synOCR ENDE/p" | wc -c ) -eq 160 ] && cat "${LOGDIR}$i" | grep -q "synOCR ENDE" ; then
        rm "${LOGDIR}$i"
    fi
done

# delete surplus logs:
# ---------------------------------------------------------------------
count2del=$(( $(ls -t "${LOGDIR}" | egrep -o '^synOCR.*.log$' | wc -l) - $LOGmax ))
if [ ${count2del} -ge 0 ]; then
    IFS=$'\012'  # corresponds to a $'\n' newline
    for i in $(ls -tr "${LOGDIR}" | egrep -o '^synOCR.*.log$' | head -n${count2del} ) ; do
        IFS=$OLDIFS
        rm "${LOGDIR}$i"
    done
fi
count2del=$(( $(ls -t "${LOGDIR}" | egrep -o '^synOCR_searchfile.*.txt$' | wc -l) - $LOGmax ))
if [ ${count2del} -ge 0 ]; then
    IFS=$'\012'  # corresponds to a $'\n' newline
    for i in $(ls -tr "${LOGDIR}" | egrep -o '^synOCR_searchfile.*.txt$' | head -n${count2del} ) ; do
        IFS=$OLDIFS
        rm "${LOGDIR}$i"
    done
fi
}


purge_backup()
{
#########################################################################################
# This function cleans up older backup files                                            #
#########################################################################################

if [[ -z $backup_max ]] || [[ $backup_max == 0 ]]; then
    echo "              ➜ purge backup deactivated"
    return
fi

echo "              ➜ purge backup files:"

# delete surplus logs:
if [[ $backup_max_type == days ]]; then
    echo -n "                delete $(find "${BACKUPDIR}" -maxdepth 1 -iname "*.pdf" -mtime +$backup_max | wc -l) files ( > $backup_max days) ➜ "

    del_log=$(find "${BACKUPDIR}" -maxdepth 1 -iname "*.pdf" -mtime +$backup_max -exec rm {} \;)

    if [ $? = 0 ]; then
        echo "ok"
    else
        echo "failed!"
        echo "$del_log"
    fi
else
    echo -n "                delete "$(ls -t "${BACKUPDIR}" | grep -i pdf | tail -n+$(($backup_max+1)) | wc -l )" files ( > $backup_max files) ➜ "

#   del_log=$(ls -tF "${BACKUPDIR}" | grep -i pdf | tail -n+$(($backup_max+1)) | xargs rm -rf)
# ---------------------------------------------------------------------
    count2del=$(( $(ls -t "${BACKUPDIR}" | grep -i pdf | wc -l) - $backup_max ))
    if [ ${count2del} -ge 0 ]; then
        IFS=$'\012'  # corresponds to a $'\n' newline
        for i in $(ls -tr "${BACKUPDIR}" | grep -i pdf | head -n${count2del} ) ; do
            IFS=$OLDIFS
            rm -fv "${BACKUPDIR}${i}"
        done
    fi

    if [ $? = 0 ]; then
        echo "ok"
    else
        echo "failed!"
        echo "$del_log"
    fi
fi

}


main_run()
{
#########################################################################################
# This function passes the files to docker / search for tags / …                        #
#########################################################################################

exclusion=false
if echo "${SearchPraefix}" | grep -qE '^!' ; then
    # is the prefix / suffix an exclusion criteria?
    exclusion=true
    SearchPraefix=$(echo "${SearchPraefix}" | sed -e 's/^!//')
fi

if echo "${SearchPraefix}" | grep -q "\$"$ ; then
    # is suffix
    SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
    if [[ $exclusion = false ]] ; then
        files=$(find "${INPUTDIR}" -maxdepth 1 -iname "*${SearchPraefix}.pdf" -type f)
    elif [[ $exclusion = true ]] ; then
        files=$(find "${INPUTDIR}" -maxdepth 1 -iname "*.pdf" -type f -not -iname "*${SearchPraefix}.pdf" -type f)
    fi
else
    # is prefix
    SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
    if [[ $exclusion = false ]] ; then
        files=$(find "${INPUTDIR}" -maxdepth 1 -iname "${SearchPraefix}*.pdf" -type f)
    elif [[ $exclusion = true ]] ; then
        files=$(find "${INPUTDIR}" -maxdepth 1 -iname "*.pdf" -type f -not -iname "${SearchPraefix}*.pdf" -type f)
    fi
fi

# make special characters visible if necessary
# ---------------------------------------------------------------------
    [[ $loglevel = "2" ]] && printf "                  show files in INPUT with transcoded special characters\n\n" && ls "${INPUTDIR}" | sed -ne 'l'

# document split handling
# ---------------------------------------------------------------------
if [ -n "${documentSplitPattern}" ]; then
    IFS=$'\012'  # corresponds to a $'\n' newline
    for input in ${files} ; do
        IFS=$OLDIFS

        filesWithSplittedParts=()
        numberSplitPages=0
        filename=$(basename "$input")
        echo -n "PREPROCESSING:➜ $filename"

# create temporary working directory
# ---------------------------------------------------------------------
        work_tmp=$(mktemp -d -t tmp.XXXXXXXXXX)
        trap 'rm -rf "$work_tmp"; exit' EXIT
        outputtmp="${work_tmp}/${filename}"

        echo "              ➜ Searching for document split pattern in document $filename"

# OCRmyPDF:
# ---------------------------------------------------------------------
        echo "                  temporary OCR to be able to recognize separator sheets:"

        dockerlog=$(OCRmyPDF 2>&1)
        sleep 5

        echo -e
        echo "              ➜ OCRmyPDF-LOG:"
        echo "$dockerlog" | sed -e "s/^/${dockerlogLeftSpace}/g"
        echo "              ← OCRmyPDF-LOG-END"
        echo -e

# count pages containing document split pattern
# ---------------------------------------------------------------------
        pages=()
        while IFS= read -r line; do
            pages+=( "$line" )
        done <<< $( pdftotext "$outputtmp" - | grep -F -o -e $'\f' -e "$documentSplitPattern" | awk 'BEGIN{page=1} /\f/{++page;next} 1{printf "%d\n", page, $0;}' )
        numberSplitPages=${#pages[@]}
        echo "                $numberSplitPages split pages detected in file $filename"

# split document
# ---------------------------------------------------------------------
        if (( $numberSplitPages > 0 )); then
            let currentPart=$numberSplitPages+1
            fileNoExtension="${filename%%.*}"
            extension="${filename#*.}"
            lastPage="z"
            for (( idx=${#pages[@]}-1 ; idx>=0 ; idx-- )) ; do
                partFileName="$fileNoExtension-$currentPart.$extension"
                let firstPage=${pages[idx]}+1
                echo "                splitting pdf: pages $firstPage-$lastPage into $partFileName"
                dockerlog=$(docker run --rm -i --log-driver=none --mount type=bind,source="${INPUTDIR}",target=/tmp/synocr -w /tmp/synocr --entrypoint /bin/qpdf -a stdin -a stdout -a stderr $dockercontainer "$filename" --pages . $firstPage-$lastPage -- "$partFileName")
                echo "$dockerlog" | sed -e "s/^/${dockerlogLeftSpace}/g"
                let currentPart=$currentPart-1
                let lastPage=${pages[idx]}-1
                filesWithSplittedParts+=($INPUTDIR/$partFileName)
            done
            firstPage=1
            partFileName="$fileNoExtension-$currentPart.$extension"
            echo "                splitting pdf: pages $firstPage-$lastPage into $partFileName"
            dockerlog=$(docker run --rm -i --log-driver=none --mount type=bind,source="${INPUTDIR}",target=/tmp/synocr -w /tmp/synocr --entrypoint /bin/qpdf -a stdin -a stdout -a stderr  $dockercontainer "$filename" --pages . $firstPage-$lastPage -- "$partFileName")
            echo "$dockerlog" | sed -e "s/^/${dockerlogLeftSpace}/g"
            filesWithSplittedParts+=($INPUTDIR/$partFileName)

# delete / save source file (takes into account existing files with the same name): ${filename%.*}
# ---------------------------------------------------------------------
            if [ $backup = true ]; then
                sourceFileCount=$(ls -t "${BACKUPDIR}" | grep -o "^${filename%.*}.*" | wc -l)
                if [ $sourceFileCount -eq 0 ]; then
                    mv "$input" "${BACKUPDIR}${filename}"
                    echo "              ➜ move source file to: ${BACKUPDIR}${filename}"
                else
                    while [ -f "${BACKUPDIR}${filename%.*} ($sourceFileCount).pdf" ]; do
                        sourceFileCount=$(( $sourceFileCount + 1 ))
                        echo "                  continue counting … ($sourceFileCount)"
                    done
                    mv "$input" "${BACKUPDIR}${filename%.*} ($sourceFileCount).pdf"
                    echo "              ➜ move source file to: ${BACKUPDIR}${filename%.*} ($sourceFileCount).pdf"
                fi
            else
                echo "              ➜ delete source file"
                rm -f "$input"
            fi
        else
            filesWithSplittedParts+=($input)
        fi
        rm -rf "$work_tmp"
    done

    files=""
    for fis2 in "${filesWithSplittedParts[@]}" ; do
        files=$files$'\n'$fis2
    done
    echo "                document split processing finished"
fi

# count pages / files:
# ---------------------------------------------------------------------
IFS=$'\012'  # corresponds to a $'\n' newline
for input in ${files} ; do
    IFS=$OLDIFS
    if [ $(which pdfinfo) ]; then
        pagecount_latest=$(pdfinfo "${input}" 2>/dev/null | grep "Pages\:" | awk '{print $2}')
        [[ $loglevel = "2" ]] && echo "                (pages counted with pdfinfo)"
    elif [ $(which exiftool) ]; then
        pagecount_latest=$(exiftool -"*Count*" "${input}" 2>/dev/null | awk -F' ' '{print $NF}')
        [[ $loglevel = "2" ]] && echo "                (pages counted with exiftool)"
    fi

    [ -z $pagecount_latest ] && pagecount_latest=0 && echo "                ERROR - with pdfinfo / exiftool - \$pagecount was set to 0"

# adapt counter:
    global_pagecount_new=$(( $global_pagecount + $pagecount_latest))
    global_ocrcount_new=$(( $global_ocrcount + 1))
    pagecount_profile_new=$(( $pagecount_profile + $pagecount_latest))
    ocrcount_profile_new=$(( $ocrcount_profile + 1))

# create temporary working directory
# ---------------------------------------------------------------------
    work_tmp=$(mktemp -d -t tmp.XXXXXXXXXX)
    trap 'rm -rf "$work_tmp"; exit' EXIT

    echo -e
    filename=$(basename "$input")
    title=${filename%.*}
    echo -n "PROCESSING:   ➜ $filename"
    echo " ($(date))"
    date_start=$(date +%s)

    if [ $delSearchPraefix = "yes" ] && [ ! -z "${SearchPraefix}" ]; then
        title=$( echo "${title}" | sed s/${SearchPraefix}//I )
    fi

    outputtmp="${work_tmp}/${title}.pdf"
    echo "                  temp. target file: ${outputtmp}"

    [[ $loglevel = "2" ]] && printf "\n                [runtime up to now:    $(sec_to_time $(( $(date +%s) - ${date_start} )))]\n\n"

# OCRmyPDF:
# ---------------------------------------------------------------------
    sleep 1
    dockerlog=$(OCRmyPDF 2>&1)
    sleep 1

    echo -e
    echo "              ➜ OCRmyPDF-LOG:"
    echo "$dockerlog" | sed -e "s/^/${dockerlogLeftSpace}/g"
    echo "              ← OCRmyPDF-LOG-END"
    echo -e

    [[ $loglevel = "2" ]] && printf "\n                [runtime up to now:    $(sec_to_time $(( $(date +%s) - ${date_start} )))]\n\n"

# check if target file is valid (not empty), otherwise continue / defective source files are moved to ERROR including LOG:
# ---------------------------------------------------------------------
    if [ $(stat -c %s "${outputtmp}") -eq 0 ] || [ ! -f "${outputtmp}" ];then
        echo "                  ┖➜ failed! (target file is empty or not available)"
        rm "${outputtmp}"
        if echo "$dockerlog" | grep -q ERROR ;then
            if [ ! -d "${INPUTDIR}ERRORFILES" ] ; then
                echo "                                  ERROR-Directory [${INPUTDIR}ERRORFILES] will be created!"
                mkdir "${INPUTDIR}ERRORFILES"
            fi

            destfilecount=$(ls -t "${INPUTDIR}ERRORFILES" | grep -o "^${filename%.*}.*" | wc -l)
            if [ $destfilecount -eq 0 ]; then
                output="${INPUTDIR}ERRORFILES/${filename%.*}.pdf"
            else
                while [ -f "${INPUTDIR}ERRORFILES/${filename%.*} ($destfilecount).pdf" ]
                    do
                        destfilecount=$(( $destfilecount + 1 ))
                        echo "                                  continue counting … ($destfilecount)"
                    done
                output="${INPUTDIR}ERRORFILES/${filename%.*} ($destfilecount).pdf"
                echo "                                  File name already exists! Add counter ($destfilecount)"
            fi
            mv "$input" "$output"
            if [ "$loglevel" != 0 ] ;then
                cp "$LOGFILE" "${output}.log"
            fi
            echo "                              ┖➜ move to ERRORFILES"
        fi
        rm -rf "$work_tmp"
        continue
    else
        printf "                target file (OK): ${outputtmp}\n\n"
    fi


# temporary output destination with seconds for uniqueness (otherwise there will be duplication if renaming syntax is missing)
# ---------------------------------------------------------------------
    output="${OUTPUTDIR}temp_${title}_$(date +%s).pdf"

# move temporary file to destination folder:
# ---------------------------------------------------------------------
    mv "${outputtmp}" "${output}"

# source file permissions-Log:
# ---------------------------------------------------------------------
    if [[ $loglevel = "2" ]] ; then
        echo "              ➜ File permissions source file:"
        echo -n "                  "
        ls -l "$input"
    fi

# exact text
# ---------------------------------------------------------------------
    searchfile="${work_tmp}/synOCR.txt"
    searchfilename="${work_tmp}/synOCR_filename.txt"    # for search in file name
    echo "${title}" > "${searchfilename}"

# Search in the whole documents, or only on the first page?:
# ---------------------------------------------------------------------
    if [ $searchAll = no ]; then
        pdftotextOpt="-l 1"
    else
        pdftotextOpt=""
    fi

    /bin/pdftotext -layout $pdftotextOpt "$output" "$searchfile"
    sed -i 's/^ *//' "$searchfile"        # delete beginning blanks

    content=$(cat "$searchfile" )   # the standard rules search in the variable / the extended rules directly in the source file

    [[ $loglevel = "2" ]] && cp "$searchfile" "${LOGDIR}synOCR_searchfile_${title}.txt"

# search by tags:
# ---------------------------------------------------------------------
    tag_search

# search by date:
# ---------------------------------------------------------------------
    dateIsFound=no
    find_date 1

    date_dd_source=$(stat -c %y "$input" | awk '{print $1}' | awk -F- '{print $3}')
    date_mm_source=$(stat -c %y "$input" | awk '{print $1}' | awk -F- '{print $2}')
    date_yy_source=$(stat -c %y "$input" | awk '{print $1}' | awk -F- '{print $1}')
    date_houre_source=$(stat -c %y "$input" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $1}')
    date_min_source=$(stat -c %y "$input" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $2}')
    date_sek_source=$(stat -c %y "$input" | awk '{print $2}' | awk -F. '{print $1}' | awk -F: '{print $3}')

    if [ $dateIsFound = no ]; then
        echo "                  Date not found in OCR text - use file date:"
        date_dd=$date_dd_source
        date_mm=$date_mm_source
        date_yy=$date_yy_source
        echo "                  day:  ${date_dd}"
        echo "                  month:${date_mm}"
        echo "                  year: ${date_yy}"
    fi

# compose and rename file names / move to target:
# ---------------------------------------------------------------------
    rename

# delete / save source file (takes into account existing files with the same name): ${filename%.*}
# ---------------------------------------------------------------------
    if [ $backup = true ]; then
        sourceFileCount=$(ls -t "${BACKUPDIR}" | grep -o "^${filename%.*}.*" | wc -l)
        if [ $sourceFileCount -eq 0 ]; then
            mv "$input" "${BACKUPDIR}${filename}"
            echo "              ➜ move source file to: ${BACKUPDIR}${filename}"
        else
            while [ -f "${BACKUPDIR}${filename%.*} ($sourceFileCount).pdf" ]; do
                sourceFileCount=$(( $sourceFileCount + 1 ))
                echo "                  continue counting … ($sourceFileCount)"
            done
            mv "$input" "${BACKUPDIR}${filename%.*} ($sourceFileCount).pdf"
            echo "              ➜ move source file to: ${BACKUPDIR}${filename%.*} ($sourceFileCount).pdf"
        fi
    else
        rm -f "$input"
        echo "              ➜ delete source file"
    fi

# Notification:
# ---------------------------------------------------------------------
    # ToDo: the automatic language setting should be included here:
    if [ $dsmtextnotify = "on" ] ; then
        sleep 1
        file_notify=$(basename "${output}")
        if [[ $dsm_version = "7" ]] ; then

            # adjust message text with filename e.g.:
# strings are preloadet from DSM / modify currently not possible ! ! !
#            for file in /usr/syno/synoman/webman/3rdparty/synOCR/texts/**/strings; do
#                sed -i "s/job_successful_replacement/${file_notify}/" "$file"
#            done
            synodsmnotify -c SYNO.SDS.ThirdParty.App.synOCR $MessageTo synOCR:app:app_name synOCR:app:job_successful
            # reset message text:
#            for file in /usr/syno/synoman/webman/3rdparty/synOCR/texts/**/strings; do
#                sed -i "s/${file_notify}/job_successful_replacement/" "$file"
#            done
        else
           synodsmnotify $MessageTo "synOCR" "File [${file_notify}] was processed"
        fi
        sleep 1
    fi

    if [ $dsmbeepnotify = "on" ] ; then
        sleep 1
        echo 2 > /dev/ttyS1 #short beep
        sleep 1
    fi

    if [ ! -z $PBTOKEN ] ; then
        PB_LOG=$(curl $cURLloglevel --header "Access-Token:${PBTOKEN}" https://api.pushbullet.com/v2/pushes -d type=note -d title="synOCR" -d body="Datei [$(basename "${output}")] ist fertig.")
        if [[ $loglevel = "2" ]] ; then
            echo "                  PushBullet-LOG:"
            echo "$PB_LOG" | sed -e "s/^/               /g"
        elif echo "$PB_LOG" | grep -q "error"; then # for log level 1 only error output
            echo -n "                  PushBullet-Error: "
            echo "$PB_LOG" | jq -r '.error_code'
        fi
    else
        echo "                  INFO: (PushBullet-TOKEN not set)"
    fi

# update file count total: ${pagecount_profile_new} ${ocrcount_profile_new} ${global_pagecount_new} ${global_ocrcount_new}
# ---------------------------------------------------------------------
    sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET value_1='$global_pagecount_new' WHERE key='global_pagecount'"
    sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET value_1='$global_ocrcount_new' WHERE key='global_ocrcount'"
# update file count profile:
    sqlite3 "./etc/synOCR.sqlite" "UPDATE config SET pagecount='$pagecount_profile_new' WHERE profile_ID='$profile_ID'"
    sqlite3 "./etc/synOCR.sqlite" "UPDATE config SET ocrcount='$ocrcount_profile_new' WHERE profile_ID='$profile_ID'"

    echo -e
    echo "              Stats:"
    echo "                  ➜ runtime last file:    $(sec_to_time $(( $(date +%s) - ${date_start} )))"
    echo "                  ➜ pagecount last file:  $pagecount_latest"
    echo "                  ➜ file count profile :  (profile $profile) - ${ocrcount_profile_new} PDF's / ${pagecount_profile_new} Pages processed up to now"
    echo "                  ➜ file count total:     ${global_ocrcount_new} PDF's / ${global_pagecount_new} Pages processed up to now"
    echo -e
    
# delete temporary working directory:
# ---------------------------------------------------------------------
    echo "              ➜ delete tmp-files …"
    rm -rf "$work_tmp"
done
}

#        _______________________________________________________________________________
#       |                                                                               |
#       |                                 RUN THE FUNCTIONS                             |
#       |_______________________________________________________________________________|

    printf "\n\n\n"
    echo "    ----------------------------------"
    echo "    |    ==> Funktionsaufrufe <==    |"
    echo "    ----------------------------------"

    update_dockerimage
    main_run
    purge_log
    purge_backup

    printf "\n\n\n"

exit 0
