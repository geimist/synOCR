#!/bin/bash

#############################################################################################
#   description:    start / stop monitoring with inotify                                    #
#                                                                                           #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/input_monitor.sh [start|stop]  #
#   © 2023 by geimist                                                                       #
#############################################################################################

monitored_folders="/usr/syno/synoman/webman/3rdparty/synOCR/etc/inotify.list"
inotify_process_id=$(ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk -F' ' '{print $2}')


# create list (array need for tee) with all active log folders:
# --------------------------------------------------------------
LOG_DIR_LIST=()
while read value ; do
    [ -d "${value%/*}" ] && LOG_DIR_LIST+=( "$value" )
done <<<"$(sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT LOGDIR FROM config WHERE active='1' AND LOGDIR IS NOT NULL AND NOT LOGDIR=''" 2>/dev/null | sort | uniq | sed -e "s~$~/inotify.log~g")"


if [ ! $(which inotifywait) ]; then
    echo "ERROR: inotify-tools are not installed" | tee -a "${LOG_DIR_LIST[@]}"
    echo "You can install the SPK from https://synocommunity.com/package/inotify-tools" | tee -a "${LOG_DIR_LIST[@]}"
    exit 1
fi


inotify_start() {
# start monitoring:
# --------------------------------------------------------------
    printf "\n---------- START MONITORING ---------- $(date +%Y-%m-%d_%H-%M-%S) ----------\n" | tee -a "${LOG_DIR_LIST[@]}" # > /dev/null
    nohup inotifywait --fromfile "${monitored_folders}" -e moved_to -e close_write --monitor --timeout -1 | 
        while read line ; do 
            printf "\n---------------- EVENT --------------- $(date +%Y-%m-%d_%H-%M-%S) ----------\n"
            printf "detected event: $line\n"
            printf "\nsynOCR-start.sh Log:\n"
            /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh
        done | tee -a "${LOG_DIR_LIST[@]}" &

    sleep 1
}


inotify_stop() 
{
# stop monitoring:
# --------------------------------------------------------------
    printf "\n---------- STOP  MONITORING ---------- $(date +%Y-%m-%d_%H-%M-%S) ----------\n" | tee -a "${LOG_DIR_LIST[@]}" # > /dev/null
    [ -f "${monitored_folders}" ] && rm -f "${monitored_folders}"
    kill $inotify_process_id
    if [ $? = 0 ]; then
        echo "Monitoring ended" | tee -a "${LOG_DIR_LIST[@]}" #> /dev/null
    else
        echo "ERROR when stopping the monitoring!" | tee -a "${LOG_DIR_LIST[@]}" #> /dev/null
        exit 1
    fi

    sleep 1
}


# start-stop-monitoring:
case "$1" in
    start)
        inotify_start
        exit 0
        ;;
    stop)
        inotify_stop
        exit 0
        ;;
esac

exit 0
