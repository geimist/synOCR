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

# Sprachvariablen laden:
    source "./includes/functions.sh"
    language

# läuft bereits eine Instanz von synOCR?
    synOCR_pid=$( /bin/pidof synOCR.sh )
    if [ ! -z "$synOCR_pid" ] ; then
        if [ $callFrom = GUI ] ; then
            echo '<p class="center"><span style="color: #BD0010;"><b>'$lang_synOCR_start_is_running'</b><br>(Prozess-ID: '$synOCR_pid')</span></p>'
            echo '<br /><p class="center"><button name="page" value="main-kill-synocr" style="color: #BD0010;">('$lang_synOCR_start_req_kill')</button></p><br />'
        else
            echo "$lang_synOCR_start_is_running (Prozess-ID: ${synOCR_pid})"
        fi
        exit
    else
        if [ $callFrom = GUI ] ; then
            echo '<p class="title">'$lang_synOCR_start_runs' ...</p><br><br><br><br>
            <center><table id="system_msg" style="width: 40%;table-align: center;">
                <tr>
                    <th style="width: 20%;"><img class="imageStyle" alt="status_loading" src="images/status_loading.gif" style="float:left;"></th>
                    <th style="width: 80%;"><p class="center"><span style="color: #424242;font-weight:normal;">'$lang_synOCR_start_wait1'</span></p></th>
                </tr>
            </table></center>'
        else
            echo "$lang_synOCR_start_runs ..."
            echo "$lang_synOCR_start_wait2"
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
                <p class="center"><span style="color: #BD0010;"><b>! ! ! '$lang_synOCR_start_lost_input' ! ! !</b><br>'$lang_synOCR_start_abort'<br></span></p>'
            else
                echo "! ! ! $lang_synOCR_start_lost_input ! ! !"
                echo "$lang_synOCR_start_abort"
            fi
            continue
        fi

    # muss das Zielverzeichnis erstellt werden und ist der Pfad zulässig?
        if [ ! -d "$OUTPUTDIR" ] && echo "$OUTPUTDIR" | grep -q "/volume" ; then
            if /usr/syno/sbin/synoshare --enum ENC | grep -q $(echo "$OUTPUTDIR" | awk -F/ '{print $3}') ; then
                # handelt es sich um einen verschlüsselten Ordner und ist dieser eingehangen?
                if [ $callFrom = GUI ] ; then
                    echo '<p class="center"><span style="color: #BD0010;"><b>! ! ! '$lang_synOCR_start_umount_target' ! ! !</b><br>EXIT SCRIPT!<br></span></p>'
                else
                    echo "$lang_synOCR_start_umount_target    ➜    EXIT SCRIPT!"
                fi
                continue
            fi
            mkdir -p "$OUTPUTDIR"
            if [ $callFrom = GUI ] ; then
                echo '
                <p class="center"><span style="color: #BD0010;"><b>'$lang_synOCR_start_target_created'</b></span></p>'
            else
                echo "$lang_synOCR_start_target_created"
            fi
        elif [ ! -d "$OUTPUTDIR" ] || ! $(echo "$OUTPUTDIR" | grep -q "/volume") ; then
            if [ $callFrom = GUI ] ; then
                echo '
                <p class="center"><span style="color: #BD0010;"><b>! ! ! '$lang_synOCR_start_check_target' ! ! !</b><br>'$lang_synOCR_start_abort'<br></span></p>'
            else
                echo "! ! ! $lang_synOCR_start_check_target ! ! !"
                echo "$lang_synOCR_start_abort"
            fi
            continue
        fi

    # Dateizähler:
        if [ ! -f ./etc/counter ] ; then
            touch ./etc/counter
            echo "startcount=\"$(date +%Y)-$(date +%m)-$(date +%d)\"" >> ./etc/counter
            echo "ocrcount=\"0\"" >> ./etc/counter
            echo "pagecount=\"0\"" >> ./etc/counter
            echo "                      --> counter-File was created"
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
            if /usr/syno/sbin/synoshare --enum ENC | grep -q $(echo "$LOGDIR" | awk -F/ '{print $3}') ; then
                if [ $callFrom = GUI ] ; then
                    echo '<p class="center"><span style="color: #BD0010;"><b>! ! ! '$lang_synOCR_start_umount_log' ! ! !</b><br>EXIT SCRIPT!<br></span></p>'
                else
                    echo "$lang_synOCR_start_umount_log    ➜    EXIT SCRIPT!"
                fi
                continue
            fi
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
            echo "    |     synOCR exit with ERROR!     |" >> $LOGFILE
            echo "    -----------------------------------" >> $LOGFILE
            echo "$lang_synOCR_start_errorexit"
            echo "$lang_synOCR_start_loginfo: $LOGFILE"
            exit_status=ERROR
        fi
    done

if  [ $exit_status = "ERROR" ] ; then
    exit 1
else
    exit 0
fi
