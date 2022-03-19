#!/bin/sh
# /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh start stop GUI

# changes to synOCR directory and starts synOCR with or without LOG (depending on configuration)
# adjust monitoring with inotifywait


callFrom=shell
exit_status=0
dsm_version=$(synogetkeyvalue /etc.defaults/VERSION majorversion)
machinetyp=$(uname --machine)
monitored_folders="/usr/syno/synoman/webman/3rdparty/synOCR/etc/inotify.list"


# create list (array need for tee) with all active log folders:
# --------------------------------------------------------------
log_dir_list=()
while read value ; do
    [ -d "${value%/*}" ] && log_dir_list+=( "$value" )
done <<<"$(sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT LOGDIR FROM config WHERE active='1' AND LOGDIR IS NOT NULL AND NOT LOGDIR=''" 2>/dev/null | sort | uniq | sed -e "s~$~/inotify.log~g")"


inotify_process_id () {
    # print process id of inotify in
    ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk -F' ' '{print $2}'
}

# reading parameters:
for i in "$@" ; do
    case $i in
        start)
            # (re)start-monitoring:
            monitor=off
            loop_count=0
            while [ "$monitor" = off ] ; do

                # terminate parallel instances:
                if [ $(echo $(inotify_process_id) | awk '{ print NF; }') -gt 1 ]; then 
                    echo "parallel processes active - terminate ..." | tee -a "${log_dir_list[@]}"
                    kill $(inotify_process_id)
                fi

                # start, if not running:
                if [ -z "$(inotify_process_id)" ] ;then
                    echo "does not run - start monitoring ..." | tee -a "${log_dir_list[@]}"
                    sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT INPUTDIR FROM config WHERE active='1'" 2>/dev/null | sort | uniq > "${monitored_folders}"
                    /usr/syno/synoman/webman/3rdparty/synOCR/input_monitor.sh start
                else
                    # check if restart is necessary:
#                   echo "still running (count of processes: $(echo $(inotify_process_id) | awk '{ print NF; }')) - check if restart is necessary:" | tee -a "${log_dir_list[@]}"
                    sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT INPUTDIR FROM config WHERE active='1'" 2>/dev/null | sort | uniq > "${monitored_folders}_tmp"

                    if [ "$(cat "$monitored_folders" 2>/dev/null)" != "$(cat "${monitored_folders}_tmp")" ]; then
                        echo "still running, but change noticed in the watched folders - restart monitoring ..." | tee -a "${log_dir_list[@]}"
                        rm -f "${monitored_folders}_tmp"

                        echo "stop monitoring ..." | tee -a "${log_dir_list[@]}"
                        /usr/syno/synoman/webman/3rdparty/synOCR/input_monitor.sh stop
                    else
#                       echo "no restart necessary" | tee -a "${log_dir_list[@]}"
                        break
                    fi
                fi

                if [ "$(inotify_process_id)" ]; then
                    monitor=on
                    echo "Monitoring successfully started" | tee -a "${log_dir_list[@]}"
                    break
                fi

                loop_count=$((loop_count + 1))
                echo "loop count: $loop_count" | tee -a "${log_dir_list[@]}"

                if [ "$loop_count" -gt 10 ]; then
                    echo "! ! ! ERROR: failed to start monitoring after $loop_count trys" | tee -a "${log_dir_list[@]}"
                    break 1
                fi
            done

            sleep 1
            shift
            ;;
        stop)
            # stop-monitoring:
            if [ "$(inotify_process_id)" ] ;then
                echo "stop monitoring ..." | tee -a "${log_dir_list[@]}"
                /usr/syno/synoman/webman/3rdparty/synOCR/input_monitor.sh stop | tee -a "${log_dir_list[@]}"
                sleep 1
            fi
            exit 0
#           shift
            ;;
        GUI)
            # was the script called from the GUI (call with parameter "GUI")? / the log output is adjusted accordingly
            callFrom=GUI
#           shift
            ;;
    esac
done


if [ "$callFrom" = shell ] ; then
    # adjust PATH:
    if [ $machinetyp = "x86_64" ]; then
        PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin:/usr/local/bin:/opt/usr/bin:/usr/syno/synoman/webman/3rdparty/synOCR/bin
    elif [ $machinetyp = "aarch64" ]; then
        PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin:/usr/local/bin:/opt/usr/bin:/usr/syno/synoman/webman/3rdparty/synOCR/bin_aarch64
    fi

# set docker and admin permission to user synOCR for DSM7 and above
    if [ "$dsm_version" -ge 7 ]; then
        echo "synOCR run at DSM7 or above"
        echo -n "    ➜ check admin permissions: "
        if ! cat /etc/group | grep ^administrators | grep -q synOCR ; then
            echo "added user synOCR to group administrators ..."
            sed -i "/^administrators:/ s/$/,synOCR/" /etc/group
        else
            echo "ok"
        fi

        echo -n "    ➜ check docker group and permissions: "
        if ! cat /etc/group | grep -q ^docker: ; then
            echo "create group docker ..."
            synogroup --add docker
            chown root:docker /var/run/docker.sock
            synogroup --member docker synOCR
        elif ! cat /etc/group | grep ^docker: | grep -q synOCR ; then
            echo "added user synOCR to group docker ..."
            sed -i "/^docker:/ s/$/,synOCR/" /etc/group
        else
            echo "ok [$(cat /etc/group | grep ^docker:)]"
        fi
    fi
fi

# Read working directory and change into it:
    APPDIR=$(cd $(dirname $0);pwd)
    cd ${APPDIR}

# Load language variables:
    source "./includes/functions.sh"
    language

# Check DB (ggf. erstellen / upgrade):
    DBupgradelog=$(./upgradeconfig.sh)

    if [ ! -z "$DBupgradelog" ] ; then
        echo "${lang_edit_dbupdate}: $DBupgradelog"
    fi

# is an instance of synOCR already running?
    synOCR_pid=$( /bin/pidof synOCR.sh )
    if [ ! -z "$synOCR_pid" ] ; then
        if [ "$callFrom" = GUI ] ; then
            echo '
            <p class="text-center synocr-text-red">
                <b>'$lang_synOCR_start_is_running'</b><br>(Prozess-ID: '$synOCR_pid')
            </p><br />'
            echo '
            <p class="text-center">
                <button name="page" value="main-kill-synocr" style="color: #BD0010;">('$lang_synOCR_start_req_kill')</button>
            </p><br />'
        else
            echo "$lang_synOCR_start_is_running (Prozess-ID: ${synOCR_pid})"
        fi
        exit
    else
        if [ "$callFrom" = GUI ] ; then
            echo '
            <h2 class="synocr-text-blue mt-3">'$lang_synOCR_start_runs' ...</h2>
            <p>&nbsp;</p>
            <center>
                <table id="system_msg" style="width: 40%; table-align: center;">
                    <tr>
                        <th style="width: 15%;">
                            <img class="float-start" alt="status_loading" src="images/status_loading.gif">
                        </th>
                        <th style="width: 85%;">
                            <p class="text-center mt-2"><span style="color: #424242; font-weight:normal;">'$lang_synOCR_start_wait1'</span></p>
                        </th>
                    </tr>
                </table>
            </center>'
        else
            echo "$lang_synOCR_start_runs ..."
            echo "$lang_synOCR_start_wait2"
        fi
    fi

# check for update:
    if [[ $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='checkmon'") -ne $(date +%m) ]]; then
        local_version=$(grep "^version" /var/packages/synOCR/INFO | cut -d '"' -f2)
        sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET value_1='$(date +%m)' WHERE key='checkmon'"
        if [[ $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='checkmon'") -eq $(date +%m) ]]; then
            server_info=$(wget --no-check-certificate --timeout=20 --tries=3 -q -O - "https://geimist.eu/synOCR/updateserver.php?file=VERSION_DSM${dsm_version}&version=${local_version}&arch=$machinetyp" )
            online_version=$(echo "$server_info" | sed -n "2p")
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET value_1='${online_version}' WHERE key='online_version'"
            if [[ $(echo "$server_info" | sed -n "1p" ) != "ok" ]]; then
                sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET value_1='$(date -d "-1 month" +%m)' WHERE key='checkmon'"
            fi
            highest_version=$(printf "${online_version}\n${local_version}" | sort -V | tail -n1)
            if [[ "${local_version}" != "$highest_version" ]] ; then
                if [ "$dsm_version" = "7" ] ; then
                    synodsmnotify -c SYNO.SDS.ThirdParty.App.synOCR @administrators synOCR:app:app_name synOCR:app:update_available
                else
                    synodsmnotify @administrators "synOCR" "Update available [version ${online_version}]"
                fi
            fi
        fi
    fi

# load configuration:
    sSQL="SELECT profile_ID, INPUTDIR, OUTPUTDIR, LOGDIR, SearchPraefix, loglevel, profile FROM config WHERE active='1' "
    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL")

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

    # is the source directory present and is the path valid?
        if [ ! -d "${INPUTDIR}" ] || ! $(echo "${INPUTDIR}" | grep -q "/volume") ; then
            if [ "$callFrom" = GUI ] ; then
                echo '
                <p class="text-center">
                    <span style="color: #BD0010;"><b>! ! ! '$lang_synOCR_start_lost_input' ! ! !</b><br>'$lang_synOCR_start_abort'<br></span>
                </p>'
            else
                echo "! ! ! $lang_synOCR_start_lost_input ! ! !"
                echo "$lang_synOCR_start_abort"
            fi
            continue
        fi

    # must the target directory be created and is the path allowed?
        if [ ! -d "$OUTPUTDIR" ] && echo "$OUTPUTDIR" | grep -q "/volume" ; then
            if /usr/syno/sbin/synoshare --enum ENC | grep -q $(echo "$OUTPUTDIR" | awk -F/ '{print $3}') ; then
                # is it an encrypted folder and is it mounted?
                if [ "$callFrom" = GUI ] ; then
                    echo '
                    <p class="text-center"><
                        span style="color: #BD0010;"><b>! ! ! '$lang_synOCR_start_umount_target' ! ! !</b><br>EXIT SCRIPT!<br></span>
                    </p>'
                else
                    echo "$lang_synOCR_start_umount_target    ➜    EXIT SCRIPT!"
                fi
                continue
            fi
            mkdir -p "$OUTPUTDIR"
            if [ "$callFrom" = GUI ] ; then
                echo '
                <p class="text-center">
                    <span style="color: #BD0010;"><b>'$lang_synOCR_start_target_created'</b></span>
                </p>'
            else
                echo "$lang_synOCR_start_target_created"
            fi
        elif [ ! -d "$OUTPUTDIR" ] || ! $(echo "$OUTPUTDIR" | grep -q "/volume") ; then
            if [ "$callFrom" = GUI ] ; then
                echo '
                <p class="text-center">
                    <span style="color: #BD0010;"><b>! ! ! '$lang_synOCR_start_check_target' ! ! !</b><br>'$lang_synOCR_start_abort'<br></span>
                </p>'
            else
                echo "! ! ! $lang_synOCR_start_check_target ! ! !"
                echo "$lang_synOCR_start_abort"
            fi
            continue
        fi

    # only start (create LOG) if there is something to do:
        exclusion=false
        count_inputpdf=0

        if echo "${SearchPraefix}" | grep -qE '^!' ; then
            # is the prefix / suffix an exclusion criterion?
            exclusion=true
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e 's/^!//')
        fi

        if echo "${SearchPraefix}" | grep -q "\$"$ ; then
            # is suffix
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            if [[ "$exclusion" = false ]] ; then
                count_inputpdf=$(ls -t "${INPUTDIR}" | egrep -i "^.*${SearchPraefix}.pdf$" | wc -l)
            elif [[ "$exclusion" = true ]] ; then
                count_inputpdf=$(ls -t "${INPUTDIR}" | egrep -i "^.*.pdf$" | cut -f 1 -d '.' | egrep -iv "${SearchPraefix}$" | wc -l)
            fi
        else
            # is prefix
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            if [[ "$exclusion" = false ]] ; then
                count_inputpdf=$(ls -t "${INPUTDIR}" | egrep -i "^${SearchPraefix}.*.pdf$" | wc -l)
            elif [[ "$exclusion" = true ]] ; then
                count_inputpdf=$(ls -t "${INPUTDIR}" | egrep -i "^.*.pdf$" | egrep -iv "^${SearchPraefix}.*.pdf$" | wc -l)
            fi
        fi

        if [ "$count_inputpdf" -eq 0 ] ;then
            continue
        fi

    # start synOCR and check and create log directory if necessary
        LOGDIR="${LOGDIR%/}/"
        LOGFILE="${LOGDIR}synOCR_$(date +%Y-%m-%d_%H-%M-%S).log"

        umask 000   # so that files can also be edited by other users / http://openbook.rheinwerk-verlag.de/shell_programmierung/shell_011_003.htm

        if echo "$LOGDIR" | grep -q "/volume" && [ -d "$LOGDIR" ] && [ "$loglevel" != 0 ] ;then
            ./synOCR.sh "$profile_ID" "$LOGFILE" >> $LOGFILE 2>&1     # $LOGFILE is passed as a parameter to synOCR, since the file may be needed there for ERRORFILES
        elif echo "$LOGDIR" | grep -q "/volume" && [ ! -d "$LOGDIR" ] && [ "$loglevel" != 0 ] ;then
            if /usr/syno/sbin/synoshare --enum ENC | grep -q $(echo "$LOGDIR" | awk -F/ '{print $3}') ; then
                if [ "$callFrom" = GUI ] ; then
                    echo '
                    <p class="text-center">
                        <span style="color: #BD0010;"><b>! ! ! '$lang_synOCR_start_umount_log' ! ! !</b><br>EXIT SCRIPT!<br></span>
                    </p>'
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
            echo "  ######################################" >> $LOGFILE
            echo "  # ---------------------------------- #" >> $LOGFILE
            echo "  # |    ==> END OF FUNCTIONS <==    | #" >> $LOGFILE
            echo "  # ---------------------------------- #" >> $LOGFILE
            echo "  ######################################" >> $LOGFILE
        else
            echo "  ######################################" >> $LOGFILE
            echo "  # ---------------------------------- #" >> $LOGFILE
            echo "  # |    ==> EXIT WITH ERROR! <==    | #" >> $LOGFILE
            echo "  # ---------------------------------- #" >> $LOGFILE
            echo "  ######################################" >> $LOGFILE
            echo "$lang_synOCR_start_errorexit"
            echo "$lang_synOCR_start_loginfo: $LOGFILE"
            exit_status=ERROR
        fi
    done

if  [ "$exit_status" = "ERROR" ] ; then
    exit 1
else
    exit 0
fi
