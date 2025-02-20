#!/bin/bash
# shell-check disable=SC2009

#############################################################################################
#   description:    start / stop monitoring with inotify                                    #
#                                                                                           #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/input_monitor.sh [start|stop]  #
#   © 2025 by geimist                                                                       #
#############################################################################################

monitored_folders="/usr/syno/synoman/webman/3rdparty/synOCR/etc/inotify.list"
inotify_process_id=$(ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk -F' ' '{print $2}')

# create list (array need for tee) with all active log folders:
# --------------------------------------------------------------
LOG_DIR_LIST=()
while read -r value ; do
    [ -d "${value%/*}" ] && LOG_DIR_LIST+=( "$value" )
done <<< "$(sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT LOGDIR FROM config WHERE active='1' AND LOGDIR IS NOT NULL AND NOT LOGDIR=''" 2>/dev/null | sort | uniq | sed -e "s~$~/inotify.log~g")"

# Delay in seconds
delay="$(sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='inotify_delay'" )"

if [ ! "$(which inotifywait)" ]; then
    echo "ERROR: inotify-tools are not installed" | tee -a "${LOG_DIR_LIST[@]}"
    echo "You can install the SPK from https://synocommunity.com/package/inotify-tools" | tee -a "${LOG_DIR_LIST[@]}"
    exit 1
fi


inotify_start() 
{
# start monitoring:
# --------------------------------------------------------------
    printf "\n%s\n" "---------- START MONITORING ---------- $(date +%Y-%m-%d_%H-%M-%S) ----------" | tee -a "${LOG_DIR_LIST[@]}" # > /dev/null


    while read -r value ; do
        dir="$(echo "${value}" | awk -F'\t' '{print $1}')"
        profilename="$(echo "${value}" | awk -F'\t' '{print $2}')"
        [ ! -d "${dir}" ] && echo "ERROR @ profile ${profilename}: inotify-tools cannot be started because \"${dir}\" is not a valid folder! " | tee -a "${LOG_DIR_LIST[@]}" && return
    done <<< "$(sqlite3 -separator $'\t' /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT INPUTDIR, profile FROM config WHERE active='1'" 2>/dev/null )" 

    nohup inotifywait --fromfile "${monitored_folders}" -e moved_to -e close_write --monitor --timeout -1 | 
    while read -r line ; do 
        printf "\n%s\n" "---------------- EVENT --------------- $(date +%Y-%m-%d_%H-%M-%S) ----------"
        printf "%s\n" "detected event: ${line}"

        # Extrahiere den vollen Dateipfad aus dem Event
        dir=$(echo "${line}" | awk '{print $1}')
        file=$(echo "${line}" | awk '{print $3}')
        full_path="${dir}/${file}"

# ToDo: Man könnte die nachfolgende Schleife als Subshell im Hintergrund ausführen `( … ) & `
#       so könnte man auf einzelne Quelldateien reagieren. Die Übergabe an synOCR-start.sh und synOCR.sh
#       müsste dann aber mit dem Dateipfad als Parameter aufgerufen werden.
        if [[ ${delay:-0} -ne 0 ]]; then
            while true; do
                if [ -f "${full_path}" ]; then
                    current_time=$(date +%s)
                    file_time=$(stat -c %Y "${full_path}")
                    if [ $((current_time - file_time)) -ge ${delay} ]; then
                        printf "%s\n" "Processing started (file older than ${delay}s)"
                        printf "\n%s\n" "synOCR-start.sh Log:"
                        /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh
                        break
                    fi
                fi
                sleep 1
            done
        else
            printf "%s\n" "instant execution (delay is not set)"
            printf "\n%s\n" "synOCR-start.sh Log:"
            /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh
        fi

    done | tee -a "${LOG_DIR_LIST[@]}" &

    sleep 1
}


inotify_stop() 
{
# stop monitoring:
# --------------------------------------------------------------
    printf "\n%s\n" "---------- STOP  MONITORING ---------- $(date +%Y-%m-%d_%H-%M-%S) ----------" | tee -a "${LOG_DIR_LIST[@]}" # > /dev/null
    [ -f "${monitored_folders}" ] && rm -f "${monitored_folders}"
    if kill ${inotify_process_id}; then
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
