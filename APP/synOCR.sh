#!/bin/sh
# /usr/syno/synoman/webman/3rdparty/synOCR/synOCR.sh

###################################################################################

    echo "    -----------------------------------"
    echo "    |    ==> Installationsinfo <==    |"
    echo "    -----------------------------------"
    echo -e
    
    CLIENTVERSION=$(get_key_value /var/packages/synOCR/INFO version)
    DevChannel="BETA"    # Release
    
# ---------------------------------------------------------------------------------
#           GRUNDKONFIGRUATIONEN / INDIVIDUELLE ANPASSUNGEN / Standardwerte       |
#           (alle Werte können durch setzen in der Konfiguration.txt              |
#           überschrieben werden)                                                 |
# ---------------------------------------------------------------------------------
    synocrdomain="geimist.eu"   # notwendig für Update, Konsitenzprüfung, DEV-Report und evtl. in Zukunft zum abfragen der API-Keys
    niceness=15                 # Die Priorität liegt im Bereich von -20 bis +19 (in ganzzahligen Schritten), wobei -20 die höchste Priorität (=meiste Rechenleistung) und 19 die niedrigste Priorität (=geringste Rechenleistung) ist. Die Standardpriorität ist 0. AUF NEGATIVE WERTE SOLLTE UNBEDINGT VERZICHTET WERDEN!
    LOGFILE="$1"                # aktuelles Logfile / wird von Startskript übergeben

# an welchen User/Gruppe soll die DSM-Benachrichtigung gesendet werden :
# ---------------------------------------------------------------------
    synOCR_user=$(whoami); echo "synOCR-User:              $synOCR_user"
    if cat /etc/group | grep administrators | grep -q "$synOCR_user"; then
        isAdmin=yes
    else
        isAdmin=no
    fi
    MessageTo="@administrators"	# Administratoren (Standardeinstellung)
    #MessageTo="$synOTR_user"	# User, welche synOTR aufgerufen hat (funktioniert natürlich nicht bei root, da root kein DSM-GUI-LogIn hat und die Message ins leere läuft)

# Arbeitsverzeichnis auslesen und hineinwechseln:
# ---------------------------------------------------------------------
    OLDIFS=$IFS	                # ursprünglichen Fieldseparator sichern
    APPDIR=$(cd $(dirname $0);pwd)
    cd ${APPDIR}

# Konfigurationsdatei einbinden:
# ---------------------------------------------------------------------
    CONFIG=etc/Konfiguration.txt
    . ./$CONFIG

# Systeminformation / LIBRARY_PATH anpassen / PATH anpassen:
# --------------------------------------------------------------------- 
    echo "synOCR-Version:           $CLIENTVERSION"
    machinetyp=`uname --machine`; echo "Architektur:              $machinetyp"
    dsmbuild=`uname -v | awk '{print $1}' | sed "s/#//g"`; echo "DSM-Build:                $dsmbuild"
    read MAC </sys/class/net/eth0/address
    sysID=`echo $MAC | cksum | awk '{print $1}'`; sysID="$(printf '%010d' $sysID)" #echo "Prüfsumme der MAC-Adresse als Hardware-ID: $sysID" 10-stellig
    device=`uname -a | awk -F_ '{print $NF}' | sed "s/+/plus/g" `; echo "Gerät:                    $device ($sysID)"	    #  | sed "s/ds//g"
    echo "verwendetes Image:        $dockercontainer"
    echo "verwendete Parameter:     $ocropt"
    echo "ersetze Suchpräfix:       $delSearchPraefix"
    echo "Umbenennungssyntax:       $NameSyntax"
    
# Konfiguration für LogLevel:
# ---------------------------------------------------------------------
    # LOGlevel:     0 => Logging inaktiv / 1 => normal / 2 => erweitert
    if [ $loglevel = "1" ] ; then
        echo "Loglevel:                 normal"
        cURLloglevel="-s"
        wgetloglevel="-q"
    elif [ $loglevel = "2" ] ; then
        echo "Loglevel:                 erweitert"
        cURLloglevel="-v"
        wgetloglevel="-v"
    fi


# Verzeichnisse prüfen bzw. anlegen und anpassen:
# ---------------------------------------------------------------------
    echo "Anwendungsverzeichnis:    ${APPDIR}"
    
    # Variablenkorrektur für ältere Konfiguration.txt und Slash anpassen:
    INPUTDIR="${INPUTDIR%/}/"
    if [ -d "$INPUTDIR" ] ; then
        echo "Quellverzeichnis:         $INPUTDIR"
    else
        echo "Quellverzeichnis ungültig oder nicht gesetzt!"
        exit 1
    fi
    
    OUTPUTDIR="${OUTPUTDIR%/}/"
    echo "Quellverzeichnis:         ${OUTPUTDIR}"
    
    BACKUPDIR="${BACKUPDIR%/}/"
    if [ -d "$BACKUPDIR" ] && echo "$BACKUPDIR" | grep -q "/volume" ; then
        echo "BackUp-Verzeichnis:       $BACKUPDIR"
        backup=true
    elif echo "$BACKUPDIR" | grep -q "/volume" ; then
        mkdir -p "$BACKUPDIR"
        echo "BackUp-Verzeichnis wurde erstellt [$BACKUPDIR]"
        backup=true
    else
        echo "Dateien werden sofort gelöscht! / Kein gültiges Verzeichnis [$BACKUPDIR]"
        backup=false
    fi

    LOGDIR="${LOGDIR%/}/"

#################################################################################################
#        _______________________________________________________________________________        #
#       |                                                                               |       #
#       |                           BEGINN DER FUNKTIONEN                               |       #
#       |_______________________________________________________________________________|       #
#                                                                                               #
#################################################################################################


parseRegex () 
{
# In dieser Funktion wird der mit einem regulären Ausdruck beschriebene Teilstring zurückgegeben
# Aufruf: parseRegex "string" "regex"
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
# Diese Funktion bereinigt ältere Logfiles                                               #
#########################################################################################

if [ -z $LOGmax ]; then
    echo "purge_LOG deaktiviert"
    return
fi

# leere Logs löschen:
# (sollte durch Abfrage in Startskript nicht mehr benötigt werden)
for i in `ls -tr "${LOGDIR}" | egrep -o '^synOCR.*.log$' `                   # Auflistung aller LOG-Dateien
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

# überzählige logs löschen:
count2del=$( expr $(ls -t "${LOGDIR}" | egrep -o '^synOCR.*.log$' | wc -l) - $LOGmax )
if [ ${count2del} -ge 0 ]; then
    for i in `ls -tr "${LOGDIR}" | egrep -o '^synOCR.*.log$' | head -n${count2del} `
        do
        #    if [ $endgueltigloeschen = "on" ] ; then
                rm "${LOGDIR}$i"
        #    else
        #        mv "${LOGDIR}$i" "$OTRkeydeldir"
        #    fi
        done
fi
}


mainrun() 
{
#########################################################################################
# Diese Funktion übergibt die Dateien an docker                                         #
#########################################################################################
    
IFS=$'\012'	 # entspricht einem $'\n' Newline
for input in $(find "${INPUTDIR}" -maxdepth 1 -iname "${SearchPraefix}*.pdf" -type f) #  -mmin +"$timediff" -o -name "${SearchPraefix}*.PDF" 
    do
        IFS=$OLDIFS
    # temporäres Arbeitsverzeichnis erstellen
        work_tmp=$(mktemp -d -t tmp.XXXXXXXXXX)
        trap 'rm -rf "$work_tmp"; exit' EXIT
        
        echo -e
        filename=$(basename "$input")
        title=${filename%.*}
        echo -n "    VERARBEITE:       --> $filename"
        echo " ($(date))"
        date_start=$(date +%s)

        if [ $delSearchPraefix = "yes" ] && [ ! -z "${SearchPraefix}" ]; then
            title=$( echo "${title}" | sed s/${SearchPraefix}//I )
        fi
    
    # Zieldateiname erstellen (berücksichtigt gleichnamige vorhandene Dateien):
        destfilecount=$(ls -t "${OUTPUTDIR}" | grep -o "^${title}.*" | wc -l)
        if [ $destfilecount -eq 0 ]; then
            output="${OUTPUTDIR}${title}.pdf"
        else
            while [ -f "${OUTPUTDIR}${title} ($destfilecount).pdf" ]
                do
                    destfilecount=$( expr $destfilecount + 1 )
                    echo "                          zähle weiter … ($destfilecount)"
                done
            output="${OUTPUTDIR}${title} ($destfilecount).pdf"
            echo "                          Dateiname ist bereits vorhanden! Ergänze Zähler ($destfilecount)"
        fi
        
        outputtmp="${work_tmp}/${title}.pdf"
        echo "                          temp. Zieldatei: ${outputtmp}"

    # OCRmyPDF:
        OCRmyPDF()
        {
            # https://www.synology-forum.de/showthread.html?99516-Container-Logging-in-Verbindung-mit-stdin-und-stdout
            cat "$input" | /usr/local/bin/docker run --name synOCR --rm -i -log-driver=none -a stdin -a stdout -a stderr $dockercontainer $ocropt - - | cat - > "$outputtmp"
        }
        sleep 1
        dockerlog=$(OCRmyPDF 2>&1)
        sleep 1
        
        # Example:
        #   WARNING -    2: [tesseract] unsure about page orientation
        #   WARNING -    2: [tesseract] lots of diacritics - possibly poor OCR

        echo -e
        echo "                      --> OCRmyPDF-LOG:"
        echo "$dockerlog" | sed -e "s/^/                       /g"
        echo "                      <-- OCRmyPDF-LOG-END"
        echo -e

    # prüfen, ob Zieldatei gültig (nicht leer) ist, sonst weiter / defekte Quelldateien werden inkl. LOG nach ERROR verschoben:
        if [ $(stat -c %s "${outputtmp}") -eq 0 ] || [ ! -f "${outputtmp}" ];then
            echo "                          L=> fehlgeschlagen! (Zieldatei ist leer oder nicht vorhanden)"
            rm "${outputtmp}"
            if echo "$dockerlog" | grep -q ERROR ;then
                if [ ! -d "${INPUTDIR}ERRORFILES" ] ; then
                    echo "                                                  ERROR-Verzeichnis [${INPUTDIR}ERRORFILES] wird erstellt!"
                    mkdir "${INPUTDIR}ERRORFILES"
                fi

                destfilecount=$(ls -t "${INPUTDIR}ERRORFILES" | grep -o "^${filename%.*}.*" | wc -l)
                if [ $destfilecount -eq 0 ]; then
                    output="${INPUTDIR}ERRORFILES/${filename%.*}.pdf"
                else
                    while [ -f "${INPUTDIR}ERRORFILES/${filename%.*} ($destfilecount).pdf" ]
                        do
                            destfilecount=$( expr $destfilecount + 1 )
                            echo "                                                  zähle weiter … ($destfilecount)"
                        done
                    output="${INPUTDIR}ERRORFILES/${filename%.*} ($destfilecount).pdf"
                    echo "                                                  Dateiname bereits vorhanden! Ergänze Zähler ($destfilecount)"
                fi
                mv "$input" "$output"
                if [ "$loglevel" != 0 ] ;then
                    cp "$LOGFILE" "${output}.log"
                fi
                echo "                                              L=> verschiebe nach ERRORFILES"
            fi
            rm -rf "$work_tmp"
            continue
        else
            echo "                          Zieldatei (OK): ${output}"
        fi
        
    # verschiebe temporäre Datei in Zielordner:
        mv "${outputtmp}" "${output}"
        
    # Dateirechte-Log:
        if [ $loglevel = "2" ] ; then
            echo "                      --> Dateirechte Quelldatei:"
            echo -n "                          "
            ls -l "$input"
            echo "                      --> Dateirechte Zieldatei:"
            echo -n "                          "
            ls -l "$output"
        fi

    # Datei-Attripute übertragen:
        # Probleme bei ACL-Berechtigungen …
        # echo "                      --> übertrage die Dateirechte und -besitzer"
        # cp --attributes-only -p "$input" "$output"

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
            if [ -z "$taglist" ]; then
                return
            fi
            renameTag=""
            renameCat=""
            taglist2=$( echo "$taglist" | sed -e "s/ /%20/g" | sed -e "s/;/ /g" )	# Leerzeichen in tags codieren und Semikola zu Leerzeichen (für Array) konvertieren
            tagarray=( $taglist2 )   # Tags als Array definieren
            i=0
            maxID=${#tagarray[*]}
            echo "                      --> suche Tags und Datum:"
            echo "                          Tag-Anzahl:       $maxID"

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
                    echo -n "                          Suche nach Tag:   \"${searchtag}\" => "
                    if grep $grep_opt "${searchtag}" "$searchfile" ;then
                        echo "OK (Cat: \"${categorietag}\")"
                        renameTag="#$(echo "${searchtag}" | sed -e "s/ /%20/g") ${renameTag}"
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
                    echo -n "                          Suche nach Tag:   \"$(echo ${tagarray[$i]} | sed -e "s/%20/ /g")\" => "
                    if grep $grep_opt "$(echo ${tagarray[$i]} | sed -e "s/%20/ /g" | sed -e "s/^§//g")" "$searchfile" ;then
                        echo "OK"
                        renameTag="#${tagarray[$i]} ${renameTag}"
                    else
                        echo "-"
                    fi
                fi
                i=$((i + 1))
            done
            renameTag=${renameTag% }
            renameCat=${renameCat% }
            echo "                          renameTag lautet: \"$(echo "$renameTag" | sed -e "s/%20/ /g")\""
            }
            tagsearch

        # suche nach Datum:
            dateIsFound=no
            # suche Format: dd[./-]mm[./-]yy(yy)
            founddate=$( parseRegex "$content" "([1-9]|[1-2][0-9]|3[0-1])[\./-][0-1]?[0-9][\./-](19[0-9]{2}|20[0-9]{2}|[0-9]{2})" | head -n1 )
            if [ ! -z $founddate ]; then
                echo -n "                          prüfe Datum: $founddate"
                date_dd=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $1}' | grep -o '[0-9]*') ))) # https://ubuntuforums.org/showthread.php?t=1402291&s=ea6c4468658e97610c038c97b4796b78&p=8805742#post8805742
                date_mm=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $2}') )))
                date_yy=$(echo $founddate | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')    
                if [ $(echo $date_yy | wc -c) -eq 3 ] ; then
                    date_yy="20${date_yy}"
                fi
                date "+%d/%m/%Y" -d ${date_mm}/${date_dd}/${date_yy} > /dev/null  2>&1    # valid date? https://stackoverflow.com/questions/18731346/validate-date-format-in-a-shell-script
                if [ $? -eq 0 ]; then
                    echo " --> gültig"
                    echo "                          Tag:  ${date_dd}"
                    echo "                          Monat:${date_mm}"
                    echo "                          Jahr: ${date_yy}"
                    dateIsFound=yes
                else
                    echo " --> ungültiges Format"
                fi
                founddate=""
            fi

            # suche Format: yy(yy)[./-]mm[./-]dd
            if [ $dateIsFound = no ]; then
                founddate=$( parseRegex "$content" "(19[0-9]{2}|20[0-9]{2}|[0-9]{2})[\./-][0-1]?[0-9][\./-](0[1-9]|[1-2][0-9]|3[0-1])" | head -n1 )
                if [ ! -z $founddate ]; then
                    echo -n "                          prüfe Datum: $founddate"
                    date_dd=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*') )))
                    date_mm=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $2}') )))
                    date_yy=$(echo $founddate | awk -F'[./-]' '{print $1}' | grep -o '[0-9]*')    
                    if [ $(echo $date_yy | wc -c) -eq 3 ] ; then
                        date_yy="20${date_yy}"
                    fi
                    date "+%d/%m/%Y" -d ${date_mm}/${date_dd}/${date_yy} > /dev/null  2>&1    # valid date? https://stackoverflow.com/questions/18731346/validate-date-format-in-a-shell-script
                    if [ $? -eq 0 ]; then
                        echo " --> gültig"
                        echo "                          Tag:  ${date_dd}"
                        echo "                          Monat:${date_mm}"
                        echo "                          Jahr: ${date_yy}"
                        dateIsFound=yes
                    else
                        echo " --> ungültiges Format"
                    fi
                    founddate=""
                fi
            fi

            # suche Format: mm[./-]dd[./-]yy(yy) amerikanisch
            if [ $dateIsFound = no ]; then
                founddate=$( parseRegex "$content" "[0-1]?[0-9][\./-](0[1-9]|[1-2][0-9]|3[0-1])[\./-](19[0-9]{2}|20[0-9]{2}|[0-9]{2})" | head -n1 )
                if [ ! -z $founddate ]; then
                    echo -n "                          prüfe Datum: $founddate"
                    date_dd=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $2}' | grep -o '[0-9]*') )))
                    date_mm=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $1}') )))

# hier stimmt etwas noch nicht mit der RegEx fürs Datum:
#      prüfe Datum: [72.07.41 --> ungültiges Format
#      prüfe Datum: [72.07.41./synOCR.sh: line 386: 10#[72 : syntax error: invalid arithmetic operator (error token is "[72 ") --> ungültiges Format

                    date_yy=$(echo $founddate | awk -F'[./-]' '{print $3}' | grep -o '[0-9]*')    
                    if [ $(echo $date_yy | wc -c) -eq 3 ] ; then
                        date_yy="20${date_yy}"
                    fi
                    date "+%d/%m/%Y" -d ${date_mm}/${date_dd}/${date_yy} > /dev/null  2>&1    # valid date? https://stackoverflow.com/questions/18731346/validate-date-format-in-a-shell-script
                    if [ $? -eq 0 ]; then
                        echo " --> gültig"
                        echo "                          Tag:  ${date_dd}"
                        echo "                          Monat:${date_mm}"
                        echo "                          Jahr: ${date_yy}"
                        dateIsFound=yes
                    else
                        echo " --> ungültiges Format"
                    fi
                    founddate=""
                fi
            fi
            
            if [ $dateIsFound = no ]; then
                echo "                          Datum nicht gefunden - verwende Dateidatum:"
                date_dd=$(ls -l --time-style=full-iso "$input" | awk '{print $6}' | awk -F- '{print $3}')
                date_mm=$(ls -l --time-style=full-iso "$input" | awk '{print $6}' | awk -F- '{print $2}')
                date_yy=$(ls -l --time-style=full-iso "$input" | awk '{print $6}' | awk -F- '{print $1}') 
                echo "                          Tag:  ${date_dd}"
                echo "                          Monat:${date_mm}"
                echo "                          Jahr: ${date_yy}"
            fi
        }
        findDate
        
    # Dateinamen zusammenstellen und umbenennen:
        rename() 
        {
        # Zieldatei umbenennen:
        outputtmp=${output}
        if [ ! -z "$NameSyntax" ]; then
            echo -n "                          wende Umbenennungssyntax an --> "
            title=$( echo "${title}" | sed "s/\&/%26/g" )    # "&" im Titel würde sonst durch "§tit" ersetzt
            NewName="$NameSyntax"
            NewName=$( echo "$NewName" | sed "s/§d/${date_dd}/g" )
            NewName=$( echo "$NewName" | sed "s/§m/${date_mm}/g" )
            NewName=$( echo "$NewName" | sed "s/§y/${date_yy}/g" )
            NewName=$( echo "$NewName" | sed "s/§tag/${renameTag}/g" )
            NewName=$( echo "$NewName" | sed "s/§tit/${title}/g" | sed "s/%26/\&/g" )
            NewName=$( echo "$NewName" | sed "s/%20/ /g" )
            echo "$NewName"

            if [ ! -z "$renameCat" ] && [ $moveTaggedFiles = useCatDir ] ; then
                echo "                      --> verschiebe in Kategorieverzeichnisse"
                renameCat=$( echo $renameCat | sed -e "s/#//g" )
                tagarray=( $renameCat )   # Tags als Array definieren
                i=0
                DestFolderList=""   # temp. Liste der verwendeten Zielordner um Dateiduplikate (unterschiedliche Tags, aber eine Kategorie) zu vermeiden
                maxID=${#tagarray[*]}
            #    for a in ${tagarray[@]}; do
            #        echo $a
            #    done
                while (( i < maxID )); do
                    tagdir=$(echo ${tagarray[$i]} | sed -e "s/%20/ /g")
                    echo -n "                          Tag-Ordner \"${tagdir}\" vorhanden? => "
                    if [ -d "${OUTPUTDIR}${tagdir}" ] ;then
                        echo "OK"
                    else
                        mkdir "${OUTPUTDIR}${tagdir}"
                        echo "erstellt"
                    fi

                    destfilecount=$(ls -t "${OUTPUTDIR}${tagdir}" | grep -o "^${NewName}.*" | wc -l)
                    if [ $destfilecount -eq 0 ]; then
                        output="${OUTPUTDIR}${tagdir}/${NewName}.pdf"
                    else
                        while [ -f "${OUTPUTDIR}${tagdir}/${NewName} ($destfilecount).pdf" ]
                            do
                                destfilecount=$( expr $destfilecount + 1 )
                                echo "                          zähle weiter … ($destfilecount)"
                            done
                        output="${OUTPUTDIR}${tagdir}/${NewName} ($destfilecount).pdf"
                        echo "                          Dateiname bereits vorhanden! Ergänze Zähler ($destfilecount)"
                    fi
                    
                    echo "                          Ziel:   ./${tagdir}/$(basename "${output}")"
                    # prüfen, ob selbe Datei bereits einmal in diese Kategorie einsortiert wurde (unterschiedliche Tags, aber gleich Kategorie)
                    if $(echo -e "${DestFolderList}" | grep -q "^${tagarray[$i]}$") ; then
                        echo "                          selbe Datei ist bereits in Kategorie (${tagarray[$i]}) kopiert worden und wird übersprungen!"
                    else
                        cp -l "${outputtmp}" "${output}"
                    fi
                    DestFolderList="${tagarray[$i]}\n${DestFolderList}"
                    i=$((i + 1))
                done
#                echo "                      --> lösche temp. Zieldatei"
#                rm "${outputtmp}"
            elif [ ! -z "$renameTag" ] && [ $moveTaggedFiles = useTagDir ] ; then
                echo "                      --> verschiebe in Tagverzeichnisse"
                renameTag=$( echo $renameTag | sed -e "s/#//g" )
                tagarray=( $renameTag )   # Tags als Array definieren
                i=0
                maxID=${#tagarray[*]}
            #    for a in ${tagarray[@]}; do
            #        echo $a
            #    done
                while (( i < maxID )); do
                    tagdir=$(echo ${tagarray[$i]} | sed -e "s/%20/ /g")
                    echo -n "                          Tag-Ordner \"${tagdir}\" vorhanden? => "
                    if [ -d "${OUTPUTDIR}${tagdir}" ] ;then
                        echo "OK"
                    else
                        mkdir "${OUTPUTDIR}${tagdir}"
                        echo "erstellt"
                    fi

                    destfilecount=$(ls -t "${OUTPUTDIR}${tagdir}" | grep -o "^${NewName}.*" | wc -l)
                    if [ $destfilecount -eq 0 ]; then
                        output="${OUTPUTDIR}${tagdir}/${NewName}.pdf"
                    else
                        while [ -f "${OUTPUTDIR}${tagdir}/${NewName} ($destfilecount).pdf" ]
                            do
                                destfilecount=$( expr $destfilecount + 1 )
                                echo "                          zähle weiter … ($destfilecount)"
                            done
                        output="${OUTPUTDIR}${tagdir}/${NewName} ($destfilecount).pdf"
                        echo "                          Dateiname bereits vorhanden! Ergänze Zähler ($destfilecount)"
                    fi

                    echo "                          Ziel:   ./${tagdir}/$(basename "${output}")"
                    cp -l "${outputtmp}" "${output}"
                    i=$((i + 1))
                done
#                echo "                      --> lösche temp. Zieldatei"
#                rm "${outputtmp}"
            else
                destfilecount=$(ls -t "${OUTPUTDIR}" | grep -o "^${NewName}.*" | wc -l)
                if [ $destfilecount -eq 0 ]; then
                    output="${OUTPUTDIR}${NewName}.pdf"
                else
                    while [ -f "${OUTPUTDIR}${NewName} ($destfilecount).pdf" ]
                        do
                            destfilecount=$( expr $destfilecount + 1 )
                            echo "                          zähle weiter … ($destfilecount)"
                        done
                    output="${OUTPUTDIR}${NewName} ($destfilecount).pdf"
                    echo "                          Dateiname bereits vorhanden! Ergänze Zähler ($destfilecount)"
                fi
                echo "                          Zieldatei: $(basename "${output}")"
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
                echo "                      --> verschiebe Quelldatei nach: ${BACKUPDIR}${filename}"
            else
                while [ -f "${BACKUPDIR}${filename%.*} ($sourcefilecount).pdf" ]
                    do
                        sourcefilecount=$( expr $sourcefilecount + 1 )
                        echo "                          zähle weiter … ($sourcefilecount)"
                    done
                mv "$input" "${BACKUPDIR}${filename%.*} ($sourcefilecount).pdf"
                echo "                      --> verschiebe Quelldatei nach: ${BACKUPDIR}${filename%.*} ($sourcefilecount).pdf"
            fi
        else
            rm "$input"
            echo "                      --> lösche Quelldatei"
        fi

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
                echo "                          PushBullet-LOG:"
                echo "$PB_LOG" | sed -e "s/^/                       /g"
            elif echo "$PB_LOG" | grep -q "error"; then # für Loglevel 1 nur Errorausgabe
                echo -n "                          PushBullet-Error: "
                echo "$PB_LOG" | jq -r '.error_code'
            fi
        else
            echo "                          INFO: (PushBullet-TOKEN nicht gesetzt)"
        fi

    # Dateizähler:
        synosetkeyvalue ./etc/counter pagecount $(expr $(get_key_value ./etc/counter pagecount) + $pagecount_latest)
        synosetkeyvalue ./etc/counter ocrcount $(expr $(get_key_value ./etc/counter ocrcount) + 1)
        echo "                          INFO: (Laufzeit letzte Datei: $(( $(date +%s) - $date_start )) Sekunden (Seitenanzahl: $pagecount_latest) | gesamt: $(get_key_value ./etc/counter ocrcount) PDFs / > $(get_key_value ./etc/counter pagecount) Seiten bisher verarbeitet)"

    # temporäres Arbeitsverzeichnis löschen:
        rm -rf "$work_tmp"
    done
}

#        _______________________________________________________________________________
#       |                                                                               |
#       |                           AUFRUF DER FUNKTIONEN                               |
#       |_______________________________________________________________________________|

    echo -e; echo -e
    echo "    ----------------------------------"
    echo "    |    ==> Funktionsaufrufe <==    |"
    echo "    ----------------------------------"

    mainrun
    purge_LOG

    echo -e; echo -e

exit 0
