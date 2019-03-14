#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin

# Zugangsberechtigungen des DSM überprüfen (Syno-Token)
login=$(php -f /volume*/@appstore/synOCR/includes/token.php) || exit
login_user=$(echo $login | sed "s/.*user: //;s/ admin:.*//") || exit
login_admin=$(echo $login | sed -e 's/.*admin: //') || exit
if [ -n "$login" ]; then
	if [[ "$login" != "0" ]] && [[ "$login_user" != "0" ]]; then
		access="yes"
	fi
fi

# Script beenden wenn Zugang nicht gewährt
if [ -z "$access" ]; then
	exit
else
    # Benutzerordner initiieren
	dir=$(echo /volume*/@appstore/synOCR) || exit
	get_var=$(which get_key_value) || exit
	set_var=$(which synosetkeyvalue) || exit
	usersettings="$dir/usersettings"
	var="$dir/usersettings/var.txt"

#	var="$usersettings/var.txt"
#	stop="$usersettings/stop.txt"
	stop="$dir/usersettings/stop.txt"
	black="color: #000000"
	green="color: #00B10D"
	red="color: #DF0101"
	synotrred="color: #BD0010"
	blue="color: #2A588C"
	orange="color: #FFA500"
	grey="color: #424242"
	grey1="color: #53657D"
	grey2="color: #374355"
    
    # Konfiguration laden:
#    source $dir/app/etc/Konfiguration.txt
    
    # MAC-Adresse auslesen (um DEV-Seiten zu verstecken)
    read MAC </sys/class/net/eth0/address
	sysID=`echo $MAC | cksum | awk '{print $1}'`; sysID="$(printf '%010d' $sysID)" #echo "Prüfsumme der MAC-Adresse als Hardware-ID: $sysID" 10-stellig
fi


if [ -z "$backifs" ]; then
	backifs="$IFS"
	readonly backifs
fi

IFS="&"
set -- $QUERY_STRING
IFS='
'

# Umgebungsparameter initiieren
for i in "$@"; do
	IFS="$backifs"
	variable=${i%%=*}
	encode_value=${i##*=}
	decode_value=$(echo "$encode_value" | sed -f $dir/includes/decode.sed)
	"$set_var" "$var" "$variable" "$decode_value"
	"$set_var" "$var" "encode_$variable" "$encode_value"
done

if [ -f "$var" ]; then
	source "$var"
fi

mainpage=${page%%-*}
site=${page##*-}
sitemore=$(expr $site + 1)
siteless=$(expr $site - 1)

if [[ "$mainpage" == "start" ]]; then
	[ -f "$var" ] && rm "$var"
	[ -f "$stop" ] && rm "$stop"
	[ -f "$usersettings/stop2.txt" ] && rm "$usersettings/stop2.txt"
	mainpage="main"
fi

# Layout - Startseite definieren
if [ -z "$page" ]; then
	mainpage="main"
fi

"$set_var" "$var" "page" ""

# Layout - Grundgerüst öffnen inkl. Navigation -
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
	<link rel="stylesheet" type="text/css" href="css/synocr_1.1.0.css" />
	<!--Load the AJAX API-->
    <!--<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>-->
    <script type="text/javascript" src="js/chartsloader.js"></script>
</head>
<body>'

echo '<div id="wrapper">'
echo '
<div id="navleft">
    <div id="navleftinbox">
    <ul class="li_blank">'

#   alte main-Page:
    if [[ "$mainpage" == "main" ]]; then
    	echo '
    	<li><a class="navitemselc" href="index.cgi?page=main"><img class="svg" src="images/home_white@geimist.svg" height="25" width="25"/>Übersicht</a></li>'
    else
    	echo '
    	<li><a class="navitem" href="index.cgi?page=main"><img class="svg" src="images/home_grey3@geimist.svg" height="25" width="25"/>Übersicht</a></li>'
    fi

if [[ "$mainpage" == "edit" ]]; then
	echo '
	<li><a class="navitemselc" href="index.cgi?page=edit"><img class="svg" src="images/settings_white@geimist.svg" height="25" width="25"/>Konfiguration</a></li>'
else
	echo '
	<li><a class="navitem" href="index.cgi?page=edit"><img class="svg" src="images/settings_grey3@geimist.svg" height="25" width="25"/>Konfiguration</a></li>'
fi

if [[ "$mainpage" == "timer" ]]; then
	echo '
	<li><a class="navitemselc" href="index.cgi?page=timer"><img class="svg" src="images/calendar_white@geimist.svg" height="25" width="25"/>Zeitplaner</a></li>'
else
	echo '
	<li><a class="navitem" href="index.cgi?page=timer"><img class="svg" src="images/calendar_grey3@geimist.svg" height="25" width="25"/>Zeitplaner</a></li>'
fi

if [[ "$mainpage" == "help" ]]; then
	echo '
	<li><a class="navitemselc" href="index.cgi?page=help"><img class="svg" src="images/help_white@geimist.svg" height="25" width="25"/>Hilfe</a></li>'
else
	echo '
	<li><a class="navitem" href="index.cgi?page=help"><img class="svg" src="images/help_grey3@geimist.svg" height="25" width="25"/>Hilfe</a></li>'
fi

#   alte status.sh:
#    if [[ "$mainpage" == "status" ]] ; then
#    	echo '<li><a class="navitemselc" href="index.cgi?page=status"><img class="svg" src="images/status_white@geimist.svg" height="25" width="25"/>Status</a></li>'
#    else
#    	echo '<li><a class="navitem" href="index.cgi?page=status"><img class="svg" src="images/status_grey3@geimist.svg" height="25" width="25"/>Status</a></li>'
#    fi

echo '</ul>
    </div>
    </div>'

echo '
<p style="padding: 15px;">
<div class="clear"></div>'

# Layout - Dynamischer Seitenaustausch
echo '
	<form action="index.cgi" method="get" autocomplete="on">'

	if [ -z "$mainpage" ]; then
		echo 'Die Seite konnte nicht geladen werden!'
	else
		script="$mainpage.sh"
		if [ -f "$script" ]; then
			. ./"$script"
		else
			. ./main.sh
		fi
	fi

# Fehlerausgabe
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

# Layout - Grundgerüst schließen -
echo '
	</form>
    </div>
</body>
</html>'
