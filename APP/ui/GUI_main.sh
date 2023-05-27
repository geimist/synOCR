#!/bin/bash
# shellcheck disable=SC2154

#################################################################################
#   description:    - generates the main page for the GUI                       #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/main.sh            #
#   © 2023 by geimist                                                           #
#################################################################################

PATH=$PATH:/usr/local/bin:/opt/usr/bin
dsmMajorVersion=$(synogetkeyvalue /etc.defaults/VERSION majorversion)

# Read file status:
# ---------------------------------------------------------------------
    # Count of unfinished PDF files:
    count_input_file=0

    while read -r entry ; do
        INPUTDIR=$(echo "$entry" | awk -F'\t' '{print $1}')
        SearchPraefix=$(echo "$entry" | awk -F'\t' '{print $2}')
        img2pdf=$(echo "$entry" | awk -F'\t' '{print $3}')

        if [ "$img2pdf" = true ]; then
##          source_file_type=".jpg$|.png$|.tiff$|.jpeg$|.pdf$"
            source_file_type="\(JPG\|jpg\|PNG\|png\|TIFF\|tiff\|JPEG\|jpeg\|PDF\|pdf\)"
        else
##          source_file_type=".pdf$"
            source_file_type="\(PDF\|pdf\)"
        fi

        exclusion=false

        if echo "${SearchPraefix}" | grep -qE '^!' ; then
            # is the prefix / suffix an exclusion criterion?
            exclusion=true
##          SearchPraefix=$(echo "${SearchPraefix}" | sed -e 's/^!//')
            SearchPraefix="${SearchPraefix#!}"
        fi

        if echo "${SearchPraefix}" | grep -q "\$"$ ; then
            # is suffix
##          SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            SearchPraefix="${SearchPraefix%?}"
            if [[ "$exclusion" = false ]] ; then
##              count_input_file=$(( $(ls -tp "${INPUTDIR}" | grep -vE '/$' | grep -iEc "^.*${SearchPraefix}(${source_file_type})") + count_input_file ))
                count_input_file=$(( $(find "${INPUTDIR}" -maxdepth 1 -regex "${INPUTDIR}.*${SearchPraefix}\.${source_file_type}$" -type f -printf '.' | wc -c ) + count_input_file ))
            elif [[ "$exclusion" = true ]] ; then
##              count_input_file=$(( $(ls -tp "${INPUTDIR}" | grep -vE '/$' | grep -iE "^.*(${source_file_type})" | cut -f 1 -d '.' | grep -ivEc "${SearchPraefix}$") + count_input_file ))
                count_input_file=$(( $(find "${INPUTDIR}" -maxdepth 1 -regex "${INPUTDIR}.*\.${source_file_type}$" -not -iname "*${SearchPraefix}.*" -type f -printf '.' | wc -c ) + count_input_file ))
            fi
        else
            # is prefix
##          SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            SearchPraefix="${SearchPraefix%%\$}"
            if [[ "$exclusion" = false ]] ; then
##              count_input_file=$(( $(ls -tp "${INPUTDIR}" | grep -vE '/$' | grep -iEc "^${SearchPraefix}.*(${source_file_type})") + count_input_file ))
                count_input_file=$(( $(find "${INPUTDIR}" -maxdepth 1 -regex "${INPUTDIR}${SearchPraefix}.*\.${source_file_type}$" -type f -printf '.' | wc -c ) + count_input_file ))
            elif [[ "$exclusion" = true ]] ; then
##              count_input_file=$(( $(ls -tp "${INPUTDIR}" | grep -vE '/$' | grep -iE "^.*(${source_file_type})" | grep -ivEc "^${SearchPraefix}.*(${source_file_type})") + count_input_file ))
                count_input_file=$(( $(find "${INPUTDIR}" -maxdepth 1 -regex "${INPUTDIR}.*\.${source_file_type}$" -not -iname "${SearchPraefix}*" -type f -printf '.' | wc -c ) + count_input_file ))
            fi
        fi
    done <<< "$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT INPUTDIR, SearchPraefix, img2pdf FROM config WHERE active='1' ")"

# manual synOCR start:
# ---------------------------------------------------------------------
    if [[ "$page" == "main-run-synocr" ]]; then
        echo '
        <div class="Content_1Col_full">'
            /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh GUI
            echo '
            <meta http-equiv="refresh" content="2; URL=index.cgi?page=main">
        </div>'
    fi

# manual synOCR start monitoring:
# ---------------------------------------------------------------------
    if [[ "$page" == "main-run-synocr-monitoring" ]]; then
        /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh start >/dev/null 2>&1 &

        echo '
        <div class="Content_1Col_full" style="font-size: 0.8rem; color: #808080;">'"${lang_main_reload_manualy}"' ...
            <meta http-equiv="refresh" content="0; URL=index.cgi?page=main">
        </div>'
    fi

# manual synOCR stop monitoring:
# ---------------------------------------------------------------------
    if [[ "${page}" == "main-stop-synocr-monitoring" ]]; then
        /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh stop >/dev/null 2>&1 &
       
        echo '
        <div class="Content_1Col_full" style="font-size: 0.8rem; color: #808080;">'"${lang_main_reload_manualy}"' ...
            <meta http-equiv="refresh" content="0; URL=index.cgi?page=main">
        </div>'
    fi

# Force synOCR exit:
# ---------------------------------------------------------------------
    if [[ "${page}" == "main-kill-synocr" ]]; then
        killall synOCR.sh
        docker stop -t 0 synOCR > /dev/null  2>&1
        echo '<meta http-equiv="refresh" content="0; URL=index.cgi?page=main">'
    fi

# check inotifywait:
# ---------------------------------------------------------------------
    [ "$(which inotifywait)" ] && inotify_tools_ready=1 || inotify_tools_ready=0

# Body:
# ---------------------------------------------------------------------
if [[ "${page}" == "main" ]] || [[ "${page}" == "" ]]; then
    # -> Headline

    echo '
    <h2 class="synocr-text-blue mt-3">synOCR '"${lang_page1}"'</h2>'
#   echo '<p>&nbsp;</p>'

    # monitoring active?:
##  if [ $(ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk -F' ' '{print $2}') ]; then
    PID=$(ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk -F' ' '{print $2}')
    if [ -n "${PID}" ]; then
        # pulsate icon, if monitoring are running
        css_pulsate='class="pulsate"'
        monitoring_title='title="monitoring is running"'
##      monitoring_state=1
##      monitoring_user=$(ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk -F' ' '{print $1}')
        monitoring_user=$(ps -p "${PID}" -o user=)

        # check if the list of watched folders is still up to date:
        monitored_folders="/usr/syno/synoman/webman/3rdparty/synOCR/etc/inotify.list"
        sqlite3 /usr/syno/synoman/webman/3rdparty/synOCR/etc/synOCR.sqlite "SELECT INPUTDIR FROM config WHERE active='1'" 2>/dev/null | sort | uniq > "${monitored_folders}_tmp"

        if [ "$(cat "${monitored_folders}" 2>/dev/null)" != "$(cat "${monitored_folders}_tmp")" ]; then
            if [ "${dsmMajorVersion}" -ge 7 ] && [ "$monitoring_user" = root ]; then
                # if inotify was started by root, it cannot be restarted by the user synOCR via the GUI
                echo ' 
                <h5 class="text-center pulsate" style="font-size: 0.7rem;">
                    '"${lang_main_monitor_restart_necessary_1}"'<br>
                    '"${lang_main_monitor_restart_necessary_2}"'<br>
                    '"${lang_main_monitor_restart_necessary_3}"'<br>
                </h5>'
            else
                nohup /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh start >/dev/null 2>&1 &
            fi
        fi
        rm -f "${monitored_folders}_tmp"
    else
        # pulsate icon, if monitoring are running
        css_pulsate=""
        monitoring_title='title="monitoring is not running"'
##      monitoring_state=0
    fi

#   notify about update, if necessary:
# ---------------------------------------------------------------------
    if [ "$(grep "^beta" /var/packages/synOCR/INFO | cut -d '"' -f2)" = yes ]; then
        release_channel=beta
    else
        release_channel=release
    fi
    server_info=$(wget --no-check-certificate --timeout=20 --tries=3 -q -O - "https://geimist.eu/synOCR/updateserver.php?file=VERSION" )
#   online_version=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='online_version'")
    online_version=$(echo "${server_info}" | jq -r .dsm.dsm"${dsmMajorVersion}"."${release_channel}".version )
    downloadUrl=$(echo "${server_info}" | jq -r .dsm.dsm"${dsmMajorVersion}"."${release_channel}".downloadUrl )
    changeLogUrl=$(echo "${server_info}" | jq -r .dsm.dsm"${dsmMajorVersion}"."${release_channel}".changeLogUrl )

    local_version=$(grep "^version" /var/packages/synOCR/INFO  | cut -d '"' -f2)
    highest_version=$(printf "%s\n%s" "${online_version}" "${local_version}" | sort -V | tail -n1)
    if [[ "${local_version}" != "${highest_version}" ]] ; then
        echo ' 
        <h5 class="text-center">
            <a href="'"${downloadUrl}"'" onclick="window.open(this.href); return false;" class="pulsate" style="font-size: 0.7rem;">'"${lang_main_update_available}"' [DOWNLOAD VERSION '"${online_version}"' </a>
                <span class="pulsate" style="font-size: 0.7rem;">/</span>
            <a href="'"${changeLogUrl}"'" onclick="window.open(this.href); return false;" class="pulsate" style="font-size: 0.7rem;"> CHANGELOG]</a>
        </h5>'
    fi

    echo '
    <h5 class="text-center">
        <strong class="synocr-text-red">'"${lang_main_title1}"'</strong>
    </h5>'

# check Docker:
    if [ ! "$(which docker)" ]; then
##      permissions_ready=0
        echo '
        <p class="text-center synocr-text-red mb-5">'"${lang_attention}"':<br>'"${lang_main_dockerfailed1}"'<br>'"${lang_main_dockerfailed2}"'</p>
        <div class="float-end">
            <img src="images/status_error@geimist.svg" height="120" width="120" style="padding: 10px">
        </div>'
    elif [ "${dsmMajorVersion}" -ge 7 ] && (! grep "^administrators" /etc/group | grep -q synOCR || ! grep "^docker:" /etc/group | grep -q synOCR ); then
##      permissions_ready=0
        echo '
        <p class="text-center synocr-text-red">'"${lang_attention}"':<br>'"${lang_main_permissions_failed1}"'<br>'"${lang_main_permissions_failed2}"'<br>('"${lang_main_permissions_failed3}"')
            <code class="mb-5">/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh</code>
        </p>
        <div class="float-end">
            <img src="images/status_error@geimist.svg" height="120" width="120" style=";padding: 10px">
        </div>'
    elif [[ "$count_input_file" == 0 ]]; then
##      permissions_ready=1
        # remove dockercontainer & image synocr_helper
        docker container rm synocr_helper >/dev/null 2>&1
        docker image rm synocr_helper_image >/dev/null 2>&1
        echo '
        <div class="float-end">
            <img src="images/status_green@geimist.svg" height="120" width="120" style="padding: 10px" '"${css_pulsate}"' '"${monitoring_title}"'>
        </div>'
    else
##      permissions_ready=1
        # remove dockercontainer & image synocr_helper
        docker container rm synocr_helper >/dev/null 2>&1
        docker image rm synocr_helper_image >/dev/null 2>&1
        echo '
        <div class="float-end">
            <img src="images/sanduhr_blue@geimist.svg" height="120" width="120" style="padding: 10px" '"${css_pulsate}"' '"${monitoring_title}"'>
        </div>'
    fi

    echo '
    <p>&nbsp;</p>
    <h2 class="synocr-text-blue">'"${lang_main_title2}"':</h2>
    <p>&nbsp;</p>
    <p>'"${lang_main_desc1}"'</p>
    <p>'"${lang_main_desc2}"'</p>'
#   echo '<p>&nbsp;</p>'

# show start button, if DSM is DSM6 or user synOCR is in groups administrators AND docker:
##  if [ "${dsmMajorVersion}" -eq 6 ] || (grep "^administrators" /etc/group | grep -q synOCR && grep "^docker" /etc/group | grep -q synOCR) ; then
    if [ "${dsmMajorVersion}" -eq 6 ] || { grep "^administrators" /etc/group | grep -q synOCR && grep "^docker" /etc/group | grep -q synOCR ; } ; then
        if [ "${inotify_tools_ready}" -eq 0 ]; then 
            # start single run:
            echo '
            <p class="text-center">
                <button name="page" class="btn btn-primary" style="background-color: #0086E5;" value="main-run-synocr">'"${lang_main_buttonrun}"'</button>
                <p class="text-center">'"${lang_help_QS_1b}"' (<a href="https://synocommunity.com/package/inotify-tools" onclick="window.open(this.href); return false;" style="'"${synocrred}"';"><b>'"${lang_foot_buttondownDB}"' Inotify-Tools</b></a>)</p>                
            </p><br />'
        elif [ "${inotify_tools_ready}" -eq 1 ] && { [ "${dsmMajorVersion}" -eq 6 ] || [ "${monitoring_user}" != root ]; }; then 
            if [ -n "${PID}" ]; then
                # stop / (re-)start monitoring:
                echo '
                <p class="text-center">
                    <button name="page" class="btn btn-primary" style="background-color: #0086E5;" value="main-run-synocr-monitoring">'"${lang_main_button_restart_monitoring}"'</button>
                    <button name="page" class="btn btn-white" style="color: #FFFFFF; background-color: #BD0010;" value="main-stop-synocr-monitoring">'"${lang_main_button_stop_monitoring}"'</button>
                </p><br />'
            else
                # start monitoring:
                echo '
                <p class="text-center">
                    <button name="page" class="btn btn-primary" style="background-color: #0086E5;" value="main-run-synocr-monitoring">'"${lang_main_button_start_monitoring}"'</button>
                </p><br />'
            fi
        elif [ "${monitoring_user}" = root ] && [ -n "${PID}" ]; then 
            # if running under root, controlling over GUI is not possible:
            echo '
            <br /><p style="'"${synocrred}"';"><b>'"${lang_main_desc3}"':</b></p>
            <p>'"${lang_main_desc4}"'</p>'
            # start single run:
        #    echo '
        #    <br><p class="text-center">
        #        <button name="page" class="btn btn-primary" style="background-color: #0086E5;" value="main-run-synocr">'"${lang_main_buttonrun}"'</button>
        #        <p class="text-center">'"${lang_help_QS_1b}"' (<a href="https://synocommunity.com/package/inotify-tools" onclick="window.open(this.href); return false;" style="'"${synocrred}"';"><b>'"${lang_foot_buttondownDB}"' Inotify-Tools</b></a>)</p>                
        #    </p><br />'
        fi
    fi

# Section Status / Statistics:
echo '
<div class="accordion" id="Accordion-01">
    <div class="accordion-item border-start-0 border-end-0" style="border-style: dashed none dashed none; size: 1px;">
        <h2 class="accordion-header" id="Heading-01">
            <button class="accordion-button collapsed bg-white synocr-accordion-glow-off" type="button" data-bs-toggle="collapse" data-bs-target="#Collapse-01" aria-expanded="false" aria-controls="collapseTwo">
                <span class="synocr-text-blue">'"${lang_main_statshead}"':</span>
            </button>
        </h2>
        <div id="Collapse-01" class="accordion-collapse collapse border-white" aria-labelledby="Heading-01" data-bs-parent="#Accordion-01">
            <div class="accordion-body">
                <table class="table table-borderless" style="width: 70%;">
                    <thead">
                        <tr>
                            <th scope="col">'"${lang_main_openjobs}"':</th>
                            <th scope="col">&nbsp;</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>'
                            if [[ "${count_input_file}" == 0 ]]; then
                                echo '
                                <td class="synocr-text-blue">'"${lang_main_openfilecount}"':</td>
                                <td class="synocr-text-green">'"${lang_main_alldone}"'</td>'
                            else
                                echo '
                                <td class="synocr-text-blue">'"${lang_main_openfilecount}"': </td>
                                <td class="synocr-text-red">'"${count_input_file}"'</td>'
                            fi
                            echo '
                        </tr>
                        <tr>
                            <td class="synocr-text-blue">'"${lang_main_totalsince}"' '"$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='count_start_date'")"' (PDF / '"${lang_main_pages}"'):</td>
                            <td class="synocr-text-green">'"$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_ocrcount'")"' / '"$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_pagecount'")"'</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>


        <!-- <p>Hier soll in Zukunft noch eine Statusübersicht / Statistik zu finden sein …<br>
        - https://developers.google.com/chart/interactive/docs/quick_start<br>
        - http://jsfiddle.net/api/post/jquery/1.6/ (http://elycharts.com/examples) </p>
        <br><div class="tab"><p>'"${dbinfo}"'</p></div>-->'

fi
