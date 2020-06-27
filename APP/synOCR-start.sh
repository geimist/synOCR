#!/bin/sh
# /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh
# wechselt in synOCR-Verzeichnis und startet synOCR mit bzw. ohne LOG (je nach Konfiguration)

# wurde das Skript von der GUI aufgerufen (Aufruf mit Parameter "GUI")?
    callFrom=$1
    if [ -z $callFrom ] ; then
        callFrom=shell
    fi
    exit_status=0

# Arbeitsverzeichnis auslesen und hineinwechseln:
    APPDIR=$(cd $(dirname $0);pwd)
    cd ${APPDIR}

# läuft bereits eine Instanz von synOCR?
    synOCR_pid=$( /bin/pidof synOCR.sh )
    if [ ! -z "$synOCR_pid" ] ; then
        if [ $callFrom = GUI ] ; then
            echo '<p class="center"><span style="color: #BD0010;"><b>synOCR läuft bereits!</b><br>(Prozess-ID: '$synOCR_pid')</span></p>'
            echo '<br /><p class="center"><button name="page" value="main-kill-synocr" style="color: #BD0010;">(Beenden erzwingen?)</button></p><br />'
        else
            echo "synOCR läuft bereits! (Prozess-ID: ${synOCR_pid})"
        fi
        exit
    else
        if [ $callFrom = GUI ] ; then
            echo '<p class="title">synOCR wurde gestartet ...</p><br><br><br><br>
            <center><table id="system_msg" style="width: 40%;table-align: center;">
                <tr>
                    <th style="width: 20%;"><img class="imageStyle" alt="status_loading" src="images/status_loading.gif" style="float:left;"></th>
                    <th style="width: 80%;"><p class="center"><span style="color: #424242;font-weight:normal;">Bitte warten, bis die Dateien<br>fertig abgearbeitet wurden.</span></p></th>
                </tr>
            </table></center>'
        else
            echo "synOCR wurde gestartet ..."
            echo "Bitte warten, bis die Dateien fertig abgearbeitet wurden."
        fi
    fi

# Konfigurationsdatei einbinden:
    sSQL="SELECT profile_ID, INPUTDIR, OUTPUTDIR, LOGDIR, SearchPraefix, loglevel, profile FROM config WHERE active='1' "
    sqlerg=`sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL"`

    IFS=$'\012'
    for entry in $sqlerg; do
        IFS=$OLDIFS
        profile_ID=$(echo "$entry" | awk -F'\t' '{print $1}')
        INPUTDIR=$(echo "$entry" | awk -F'\t' '{print $2}')
        OUTPUTDIR=$(echo "$entry" | awk -F'\t' '{print $3}')
        LOGDIR=$(echo "$entry" | awk -F'\t' '{print $4}')
        SearchPraefix=$(echo "$entry" | awk -F'\t' '{print $5}')
        loglevel=$(echo "$entry" | awk -F'\t' '{print $6}')
        profile=$(echo "$entry" | awk -F'\t' '{print $7}')

    # ist das Quellverzeichnis vorhanden und ist der Pfad zulässig?
        if [ ! -d "${INPUTDIR}" ] || ! $(echo "${INPUTDIR}" | grep -q "/volume") ; then
            if [ $callFrom = GUI ] ; then
                echo '
                <p class="center"><span style="color: #BD0010;"><b>! ! ! Quellverzeichnis in der Konfiguration prüfen ! ! !</b><br>Programmlauf wird beendet.<br></span></p>'
            else
                echo "! ! ! Quellverzeichnis in der Konfiguration prüfen ! ! !"
                echo "Programmlauf wird beendet."
            fi
            exit 1
        fi

    # muss das Zielverzeichnis erstellt werden und ist der Pfad zulässig?
        if [ ! -d "$OUTPUTDIR" ] && echo "$OUTPUTDIR" | grep -q "/volume" ; then
            mkdir -p "$OUTPUTDIR"
            if [ $callFrom = GUI ] ; then
                echo '
                <p class="center"><span style="color: #BD0010;"><b>Zielverzeichnis wurde erstellt.</b></span></p>'
            else
                echo "Zielverzeichnis wurde erstellt."
            fi
        elif [ ! -d "$OUTPUTDIR" ] || ! $(echo "$OUTPUTDIR" | grep -q "/volume") ; then
            if [ $callFrom = GUI ] ; then
                echo '
                <p class="center"><span style="color: #BD0010;"><b>! ! ! Zielverzeichnis in der Konfiguration prüfen ! ! !</b><br>Programmlauf wird beendet.<br></span></p>'
            else
                echo "! ! ! Zielverzeichnis in der Konfiguration prüfen ! ! !"
                echo "Programmlauf wird beendet."
            fi
            exit 1
        fi

    # Dateizähler:
        if [ ! -f ./etc/counter ] ; then
            touch ./etc/counter
            echo "startcount=\"$(date +%Y)-$(date +%m)-$(date +%d)\"" >> ./etc/counter
            echo "ocrcount=\"0\"" >> ./etc/counter
            echo "pagecount=\"0\"" >> ./etc/counter
            echo "                      --> counter-File wurde erstellt"
        else
            if ! cat ./etc/counter | grep -q "pagecount" ; then
                echo "pagecount=\"$(get_key_value ./etc/counter ocrcount)\"" >> ./etc/counter
            fi
        fi
        if [[ $(sqlite3 ./etc/synOCR.sqlite "SELECT checkmon FROM system WHERE rowid=1") != $(date +%m) ]]; then
            #if [[ $(wget --no-check-certificate --timeout=30 --tries=3 -q -O - "http://geimist.eu/synOCR/VERSION" | head -n1) = "ok" ]]; then
                wget --no-check-certificate --timeout=30 --tries=3 -q -O - "https://geimist.eu/synOCR/VERSION"
                sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET checkmon='$(date +%m)' WHERE rowid=1"
            #fi
        fi

    # nur starten (LOG erstellen), sofern es etwas zu tun gibt:
        exclusion=false
        count_inputpdf=0

        if echo "${SearchPraefix}" | grep -qE '^!' ; then
            # ist der prefix / suffix ein Ausschlusskriterium?
            exclusion=true
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e 's/^!//')
        fi

        if echo "${SearchPraefix}" | grep -q "\$"$ ; then
            # is suffix
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            if [[ $exclusion = false ]] ; then
                count_inputpdf=$(ls -t "${INPUTDIR}" | egrep -i "^.*${SearchPraefix}.pdf$" | wc -l)
            elif [[ $exclusion = true ]] ; then
                count_inputpdf=$(ls -t "${INPUTDIR}" | egrep -i "^.*.pdf$" | cut -f 1 -d '.' | egrep -iv "${SearchPraefix}$" | wc -l)
            fi
        else
            # is prefix
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            if [[ $exclusion = false ]] ; then
                count_inputpdf=$(ls -t "${INPUTDIR}" | egrep -i "^${SearchPraefix}.*.pdf$" | wc -l)
            elif [[ $exclusion = true ]] ; then
                count_inputpdf=$(ls -t "${INPUTDIR}" | egrep -i "^.*.pdf$" | egrep -iv "^${SearchPraefix}.*.pdf$" | wc -l)
            fi
        fi

        if [ $count_inputpdf -eq 0 ] ;then
            continue
        fi

    # synOCR starten und ggf. Logverzeichnis prüfen und erstellen
        LOGDIR="${LOGDIR%/}/"
        LOGFILE="${LOGDIR}synOCR_$(date +%Y-%m-%d_%H-%M-%S).log"

        umask 000   # damit Files auch von anderen Usern bearbeitet werden können / http://openbook.rheinwerk-verlag.de/shell_programmierung/shell_011_003.htm

        if echo "$LOGDIR" | grep -q "/volume" && [ -d "$LOGDIR" ] && [ "$loglevel" != 0 ] ;then
            ./synOCR.sh "$profile_ID" "$LOGFILE" >> $LOGFILE 2>&1     # $LOGFILE wird als Parameter an synOCR übergeben, da die Datei dort ggf. bei ERRORFILES benötigt wird
        elif echo "$LOGDIR" | grep -q "/volume" && [ ! -d "$LOGDIR" ] && [ "$loglevel" != 0 ] ;then
            mkdir -p "$LOGDIR"
            ./synOCR.sh "$profile_ID" "$LOGFILE" >> $LOGFILE 2>&1
        else
            loglevel=0
            ./synOCR.sh "$profile_ID"
        fi

        if (( $? == 0 )); then
            echo "    -----------------------------------" >> $LOGFILE
            echo "    |       ==> synOCR ENDE <==       |" >> $LOGFILE
            echo "    -----------------------------------" >> $LOGFILE
        else
            echo "    -----------------------------------" >> $LOGFILE
            echo "    |   synOCR mit Fehlern beendet!   |" >> $LOGFILE
            echo "    -----------------------------------" >> $LOGFILE
            echo "synOCR wurde mit Fehlern beendet!"
            echo "weitere Informationen im LOG: $LOGFILE"
            exit_status=ERROR
        fi
    done

if  [ $exit_status = "ERROR" ] ; then
    exit 1
else
    exit 0
fi
