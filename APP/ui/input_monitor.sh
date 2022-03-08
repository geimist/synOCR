#!/bin/bash
#  /usr/syno/synoman/webman/3rdparty/synOCR/includes/input_monitor.sh start stop

monitored_folders="/usr/syno/synoman/webman/3rdparty/synOCR/etc/inotify.list"
inotify_process_id=$(ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk -F' ' '{print $2}')


# inotify-tools currently not included ...
#   if [ $(uname --machine) = "x86_64" ] && [ ! $(which inotifywait) ]; then
#       export PATH=$PATH:${0%/*}/bin
#       export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${0%/*}/lib
#   elif [ $(uname --machine) = aarch64 ] ; then
#       export PATH=$PATH:${0%/*}/bin_aarch64
#       export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${0%/*}/lib_aarch64
#   fi

if [ ! $(which inotifywait) ]; then
    echo "ERROR: inotify-tools are not installed"
    exit 1
fi


inotify_start() {
# start monitoring:
# --------------------------------------------------------------
    if [ -z "$inotify_process_id" ];then
        echo "Monitoring has started ..."
        inotifywait --fromfile "${monitored_folders}" -e moved_to -e create --monitor --timeout -1 | 
            while read line ; do 
                echo "--------------------------- EVENT --------------------------- $(date +%Y-%m-%d_%H-%M-%S) ---------------------------"
                echo "$line"
                /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh
            done &
    fi
    sleep 1
}


inotify_stop() 
{
# stop monitoring:
# --------------------------------------------------------------
    if [ -n "$inotify_process_id" ];then
        echo "--------------------- STOP  MONITORING ---------------------- $(date +%Y-%m-%d_%H-%M-%S) ---------------------------"
        [ -f "${monitored_folders}" ] && rm -f "${monitored_folders}"
        kill "$inotify_process_id"
        if [ $? = 0 ]; then
            echo "Monitoring ended"
        else
            echo "ERROR when stopping the monitoring!"
            exit 1
        fi
        sleep 1
    fi
}


# start-stop-monitoring:
case "$1" in
    start)
        # Check if a restart of the monitoring is necessary / update watch folder list:
        sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT INPUTDIR FROM config WHERE active='1'" 2>/dev/null | sort | uniq > "${monitored_folders}_tmp"
        if [ "$(cat "$monitored_folders" 2>/dev/null)" = "$(cat "${monitored_folders}_tmp")" ]; then
            inotify_start
            rm -f "${monitored_folders}_tmp"
        else
            echo "--------------------- START MONITORING ---------------------- $(date +%Y-%m-%d_%H-%M-%S) ---------------------------"
            echo "Change noticed in the watched folders!"
            echo "start / restart monitoring ..."
            mv "${monitored_folders}_tmp" "${monitored_folders}"
            inotify_stop
            sleep 1
            inotify_start
        fi
        exit 0
        ;;
    stop)
        inotify_stop
        exit 0
        ;;
esac

exit 0











https://www.linux-community.de/ausgaben/linuxuser/2017/01/bescheid/

--fromfile Datei 
    definiert die zu überwachenden Dateien über eine Datei mit den Pfaden. 

--format <fmt>	
Legt das Ausgabeformat fest. Es werden nur maximal ca. 4000 Zeichen ausgegeben.
    %w  wird durch den Verzeichnispfad ersetzt
    %f  wird durch den Dateinamen ersetzt, falls einer relevant ist
    %e  wird durch die Events ersetzt, mehrere Events werden durch Komma getrennt
    %Xe wird durch die Events ersetzt, mehrere Events werden durch das Zeichen an der Stelle X ersetzt
    %T  wird durch die aktuelle Zeit ersetzt, das Format kann mit --timefmt festgelegt werden

Inotify-Events:
Kürzel          Format
------------------------------------------------------------
access          Eine Datei wurde gelesen.
modify          Eine Datei wurde geändert.
attrib          Die Metadaten einer Datei wurden geändert (Zeitstempel, Rechte, erweiterte Attribute).
close_write     Eine Datei wurde geschlossen nachdem sie zum schreiben geöffnet wurde, sie muss aber nicht verändert worden sein.
close_nowrite   Eine Datei wurde geschlossen nachdem sie schreibgeschützt geöffnet wurde.
close           wie close_write und close_nowrite zusammen
open            Eine Datei wurde geöffnet.
moved_to        Eine Datei oder ein Verzeichnis wurde in ein zu überwachendes Verzeichnis verschoben oder im Verzeichnis verschoben.
moved_from      Eine Datei oder ein Verzeichnis wurde aus oder in einem überwachten Verzeichnis verschoben.
move            wie moved_to und moved_from zusammen
move_self       Eine überwachte Datei oder ein überwachtes Verzeichnis wurde verschoben. Danach wird die Überwachung abgeschaltet.
create          Eine Datei wurde erstellt.
delete          Eine Datei wurde gelöscht.
delete_self     Eine überwachte Datei oder ein überwachtes Verzeichnis wurde gelöscht. Danach wird die Überwachung abgeschaltet.
unmount         Das Dateisystem, auf dem sich die Überwachung befand, wurde ausgehängt. Danach wird die Überwachung abgeschaltet. Dieses Event kann auch auftreten, wenn es nicht explizit überwacht wurde.



