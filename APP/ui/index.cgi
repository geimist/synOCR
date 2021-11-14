#!/bin/bash
# /usr/syno/synoman/webman/3rdparty/synOCR/index.cgi

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
            syno_privilege=$(echo "${rar_data}" | grep "SYNO.SDS.ThirdParty.App.${app_name}" | cut -d ":" -f2 | cut -d '"' -f2)
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


# Load language settings from ./includes/functions.sh
    [ -f "${app_home}/includes/functions.sh" ] && source "${app_home}/includes/functions.sh" || exit
    language

# ---------------------------------------------------------------------
    # Initiate user folder
    get_var=$(which get_key_value) || exit
    set_var=$(which synosetkeyvalue) || exit
    usersettings="${app_home}/usersettings"    # ToDo: move to "${app_home}/etc"
    if [ ! -d "$usersettings" ]; then
        mkdir "$usersettings"
    fi
    var="${app_home}/usersettings/var.txt"

#   var="$usersettings/var.txt"
#   stop="$usersettings/stop.txt"
    stop="${app_home}/usersettings/stop.txt"
    black="color: #000000"
    green="color: #00B10D"
    red="color: #DF0101"
    synotrred="color: #BD0010"
    synocrred="color: #BD0010"
    blue="color: #2A588C"
    orange="color: #FFA500"
    grey="color: #424242"
    grey1="color: #53657D"
    grey2="color: #374355"

    # read MAC-adress (only to hide DEV pages)
    read MAC </sys/class/net/eth0/address
    sysID=`echo $MAC | cksum | awk '{print $1}'`; sysID="$(printf '%010d' $sysID)" #echo "Prüfsumme der MAC-Adresse als Hardware-ID: $sysID" 10-stellig


    if [ -z "$backifs" ]; then
        backifs="$IFS"
        readonly backifs
    fi

    IFS="&"
    set -- $QUERY_STRING
    IFS='
'

# Initiate environment parameters:
    for i in "$@"; do
        IFS="$backifs"
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
    site=${page##*-}
    sitemore=$(( $site + 1 ))
    siteless=$(( $site - 1 ))

    if [[ "$mainpage" == "start" ]]; then
        [ -f "$var" ] && rm "$var"
        [ -f "$stop" ] && rm "$stop"
        [ -f "$usersettings/stop2.txt" ] && rm "$usersettings/stop2.txt"
        mainpage="main"
    fi

# Layout - Define Home Page:
    if [ -z "$page" ]; then
        mainpage="main"
    fi

    "$set_var" "$var" "page" ""

# Layout - Open basic framework incl. navigation -
echo "Content-type: text/html"
echo
echo '
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>synOCR</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <link rel="icon" type="image/svg+xml" href="images/synOCR-LOGO.svg" sizes="any">
    <!-- <link rel="shortcut icon" href="images/uh_32.png" type="image/x-icon" /> -->
    <link rel="stylesheet" type="text/css" href="includes/synocr_1.1.0.css" />
    <!--Load the AJAX API-->
    <!--<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>-->
    <script type="text/javascript" src="js/chartsloader.js"></script>
</head>
<body>'
# Check Enviroment
# echo '<b>SynoToken:</b> '$syno_token' - <b>User name:</b> '$syno_user' - <b>User exist:</b> '$user_exist' - <b>Is admin:</b> '$is_admin' - <b>Is authenticated:</b> '$is_authenticated''
# echo '<br />'${txtActivatePrivileg}'<br />'

echo '<div id="wrapper">'
echo '
<div id="navleft">
    <div id="navleftinbox">
    <ul class="li_blank">'

#   old main-Page:
    if [[ "$mainpage" == "main" ]]; then
        echo '
        <li><a class="navitemselc" href="index.cgi?page=main"><img class="svg" src="images/home_white@geimist.svg" height="25" width="25"/>'$lang_page1'</a></li>'
    else
        echo '
        <li><a class="navitem" href="index.cgi?page=main"><img class="svg" src="images/home_grey3@geimist.svg" height="25" width="25"/>'$lang_page1'</a></li>'
    fi

if [[ "$mainpage" == "edit" ]]; then
    echo '
    <li><a class="navitemselc" href="index.cgi?page=edit"><img class="svg" src="images/settings_white@geimist.svg" height="25" width="25"/>'$lang_page2'</a></li>'
else
    echo '
    <li><a class="navitem" href="index.cgi?page=edit"><img class="svg" src="images/settings_grey3@geimist.svg" height="25" width="25"/>'$lang_page2'</a></li>'
fi

if [[ "$mainpage" == "timer" ]] && [[ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -lt 7 ]]; then
    echo '
    <li><a class="navitemselc" href="index.cgi?page=timer"><img class="svg" src="images/calendar_white@geimist.svg" height="25" width="25"/>'$lang_page3'</a></li>'
elif [[ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -lt 7 ]]; then
    echo '
    <li><a class="navitem" href="index.cgi?page=timer"><img class="svg" src="images/calendar_grey3@geimist.svg" height="25" width="25"/>'$lang_page3'</a></li>'
fi

if [[ "$mainpage" == "help" ]]; then
    echo '
    <li><a class="navitemselc" href="index.cgi?page=help"><img class="svg" src="images/help_white@geimist.svg" height="25" width="25"/>'$lang_page4'</a></li>'
else
    echo '
    <li><a class="navitem" href="index.cgi?page=help"><img class="svg" src="images/help_grey3@geimist.svg" height="25" width="25"/>'$lang_page4'</a></li>'
fi


echo '</ul>
    </div>
    </div>'

echo '
<p style="padding: 15px;">
<div class="clear"></div>'

# Layout - Dynamic page exchange:
echo '
    <form action="index.cgi" method="get" autocomplete="on">'
    

    if [ -z "$mainpage" ]; then
        echo 'The page could not be found!'
    else
        script="$mainpage.sh"
        if [ -f "$script" ]; then
            . ./"$script"
        else
            . ./main.sh
        fi
    fi

# Error output:
if [ -f "$usersettings/stop2.txt" ]; then
#<div id="Content_1Col">
    echo '
    <div class="Content_1Col_full">
        <div class="warning">
            <p class="center">'
            IFS='
            '
            for i in $(< "$usersettings/stop2.txt"); do
                IFS="$backifs"
                echo ''$i''
            done
            [ -f "$stop" ] && rm "$stop"
            [ -f "$usersettings/stop2.txt" ] && rm "$usersettings/stop2.txt"
            echo '
            </p>
        </div>
        <div id="lastLine"></div>
    </div><div class="clear"></div>'
#</div>
fi

if [ -f "$stop" ]; then
    cp "$stop" "$usersettings/stop2.txt"
    echo '<meta http-equiv="refresh" content="0; url=index.cgi?page='$(echo "$page" | sed 's/[[:digit:]]*$//')''$siteless'#lastLine">'
fi

# Footer
if [ -f "footer.sh" ] && [ ! -f "$stop" ]; then
    . ./footer.sh
fi

# Layout - Close base frame -
echo '
    </form>
    </div>
</body>
</html>'
