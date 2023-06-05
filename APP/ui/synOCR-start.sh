#!/bin/bash
# shellcheck disable=SC1091,SC2009,SC2094,SC2154

#################################################################################
#   description:    - changes to synOCR directory and starts synOCR             #
#                     with or without LOG (depending on configuration)          #
#                   - adjust monitoring with inotifywait                        #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh    #
#   arguments:      - start (starts inotifywait / restarts it, if needed)       #
#                   - stop (stop inotifywait)                                   #
#                   - GUI (log formated as html)                                #
#   © 2023 by geimist                                                           #
#################################################################################

callFrom=shell
exit_status=0
dsm_version=$(synogetkeyvalue /etc.defaults/VERSION majorversion)
machinetyp=$(uname --machine)
monitored_folders="/usr/syno/synoman/webman/3rdparty/synOCR/etc/inotify.list"

umask 0011   # so that creaded files can also be edited by other users / http://openbook.rheinwerk-verlag.de/shell_programmierung/shell_011_003.htm

# create list (array need for tee) with all active log folders:
# --------------------------------------------------------------
log_dir_list=()
while read -r value ; do
    [ -d "${value%/*}" ] && log_dir_list+=( "${value}" ) #&& chmod 766 "$value"
done <<<"$(sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT LOGDIR FROM config WHERE active='1' AND LOGDIR IS NOT NULL AND NOT LOGDIR=''" 2>/dev/null | sort | uniq | sed -e "s~$~/inotify.log~g")"


inotify_process_id () {
    # print process id of inotify
    ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk -F' ' '{print $2}'
}

# reading parameters:
for i in "$@" ; do
    case $i in
        start)
            # (re)start-monitoring:
            monitor=off
            loop_count=0
            while [ "${monitor}" = off ] ; do

                # terminate parallel instances:
                if [ "$(inotify_process_id | awk '{ print NF; }')" -gt 1 ]; then 
                    echo "parallel processes active - terminate ..." | tee -a "${log_dir_list[@]}"
                    kill "$(inotify_process_id)"
                fi

                # start, if not running:
                if [ -z "$(inotify_process_id)" ] ;then
                    echo "does not run - start monitoring ..." | tee -a "${log_dir_list[@]}"
                    sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT INPUTDIR FROM config WHERE active='1'" 2>/dev/null | sort | uniq > "${monitored_folders}" 
                    /usr/syno/synoman/webman/3rdparty/synOCR/input_monitor.sh start
                else
                    # check if restart is necessary:
                    sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT INPUTDIR FROM config WHERE active='1'" 2>/dev/null | sort | uniq > "${monitored_folders}_tmp"

                    if [ "$(cat "${monitored_folders}" 2>/dev/null)" != "$(cat "${monitored_folders}_tmp")" ]; then
                        echo "still running, but change noticed in the watched folders - restart monitoring ..." | tee -a "${log_dir_list[@]}"
                        rm -f "${monitored_folders}_tmp"

                        echo "stop monitoring ..." | tee -a "${log_dir_list[@]}"
                        /usr/syno/synoman/webman/3rdparty/synOCR/input_monitor.sh stop
                    else
                        rm -f "${monitored_folders}_tmp"
                        break
                    fi
                fi

                if [ "$(inotify_process_id)" ]; then
                    monitor=on
                    echo "Monitoring successfully started" | tee -a "${log_dir_list[@]}"
                    break
                fi

                loop_count=$((loop_count + 1))
                echo "loop count: ${loop_count}" | tee -a "${log_dir_list[@]}"

                if [ "${loop_count}" -gt 10 ]; then
                    echo "! ! ! ERROR: failed to start monitoring after ${loop_count} trys" | tee -a "${log_dir_list[@]}"
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


# Read working directory and change into it:
    APPDIR=$(cd "$(dirname "$0")" || exit 1;pwd)
    cd "${APPDIR}" || exit 1

if [ "${callFrom}" = shell ] ; then
    # adjust PATH:
    if [ "${machinetyp}" = "x86_64" ]; then
        PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin:/usr/local/bin:/opt/usr/bin:/usr/syno/synoman/webman/3rdparty/synOCR/bin
    elif [ "${machinetyp}" = "aarch64" ]; then
        PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin:/usr/local/bin:/opt/usr/bin:/usr/syno/synoman/webman/3rdparty/synOCR/bin_aarch64
    fi

    # set docker and admin permission to user synOCR for DSM7 and above
    if [ "${dsm_version}" -ge 7 ]; then
        echo "synOCR run at DSM7 or above"
        source "./check_permissions.sh"
    fi
fi

# Load language variables:
    source "./includes/functions.sh"
    language

# Check DB (ggf. erstellen / upgrade):
    DBupgradelog=$(./upgradeconfig.sh)

    if [ -n "${DBupgradelog}" ] ; then
        echo "${lang_edit_dbupdate}: ${DBupgradelog}"
    fi

# is an instance of synOCR already running?
    synOCR_pid=$( /bin/pidof synOCR.sh )
    if [ -n "${synOCR_pid}" ] ; then
        if [ "${callFrom}" = GUI ] ; then
            echo '
            <p class="text-center synocr-text-red">
                <b>'"${lang_synOCR_start_is_running}"'</b><br>(Prozess-ID: '"${synOCR_pid}"')
            </p><br />'
            echo '
            <p class="text-center">
                <button name="page" value="main-kill-synocr" style="color: #BD0010;">('"${lang_synOCR_start_req_kill}"')</button>
            </p><br />'
        else
            echo "${lang_synOCR_start_is_running} (Prozess-ID: ${synOCR_pid})"
        fi
        exit
    else
        if [ "${callFrom}" = GUI ] ; then
            echo '
            <h2 class="synocr-text-blue mt-3">'"${lang_synOCR_start_runs}"' ...</h2>
            <p>&nbsp;</p>
            <center>
                <table id="system_msg" style="width: 40%; table-align: center;">
                    <tr>
                        <th style="width: 15%;">
                            <img class="float-start" alt="status_loading" src="images/status_loading.gif">
                        </th>
                        <th style="width: 85%;">
                            <p class="text-center mt-2"><span style="color: #424242; font-weight:normal;">'"${lang_synOCR_start_wait1}"'<br>'"${lang_synOCR_start_wait2}"'</span></p>
                        </th>
                    </tr>
                </table>
            </center>'
        else
            echo "${lang_synOCR_start_runs} ..."
            echo "${lang_synOCR_start_wait1} ${lang_synOCR_start_wait2}"
        fi
    fi

# monthly check for updates:
    if [[ $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='checkmon'") != $(date +%m) ]]; then
        local_version=$(grep "^version" /var/packages/synOCR/INFO | cut -d '"' -f2)
        if [ "$(grep "^beta" /var/packages/synOCR/INFO | cut -d '"' -f2)" = yes ]; then
            release_channel=beta
        else
            release_channel=release
        fi
        sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET value_1='$(date +%m)' WHERE key='checkmon'"
        if [[ $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='checkmon'") = $(date +%m) ]]; then
            server_info=$(wget --no-check-certificate --timeout=20 --tries=3 -q -O - "https://geimist.eu/synOCR/updateserver.php?file=VERSION&version=${local_version}&arch=${machinetyp}&dsm=${dsm_version}&device=$(uname -a | awk -F_ '{print $NF}' | sed "s/+/plus/g")" )
            online_version=$(echo "${server_info}" | jq -r .dsm.dsm"${dsm_version}"."${release_channel}".version)
#            downloadUrl=$(echo "${server_info}" | jq -r .dsm.dsm"${dsm_version}"."${release_channel}".downloadUrl )
#            changeLogUrl=$(echo "${server_info}" | jq -r .dsm.dsm"${dsm_version}"."${release_channel}".changeLogUrl )
 
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET value_1='${online_version}' WHERE key='online_version'"
            # reset checkmon if failed get version:
            if grep -qvE '^[0-9.]+$' <<< "${online_version}"; then
                sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET value_1='$(date -d "-1 month" +%m)' WHERE key='checkmon'"
            fi
            highest_version=$(printf "%s\n%s" "${online_version}" "${local_version}" | sort -V | tail -n1)
            if [[ "${local_version}" != "${highest_version}" ]] ; then
                if [ "${dsm_version}" = 7 ] ; then
                
                # synodsmnotify dosn't rendering html / how works the switch -p html/plain?
                #    msg_download='<br><a href="'${downloadUrl}'" onclick="window.open(this.href); return false;" class="pulsate" style="font-size: 0.7rem;">DOWNLOAD VERSION '${online_version}' </a>'
                #    msg_changelog='<br><a href="'${changeLogUrl}'" onclick="window.open(this.href); return false;" class="pulsate" style="font-size: 0.7rem;">CHANGELOG]</a>'
                #    msg_download='<a href="'${downloadUrl}'">DOWNLOAD VERSION '${online_version}'</a>'
                #    msg_changelog='<a href="'${changeLogUrl}'"> CHANGELOG </a>'

                    synodsmnotify -c "SYNO.SDS.synOCR.Application" @administrators "synOCR:app:app_name" "synOCR:app:update_available" "${local_version}" "${online_version}" #"${msg_download}" "${msg_changelog}"
                else
                    synodsmnotify @administrators "synOCR" "Update available [version ${online_version}]"
                fi
            fi
        fi
    fi

# load configuration:
    sSQL="SELECT 
            profile_ID, 
            INPUTDIR, 
            OUTPUTDIR, 
            LOGDIR, 
            SearchPraefix, 
            loglevel, 
            profile, 
            img2pdf 
        FROM 
            config 
        WHERE 
            active='1'
        ORDER BY 
            profile COLLATE NOCASE ASC;"

    while read -r entry; do
        profile_ID=$(echo "${entry}" | awk -F'\t' '{print $1}')
        INPUTDIR=$(echo "${entry}" | awk -F'\t' '{print $2}')
        OUTPUTDIR=$(echo "${entry}" | awk -F'\t' '{print $3}')
        LOGDIR=$(echo "${entry}" | awk -F'\t' '{print $4}')
        SearchPraefix=$(echo "${entry}" | awk -F'\t' '{print $5}')
        loglevel=$(echo "${entry}" | awk -F'\t' '{print $6}')
        profile=$(echo "${entry}" | awk -F'\t' '{print $7}')
        img2pdf=$(echo "${entry}" | awk -F'\t' '{print $8}')

    # is the source directory present and is the path valid?
        if [ ! -d "${INPUTDIR}" ] || ! echo "${INPUTDIR}" | grep -q "/volume" ; then
            if [ "${callFrom}" = GUI ] ; then
                echo '
                <p class="text-center">
                    <span style="color: #BD0010;"><b>! ! ! '"${lang_synOCR_start_lost_input}"' ! ! !</b><br>'"${lang_synOCR_start_abort}"' ('"${profile}"' [ID: '"${profile_ID}"'])<br></span>
                </p>
                '
            else
                echo "! ! ! ${lang_synOCR_start_lost_input} ! ! !"
                echo "${lang_synOCR_start_abort} (${profile} [ID: ${profile_ID}])"
            fi
            continue
        fi

    # must the target directory be created and is the path allowed?
        if [ ! -d "${OUTPUTDIR}" ] && echo "${OUTPUTDIR}" | grep -q "/volume" ; then
            if /usr/syno/sbin/synoshare --enum ENC | grep -q "$(echo "${OUTPUTDIR}" | awk -F/ '{print $3}')" ; then
                # is it an encrypted folder and is it mounted?
                if [ "${callFrom}" = GUI ] ; then
                    echo '
                    <p class="text-center"><
                        span style="color: #BD0010;"><b>! ! ! '"${lang_synOCR_start_umount_target}"' ! ! !</b><br>EXIT SCRIPT!<br></span>
                    </p>'
                else
                    echo "${lang_synOCR_start_umount_target}    ➜    EXIT SCRIPT!"
                fi
                continue
            fi
            mkdir -p "${OUTPUTDIR}"
            if [ "${callFrom}" = GUI ] ; then
                echo '
                <p class="text-center">
                    <span style="color: #BD0010;"><b>'"${lang_synOCR_start_target_created}"'</b></span>
                </p>'
            else
                echo "${lang_synOCR_start_target_created}"
            fi
        elif [ ! -d "${OUTPUTDIR}" ] || ! echo "${OUTPUTDIR}" | grep -q "/volume" ; then
            if [ "${callFrom}" = GUI ] ; then
                echo '
                <p class="text-center">
                    <span style="color: #BD0010;"><b>! ! ! '"${lang_synOCR_start_check_target}"' ! ! !</b><br>'"${lang_synOCR_start_abort}"'<br></span>
                </p>'
            else
                echo "! ! ! ${lang_synOCR_start_check_target} ! ! !"
                echo "${lang_synOCR_start_abort}"
            fi
            continue
        fi

    # only start (create LOG) if there is something to do:
        exclusion=false
        count_input_file=0

        if [ "${img2pdf}" = true ]; then
#            source_file_type=".jpg$|.png$|.tiff$|.jpeg$|.pdf$"
            source_file_type="\(JPG\|jpg\|PNG\|png\|TIFF\|tiff\|JPEG\|jpeg\|PDF\|pdf\)"
        else
#            source_file_type=".pdf$"
            source_file_type="\(PDF\|pdf\)"
        fi

##      if echo "${SearchPraefix}" | grep -qE '^!' ; then
        if [[ "${SearchPraefix}" =~ ^! ]]; then
            # is the prefix / suffix an exclusion criterion?
            exclusion=true
##          SearchPraefix=$(echo "${SearchPraefix}" | sed -e 's/^!//')
            SearchPraefix="${SearchPraefix#!}"
        fi

##      if echo "${SearchPraefix}" | grep -q "\$"$ ; then
        if [[ "${SearchPraefix}" =~ \$+$ ]]; then
            # is suffix
##          SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            SearchPraefix="${SearchPraefix%?}"
            if [[ "${exclusion}" = false ]] ; then
##              count_input_file=$(ls -tp "${INPUTDIR}" | grep -vE '/$' | grep -iEc "^.*${SearchPraefix}(${source_file_type})")
                count_input_file=$(find "${INPUTDIR}" -maxdepth 1 -regex "${INPUTDIR}.*${SearchPraefix}\.${source_file_type}$" -type f -printf '.' | wc -c )
            elif [[ "${exclusion}" = true ]] ; then
##              count_input_file=$(ls -tp "${INPUTDIR}" | grep -vE '/$' | grep -iE "^.*(${source_file_type})" | cut -f 1 -d '.' | grep -ivEc "${SearchPraefix}$")
                count_input_file=$(find "${INPUTDIR}" -maxdepth 1 -regex "${INPUTDIR}.*\.${source_file_type}$" -not -iname "*${SearchPraefix}.*" -type f -printf '.' | wc -c )
            fi
        else
            # is prefix
##          SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            SearchPraefix="${SearchPraefix%%\$}"
            if [[ "${exclusion}" = false ]] ; then
##              count_input_file=$(ls -tp "${INPUTDIR}" | grep -vE '/$' | grep -iEc "^${SearchPraefix}.*(${source_file_type})")
                count_input_file=$(find "${INPUTDIR}" -maxdepth 1 -regex "${INPUTDIR}${SearchPraefix}.*\.${source_file_type}$" -type f -printf '.' | wc -c )
            elif [[ "${exclusion}" = true ]] ; then
##              count_input_file=$(ls -tp "${INPUTDIR}" | grep -vE '/$' | grep -iE "^.*(${source_file_type})" | grep -ivEc "^${SearchPraefix}.*(${source_file_type})")
                count_input_file=$(find "${INPUTDIR}" -maxdepth 1 -regex "${INPUTDIR}.*\.${source_file_type}$" -not -iname "${SearchPraefix}*" -type f -printf '.' | wc -c )
            fi
        fi

        if [ "${count_input_file}" -eq 0 ] ;then
            continue
        fi

    # start synOCR and check and create log directory if necessary
        LOGDIR="${LOGDIR%/}/"
        LOGFILE="${LOGDIR}synOCR_$(date +%Y-%m-%d_%H-%M-%S).log"

        if echo "${LOGDIR}" | grep -q "/volume" && [ -d "${LOGDIR}" ] && [ "${loglevel}" != 0 ] ;then
            ./synOCR.sh "${profile_ID}" "${LOGFILE}" >> "${LOGFILE}" 2>&1     # $LOGFILE is passed as a parameter to synOCR, since the file may be needed there for ERRORFILES
        elif echo "${LOGDIR}" | grep -q "/volume" && [ ! -d "${LOGDIR}" ] && [ "${loglevel}" != 0 ] ;then
            if /usr/syno/sbin/synoshare --enum ENC | grep -q "$(echo "${LOGDIR}" | awk -F/ '{print $3}')" ; then
                if [ "${callFrom}" = GUI ] ; then
                    echo '
                    <p class="text-center">
                        <span style="color: #BD0010;"><b>! ! ! '"${lang_synOCR_start_umount_log}"' ! ! !</b><br>EXIT SCRIPT!<br></span>
                    </p>'
                else
                    echo "${lang_synOCR_start_umount_log}    ➜    EXIT SCRIPT!"
                fi
                continue
            fi
            mkdir -p "${LOGDIR}"
            ./synOCR.sh "${profile_ID}" "${LOGFILE}" >> "${LOGFILE}" 2>&1
        else
            loglevel=0
            ./synOCR.sh "${profile_ID}" >/dev/null
        fi

        # shellcheck disable=SC2181
        if [ $? = 0 ] && [ "${loglevel}" != 0 ]; then
            {
            echo "  ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●"
            echo "  ● ---------------------------------- ●"
            echo "  ● |    ==> END OF FUNCTIONS <==    | ●"
            echo "  ● ---------------------------------- ●"
            echo "  ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●"
            } >> "${LOGFILE}"
        elif [ $? != 0 ] && [ "${loglevel}" != 0 ]; then
            {
            echo "  ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●"
            echo "  ● ---------------------------------- ●"
            echo "  ● |    ==> EXIT WITH ERROR! <==    | ●"
            echo "  ● ---------------------------------- ●"
            echo "  ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●"
            } >> "${LOGFILE}"

            echo "${lang_synOCR_start_errorexit}"
            echo "${lang_synOCR_start_loginfo}: ${LOGFILE}"
            exit_status=ERROR
        elif [ $? != 0 ] && [ "${loglevel}" = 0 ]; then
            echo "${lang_synOCR_start_errorexit}"
            exit_status=ERROR
        fi
    done <<< "$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "${sSQL}")"

if  [ "${exit_status}" = ERROR ] ; then
    exit 1
else
    exit 0
fi
