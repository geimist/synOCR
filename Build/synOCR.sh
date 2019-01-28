#!/bin/sh
# /usr/syno/synoman/webman/3rdparty/synOCR/synOCR.sh

###################################################################################

    echo "    -----------------------------------"
    echo "    |    ==> Installationsinfo <==    |"
    echo "    -----------------------------------"
    echo -e
    
    CLIENTVERSION=`get_key_value /var/packages/synOCR/INFO version`
    DevChannel="BETA"    # Release
    
# ---------------------------------------------------------------------------------
#           GRUNDKONFIGRUATIONEN / INDIVIDUELLE ANPASSUNGEN	/ Standardwerte	      |
#           (alle Werte können durch setzen in der Konfiguration.txt              |
#           überschrieben werden)                                                 |
# ---------------------------------------------------------------------------------
    synocrdomain="geimist.eu"   # notwendig für Update, Konsitenzprüfung, DEV-Report und evtl. in Zukunft zum abfragen der API-Keys
    niceness=15                 # Die Priorität liegt im Bereich von -20 bis +19 (in ganzzahligen Schritten), wobei -20 die höchste Priorität (=meiste Rechenleistung) und 19 die niedrigste Priorität (=geringste Rechenleistung) ist. Die Standardpriorität ist 0. AUF NEGATIVE WERTE SOLLTE UNBEDINGT VERZICHTET WERDEN!

# an welchen User/Gruppe soll die DSM-Benachrichtigung gesendet werden :
# ---------------------------------------------------------------------
    synOCR_user=`whoami`; echo "synOCR-User:              $synOCR_user"
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
    # für HD-Aufnahmen mit avcut mindestens 500 MB free:
#	echo -n "                          RAM installiert:    "; RAMmax=`free -m | grep 'Mem:' | awk '{print $2}'`; echo "$RAMmax MB"	    # verbauter RAM
#	echo -n "                          RAM verwendet:      "; RAMused=`free -m | grep 'Mem:' | awk '{print $3}'`;	echo "$RAMused MB"  # genutzter RAM
#	echo -n "                          RAM verfügbar:      "; RAMfree=$(( $RAMmax - $RAMused )); 	echo "$RAMfree MB"
    echo "verwendetes Image:        $dockercontainer"
    echo "verwendete Parameter:     $ocropt"
    echo "ersetze Suchpräfix:       $delSearchPraefix"
    
# Konfiguration für LogLevel:
# ---------------------------------------------------------------------
    # LOGlevel:		0 => Logging inaktiv / 1 => normal / 2 => erweitert
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
    	echo -e
    	filename=`basename "$input"`
    	title=${filename%.*}
    	echo -n "    VERARBEITE:       --> $filename"
    	echo " ($(date))"
    	date_start=$(date +%s)

    # Zieldateiname erstellen (berücksichtigt gleichnamige vorhandene Dateien):
        if [ $delSearchPraefix = "yes" ] ; then
            title=$( echo ${title} | sed s/${SearchPraefix}//I )
        fi

    	destfilecount=$(ls -t "${OUTPUTDIR}" | egrep -o "${title}.*" | wc -l)
    	if [ $destfilecount -eq 0 ]; then
    	    output="${OUTPUTDIR}${title}.pdf"
    	else
    	    count=$( expr $destfilecount + 1 )
    	    output="${OUTPUTDIR}${title} ($count).pdf"
    	fi

# echo Zieldatei noch anpassen (später mit Tags und Date)
        echo "                          (temp. Zieldatei: ${output})"

    # OCRmyPDF:
        OCRmyPDF()
        {
            # https://www.synology-forum.de/showthread.html?99516-Container-Logging-in-Verbindung-mit-stdin-und-stdout
            cat "$input" | /usr/local/bin/docker run --name synOCR --rm -i -log-driver=none -a stdin -a stdout -a stderr $dockercontainer $ocropt - - | cat - > "$output"
        }
        sleep 1
        dockerlog=$(OCRmyPDF 2>&1)
        sleep 1

        echo -e
        echo "                      --> OCRmyPDF-LOG:"
        echo "$dockerlog" | sed -e "s/^/                       /g"
        echo "                      <-- OCRmyPDF-LOG-END"
        echo -e

    # prüfen, ob Zieldatei gültig (nicht leer) ist, sonst weiter:
        if [ $(stat -c %s "$output") -eq 0 ] || [ ! -f "$output" ];then
            echo "                          L=> fehlgeschlagen! (Zieldatei ist leer oder nicht vorhanden)"
            rm "$output"
            continue
        fi

    # Datei-Attripute übertragen:
        echo "                      --> übertrage die Dateirechte und -besitzer"
        cp --attributes-only -p "$input" "$output"
        
    # suche nach Datum und Tags in Dokument:
        findDate()
        {
#        if [ ! umbenennung aktiv? ]; then
#            return
#        fi

        # Text exrahieren
            if [ -d "/tmp/synOCR" ]; then
            	rm -r /tmp/synOCR
            fi
            searchfile="/tmp/synOCR/synOCR.txt" # evtl. nur in Variable schreiben
            mkdir /tmp/synOCR
            /bin/pdftotext -layout -l 1 "$output" "$searchfile"
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
            taglist=$( echo "$taglist" | sed -e "s/ /%20/g" | sed -e "s/;/ /g" )
            tagarray=( $taglist )   # Tags als Array definieren
            i=0
            maxID=${#tagarray[*]}
            echo "                      --> suche Tags und Datum:"
            echo "                          Tag-Anzahl:       $maxID"

        #    for a in ${tagarray[@]}; do
        #        echo $a
        #    done
            while (( i < maxID )); do
                if echo "${tagarray[$i]}" | grep -q "=" ;then
                    searchtag=$(echo "${tagarray[$i]}" | awk -F'=' '{print $1}' | sed -e "s/%20/ /g")
                    categorietag=$(echo "${tagarray[$i]}" | awk -F'=' '{print $2}' | sed -e "s/%20/ /g")
                    echo -n "                          Suche nach Tag:   \"${searchtag}\" => "
                    if grep -qi "${searchtag}" "$searchfile" ;then
                        echo "OK (Cat: \"${categorietag}\")"
                        renameTag="#$(echo "${searchtag}" | sed -e "s/ /%20/g") ${renameTag}"
                        renameCat="$(echo "${categorietag}" | sed -e "s/ /%20/g") ${renameCat}"
                    else
                        echo "-"
                    fi
                else
                    echo -n "                          Suche nach Tag:   \"${tagarray[$i]}\" => "
                    if grep -qi "${tagarray[$i]}" "$searchfile" ;then
                        echo "OK"
                        renameTag="#$( echo ${tagarray[$i]} | sed -e "s/ /%20/g") ${renameTag}"
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
            if [ -n $founddate ]; then
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
                if [ -n $founddate ]; then
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
                if [ -n $founddate ]; then
                    echo -n "                          prüfe Datum: $founddate"
                    date_dd=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $2}' | grep -o '[0-9]*') )))
                    date_mm=$(printf '%02d' $(( 10#$(echo $founddate | awk -F'[./-]' '{print $1}') )))
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
            NewName="$NameSyntax"
            NewName=`echo $NewName | sed "s/§d/${date_dd}/g"`
            NewName=`echo $NewName | sed "s/§m/${date_mm}/g"`
            NewName=`echo $NewName | sed "s/§y/${date_yy}/g"`
            NewName=`echo $NewName | sed "s/§tag/${renameTag}/g"`
            NewName=`echo $NewName | sed "s/§tit/${title}/g"`
            NewName=`echo $NewName | sed "s/%20/ /g"`

            if [ ! -z "$renameTag" ] && [ $moveTaggedFiles = yes ]; then
                echo "                      --> verschiebe in Tagverzeichnisse"
                if [ ! -z "$renameCat" ]; then
                    renameTag="$renameCat"  # verwende Categorie-Tags für Ordner
                fi
                renameTag=$( echo $renameTag | sed -e "s/#//g" )
                tagarray=( $renameTag )   # Tags als Array definieren
                i=0
                maxID=${#tagarray[*]}
            #    for a in ${tagarray[@]}; do
            #        echo $a
            #    done
            #    echo "                          benenne um und verschiebe Zieldatei"
            #    echo "                          von:    $(basename "${outputtmp}")"
                while (( i < maxID )); do
                    tagdir=$(echo ${tagarray[$i]} | sed -e "s/%20/ /g")
                    echo -n "                          Tag-Ordner \"${tagdir}\" vorhanden? => "
                    if [ -d "${OUTPUTDIR}${tagdir}" ] ;then
                        echo "OK"
                    else
                        mkdir "${OUTPUTDIR}${tagdir}"
                        echo "erstellt"
                    fi
            		destfilecount=$(ls -t "${OUTPUTDIR}${tagdir}" | egrep -o "${NewName}.*" | wc -l)
            		if [ $destfilecount -eq 0 ]; then
            		    output="${OUTPUTDIR}${tagdir}/${NewName}.pdf"
            		else
            		    count=$( expr $destfilecount + 1 )
            		    output="${OUTPUTDIR}${tagdir}/${NewName} ($count).pdf"
            		fi
                    echo "                          Ziel:   ./${tagdir}/$(basename "${output}")"
                    cp -l "${outputtmp}" "${output}"
                    i=$((i + 1))
                done
                echo "                          lösche temp. Zieldatei"
                rm "${outputtmp}"
            else
        		destfilecount=$(ls -t "${OUTPUTDIR}" | egrep -o "${NewName}.*" | wc -l)
        		if [ $destfilecount -eq 0 ]; then
        		    output="${OUTPUTDIR}${NewName}.pdf"
        		else
        		    count=$( expr $destfilecount + 1 )
        		    output="${OUTPUTDIR}${NewName} ($count).pdf"
        		fi
                echo "                          Umbenennung ursprüngliche Zieldatei"
                echo "                          von:    $(basename "${outputtmp}")"
                echo "                          nach:   $(basename "${output}")"
                mv "${outputtmp}" "${output}"
            fi
        fi
        }
        rename

    # Quelldatei löschen / sichern (berücksichtigt gleichnamige vorhandene Dateien): ${filename%.*}
        if [ $backup = true ]; then
    		sourcefilecount=$(ls -t "${BACKUPDIR}" | egrep -o "${filename%.*}.*" | wc -l)
    		if [ $sourcefilecount -eq 0 ]; then
    		    mv "$input" "${BACKUPDIR}${filename}"
    		    echo "                      --> verschiebe Quelldatei nach: ${BACKUPDIR}${filename}"
    		else
    		    count=$( expr $sourcefilecount + 1 )
    		    mv "$input" "${BACKUPDIR}${filename%.*} ($count).pdf"
    		    echo "                      --> verschiebe Quelldatei nach: ${BACKUPDIR}${filename%.*} ($count).pdf"
    		fi
    	else
    	    rm "$input"
    		echo "                      --> lösche Quelldatei"
        fi

    # Benachrichtigung:
        if [ $dsmtextnotify = "on" ] ; then
            sleep 1
            synodsmnotify $MessageTo "synOCR" "$(basename "${output}") ist fertig"
            sleep 1
        fi
        if [ $dsmbeepnotify = "on" ] ; then
            sleep 1
            echo 2 > /dev/ttyS1 #short beep
            sleep 1
        fi
        if [ ! -z $PBTOKEN ] ; then
            PB_LOG=`curl $cURLloglevel --header "Access-Token:${PBTOKEN}" https://api.pushbullet.com/v2/pushes -d type=note -d title="synOCR" -d body="PDF [$(basename "${output}")] ist fertig."`
            if [ $loglevel = "2" ] ; then
                echo "                          PushBullet-LOG:"
                echo "$PB_LOG" | sed -e "s/^/                       /g"
            elif echo "$PB_LOG" | grep -q "error"; then # für Loglevel 1 nur Errorausgabe
                echo -n "                          PushBullet-Error: "
                echo "$PB_LOG" | jq -r '.error_code'
            fi
        else
            echo "                          (INFO: PushBullet-TOKEN nicht gesetzt)"
        fi
    #    wget --timeout=30 --tries=2 -q -O - "http://${synocrdomain}/synOCR/synOCR_FILECOUNT" >/dev/null 2>&1

    # Dateizähler:
        if [ ! -f ./etc/counter ] ; then
            touch ./etc/counter
            echo "startcount=\"$(date +%Y)-$(date +%m)-$(date +%d)\"" >> ./etc/counter
            echo "ocrcount=\"0\"" >> ./etc/counter
            echo "                      --> counter-File wurde erstellt"
        fi
        synosetkeyvalue ./etc/counter ocrcount $(expr $(get_key_value ./etc/counter ocrcount) + 1)        
        echo "                          INFO: (Laufzeit letzt Datei: $(( $(date +%s) - $date_start )) Sekunden / $(get_key_value ./etc/counter ocrcount) PDFs bisher verarbeitet)"
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

