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
# 			GRUNDKONFIGRUATIONEN / INDIVIDUELLE ANPASSUNGEN	/ Standardwerte	      |	  
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
	if [ -d "$OUTPUTDIR" ] && echo "$BACKUPDIR" | grep -q "/volume" ; then
		echo "Zielverzeichnis:          $OUTPUTDIR"
	else
		mkdir -p "$OUTPUTDIR"		
		echo "Zielverzeichnis wurde erstellt [$OUTPUTDIR]"
	fi
	
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
        if [ $( cat "${LOGDIR}$i" | tail -n5 | head -n2 | wc -c ) -le 5 ] && cat "${LOGDIR}$i" | grep -q "synOCR ENDE" ; then
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


cal_scan() 
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
		destfilecount=$(ls -t "${OUTPUTDIR}" | egrep -o "${RenamePraefix}${title}.*" | wc -l)
		if [ $destfilecount -eq 0 ]; then
		    output="${OUTPUTDIR}${RenamePraefix}${filename}"
		else
		    count=$( expr $destfilecount + 1 )
		    output="${OUTPUTDIR}${RenamePraefix}${title} ($count).pdf"
		fi

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
        echo "OCRmyPDF-LOG:"
        echo "$dockerlog"
        echo -e

    # prüfen, ob Zieldatei gültig (nicht leer) ist, sonst weiter:
#        if [ $(ls -s "$output" | awk '{ print $1 }') -eq 0 ] || [ ! -f "$output" ];then 
        if [ $(stat -c %s "$output") -lt 10 ] || [ ! -f "$output" ];then
            echo "                          L=> fehlgeschlagen! (Zieldatei ist leer oder nicht vorhanden)"
            rm "$output"
            continue
        fi

    # Datei-Attripute übertragen:
        echo "                      --> übertrage die Dateirechte und -besitzer"
        cp --attributes-only -p "$input" "$output"
    
    # Quelldatei löschen / sichern (berücksichtigt gleichnamige vorhandene Dateien):
        if [ $backup = true ]; then
    		sourcefilecount=$(ls -t "${BACKUPDIR}" | egrep -o "${title}.*" | wc -l)
    		if [ $sourcefilecount -eq 0 ]; then
    		    mv "$input" "${BACKUPDIR}${filename}"
    		    echo "                      --> verschiebe Quelldatei nach: ${BACKUPDIR}${filename}"
    		else
    		    count=$( expr $sourcefilecount + 1 )
    		    mv "$input" "${BACKUPDIR}${title} ($count).pdf"
    		    echo "                      --> verschiebe Quelldatei nach: ${BACKUPDIR}${title} ($count).pdf"
    		fi
    	else
    	    rm "$input"
    		echo "                      --> lösche Quelldatei"
        fi

        findDate()
        {        
        return # under construction!
        
        # Text exrahieren und Datum suchen
        if [ -d "/tmp/synOCR" ]; then
        	rm -r /tmp/synOCR
        fi
        searchfile="/tmp/synOCR/synOCR.txt"
        mkdir /tmp/synOCR
        /bin/pdftotext -layout -l 1 "$output" "$searchfile"


        
        
        cp "$searchfile" "${OUTPUTDIR}${RenamePraefix}${title} ($count).txt"


return

        # /volume1/homes/admin/Drive/SCANNER/_OUTPUT/test.txt
        #            if (preg_match("/(0\d|1[012]|\d)[-.\/](31|30|[012]\d|\d)[-.\/](20[0-9][0-9])/", $line, $matches)) { // mm.dd.20yy




        cat "/volume1/homes/admin/Drive/SCANNER/_OUTPUT/test.txt" | egrep -o "[0-9]\{1,2\}[.\-]\?[0-9]\{1,2\}[.\-]\?20[0-9]\{1,2\}" | head -n1
        
        
        
        
        #[0-9]\{1,2\}[.\-]\?[0-9]\{1,2\}[.\-]\?20[0-9]\{1,2\}
        
        #        SuggestedMovieName=`cat "$tmp/$CUTLIST" | grep "SuggestedMovieName=" | sed "s/SuggestedMovieName\=//g;s/[0-9]\{2,4\}[.][0-9]\{1,2\}[.][0-9]\{1,2\}[ _][0-9]\{2\}[\-][0-9]\{2\}/Datum_Zeit/g;s/[0-9]\{2,4\}[.][0-9]\{1,2\}[.][0-9]\{1,2\}/Datum/g;s/_/ /g" | /usr/bin/tr -d "\r" ` #| awk -F. '{print $1}'` # Datum, Zeit im OTR-Format und Unterstriche werden entfernt
        #        usercomment=`cat "$tmp/$CUTLIST" | grep "usercomment=" | sed "s/usercomment\=//g;s/[0-9]\{2,4\}[.][0-9]\{1,2\}[.][0-9]\{1,2\}[ _][0-9]\{2\}[\-][0-9]\{2\}/Datum_Zeit/g;s/[0-9]\{2,4\}[.][0-9]\{1,2\}[.][0-9]\{1,2\}/Datum/g;s/_/ /g" | /usr/bin/tr -d "\r" ` #| awk -F. '{print $1}'`
        
        #        if echo "$SuggestedMovieName" | grep -q "[sST]\?[0-9]\{1,2\}[.\-xX]\?[eE]\?[0-9]\{1,2\}" ; then  # [[:space:]]  # S01E01 / S01.E01 / 01-01 / 01x01 / teilweise ohne führende Null
        #            #CL_serieninfo=$(parseRegex "$SuggestedMovieName" ".[sST]?[0-9]{1,2}[.\-xX]?[eE]?[0-9]{1,2}" | head -n1)    # head -n1: nur der erste Fund im String wird verwendet
        #            CL_serieninfo=$(echo "$SuggestedMovieName" | egrep -o "[sST]?[0-9]{1,2}[.\-xX]?[eE]?[0-9]{1,2}" | head -n1)
        #            CL_serieninfo_season=$(echo "$CL_serieninfo" | awk '{print toupper($0) }' | sed "s/S/ /g;s/T/ /g;s/E/ /g;s/X/ /g;s/-/ /g;s/\./ /g;s/  / /g" | awk '{print $1}')
        #            CL_serieninfo_episode=$(echo "$CL_serieninfo" | awk '{print toupper($0) }' | sed "s/S/ /g;s/T/ /g;s/E/ /g;s/X/ /g;s/-/ /g;s/\./ /g;s/  / /g" | awk '{print $2}')
        #            CL_serieninfofound=1
        #        elif echo "$usercomment" | grep -q "[sST]\?[0-9]\{1,2\}[.\-xX]\?[eE]\?[0-9]\{1,2\}" ; then 
        #            #CL_serieninfo=$(parseRegex "$usercomment" "[sST]?[0-9]{1,2}[.\-xX]?[eE]?[0-9]{1,2}" | head -n1)
        #            CL_serieninfo=$(echo "$usercomment" | egrep -o "[sST]?[0-9]{1,2}[.\-xX]?[eE]?[0-9]{1,2}" | head -n1)
        #            CL_serieninfo_season=$(echo "$CL_serieninfo" | awk '{print toupper($0) }' | sed "s/S/ /g;s/T/ /g;s/E/ /g;s/X/ /g;s/-/ /g;s/\./ /g;s/  / /g" | awk '{print $1}')
        #            CL_serieninfo_episode=$(echo "$CL_serieninfo" | awk '{print toupper($0) }' | sed "s/S/ /g;s/T/ /g;s/E/ /g;s/X/ /g;s/-/ /g;s/\./ /g;s/  / /g" | awk '{print $2}')
        #            CL_serieninfofound=1
        #        fi
        }

        findDate

    # Dateizähler:
        if [ ! -f ./etc/counter ] ; then
            touch ./etc/counter
            echo "startcount=\"$(date +%Y)-$(date +%m)-$(date +%d)\"" >> ./etc/counter
            echo "ocrcount=\"0\"" >> ./etc/counter
            echo "                      --> counter-File wurde erstellt"
        fi
        synosetkeyvalue ./etc/counter ocrcount $(expr $(get_key_value ./etc/counter ocrcount) + 1)
        echo "                      --> $(get_key_value ./etc/counter ocrcount) PDFs bisher verarbeitet"

    # Benachrichtigung:
        if [ $dsmtextnotify = "on" ] ; then
            sleep 1
            synodsmnotify $MessageTo "synOCR" "${filename} ist fertig"
            sleep 1
        fi
        if [ $dsmbeepnotify = "on" ] ; then
            sleep 1
            echo 2 > /dev/ttyS1 #short beep
            sleep 1
        fi
        if [ ! -z $PBTOKEN ] ; then
            PB_LOG=`curl $cURLloglevel --header "Access-Token:${PBTOKEN}" https://api.pushbullet.com/v2/pushes -d type=note -d title="synOCR" -d body="PDF [${filename}] ist fertig."`
            if [ $LOGlevel = "2" ] ; then
                echo "        PushBullet-LOG:"
                echo "$PB_LOG"
            elif echo "$PB_LOG" | grep -q "error"; then # für Loglevel 1 nur Errorausgabe
                echo -n "        PushBullet-Error: "
                echo "$PB_LOG" | jq -r '.error_code'
            fi
        else
            echo "                          (PushBullet-TOKEN nicht gesetzt)"
        fi
    #    wget --timeout=30 --tries=2 -q -O - "http://${synocrdomain}/synOCR/synOCR_FILECOUNT" >/dev/null 2>&1
        echo "                      --> (Laufzeit: $(( $(date +%s) - $date_start )) Sekunden)"
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
	
	cal_scan
	purge_LOG
	
	echo -e; echo -e
	
exit 0
