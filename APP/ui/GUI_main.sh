#!/bin/bash
# shellcheck disable=SC2009,SC2154

#################################################################################
#   description:    - generates the main page for the GUI                       #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/main.sh            #
#   © 2026 by geimist                                                           #
#################################################################################

PATH=$PATH:/usr/local/bin:/opt/usr/bin
dsm_major=$(grep "^majorversion" /etc.defaults/VERSION | cut -d '"' -f2 )

# Read file status:
# ---------------------------------------------------------------------
    count_input_file=$(synocr_count_input_files)

    # Live progress: initial render server-side; bars/icon/open-file count via synocr-progress.js
    synocr_progress_compute
    _synocr_progress_style="display:none;"
    if [ "${synocr_pg_running:-0}" -eq 1 ]; then
        _synocr_progress_style=""
    fi

    _synocr_open_files_row_style="display:none;"
    if [ "${count_input_file:-0}" -gt 0 ] && [ "${synocr_pg_running:-0}" -eq 0 ]; then
        _synocr_open_files_row_style=""
    fi

    _pg_display_file="-"
    [ -n "${synocr_pg_file}" ] && _pg_display_file="${synocr_pg_file}"
    _pg_display_step="-"
    [ -n "${synocr_pg_step_label}" ] && _pg_display_step="${synocr_pg_step_label}"
    _pg_step_fraction=""
    if [ "${synocr_pg_step_total:-0}" -gt 0 ]; then
        _pg_step_fraction="(${synocr_pg_step_index:-0}/${synocr_pg_step_total}) "
    fi
    _pg_files_label=$(synocr_lang_fill_x "${lang_main_progress_files}" done "${synocr_pg_files_done:-0}" total "${synocr_pg_files_total:-0}")

    _pg_files_bar_class="progress-bar"
    _pg_file_bar_class="progress-bar bg-info"
    if [ "${synocr_pg_running:-0}" -eq 1 ]; then
        _pg_files_bar_class="progress-bar progress-bar-striped progress-bar-animated"
        _pg_file_bar_class="progress-bar bg-info progress-bar-striped progress-bar-animated"
    fi

    _pg_profile_style="display:none;"
    _pg_profile_text=""
    if [ -n "${synocr_pg_profile}" ]; then
        _pg_profile_style=""
        _pg_profile_text="${synocr_pg_profile}"
    fi

    synocr_progress_config_json=$(jq -n \
        --arg statusUrl "index.cgi?page=main-status" \
        --arg filesTpl "${lang_main_progress_files}" \
        --arg iconIdle "images/status_green@geimist.svg" \
        --arg iconBusy "images/sanduhr_blue@geimist.svg" \
        --arg allDoneText "${lang_main_alldone}" \
        --arg doneStepText "${lang_main_progress_step_cleanup:-${lang_main_alldone}}" \
        --arg profileLabel "${lang_edit_profname}" \
        --argjson pollMs 2500 \
        --argjson doneHoldMs 5000 \
        --argjson doneFadeMs 800 \
        '{statusUrl:$statusUrl,filesTpl:$filesTpl,iconIdle:$iconIdle,iconBusy:$iconBusy,allDoneText:$allDoneText,doneStepText:$doneStepText,profileLabel:$profileLabel,pollMs:$pollMs,doneHoldMs:$doneHoldMs,doneFadeMs:$doneFadeMs}' 2>/dev/null) || synocr_progress_config_json=""

# manual synOCR start:
# ---------------------------------------------------------------------
    if [[ "${synocr_request_page}" == "main-run-synocr" ]]; then
        nohup /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh run >/dev/null 2>&1 &
        echo '<meta http-equiv="refresh" content="0; URL=index.cgi?page=main">'
    fi

# manual synOCR start/stop monitoring: wait page with spinner, then -run page in index.cgi
# ---------------------------------------------------------------------
    if [[ "${synocr_request_page}" == "main-run-synocr-monitoring" ]] || [[ "${synocr_request_page}" == "main-stop-synocr-monitoring" ]]; then
        _synocr_mon_run_page="${synocr_request_page}-run"
        if [[ "${synocr_request_page}" == "main-stop-synocr-monitoring" ]]; then
            _synocr_mon_wait_text="${lang_main_button_stop_monitoring} …"
        elif [ -n "$(ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk -F' ' '{print $2}' | head -n1)" ]; then
            _synocr_mon_wait_text="${lang_main_button_restart_monitoring} …"
        else
            _synocr_mon_wait_text="${lang_main_button_start_monitoring} …"
        fi
        echo '
    <h2 class="synocr-text-blue mt-3">synOCR '"${lang_page1}"'</h2>
    <div class="Content_1Col_full text-center">
        <p class="mt-4 mb-3 px-2" style="font-size: 0.95rem;">'"${_synocr_mon_wait_text}"'</p>
        <div class="mb-4"><img src="images/status_loading.gif" width="32" height="32" alt="" role="presentation"></div>
        <p class="text-muted small mb-3"><a href="index.cgi?page='"${_synocr_mon_run_page}"'">'"${lang_main_update_repo_feed_wait_fallback_link}"'</a></p>
        <noscript><p class="small"><a href="index.cgi?page='"${_synocr_mon_run_page}"'">'"${lang_main_update_repo_feed_wait_fallback_link}"'</a></p></noscript>
        <script>setTimeout(function(){ window.location.replace("index.cgi?page='"${_synocr_mon_run_page}"'"); }, 150);</script>
    </div>'
    fi

# Force synOCR exit:
# ---------------------------------------------------------------------
    if [[ "${synocr_request_page}" == "main-kill-synocr" ]]; then
        killall synOCR.sh
        docker stop -t 0 synOCR > /dev/null  2>&1
        synocr_status_clear
        echo '<meta http-equiv="refresh" content="0; URL=index.cgi?page=main">'
    fi

# configure DSM package feed (synOCR repo) via Docker:
# ---------------------------------------------------------------------
    if [[ "${synocr_request_page}" == "main-setup-repo-feed" ]]; then
        echo '
    <h2 class="synocr-text-blue mt-3">synOCR '"${lang_page1}"'</h2>
    <div class="Content_1Col_full text-center">
        <p class="mt-4 mb-3 px-2" style="font-size: 0.95rem;">'"${lang_main_update_repo_feed_wait_prepare}"'</p>
        <div class="mb-4"><img src="images/status_loading.gif" width="32" height="32" alt="" role="presentation"></div>
        <p class="text-muted small mb-3"><a href="index.cgi?page=main-setup-repo-feed-run">'"${lang_main_update_repo_feed_wait_fallback_link}"'</a></p>
        <noscript><p class="small"><a href="index.cgi?page=main-setup-repo-feed-run">'"${lang_main_update_repo_feed_wait_fallback_link}"'</a></p></noscript>
        <script>setTimeout(function(){ window.location.replace("index.cgi?page=main-setup-repo-feed-run"); }, 150);</script>
    </div>'
    fi

    if [[ "${synocr_request_page}" == "main-setup-repo-feed-run" ]]; then
        echo '
    <h2 class="synocr-text-blue mt-3">synOCR '"${lang_page1}"'</h2>
    <div class="Content_1Col_full">
        <p class="text-center mt-3 mb-2 px-2" style="font-size: 0.95rem;">'"${lang_main_update_repo_feed_wait_working}"'</p>
        <div id="synocr-feed-wait-spinner" class="text-center mb-3"><img src="images/status_loading.gif" width="32" height="32" alt="" role="presentation"></div>'
        setup_version_info=""
        setup_repo_config_ready=0
        if setup_version_info=$(synocr_fetch_version_json --connect-timeout 10 --max-time 20); then
            synocr_version_parse_package_repo "${setup_version_info}" setup_repo_
        fi
        setup_msg="lang_main_update_repo_feed_setup_error_unknown"
        setup_rc=""
        if [ "${setup_repo_config_ready}" -ne 1 ]; then
            setup_msg="lang_main_update_repo_feed_setup_error_config"
        elif [ ! "$(which docker)" ]; then
            setup_msg="lang_main_update_repo_feed_setup_error_no_docker"
        elif ! docker info >/dev/null 2>&1; then
            setup_msg="lang_main_update_repo_feed_setup_error_no_docker"
        else
            export SYNOCR_APP_HOME="${app_home}"
            export SYNOCR_REPO_NAME="${setup_repo_name}"
            export SYNOCR_REPO_FEED="${setup_repo_feed_url}"
            export SYNOCR_REPO_HOST_PATTERN="${setup_repo_host_pattern}"
#            chmod +x ./synocr-setup-package-feed.sh 2>/dev/null

            ./includes/synocr-setup-package-feed.sh

            setup_rc=$?
            case "${setup_rc}" in
                0) setup_msg="lang_main_update_repo_feed_setup_success" ;;
                7) setup_msg="lang_main_update_repo_feed_setup_msg_already" ;;
                2) setup_msg="lang_main_update_repo_feed_setup_error_no_docker" ;;
                3) setup_msg="lang_main_update_repo_feed_setup_error_feeds_read" ;;
                4) setup_msg="lang_main_update_repo_feed_setup_error_feeds_json" ;;
                5) setup_msg="lang_main_update_repo_feed_setup_error_merge" ;;
                6) setup_msg="lang_main_update_repo_feed_setup_error_docker" ;;
                8) setup_msg="lang_main_update_repo_feed_setup_error_config" ;;
                *) setup_msg="lang_main_update_repo_feed_setup_error_unknown" ;;
            esac
        fi
        setup_msg_text="${!setup_msg}"
        alert_class="danger"
        case "${setup_rc:-}" in
            0) alert_class="success" ;;
            7) alert_class="info" ;;
        esac
        if [ "${setup_msg}" = "lang_main_update_repo_feed_setup_error_config" ]; then
            alert_class="warning"
        fi
        echo '
        <div class="alert alert-'"${alert_class}"' mt-2 mb-3" role="alert" style="font-size: 0.9rem;">'"${setup_msg_text}"'</div>
        <p class="text-center text-muted" style="font-size: 0.85rem;">'"${lang_main_reload_manualy}"'</p>
        <meta http-equiv="refresh" content="6; URL=index.cgi?page=main">'
        if [ "${setup_rc:-}" = 0 ] || [ "${setup_rc:-}" = 7 ]; then
        echo '<script>(function(){var s=document.getElementById("synocr-feed-wait-spinner");if(s)s.style.display="none";})();</script>'
        fi
        echo '
    </div>'
    fi

# check inotifywait:
# ---------------------------------------------------------------------
    [ "$(which inotifywait)" ] && inotify_tools_ready=1 || inotify_tools_ready=0

# Body:
# ---------------------------------------------------------------------
if [[ "${synocr_request_page}" == "main" ]] || [[ "${synocr_request_page}" == "" ]]; then
    # -> Headline

    echo '
    <h2 class="synocr-text-blue mt-3">synOCR '"${lang_page1}"'</h2>'

    echo '
    <h5 class="text-center">
        <strong class="synocr-text-red">'"${lang_main_title1}"'</strong>
    </h5>'

    # monitoring active?:
    PID=$(ps aux | grep -v "grep" | grep -E "inotifywait.*--fromfile.*inotify.list" | awk -F' ' '{print $2}')
    if [ -n "${PID}" ]; then
        # pulsate icon, if monitoring are running
        css_pulsate='class="pulsate"'
        monitoring_title='title="monitoring is running"'
        monitoring_user=$(ps -p "${PID}" -o user=)

        # check if the list of watched folders is still up to date:
        monitored_folders="/usr/syno/synoman/webman/3rdparty/synOCR/etc/inotify.list"
        synocr_sqlite "SELECT INPUTDIR FROM config WHERE active='1'" 2>/dev/null | sort | uniq > "${monitored_folders}_tmp"

        if [ "$(cat "${monitored_folders}" 2>/dev/null)" != "$(cat "${monitored_folders}_tmp")" ]; then
            if [ "${dsm_major}" -ge 7 ] && [ "$monitoring_user" = root ]; then
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
    fi

#   notify about update, if necessary:
# ---------------------------------------------------------------------
    release_channel=$(synocr_release_channel)

    version_info=""
    server_info=""
    repo_feed_url=""
    repo_name=""
    repo_host_pattern=""
    repo_setup_guide_image=""
    repo_config_ready=0
    if version_info=$(synocr_fetch_version_json); then
        server_url=$(synocr_version_server_url "${version_info}")
        server_info=$(synocr_server_fetch_version_info "${server_url}")
        synocr_version_parse_package_repo "${version_info}"
    fi
    online_version=$(echo "${server_info}" | jq -r .dsm.dsm"${dsm_major}"."${release_channel}".version )
    downloadUrl=$(echo "${server_info}" | jq -r .dsm.dsm"${dsm_major}"."${release_channel}".downloadUrl )
    changeLogUrl=$(echo "${server_info}" | jq -r .dsm.dsm"${dsm_major}"."${release_channel}".changeLogUrl )

    local_version=$(grep "^version" /var/packages/synOCR/INFO  | cut -d '"' -f2)
    highest_version=$(printf "%s\n%s" "${online_version}" "${local_version}" | sort -V | tail -n1)
    if [[ "${local_version}" != "${highest_version}" ]] ; then
        echo ' 
        <h5 class="text-center">
            <a href="'"${downloadUrl}"'" onclick="window.open(this.href); return false;" class="pulsate" style="font-size: 0.7rem;">'"${lang_main_update_available}"' [DOWNLOAD '"${local_version}"' ➜ '"${online_version}"' </a>
                <span class="pulsate" style="font-size: 0.7rem;">/</span>
            <a href="'"${changeLogUrl}"'" onclick="window.open(this.href); return false;" class="pulsate" style="font-size: 0.7rem;"> CHANGELOG]</a>
        </h5>'
    fi

    repo_feed_missing=0
    if [ "$(synocr_package_repo_feed_status "${repo_feed_url}" "${repo_host_pattern}" "${repo_config_ready}")" = missing ]; then
        repo_feed_missing=1
    fi

    repo_auto_setup_docker_ok=0
    if [ "$(which docker)" ]; then
        if [ "${dsm_major}" -lt 7 ] || { grep "^administrators" /etc/group | grep -q synOCR && grep "^docker:" /etc/group | grep -q synOCR; }; then
            repo_auto_setup_docker_ok=1
        fi
    fi

    if [ "${repo_feed_missing}" -eq 1 ]; then
        echo '
        <div class="alert alert-warning mt-2 mb-2" role="alert" style="font-size: 0.85rem;">
            <details>
                <summary><strong>'"${lang_main_update_repo_missing_title}"'</strong></summary>
                <div class="mt-2">
                    '"${lang_main_update_repo_missing_desc1}"'<br>
                    '"${lang_main_update_repo_missing_desc2}"'<br>
                    <br>'
        if [ "${repo_auto_setup_docker_ok}" -eq 1 ]; then
        echo '
                    <p class="mb-2"><b>'"${lang_main_update_repo_missing_before_auto}"'</b></p>
                    <p class="text-center mb-3">
                        <button name="page" type="submit" class="btn btn-sm btn-primary" value="main-setup-repo-feed">'"${lang_main_update_repo_missing_button_auto_setup}"'</button>
                    </p>'
        fi
        echo '
                    <b>'"${lang_main_update_repo_missing_steps_title}"'</b><br>
                    1. '"${lang_main_update_repo_missing_step1}"'<br>
                    2. '"${lang_main_update_repo_missing_step2}"'<br>
                    3. '"${lang_main_update_repo_missing_step3}"'<br>
                    4. '"${lang_main_update_repo_missing_step4}"'<br>
                    5. '"${lang_main_update_repo_missing_step5}"' <code>'"${repo_feed_url}"'</code><br>
                    <p class="mt-2 mb-0 text-center">
                        <button type="button" class="btn btn-sm btn-outline-secondary" data-bs-toggle="modal" data-bs-target="#spkrepoGuideModal">'"${lang_main_update_repo_missing_button_guide}"'</button>
                    </p>
                </div>
            </details>
        </div>

        <div class="modal fade" id="spkrepoGuideModal" tabindex="-1" aria-hidden="true">
            <div class="modal-dialog modal-dialog-centered modal-xl">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">'"${lang_main_update_repo_missing_modal_title}"'</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <div class="modal-body text-center">
                        <img id="spkrepoGuideImage" data-src="'"${repo_setup_guide_image}"'" alt="'"${lang_main_update_repo_missing_modal_img_alt}"'" style="max-width: 100%; height: auto;">
                    </div>
                </div>
            </div>
        </div>
        <script>
            document.addEventListener("DOMContentLoaded", function () {
                var guideModal = document.getElementById("spkrepoGuideModal");
                if (!guideModal) { return; }
                guideModal.addEventListener("shown.bs.modal", function () {
                    var guideImage = document.getElementById("spkrepoGuideImage");
                    if (guideImage && !guideImage.getAttribute("src")) {
                        guideImage.setAttribute("src", guideImage.getAttribute("data-src"));
                    }
                });
            });
        </script>'
    fi


# check Docker and show indicator icon:
    if [ ! "$(which docker)" ]; then
        echo '
        <p class="text-center synocr-text-red mb-5">'"${lang_attention}"':<br>'"${lang_main_dockerfailed1}"'<br>'"${lang_main_dockerfailed2}"'</p>
        <div class="float-end">
            <img src="images/status_error@geimist.svg" height="120" width="120" style="padding: 10px">
        </div>'
    elif [ "${dsm_major}" -ge 7 ] && (! grep "^administrators" /etc/group | grep -q synOCR || ! grep "^docker:" /etc/group | grep -q synOCR ); then
        echo '
        <p class="text-center synocr-text-red">'"${lang_attention}"':<br>'"${lang_main_permissions_failed1}"'<br>'"${lang_main_permissions_failed2}"'<br>('"${lang_main_permissions_failed3}"')
            <code class="mb-5">/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh</code>
        </p>
        <div class="float-end">
            <img src="images/status_error@geimist.svg" height="120" width="120" style=";padding: 10px">
        </div>'
    elif [[ "$count_input_file" == 0 ]]; then
        # remove dockercontainer & image synocr_helper
        docker container rm synocr_helper >/dev/null 2>&1
        docker image rm synocr_helper_image >/dev/null 2>&1
        echo '
        <div class="float-end">
            <img id="synocr-main-status-icon" src="images/status_green@geimist.svg" height="120" width="120" style="padding: 10px" '"${css_pulsate}"' '"${monitoring_title}"' alt="">
        </div>'
    else
        # remove dockercontainer & image synocr_helper
        docker container rm synocr_helper >/dev/null 2>&1
        docker image rm synocr_helper_image >/dev/null 2>&1
        echo '
        <div class="float-end">
            <img id="synocr-main-status-icon" src="images/sanduhr_blue@geimist.svg" height="120" width="120" style="padding: 10px" '"${css_pulsate}"' '"${monitoring_title}"' alt="">
        </div>'
    fi

    echo '
    <p>&nbsp;</p>
    <h2 class="synocr-text-blue">'"${lang_main_title2}"':</h2>
    <p>&nbsp;</p>
    <p>'"${lang_main_desc1}"'</p>
    <p>'"${lang_main_desc2}"'</p>'

# validate input directories:
    invalid_input_dir=""
    active_dirs_json=$(synocr_sqlite -json "SELECT INPUTDIR, profile FROM config WHERE active='1'" 2>/dev/null)
    while IFS= read -r row; do
        dir=$(synocr_jq_row_field "${row}" INPUTDIR)
        profilename=$(synocr_jq_row_field "${row}" profile)
        [ ! -d "${dir}" ] && invalid_input_dir="${invalid_input_dir}${profilename} ${dir}<br>"
    done < <(synocr_jq_rows "${active_dirs_json}") 

# show start button, if DSM is DSM6 or user synOCR is in groups administrators AND docker:
    if [ "${dsm_major}" -eq 6 ] || { grep "^administrators" /etc/group | grep -q synOCR && grep "^docker" /etc/group | grep -q synOCR ; } ; then
        if [ "${inotify_tools_ready}" -eq 0 ]; then 
            # start single run:
            echo '
            <p class="text-center">
                <button name="page" class="btn btn-primary" style="background-color: #0086E5;" value="main-run-synocr">'"${lang_main_buttonrun}"'</button>
                <p class="text-center">'"${lang_help_QS_1b}"' (<a href="https://synocommunity.com/package/inotify-tools" onclick="window.open(this.href); return false;" style="'"${synocrred}"';"><b>'"${lang_foot_buttondownDB}"' Inotify-Tools</b></a>)</p>                
            </p><br />'
        elif [ "${inotify_tools_ready}" -eq 1 ] && { [ "${dsm_major}" -eq 6 ] || [ "${monitoring_user}" != root ]; }; then 
            if [ -n "${invalid_input_dir}" ]; then
                # warn if invalid source directories are present:
                echo '<hr></hr><p class="synocr-text-red">'"${lang_main_invalid_input_dir}"'<br>'
                echo '<code class="mb-5">'"${invalid_input_dir}"'</code></p>'
            else
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

# Status / statistics (progress while running; open-file count only when queued and idle)
echo '
<div id="synocr-status-stats" class="mb-3">
    <p class="synocr-text-blue mb-2"><strong>'"${lang_main_statshead}"'</strong></p>
    <div id="synocr-progress" class="mb-2" style="'"${_synocr_progress_style}"'">
        <div class="d-flex align-items-center justify-content-between mb-1 synocr-progress-files-header">
            <label class="small text-muted mb-0" id="synocr-progress-files-label">'"${_pg_files_label}"'</label>
            <svg id="synocr-progress-done-ring" class="synocr-progress-done-ring" viewBox="0 0 20 20" width="20" height="20" aria-hidden="true">
                <circle class="synocr-progress-done-ring__track" cx="10" cy="10" r="8" fill="none"></circle>
                <circle class="synocr-progress-done-ring__arc" cx="10" cy="10" r="8" fill="none"></circle>
            </svg>
        </div>
        <div class="synocr-progress-details small text-muted">
            <div class="synocr-progress-detail-row mb-1">
                <span class="synocr-progress-detail-label synocr-text-blue">'"${lang_main_progress_current_file}"'</span>
                <span class="synocr-progress-detail-value" id="synocr-progress-file-name">'"${_pg_display_file}"'</span>
            </div>
            <div class="progress mb-2" style="height: 1.25rem;">
                <div id="synocr-progress-files-bar" class="'"${_pg_files_bar_class}"'" role="progressbar" style="width: '"${synocr_pg_percent_files:-0}"'%;" aria-valuenow="'"${synocr_pg_percent_files:-0}"'" aria-valuemin="0" aria-valuemax="100">'"${synocr_pg_percent_files:-0}"'%</div>
            </div>
            <div class="synocr-progress-detail-row mb-1">
                <span class="synocr-progress-detail-label synocr-text-blue">'"${lang_main_progress_step}"'</span>
                <span class="synocr-progress-detail-value">
                    <span id="synocr-progress-step-fraction">'"${_pg_step_fraction}"'</span><span id="synocr-progress-step-label">'"${_pg_display_step}"'</span>
                </span>
            </div>
            <div class="progress mb-1" style="height: 1.25rem;">
                <div id="synocr-progress-file-bar" class="'"${_pg_file_bar_class}"'" role="progressbar" style="width: '"${synocr_pg_percent_file:-0}"'%;" aria-valuenow="'"${synocr_pg_percent_file:-0}"'" aria-valuemin="0" aria-valuemax="100">'"${synocr_pg_percent_file:-0}"'%</div>
            </div>
            <div id="synocr-progress-profile" class="synocr-progress-detail-row mb-0" style="'"${_pg_profile_style}"'">
                <span class="synocr-progress-detail-label synocr-text-blue">'"${lang_edit_profname}"':</span>
                <span class="synocr-progress-detail-value" id="synocr-progress-profile-value">'"${_pg_profile_text}"'</span>
            </div>
        </div>
    </div>
    <table class="table table-borderless mb-0" style="width: 70%;">
        <tbody>
            <tr id="synocr-open-files-row" style="'"${_synocr_open_files_row_style}"'">
                <td class="synocr-text-blue">'"${lang_main_openfilecount}"':</td>
                <td id="synocr-open-files-value" class="synocr-text-red">'"${count_input_file}"'</td>
            </tr>
            <tr>
                <td class="synocr-text-blue">'"${lang_main_totalsince}"' '"$(synocr_sqlite "SELECT value_1 FROM system WHERE key='count_start_date'")"' (PDF / '"${lang_main_pages}"'):</td>
                <td class="synocr-text-green">'"$(synocr_sqlite "SELECT value_1 FROM system WHERE key='global_ocrcount'")"' / '"$(synocr_sqlite "SELECT value_1 FROM system WHERE key='global_pagecount'")"'</td>
            </tr>
        </tbody>
    </table>
</div>'


fi
