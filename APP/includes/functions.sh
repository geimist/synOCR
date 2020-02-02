#!/bin/sh

# Sprachvariablen laden (function by Ultimate Backup)
function language()
{
	# Englische Sprachdatei laden
	source "lang/lang_enu.txt"

	# Sprachdateien konfigurieren
	# Funktion zur Ermittlung der eingestellten Sprache
	# - DSM Sprache ermitteln (aus synoinfo.conf)
	# - Browser Sprache ermitteln (aus ${HTTP_ACCEPT_LANGUAGE})
	# - wenn DSM Sprache = default, dann benutze Browser Sprache
	# - Persönliche DSM Sprache ermitteln (aus usersettings)
	# - falls Persönliche DSM Sprache = default, dann benutze weiterhin die zuvor
	#   ermittelte Sprache, ansonsten benutze die ermittelte Persönliche DSM Sprache
	# - ist DSM Sprache und Persönliche DSM Sprache = "def" und Browser Sprache nicht gesetzt, dann benutze Standard Sprache (DEFLANG)
	# Prioritäten: 1. Persönliche DSM Sprache =2. DSM Sprache =3. Browser Sprache =4. Standard Sprache
	#

	# Übersetzungstabelle deklarieren
	declare -A ISO2SYNO
	ISO2SYNO=( ["de"]="ger" ["en"]="enu" ["zh"]="chs" ["cs"]="csy" ["jp"]="jpn" ["ko"]="krn" ["da"]="dan" ["fr"]="fre" ["it"]="ita" ["nl"]="nld" ["no"]="nor" ["pl"]="plk" ["ru"]="rus" ["sp"]="spn" ["sv"]="sve" ["hu"]="hun" ["tr"]="trk" ["pt"]="ptg" )

	# DSM Sprache ermitteln
	deflang="ger"
	lang=$(cat /etc/synoinfo.conf | grep language | sed 's/language=//;s/\"//g' | egrep -o "^.{3}")
	#lang_mail=$(cat /etc/synoinfo.conf | grep maillang | sed 's/maillang=//;s/\"//g' | egrep -o "^.{3}")
	#if [ "$lang" == "def" ]; then
	#	lang="$lang_mail"
    #fi

	if [[ "${lang}" == "def" ]] ; then
        # Browsersprache ermitteln
        if [ -n "${HTTP_ACCEPT_LANGUAGE}" ] ; then
            bl=`echo ${HTTP_ACCEPT_LANGUAGE} | cut -d "," -f1`
            bl=${bl:0:2}
            lang=${ISO2SYNO[${bl}]}
        else
            lang=${deflang}
        fi
	fi
	# Persönliche DSM Sprache ermitteln
	usersettingsfile=/usr/syno/etc/preference/${login_user}/usersettings
	if [ -f ${usersettingsfile} ] ; then
	    userlanguage=`jq -r ".Personal.lang" ${usersettingsfile}`
	    if [ -n "${userlanguage}" -a "${userlanguage}" != "def" -a "${userlanguage}" != "null" ] ; then
			lang=${userlanguage}
		fi
	fi

	# Sprachdatei laden
	if [ -f "lang/lang_${lang}.txt" ] && [[ "$lang" != "enu" ]]; then
		source "lang/lang_${lang}.txt"
	fi
	
}
