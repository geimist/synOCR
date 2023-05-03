#!/bin/bash

#############################################################################################
#   description:    initiate SPK GUI                                                        #
#                                                                                           #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/index.cgi                      #
#   © 2023 by geimist                                                                       #
#############################################################################################

# Initiate system
# ---------------------------------------------------------------------
    machinetyp=$(uname --machine)
    if [ $machinetyp = "x86_64" ]; then
        PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin:/usr/local/bin:/opt/usr/bin:/usr/syno/synoman/webman/3rdparty/synOCR/bin
        include_synowebapi=synowebapi_x86_64
    elif [ $machinetyp = "aarch64" ]; then
        PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin:/usr/local/bin:/opt/usr/bin:/usr/syno/synoman/webman/3rdparty/synOCR/bin_aarch64
        include_synowebapi=synowebapi_aarch64
    fi

    app_name="synOCR"
    app_home=$(echo /volume*/@appstore/${app_name}/ui)
    [ ! -d "${app_home}" ] && exit

# Resetting possible access authorizations
    unset syno_login syno_token syno_user user_exist is_admin is_privileged


# Evaluate app authentication
# --------------------------------------------------------------
    # To evaluate the SynoToken, change REQUEST_METHOD to GET.
    [[ "${REQUEST_METHOD}" == "POST" ]] && REQUEST_METHOD="GET" && OLD_REQUEST_METHOD="POST"


    # Read out and check the login authorization ( login.cgi )
    # ----------------------------------------------------------
        syno_login=$(/usr/syno/synoman/webman/login.cgi)

        # SynoToken ( only when protection against cross-site request forgery attacks is enabled )
        if echo ${syno_login} | grep -q SynoToken ; then
            syno_token=$(echo "${syno_login}" | grep SynoToken | cut -d ":" -f2 | cut -d '"' -f2)
        fi

        if [ -n "${syno_token}" ]; then
            [ -z ${QUERY_STRING} ] && QUERY_STRING="SynoToken=${syno_token}" || QUERY_STRING="${QUERY_STRING}&SynoToken=${syno_token}"
        fi

        # Login authorization ( result=success )
        if echo ${syno_login} | grep -q result ; then
            login_result=$(echo "${syno_login}" | grep result | cut -d ":" -f2 | cut -d '"' -f2)
        fi
        [[ ${login_result} != "success" ]] && { echo 'Access denied'; exit; }

        # Login successful ( success=true )
        if echo ${syno_login} | grep -q success ; then
            login_success=$(echo "${syno_login}" | grep success | cut -d "," -f3 | grep success | cut -d ":" -f2 | cut -d " " -f2 )
        fi
        [[ ${login_success} != "true" ]] && { echo 'Access denied'; exit; }


    # REQUEST_METHOD set back to POST
    [[ "${OLD_REQUEST_METHOD}" == "POST" ]] && REQUEST_METHOD="POST" && unset OLD_REQUEST_METHOD


    # Reading user/group from authenticate.cgi
    # ----------------------------------------------------------
        syno_user=$(/usr/syno/synoman/webman/authenticate.cgi)

        # Check if the user exists
        user_exist=$(grep -o "^${syno_user}:" /etc/passwd)
        [ -n "${user_exist}" ] && user_exist="yes" || exit

        # Check whether the local user belongs to the "administrators" group
        if id -G "${syno_user}" | grep -q 101; then
            is_admin="yes"
        else
            is_admin="no"
        fi

    # Evaluate authentication at application level
    # ----------------------------------------------------------
        # To evaluate the authentication, the file /usr/syno/bin/synowebapi
        # must be copied to ${app_home}/modules/synowebapi, and the
        # ownership must be adjusted to ${app_name}:${app_name}.

        if [ -f "${app_home}/includes/$include_synowebapi" ]; then
            rar_data=$($app_home/includes/$include_synowebapi --exec api=SYNO.Core.Desktop.Initdata method=get version=1 runner="$syno_user" | jq '.data.AppPrivilege')
            syno_privilege=$(echo "${rar_data}" | grep "SYNO.SDS.${app_name}.Application" | cut -d ":" -f2 | cut -d '"' -f2)
            if echo "${syno_privilege}" | grep -q "true"; then
                is_authenticated="yes"
            else
                is_authenticated="no"
            fi
        else
            is_authenticated="no"
            txtActivatePrivileg="<b>To enable app level authentication do …</b><br /><b>root@[local-machine]:~#</b> cp /usr/syno/bin/synowebapi /var/packages/${app_name}/target/ui/modules<br /><b>root@[local-machine]:~#</b> chown ${app_name}.${app_name} /var/packages/$MYPKG/target/ui/modules/synowebapi"
        fi


    # Set variables to "readonly" for protection or empty contents
    # ----------------------------------------------------------
        unset syno_login rar_data syno_privilege
        readonly syno_token syno_user user_exist is_admin is_authenticated
        
        # read MAC-adress (only to hide DEV pages)
        read MAC </sys/class/net/eth0/address
        sysID=$(echo $MAC | cksum | awk '{print $1}'); sysID="$(printf '%010d' $sysID)" #echo "Prüfsumme der MAC-Adresse als Hardware-ID: $sysID" 10-stellig


    # Load functions from ./includes/functions.sh
    # ----------------------------------------------------------
        [ -f "${app_home}/includes/functions.sh" ] && source "${app_home}/includes/functions.sh" || exit
        # Load language settings
        language


    # Initiate user folder
    # ----------------------------------------------------------
        usersettings="${app_home}/etc"
        if [ ! -d "$usersettings" ]; then
            mkdir "$usersettings"
        fi


# Processing of GET request variables
# --------------------------------------------------------------
    set_var="/usr/syno/bin/synosetkeyvalue"
    get_var="/bin/get_key_value"
    var="${app_home}/etc/var.txt"
    synocrred="color: #BD0010"
        
    # Backup of the Internal Field Separator (IFS) as well as the separation of 
    # GET/POST key/value requests, by localization of the separator "&".
    if [ -z "${backupIFS}" ]; then
        backupIFS="${IFS}"
        IFS='&'
        set -- $QUERY_STRING
        readonly backupIFS
        IFS="${backupIFS}"
    fi

    # Analyze incoming GET requests and process them into key="$value" variable
    for i in "$@"; do
        IFS="$backupIFS"
        variable=${i%%=*}
        encode_value=${i##*=}
        decode_value=$(urldecode "$encode_value")
        "$set_var" "$var" "$variable" "$decode_value"
        "$set_var" "$var" "encode_$variable" "$encode_value"
    done
    
    if [ -f "$var" ]; then
        source "$var"
    fi

    mainpage=${page%%-*}

    if [ -z "$page" ]; then
        #[ -f "${var}" ] && rm "${var}"
        mainpage="main"
    fi
    
    "$set_var" "$var" "page" ""


# Layout - Open basic framework incl. navigation -
# ----------------------------------------------------------
echo "Content-type: text/html"
echo
echo '
<!doctype html>
<html lang="en">
<head>
    <title>synOCR</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1">

        <!-- Include bootstrap framework 5.2.3 -->
        <link rel="stylesheet" href="template/bootstrap/css/bootstrap.min.css" />

        <!-- Include custom CSS formatting -->
        <link rel="stylesheet" href="template/stylesheet.css" />

        <!-- Include jQuery -->
        <script src="template/jquery/jquery-3.6.4.min.js"></script>
</head>
<body>
<body>
<header></header>
    <article>
        <!-- container -->
        <div class="container-fluid">
            <div class="row mt-2">'

                # Left column - Navigation
                # ------------------------------------------------------
                echo '
                <div class="col-3 pr-1 border-end border-light border-5">
                    <ul class="nav nav-pills flex-column">'


                        # Startpage
                        if [[ "$mainpage" == "main" ]]; then
                            echo '
                            <li class="nav-item">
                                <a class="nav-link active" style="background-color: #0086E5;" href="index.cgi?page=main">
                                    <img class="svg me-3" src="images/home_white@geimist.svg" height="25" width="25"/>'$lang_page1'
                                </a>
                            </li>'
                        else
                            echo '
                            <li class="nav-item">
                                <a class="nav-link text-secondary" href="index.cgi?page=main">
                                    <img class="svg me-3" src="images/home_grey3@geimist.svg" height="25" width="25"/>'$lang_page1'
                                </a>
                            </li>'
                        fi

                        # Settings
                        if [[ "$mainpage" == "edit" ]]; then
                            echo '
                            <li class="nav-item">
                                <a class="nav-link active" style="background-color: #0086E5;" href="index.cgi?page=edit">
                                    <img class="svg me-3" src="images/settings_white@geimist.svg" height="25" width="25"/>'$lang_page2'
                                </a>
                            </li>'
                        else
                            echo '
                            <li class="nav-item">
                                <a class="nav-link text-secondary" href="index.cgi?page=edit">
                                    <img class="svg me-3" src="images/settings_grey3@geimist.svg" height="25" width="25"/>'$lang_page2'
                                </a>
                            </li>'
                        fi

                        # Timer
#                        if [[ "$mainpage" == "timer" ]] && [[ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -lt 7 ]]; then
#                            echo '
#                            <li class="nav-item">
#                                <a class="nav-link active" style="background-color: #0086E5;" href="index.cgi?page=timer">
#                                    <img class="svg me-3" src="images/calendar_white@geimist.svg" height="25" width="25"/>'$lang_page3'
#                                </a>
#                            </li>'
#                        elif [[ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -lt 7 ]]; then
#                            echo '
#                            <li class="nav-item">
#                                <a class="nav-link text-secondary" href="index.cgi?page=timer">
#                                    <img class="svg me-3" src="images/calendar_grey3@geimist.svg" height="25" width="25"/>'$lang_page3'
#                                </a>
#                            </li>'
#                        fi

                        # Help
                        if [[ "$mainpage" == "help" ]]; then
                            echo '
                            <li class="nav-item">
                                <a class="nav-link active" style="background-color: #0086E5;" href="index.cgi?page=help">
                                    <img class="svg me-3" src="images/help_white@geimist.svg" height="25" width="25"/>'$lang_page4'
                                </a>
                            </li>'
                        else
                            echo '
                            <li class="nav-item">
                                <a class="nav-link text-secondary" href="index.cgi?page=help">
                                    <img class="svg me-3" src="images/help_grey3@geimist.svg" height="25" width="25"/>'$lang_page4'
                                </a>
                            </li>'
                        fi

                        echo '
                    </ul>
                </div><!-- col -->'

                # Right column
                # ------------------------------------------------------
                echo '
                <div class="col-9 pl-1">
                    <form action="index.cgi" method="get" autocomplete="on">'

                        # Dynamic page reloading
                        if [ -z "$mainpage" ]; then
                            echo 'The page could not be found!'
                        else
                            script="GUI_${mainpage}.sh"
                            if [ -f "$script" ]; then
                                . ./"$script"
                            else
                                . ./GUI_main.sh
                            fi
                        fi

                        # Footer
                        if [ -f "GUI_footer.sh" ] && [ ! -f "$stop" ]; then
                            . ./GUI_footer.sh
                        fi
                        echo '

                    </form>
                </div><!-- col -->
            </div><!-- row -->
        </div><!-- container -->
    </article>

    <!-- Include bootstrap JavaScript 5.2.3 -->
    <script src="template/bootstrap/js/bootstrap.min.js"></script>

</body>
</html>'
