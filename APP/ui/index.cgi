#!/bin/bash
# shellcheck disable=SC1090,SC1091,SC2034,SC2154

#############################################################################################
#   description:    initiate SPK GUI                                                        #
#                                                                                           #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/index.cgi                      #
#   © 2026 by geimist                                                                       #
#############################################################################################


# Initiate system
# ---------------------------------------------------------------------
    machinetyp=$(uname --machine)

    app_name="synOCR"
    app_title="synOCR"
    app_home=$(echo /volume*/@appstore/${app_name}/ui)
    export SYNOCR_APP_HOME="${app_home}"
    app_link=$(echo /webman/3rdparty/${app_name})
    [ ! -d "${app_home}" ] && exit

    # Cache-bust static UI assets: URL changes when any of these files change (avoids stale CSS/JS from browser or proxy cache)
    synocr_asset_ver=0
    for _synocr_f in \
        "${app_home}/template/stylesheet.css" \
        "${app_home}/template/bootstrap/css/bootstrap.min.css" \
        "${app_home}/template/jquery/jquery-3.7.1.min.js" \
        "${app_home}/template/bootstrap/js/bootstrap.bundle.min.js" \
        "${app_home}/template/synocr-progress.js" \
        "${app_home}/template/synocr-rules-editor.js" \
        "${app_home}/template/synocr-folderpicker.js" \
        "${app_home}/template/synocr_namesyntax_editor.js" \
        "${app_home}/template/synocr-regex-assistant.js" \
        "${app_home}/template/synocr-nav.js"
    do
        [ -f "${_synocr_f}" ] || continue
        _synocr_m=$(stat -c %Y "${_synocr_f}" 2>/dev/null)
        [ -z "${_synocr_m}" ] && _synocr_m=$(stat -f %m "${_synocr_f}" 2>/dev/null)
        [ -z "${_synocr_m}" ] && _synocr_m=0
        [ "${_synocr_m}" -gt "${synocr_asset_ver}" ] && synocr_asset_ver=${_synocr_m}
    done
    [ "${synocr_asset_ver}" -eq 0 ] 2>/dev/null && synocr_asset_ver=$(date +%s)
    synocr_asset_q="?v=${synocr_asset_ver}"
    synocr_bootstrap_css_href="template/bootstrap/css/bootstrap.min.css${synocr_asset_q}"
    synocr_stylesheet_href="template/stylesheet.css${synocr_asset_q}"
    synocr_jq_src="template/jquery/jquery-3.7.1.min.js${synocr_asset_q}"
    synocr_bootstrap_js_src="template/bootstrap/js/bootstrap.bundle.min.js${synocr_asset_q}"
    synocr_progress_js_src="template/synocr-progress.js${synocr_asset_q}"
    synocr_rules_editor_js_src="template/synocr-rules-editor.js${synocr_asset_q}"
    synocr_folderpicker_js_src="template/synocr-folderpicker.js${synocr_asset_q}"
    synocr_namesyntax_editor_js_src="template/synocr_namesyntax_editor.js${synocr_asset_q}"
    synocr_regex_assistant_js_src="template/synocr-regex-assistant.js${synocr_asset_q}"
    synocr_nav_js_src="template/synocr-nav.js${synocr_asset_q}"
    unset _synocr_f _synocr_m

# Evaluate app authentication
# --------------------------------------------------------------

    # To evaluate the login.cgi, change REQUEST_METHOD to GET
    if [[ "${REQUEST_METHOD}" == "POST" ]]; then
        REQUEST_METHOD="GET"
        OLD_REQUEST_METHOD="POST"
    fi

    # Read and check the login authorization ( login.cgi )
    syno_login=$(/usr/syno/synoman/webman/login.cgi)
    # Extract sid from login response for JS
    sid=$(echo "${syno_login}" | sed -n 's/.*Set-Cookie: id=\([^;]*\).*/\1/p' | cut -d'=' -f2)

    # Login permission ( result=success )
    if echo ${syno_login} | grep -q result ; then
        login_result=$(echo "${syno_login}" | grep result | cut -d ":" -f2 | cut -d '"' -f2)
    fi
    [[ ${login_result} != "success" ]] && { echo 'Access denied'; exit; }

    # Login successful ( success=true )
    if echo ${syno_login} | grep -q success ; then
        login_success=$(echo "${syno_login}" | grep success | cut -d "," -f3 | grep success | cut -d ":" -f2 | cut -d " " -f2 )
    fi
    [[ ${login_success} != "true" ]] && { echo 'Access denied'; exit; }

    # Set REQUEST_METHOD back to POST again
    if [[ "${OLD_REQUEST_METHOD}" == "POST" ]]; then
        REQUEST_METHOD="POST"
        unset OLD_REQUEST_METHOD
    fi

        
# read MAC-adress (only to hide DEV pages)
# ----------------------------------------------------------
    sysID=$(printf '%010d' "$(cksum </sys/class/net/eth0/address | awk '{print $1}')")


# Load functions from ./includes/functions.sh
# ----------------------------------------------------------
    [ -f "${app_home}/includes/functions.sh" ] && source "${app_home}/includes/functions.sh" || exit

    # Load language settings
    language


# Initiate user folder
# ----------------------------------------------------------
    usersettings="${app_home}/etc"
    if [ ! -d "${usersettings}" ]; then
        mkdir "${usersettings}"
    fi


# Processing of GET request variables
# --------------------------------------------------------------
    set_var="/usr/syno/bin/synosetkeyvalue"
    get_var="/bin/get_key_value"
    var="/tmp/synOCR_var.txt"   # work in RAM
    synocrred="color: #BD0010"
        
    # Backup of the Internal Field Separator (IFS) as well as the separation of 
    # GET/POST key/value requests, by localization of the separator "&".
    if [ -z "${backupIFS}" ]; then
        backupIFS="${IFS}"
        IFS='&'
        # shellcheck disable=SC2086
        set -- $QUERY_STRING
        readonly backupIFS
        IFS="${backupIFS}"
    fi

    # Analyze incoming GET requests and process them into key="$value" variable
    _synocr_page_from_loop=""
    for i in "$@"; do
        IFS="${backupIFS}"
        variable=${i%%=*}
        encode_value=${i##*=}
        decode_value=$(urldecode "${encode_value}")
        if [ "${variable}" = "page" ]; then
            _synocr_page_from_loop="${decode_value}"
        fi
        "${set_var}" "${var}" "${variable}" "${decode_value}"
        "${set_var}" "${var}" "encode_${variable}" "${encode_value}"
    done
    
    if [ -f "${var}" ]; then
        source "${var}"
    fi

    # Route from QUERY_STRING directly — shared /tmp/synOCR_var.txt races with concurrent polls.
    if [ -n "${_synocr_page_from_loop}" ]; then
        synocr_request_page="${_synocr_page_from_loop}"
        page="${_synocr_page_from_loop}"
    else
        synocr_request_page="${page:-}"
    fi
    mainpage=${synocr_request_page%%-*}

    if [ -z "${synocr_request_page}" ]; then
        #[ -f "${var}" ] && rm "${var}"
        mainpage="main"
    fi
    
    "${set_var}" "${var}" "page" ""

    # Live progress JSON for synocr-progress.js (no HTML shell)
    if [ "${synocr_request_page}" = "main-status" ]; then
        cd "${app_home}" || exit 1
        echo "Content-type: application/json"
        echo
        if ! synocr_render_main_status_json; then
            echo '{"state":"error","running":false,"files_remaining":0,"files_total":0,"files_done":0,"percent_files":0,"percent_file":0,"file":"","profile":"","step_id":"","step_label":"","step_index":0,"step_total":0}'
        fi
        exit 0
    fi

    # Monitoring start/stop: sync work on -run pages, then HTTP redirect (before HTML shell).
    if [ "${synocr_request_page}" = "main-run-synocr-monitoring-run" ] || [ "${synocr_request_page}" = "main-stop-synocr-monitoring-run" ]; then
        cd "${app_home}" || exit 1
        _synocr_start_sh="/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh"
        [ -x "${app_home}/synOCR-start.sh" ] && _synocr_start_sh="${app_home}/synOCR-start.sh"
        if [ "${synocr_request_page}" = "main-run-synocr-monitoring-run" ]; then
            "${_synocr_start_sh}" start >/dev/null 2>&1
        else
            "${_synocr_start_sh}" stop >/dev/null 2>&1
        fi
        echo "Status: 302 Found"
        echo "Location: index.cgi?page=main"
        echo "Content-type: text/html"
        echo
        exit 0
    fi

    # Rules API: JSON endpoints (POST) — must run before the HTML shell is emitted.
    if [ "${synocr_request_page}" = "rules-save-json" ]; then
        cd "${app_home}" || exit 1
        [ -f "${app_home}/includes/rules_api.sh" ] && source "${app_home}/includes/rules_api.sh"
        echo "Content-type: application/json"
        echo
        rules_api_save_json
        exit 0
    fi

    if [ "${synocr_request_page}" = "rules-regex-preview" ]; then
        cd "${app_home}" || exit 1
        [ -f "${app_home}/includes/rules_api.sh" ] && source "${app_home}/includes/rules_api.sh"
        echo "Content-type: application/json"
        echo
        rules_api_regex_preview
        exit 0
    fi


# Layout - Open basic framework incl. navigation -
# ----------------------------------------------------------
echo "Content-type: text/html"
echo
# shellcheck disable=SC2016
echo '
<!doctype html>
<html lang="en">
<head>
    <title>'${app_title}'</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1">

        <!-- Include bootstrap framework 5.3.2 -->
        <link rel="stylesheet" href="'${synocr_bootstrap_css_href}'" />

        <!-- Include custom CSS formatting -->
        <link rel="stylesheet" href="'${synocr_stylesheet_href}'" />

        <!-- Include jQuery 3.7.1 -->
        <script src="'${synocr_jq_src}'"></script>
</head>
<meta name="syno_sid" content="${sid}">
<body>
<header></header>
    <article>
        <!-- container -->
        <div class="container-fluid synocr-page">
            <div class="row mt-2 g-0 synocr-layout">
            <script>(function(){try{var r=document.currentScript.parentElement;if(window.localStorage.getItem("synocr_nav_collapsed")==="true")r.classList.add("synocr-layout--nav-collapsed");}catch(e){}})();</script>'

                # Left column - Navigation
                # ------------------------------------------------------
                echo '
                <div class="col-auto border-end border-light border-5 synocr-nav-col">
                    <div class="synocr-nav-inner">
                    <ul class="nav nav-pills flex-column synocr-nav-list">'

                        # Startpage
                        if [[ "${mainpage}" == "main" ]]; then
                            echo '
                            <li class="nav-item">
                                <a class="nav-link active synocr-nav-link" href="index.cgi?page=main" title="'"${lang_page1}"'">
                                    <img class="svg synocr-nav-icon" src="images/home_white@geimist.svg" height="25" width="25" alt=""/><span class="synocr-nav-label">'"${lang_page1}"'</span>
                                </a>
                            </li>'
                        else
                            echo '
                            <li class="nav-item">
                                <a class="nav-link text-secondary synocr-nav-link" href="index.cgi?page=main" title="'"${lang_page1}"'">
                                    <img class="svg synocr-nav-icon" src="images/home_grey3@geimist.svg" height="25" width="25" alt=""/><span class="synocr-nav-label">'"${lang_page1}"'</span>
                                </a>
                            </li>'
                        fi

                        # Settings
                        if [[ "${mainpage}" == "edit" ]]; then
                            echo '
                            <li class="nav-item">
                                <a class="nav-link active synocr-nav-link" href="index.cgi?page=edit" title="'"${lang_page2}"'">
                                    <img class="svg synocr-nav-icon" src="images/settings_white@geimist.svg" height="25" width="25" alt=""/><span class="synocr-nav-label">'"${lang_page2}"'</span>
                                </a>
                            </li>'
                        else
                            echo '
                            <li class="nav-item">
                                <a class="nav-link text-secondary synocr-nav-link" href="index.cgi?page=edit" title="'"${lang_page2}"'">
                                    <img class="svg synocr-nav-icon" src="images/settings_grey3@geimist.svg" height="25" width="25" alt=""/><span class="synocr-nav-label">'"${lang_page2}"'</span>
                                </a>
                            </li>'
                        fi

                        # Rule editor
                        if [[ "${mainpage}" == "rules" ]]; then
                            echo '
                            <li class="nav-item">
                                <a class="nav-link active synocr-nav-link" href="index.cgi?page=rules" title="'"${lang_page5}"'">
                                    <img class="svg synocr-nav-icon" src="images/flowchart_white.svg" height="25" width="25" alt=""/><span class="synocr-nav-label">'"${lang_page5}"'</span>
                                </a>
                            </li>'
                        else
                            echo '
                            <li class="nav-item">
                                <a class="nav-link text-secondary synocr-nav-link" href="index.cgi?page=rules" title="'"${lang_page5}"'">
                                    <img class="svg synocr-nav-icon" src="images/flowchart_grey.svg" height="25" width="25" alt=""/><span class="synocr-nav-label">'"${lang_page5}"'</span>
                                </a>
                            </li>'
                        fi

                        # Help
                        if [[ "${mainpage}" == "help" ]]; then
                            echo '
                            <li class="nav-item">
                                <a class="nav-link active synocr-nav-link" href="index.cgi?page=help" title="'"${lang_page4}"'">
                                    <img class="svg synocr-nav-icon" src="images/help_white@geimist.svg" height="25" width="25" alt=""/><span class="synocr-nav-label">'"${lang_page4}"'</span>
                                </a>
                            </li>'
                        else
                            echo '
                            <li class="nav-item">
                                <a class="nav-link text-secondary synocr-nav-link" href="index.cgi?page=help" title="'"${lang_page4}"'">
                                    <img class="svg synocr-nav-icon" src="images/help_grey3@geimist.svg" height="25" width="25" alt=""/><span class="synocr-nav-label">'"${lang_page4}"'</span>
                                </a>
                            </li>'
                        fi
                        echo '
                    </ul>
                    <button type="button" class="synocr-nav-toggle" id="synocr-nav-toggle"
                        aria-expanded="true" aria-label="'"${lang_nav_collapse}"'" title="'"${lang_nav_collapse}"'"
                        data-label-collapse="'"${lang_nav_collapse}"'" data-label-expand="'"${lang_nav_expand}"'">
                    </button>
                    </div>
                </div><!-- col -->'

                # Right column
                # ------------------------------------------------------
                echo '
                <div class="col synocr-content-col">
                    <form action="index.cgi" method="get" autocomplete="on" class="synocr-content-scroll">'

                        # Dynamic page reloading
                        if [ -z "${mainpage}" ]; then
                            echo 'The page could not be found!'
                        else
                            script="GUI_${mainpage}.sh"
                            if [ -f "${script}" ]; then
                                . ./"${script}"
                            else
                                . ./GUI_main.sh
                            fi
                        fi

                        # Footer
                        if [ -f "GUI_footer.sh" ] && [ ! -f "${stop}" ]; then
                            . ./GUI_footer.sh
                        fi
                        echo '

                    </form>
                </div><!-- col -->
            </div><!-- row -->
        </div><!-- container -->
    </article>

    <!-- Include bootstrap JavaScript 5.3.2 -->
    <script src="'${synocr_bootstrap_js_src}'"></script>
    <script src="'${synocr_nav_js_src}'"></script>'
# Main page: live progress script after bootstrap, outside the form
if [ "${mainpage}" = "main" ] && [ -n "${synocr_progress_config_json:-}" ]; then
    echo '
    <script type="application/json" id="synocr-progress-config">'"${synocr_progress_config_json}"'</script>
    <script src="'"${synocr_progress_js_src}"'"></script>'
fi
if [[ "${synocr_request_page}" == rules-edit-* ]]; then
    echo '
    <script src="'"${synocr_rules_editor_js_src}"'"></script>
    <script src="'"${synocr_folderpicker_js_src}"'"></script>
    <script src="'"${synocr_namesyntax_editor_js_src}"'"></script>
    <script src="'"${synocr_regex_assistant_js_src}"'"></script>'
fi
if [[ "${synocr_request_page}" == rules-import-* ]]; then
    echo '
    <script src="'"${synocr_folderpicker_js_src}"'"></script>'
fi
echo '

</body>
</html>'
