#!/bin/sh
# /usr/syno/synoman/webman/3rdparty/synOCR/synOCR.sh

###################################################################################

    echo "    -----------------------------------"
    echo "    |    ==> Installationsinfo <==    |"
    echo "    -----------------------------------"
    echo -e
    
    DevChannel="Release"    # BETA
    
# ---------------------------------------------------------------------------------
#           BASIC CONFIGURATIONS / INDIVIDUAL ADAPTATIONS / Default values        |
# ---------------------------------------------------------------------------------
    synocrdomain="geimist.eu"   # 
    niceness=15                 # The priority is in the range from -20 to +19 (in integer steps), where -20 is the highest priority (=most computing power) and 19 is the lowest priority (=lowest computing power). The default priority is 0. NEGATIVE VALUES SHOULD NEVER BE DEFAULTED!
    workprofile="$1"            # the profile submitted by the start script
    LOGFILE="$2"                # current logfile / is submitted by start script

# an welchen User/Gruppe soll die DSM-Benachrichtigung gesendet werden :
# ---------------------------------------------------------------------
    synOCR_user=$(whoami); echo "synOCR-user:              $synOCR_user"
    if cat /etc/group | grep administrators | grep -q "$synOCR_user"; then
        isAdmin=yes
    else
        isAdmin=no
    fi
    MessageTo="@administrators"	# Administrators (standard)
    #MessageTo="$synOTR_user"	# User, welche synOTR aufgerufen hat (funktioniert natürlich nicht bei root, da root kein DSM-GUI-LogIn hat und die Message ins leere läuft)

# Read out and change into the working directory:
# ---------------------------------------------------------------------
    OLDIFS=$IFS	                # Save original field separator
    APPDIR=$(cd $(dirname $0);pwd)
    cd ${APPDIR}

# Load configuration:
# ---------------------------------------------------------------------

    sSQL="SELECT profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, 
        delSearchPraefix, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN, 
        dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, filedate, tagsymbol, dockerimageupdate, dockerimageupdate_checked FROM config WHERE profile_ID='$workprofile' "

    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL")

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
    dsmbeepnotify=$(echo "$sqlerg" | awk -F'\t' '{print $20}')
    loglevel=$(echo "$sqlerg" | awk -F'\t' '{print $21}')
    filedate=$(echo "$sqlerg" | awk -F'\t' '{print $22}')
    tagsymbol=$(echo "$sqlerg" | awk -F'\t' '{print $23}')

# globale Werte auslesen:
    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT dockerimageupdate, dockerimageupdate_checked FROM system WHERE rowid=1 ")
    dockerimageupdate=$(echo "$sqlerg" | awk -F'\t' '{print $1}')
    dockerimageupdate_checked=$(echo "$sqlerg" | awk -F'\t' '{print $2}')
    
# System Information:
# --------------------------------------------------------------------- 
    echo "synOCR-Version:           $(get_key_value /var/packages/synOCR/INFO version)"
    machinetyp=$(uname --machine); echo "Architecture:             $machinetyp"
    dsmbuild=$(uname -v | awk '{print $1}' | sed "s/#//g"); echo "DSM-build:                $dsmbuild"
    read MAC </sys/class/net/eth0/address
    sysID=$(echo $MAC | cksum | awk '{print $1}'); sysID="$(printf '%010d' $sysID)"
    device=$(uname -a | awk -F_ '{print $NF}' | sed "s/+/plus/g")
    echo "Device:                   $device ($sysID)"	    #  | sed "s/ds//g"
    echo "current Profil:           $profile"
    echo "DB-version:               $(sqlite3 ./etc/synOCR.sqlite "SELECT DB_Version FROM system WHERE rowid=1")"
    echo "used image (created):     $dockercontainer ($(/usr/local/bin/docker inspect -f '{{ .Created }}' "$dockercontainer" | awk -F. '{print $1}'))"
    echo "used ocr-parameter:       $ocropt"
    echo "replace search prefix:    $delSearchPraefix"
    echo "renaming syntax:          $NameSyntax"
    echo "Symbol for tag marking:   ${tagsymbol}"
    echo "source for filedate:      ${filedate}"
    echo -n "Docker Test:              "
    if /usr/local/bin/docker --version | grep -q "version"  ; then
        echo "OK"
    else
        echo "WARNING: Docker could not be found. Please check if the Docker package has been installed!"
    fi

# Configuration for LogLevel:
# ---------------------------------------------------------------------
    # LOGlevel:     0 => Logging inaktiv / 1 => normal / 2 => extended
    if [ $loglevel = "1" ] ; then
        echo "Loglevel:                 normal"
        cURLloglevel="-s"
        wgetloglevel="-q"
        dockerlogLeftSpace="               "
    elif [ $loglevel = "2" ] ; then
        echo "Loglevel:                 extended"
        cURLloglevel="-v"
        wgetloglevel="-v"
        dockerlogLeftSpace="                  "
        ocropt="$ocropt -v2"
    fi


# Check or create and adjust directories:
# ---------------------------------------------------------------------
    echo "Application Directory:    ${APPDIR}"
    
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
        mkdir -p "$BACKUPDIR"
        echo "BackUp directory was created [$BACKUPDIR]"
        backup=true
    else
        echo "Files are deleted immediately! / No valid directory [$BACKUPDIR]"
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


check_dockerimage() 
{
# this function checks for image update
# --------------------------------------------------------------
    if echo $dockercontainer | grep -qE "latest$" && [[ $dockerimageupdate = 1 ]] && [[ ! $(sqlite3 ./etc/synOCR.sqlite "SELECT date_checked FROM dockerupdate WHERE image='$dockercontainer' ") = $(date +%Y-%m-%d) ]];then
        updatelog=$(docker pull $dockercontainer) #> /dev/null  2>&1
        check_date=$(date +%Y-%m-%d)
        if [ -z $(sqlite3 "./etc/synOCR.sqlite"  "SELECT * FROM dockerupdate WHERE image='$dockercontainer'") ]; then
            sqlite3 "./etc/synOCR.sqlite" "INSERT INTO dockerupdate ( image, date_checked ) VALUES  ( '$dockercontainer', '$check_date' )"	# , $(($today-1))
        else
            sqlite3 "./etc/synOCR.sqlite" "UPDATE dockerupdate SET date_checked='$check_date' WHERE image='$dockercontainer' "
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


parseRegex () 
{
# This function returns the substring described by a regular expression
# Call: parseRegex "string" "regex"
# https://stackoverflow.com/questions/5536018/how-to-print-matched-regex-pattern-using-awk
# --------------------------------------------------------------
echo "$1" | awk '{
    for(i=1; i<=NF; i++) {
        tmp=match($i, /'"${2}"'/)
        if(tmp) {
                print $i
            }
        }
    }'
}  


purge_LOG() 
{
#########################################################################################
# This function cleans up older log files                                               #
#########################################################################################

if [ -z $LOGmax ]; then
    echo "purge_LOG deactivated"
    return
fi

# Delete empty logs:
# (sollte durch Abfrage in Startskript nicht mehr benötigt werden)
for i in `ls -tr "${LOGDIR}" | egrep -o '^synOCR.*.log$' `                   # Listing of all LOG files
    do
        # if [ $( cat "${LOGDIR}$i" | tail -n5 | head -n2 | wc -c ) -le 5 ] && cat "${LOGDIR}$i" | grep -q "synOCR ENDE" ; then
        if [ $( cat "${LOGDIR}$i" | sed -n "/Funktionsaufrufe/,/synOCR ENDE/p" | wc -c ) -eq 160 ] && cat "${LOGDIR}$i" | grep -q "synOCR ENDE" ; then
        #    if [ -z "$TRASHDIR" ] ; then 
                rm "${LOGDIR}$i"
        #    else
        #        mv "${LOGDIR}$i" "$TRASHDIR"
        #    fi
        fi
    done

# delete surplus logs:
count2del=$( expr $(ls -t "${LOGDIR}" | egrep -o '^synOCR.*.log$' | wc -l) - $LOGmax )
if [ ${count2del} -ge 0 ]; then
    for i in `ls -tr "${LOGDIR}" | egrep -o '^synOCR.*.log$' | head -n${count2del} `
        do
            rm "${LOGDIR}$i"
        done
fi
}


mainrun() 
{
#########################################################################################
# This function passes the files to docker                                              #
#########################################################################################
    
IFS=$'\012'	 # corresponds to a $'\n' newline
for input in $(find "${INPUTDIR}" -maxdepth 1 -iname "${SearchPraefix}*.pdf" -type f) #  -mmin +"$timediff" -o -name "${SearchPraefix}*.PDF" 
    do
        IFS=$OLDIFS
    # create temporary working directory
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
    
    # Create destination filename (considers existing files with the same name):
        destfilecount=$(ls -t "${OUTPUTDIR}" | grep -o "^${title}.*" | wc -l)
        if [ $destfilecount -eq 0 ]; then
            output="${OUTPUTDIR}${title}.pdf"
        else
            while [ -f "${OUTPUTDIR}${title} ($destfilecount).pdf" ]
                do
                    destfilecount=$( expr $destfilecount + 1 )
                    echo "                  continue counting … ($destfilecount)"
                done
            output="${OUTPUTDIR}${title} ($destfilecount).pdf"
            echo "                  File name already exists! Add counter ($destfilecount)"
        fi
        
        outputtmp="${work_tmp}/${title}.pdf"
        echo "                  temp. target file: ${outputtmp}"

    # OCRmyPDF:
        OCRmyPDF()
        {
            # https://www.synology-forum.de/showthread.html?99516-Container-Logging-in-Verbindung-mit-stdin-und-stdout
            cat "$input" | /usr/local/bin/docker run --name synOCR --rm -i -log-driver=none -a stdin -a stdout -a stderr $dockercontainer $ocropt - - | cat - > "$outputtmp"
        }
        sleep 1
        dockerlog=$(OCRmyPDF 2>&1)
        sleep 1

        echo -e
        echo "              ➜ OCRmyPDF-LOG:"
        echo "$dockerlog" | sed -e "s/^/${dockerlogLeftSpace}/g"
        echo "              ← OCRmyPDF-LOG-END"
        echo -e

    # check if target file is valid (not empty), otherwise continue / defective source files are moved to ERROR including LOG:
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
                            destfilecount=$( expr $destfilecount + 1 )
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
            echo "                  target file (OK): ${output}"
        fi
        
    # move temporary file to destination folder:
        mv "${outputtmp}" "${output}"
        
    # File permissions-Log:
        if [ $loglevel = "2" ] ; then
            echo "              ➜ File permissions source file:"
            echo -n "                  "
            ls -l "$input"
            echo "              ➜ File permissions target file:"
            echo -n "                  "
            ls -l "$output"
        fi

    # Transmitting file attributes:
        # ( ➜ Date adjustment moved to the date function)
        echo -n "              ➜ transfer the file permissions and owners "
        if echo $( synoacltool -get "$input" ) | grep -q is_support_ACL ; then
            echo "(use ACL)"
            synoacltool -copy "$input" "$output"
            #touch --reference="$input" "$output"
        else
            echo "(use standard linux permissions)"
            cp --attributes-only -p "$input" "$output"
            #touch --reference="$input" "$output"
        fi
        
    # File permissions-Log:
        if [ $loglevel = "2" ] ; then
            echo "              ➜ File permissions target file:"
            echo -n "                  "
            ls -l "$output"
        fi
        
    # suche nach Datum und Tags in Dokument:
        findDate()
        {
        # Text exrahieren
            searchfile="${work_tmp}/synOCR.txt"

            if [ $searchAll = no ]; then
                pdftotextOpt="-l 1"
            else
                pdftotextOpt=""
            fi

            /bin/pdftotext -layout $pdftotextOpt "$output" "$searchfile"
            content=$(cat "$searchfile" )
            # cp "$searchfile" ${OUTPUTDIR} # DEV

        # suche nach Tags:
            tagsearch() 
            {
            echo "                      ➜ search tags and date:"
            if [ -z "$taglist" ]; then
                echo "                        no tags defined"
                return
            elif [ -f "$taglist" ]; then
            	echo "                        source for tags is file [$taglist]"
            	taglist=$(cat "$taglist")
            fi
            renameTag=""
            renameCat=""
            taglist2=$( echo "$taglist" | sed -e "s/ /%20/g" | sed -e "s/;/ /g" )	# Leerzeichen in tags codieren und Semikola zu Leerzeichen (für Array) konvertieren
            tagarray=( $taglist2 )   # Tags als Array definieren
            i=0
            maxID=${#tagarray[*]}
            echo "                          tag count:       $maxID"

        #    for a in ${tagarray[@]}; do
        #        echo $a
        #    done
            while (( i < maxID )); do
                if echo "${tagarray[$i]}" | grep -q "=" ;then
                    if echo $(echo "${tagarray[$i]}" | awk -F'=' '{print $1}') | grep -q  "^§" ;then
                       grep_opt="-qiw"
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
                        grep_opt="-qiw"
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
            renameTag=${renameTag% }
            renameCat=${renameCat% }
            echo "                  rename tag is: \"$(echo "$renameTag" | sed -e "s/%20/ /g")\""
            }
            tagsearch

        # suche nach Datum:
            dateIsFound=no
            # suche Format: dd[./-]mm[./-]yy(yy)
            founddate=$( parseRegex "$content" "\y([1-9]|[012][0-9]|3[01])[\./-]([1-9]|[01][0-9])[\./-](19[0-9]{2}|20[0-9]{2}|[0-9]{2})\y" | head -n1 )
            # INFO about \y: In other GNU software, the word-boundary operator is ‘\b’. However, that conflicts with the awk language’s definition of ‘\b’ as backspace, 
            # so gawk uses a different letter. The current method of using ‘\y’ for the GNU ‘\b’ appears to be the lesser of two evils.
            # https://www.gnu.org/software/gawk/manual/html_node/GNU-Regexp-Operators.html
            if [ ! -z $founddate ]; then
                echo -n "                  check date (dd mm [yy]yy): $founddate"
                date_dd=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $1}' | grep -o '[0-9]*') ))) # https://ubuntuforums.org/showthread.php?t=1402291&s=ea6c4468658e97610c038c97b4796b78&p=8805742#post8805742
                date_mm=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $2}') )))
                date_yy=$(echo $founddate | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')    
                if [ $(echo $date_yy | wc -c) -eq 3 ] ; then
                    date_yy="20${date_yy}"
                fi
                date "+%d/%m/%Y" -d ${date_mm}/${date_dd}/${date_yy} > /dev/null  2>&1    # valid date? https://stackoverflow.com/questions/18731346/validate-date-format-in-a-shell-script

                if [ $? -eq 0 ]; then
                    echo " ➜ valid"
                    echo "                  day:  ${date_dd}"
                    echo "                  month:${date_mm}"
                    echo "                  year: ${date_yy}"
                    dateIsFound=yes
                else
                    echo " ➜ invalid format"
                fi
                founddate=""
            fi

            # suche Format: yy(yy)[./-]mm[./-]dd
            if [ $dateIsFound = no ]; then
                founddate=$( parseRegex "$content" "\y(19[0-9]{2}|20[0-9]{2}|[0-9]{2})[\./-]([1-9]|[01][0-9])[\./-]([1-9]|[012][0-9]|3[01])\y" | head -n1 )
                if [ ! -z $founddate ]; then
                    echo -n "                  check date ([yy]yy mm dd): $founddate"
                    date_dd=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*') )))
                    date_mm=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $2}') )))
                    date_yy=$(echo $founddate | awk -F'[./-]' '{print $1}' | grep -o '[0-9]*')    
                    if [ $(echo $date_yy | wc -c) -eq 3 ] ; then
                        date_yy="20${date_yy}"
                    fi
                    date "+%d/%m/%Y" -d ${date_mm}/${date_dd}/${date_yy} > /dev/null  2>&1    # valid date? https://stackoverflow.com/questions/18731346/validate-date-format-in-a-shell-script
                    if [ $? -eq 0 ]; then
                        echo " ➜ valid"
                        echo "                  day:  ${date_dd}"
                        echo "                  month:${date_mm}"
                        echo "                  year: ${date_yy}"
                        dateIsFound=yes
                    else
                        echo " ➜ invalid format"
                    fi
                    founddate=""
                fi
            fi

            # suche Format: mm[./-]dd[./-]yy(yy) amerikanisch
            if [ $dateIsFound = no ]; then
                founddate=$( parseRegex "$content" "\y([1-9]|[01][0-9])[\./-]([1-9]|[012][0-9]|3[01])[\./-](19[0-9]{2}|20[0-9]{2}|[0-9]{2})\y" | head -n1 )
                if [ ! -z $founddate ]; then
                    echo -n "                  check date (mm dd [yy]yy): $founddate"
                    date_dd=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $2}' | grep -o '[0-9]*') )))
                    date_mm=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $1}') )))
                    date_yy=$(echo $founddate | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')    
                    if [ $(echo $date_yy | wc -c) -eq 3 ] ; then
                        date_yy="20${date_yy}"
                    fi
                    date "+%d/%m/%Y" -d ${date_mm}/${date_dd}/${date_yy} > /dev/null  2>&1    # valid date? https://stackoverflow.com/questions/18731346/validate-date-format-in-a-shell-script
                    if [ $? -eq 0 ]; then
                        echo " ➜ valid"
                        echo "                  day:  ${date_dd}"
                        echo "                  month:${date_mm}"
                        echo "                  year: ${date_yy}"
                        dateIsFound=yes
                    else
                        echo " ➜ invalid format"
                    fi
                    founddate=""
                fi
            fi

            date_dd_source=$(stat -c %y "$input" | awk '{print $1}' | awk -F- '{print $3}')
            date_mm_source=$(stat -c %y "$input" | awk '{print $1}' | awk -F- '{print $2}')
            date_yy_source=$(stat -c %y "$input" | awk '{print $1}' | awk -F- '{print $1}') 
            
            if [ $dateIsFound = no ]; then
                echo "                  Date not found in OCR text - use file date:"
                date_dd=$date_dd_source
                date_mm=$date_mm_source
                date_yy=$date_yy_source
                echo "                  day:  ${date_dd}"
                echo "                  month:${date_mm}"
                echo "                  year: ${date_yy}"
            fi
                
            # Dateidatum anpassen:
            echo -n "              ➜ Adapt file date (Source: "
            if [[ "$filedate" == "ocr" ]]; then
                if [ $dateIsFound = no ]; then
                    echo "Source file [OCR selected but not found])"
                    touch --reference="$input" "$output"
                else
                    echo "OCR)"
                    TZ=UTC touch -t ${date_yy}${date_mm}${date_dd}0000 "$output"
         #           TZ=$(date +%Z) touch -t ${date_yy}${date_mm}${date_dd}0000 "$output"
                fi
            elif [[ "$filedate" == "now" ]]; then
                echo "NOW)"
                #TZ=$(date +%Z) 
                touch –time=modify "$output"
            else
            #elif [[ "$filedate" == "source" ]]; then
                echo "Source file)"
                touch --reference="$input" "$output"
            fi
        }
        findDate
        
    # Dateinamen zusammenstellen und umbenennen:
        rename() 
        {
        # Zieldatei umbenennen:
        echo "              ➜ renaming:"
        outputtmp=${output}
        if [ ! -z "$NameSyntax" ]; then
            echo -n "                  apply renaming syntax ➜ "
            title=$(echo "${title}" | sed -f ./includes/encode.sed)             # für sed-Kompatibilität Sonderzeichen encodieren
            renameTag=$( echo "${renameTag}" | sed -f ./includes/encode.sed)

            NewName="$NameSyntax"
            NewName=$( echo "$NewName" | sed "s/§dsource/${date_dd_source}/g" )
            NewName=$( echo "$NewName" | sed "s/§msource/${date_mm_source}/g" )
            NewName=$( echo "$NewName" | sed "s/§ysource/${date_yy_source}/g" )
            NewName=$( echo "$NewName" | sed "s/§dnow/$(date +%d)/g" )
            NewName=$( echo "$NewName" | sed "s/§mnow/$(date +%m)/g" )
            NewName=$( echo "$NewName" | sed "s/§ynow/$(date +%Y)/g" )
            NewName=$( echo "$NewName" | sed "s/§docr/${date_dd}/g" )
            NewName=$( echo "$NewName" | sed "s/§mocr/${date_mm}/g" )
            NewName=$( echo "$NewName" | sed "s/§yocr/${date_yy}/g" )
            NewName=$( echo "$NewName" | sed "s/§tag/${renameTag}/g")
            NewName=$( echo "$NewName" | sed "s/§tit/${title}/g")
            NewName=$( echo "$NewName" | sed "s/%20/ /g" )
            
            # Fallback für alte Parameter:
            NewName=$( echo "$NewName" | sed "s/§d/${date_dd}/g" )
            NewName=$( echo "$NewName" | sed "s/§m/${date_mm}/g" )
            NewName=$( echo "$NewName" | sed "s/§y/${date_yy}/g" )

            NewName=$( echo "$NewName" | sed -f ./includes/decode.sed)          # Sonderzeichen decodieren
            renameTag=$( echo "${renameTag}" | sed -f ./includes/decode.sed)

            echo "$NewName"

            if [ ! -z "$renameCat" ] && [ $moveTaggedFiles = useCatDir ] ; then
                echo "              ➜ move to category directories"
                #renameCat=$( echo ${renameCat} | sed -e "s/${tagsymbol}//g" )
                tagarray=( $renameCat )   # Tags als Array definieren
                i=0
                DestFolderList=""   # temp. Liste der verwendeten Zielordner um Dateiduplikate (unterschiedliche Tags, aber eine Kategorie) zu vermeiden
                maxID=${#tagarray[*]}
            #    for a in ${tagarray[@]}; do
            #        echo $a
            #    done
                while (( i < maxID )); do
                    tagdir=$(echo ${tagarray[$i]} | sed -e "s/%20/ /g")
                    echo -n "                  tag directories \"${tagdir}\" exists? ➜  "
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
                        while [ -f "${OUTPUTDIR}${tagdir}/${NewName} ($destfilecount).pdf" ]
                            do
                                destfilecount=$( expr $destfilecount + 1 )
                                echo "                  continue counting … ($destfilecount)"
                            done
                        output="${OUTPUTDIR}${tagdir}/${NewName} ($destfilecount).pdf"
                        echo "                  File name already exists! Add counter ($destfilecount)"
                    fi
                    
                    echo "                  target:   ./${tagdir}/$(basename "${output}")"
                    # prüfen, ob selbe Datei bereits einmal in diese Kategorie einsortiert wurde (unterschiedliche Tags, aber gleich Kategorie)
                    if $(echo -e "${DestFolderList}" | grep -q "^${tagarray[$i]}$") ; then
                        echo "                  same file has already been copied into category (${tagarray[$i]}) and is skipped!"
                    else
                        cp -l "${outputtmp}" "${output}"
                    fi
                    DestFolderList="${tagarray[$i]}\n${DestFolderList}"
                    i=$((i + 1))
                done
                rm "${outputtmp}"
            elif [ ! -z "$renameTag" ] && [ $moveTaggedFiles = useTagDir ] ; then
                echo "              ➜ move to tag directories"
                if [ ! -z "$tagsymbol" ]; then
                    renameTag=$( echo $renameTag | sed -e "s/${tagsymbol}//g" )
                fi
                tagarray=( $renameTag )   # Tags als Array definieren
                i=0
                maxID=${#tagarray[*]}
            #    for a in ${tagarray[@]}; do
            #        echo $a
            #    done
                while (( i < maxID )); do
                    tagdir=$(echo ${tagarray[$i]} | sed -e "s/%20/ /g")
                    echo -n "                  tag directories \"${tagdir}\" exists? ➜  "
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
                    while [ -f "${OUTPUTDIR}${tagdir}/${NewName} ($destfilecount).pdf" ]
                        do
                            destfilecount=$( expr $destfilecount + 1 )
                            echo "                  continue counting … ($destfilecount)"
                        done
                    output="${OUTPUTDIR}${tagdir}/${NewName} ($destfilecount).pdf"
                    echo "                  File name already exists! Add counter ($destfilecount)"
                    fi

                    echo "                  target:   ./${tagdir}/$(basename "${output}")"
                    cp -l "${outputtmp}" "${output}"
                    i=$((i + 1))
                done
                echo "              ➜ delete temp. target file"
                rm "${outputtmp}"
            else
                destfilecount=$(ls -t "${OUTPUTDIR}" | grep -o "^${NewName}.*" | wc -l)
                if [ $destfilecount -eq 0 ]; then
                    output="${OUTPUTDIR}${NewName}.pdf"
                else
                    while [ -f "${OUTPUTDIR}${NewName} ($destfilecount).pdf" ]
                        do
                            destfilecount=$( expr $destfilecount + 1 )
                            echo "                  continue counting … ($destfilecount)"
                        done
                    output="${OUTPUTDIR}${NewName} ($destfilecount).pdf"
                    echo "                  File name already exists! Add counter ($destfilecount)"
                fi
                echo "                  target file: $(basename "${output}")"
                mv "${outputtmp}" "${output}"
            fi
        fi
        }
        rename

    # Seiten zählen
        pagecount_latest=$(./bin/pdfinfo "${input}" 2>/dev/null | grep "Pages\:" | awk '{print $2}')
        
    # Quelldatei löschen / sichern (berücksichtigt gleichnamige vorhandene Dateien): ${filename%.*}
        if [ $backup = true ]; then
            sourcefilecount=$(ls -t "${BACKUPDIR}" | grep -o "^${filename%.*}.*" | wc -l)
            if [ $sourcefilecount -eq 0 ]; then
                mv "$input" "${BACKUPDIR}${filename}"
                echo "              ➜ move source file to: ${BACKUPDIR}${filename}"
            else
                while [ -f "${BACKUPDIR}${filename%.*} ($sourcefilecount).pdf" ]
                    do
                        sourcefilecount=$( expr $sourcefilecount + 1 )
                        echo "                  continue counting … ($sourcefilecount)"
                    done
                mv "$input" "${BACKUPDIR}${filename%.*} ($sourcefilecount).pdf"
                echo "              ➜ move source file to: ${BACKUPDIR}${filename%.*} ($sourcefilecount).pdf"
            fi
        else
            rm "$input"
            echo "              ➜ delete source file"
        fi

# hier muss die automatische Spracheinstellung mit eingebaut werden:
    # Benachrichtigung:
        if [ $dsmtextnotify = "on" ] ; then
            sleep 1
            synodsmnotify $MessageTo "synOCR" "Datei [$(basename "${output}")] ist fertig"
            sleep 1
        fi
        if [ $dsmbeepnotify = "on" ] ; then
            sleep 1
            echo 2 > /dev/ttyS1 #short beep
            sleep 1
        fi
        if [ ! -z $PBTOKEN ] ; then
            PB_LOG=`curl $cURLloglevel --header "Access-Token:${PBTOKEN}" https://api.pushbullet.com/v2/pushes -d type=note -d title="synOCR" -d body="Datei [$(basename "${output}")] ist fertig."`
            if [ $loglevel = "2" ] ; then
                echo "                  PushBullet-LOG:"
                echo "$PB_LOG" | sed -e "s/^/               /g"
            elif echo "$PB_LOG" | grep -q "error"; then # für Loglevel 1 nur Errorausgabe
                echo -n "                  PushBullet-Error: "
                echo "$PB_LOG" | jq -r '.error_code'
            fi
        else
            echo "                  INFO: (PushBullet-TOKEN not set)"
        fi

    # Dateizähler:
        synosetkeyvalue ./etc/counter pagecount $(expr $(get_key_value ./etc/counter pagecount) + $pagecount_latest)
        synosetkeyvalue ./etc/counter ocrcount $(expr $(get_key_value ./etc/counter ocrcount) + 1)
        echo "                  INFO: (runtime last file: $(sec_to_time $(expr $(date +%s)-${date_start}) ) (pagecount: $pagecount_latest) | all: $(get_key_value ./etc/counter ocrcount) PDFs / > $(get_key_value ./etc/counter pagecount) Pages processed up to now)"
    # temporäres Arbeitsverzeichnis löschen:
        rm -rf "$work_tmp"
    done
}

#        _______________________________________________________________________________
#       |                                                                               |
#       |                               AUFRUF DER FUNKTIONEN                           |
#       |_______________________________________________________________________________|

    echo -e; echo -e
    echo "    ----------------------------------"
    echo "    |    ==> Funktionsaufrufe <==    |"
    echo "    ----------------------------------"

    check_dockerimage
    mainrun
    purge_LOG

    echo -e; echo -e

exit 0
