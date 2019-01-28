#!/bin/sh
# /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh
# wechselt in synOCR-Verzeichnis und startet synOCR mit bzw. ohne LOG (je nach Konfiguration)

# Arbeitsverzeichnis auslesen und hineinwechseln:
    APPDIR=$(cd $(dirname $0);pwd)
    cd ${APPDIR}

# Konfigurationsdatei einbinden:
    CONFIG=etc/Konfiguration.txt
    . ./$CONFIG

    LOGDIR="${LOGDIR%/}/"

    LOGFILE="${LOGDIR}synOCR_`date +%Y`-`date +%m`-`date +%d`_`date +%H`-`date +%M`.log"
    touch $LOGFILE

    synOCR_pid=`pidof synOCR.sh`

    if [ ! -z "$synOCR_pid" ] ; then
        echo '<p class="center"><span style="color: #BD0010;"><b>synOCR läuft bereits!</b><br>(Prozess-ID: '$synOCR_pid')</span></p>'
        echo '<br /><p class="center"><button name="page" value="status-kill-synocr" style="color: #BD0010;">(Beenden erzwingen?)</button></p><br />'
        exit
    else
        echo '<p class="title">synOCR wurde gestartet ...</p><br><br><br><br>
        <center><table id="system_msg" style="width: 40%;table-align: center;">
            <tr>   
                <th style="width: 20%;"><img class="imageStyle" alt="status_loading" src="images/status_loading.gif" style="float:left;"></th>   
                <th style="width: 80%;"><p class="center"><span style="color: #424242;font-weight:normal;">Bitte warten, bis die Dateien<br>fertig abgearbeitet wurden.</span></p></th>
            </tr>
        </table></center>'   
    fi
    
    if [ ! -d "${INPUTDIR}" ] || ! $(echo "${INPUTDIR}" | grep -q "/volume") ; then
        echo '
        <p class="center"><span style="color: #BD0010;"><b>! ! ! Quellverzeichnis in der Konfiguration prüfen ! ! !</b><br>Programmlauf wird beendet.<br></span></p>'
        exit 1
    fi
    
    if [ ! -d "$OUTPUTDIR" ] && echo "$OUTPUTDIR" | grep -q "/volume" ; then
        mkdir -p "$OUTPUTDIR"
        echo '
        <p class="center"><span style="color: #BD0010;"><b>Zielverzeichnis wurde erstellt.</b></span></p>'
    elif [ ! -d "$OUTPUTDIR" ] || ! $(echo "$BACKUPDIR" | grep -q "/volume") ; then
        echo '
        <p class="center"><span style="color: #BD0010;"><b>! ! ! Zielverzeichnis in der Konfiguration prüfen ! ! !</b><br>Programmlauf wird beendet.<br></span></p>'
        exit 1
    fi

    if [ $( ls -t "${INPUTDIR}" | egrep -oi "${SearchPraefix}.*.pdf$" | wc -l ) = 0 ] ;then
        echo '
        <p class="center"><span style="color: #228b22;"><b>es gibt nichts zu tun</b><br>Programmlauf wird beendet.<br></span></p>'
        exit 1
    fi


    if echo "$LOGDIR" | grep -q "/volume" && [ -d "$LOGDIR" ] && [ "$loglevel" != 0 ] ;then   
        ./synOCR.sh "$LOGFILE" >> $LOGFILE 2>&1
    elif echo "$LOGDIR" | grep -q "/volume" && [ ! -d "$LOGDIR" ] && [ "$loglevel" != 0 ] ;then  
        mkdir -p "$LOGDIR"
        ./synOCR.sh "$LOGFILE" >> $LOGFILE 2>&1
    else
    loglevel=0
        ./synOCR.sh
    fi

    if (( $? == 0 )); then
        echo "    -----------------------------------" >> $LOGFILE
        echo "    |       ==> synOCR ENDE <==       |" >> $LOGFILE
        echo "    -----------------------------------" >> $LOGFILE
    else
        echo "    -----------------------------------" >> $LOGFILE
        echo "    |   synOCR mit Fehlern beendet!   |" >> $LOGFILE
        echo "    -----------------------------------" >> $LOGFILE
    fi

exit 0
