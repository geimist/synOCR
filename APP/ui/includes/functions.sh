#!/bin/bash
# /usr/syno/synoman/webman/3rdparty/synOCR/includes/functions.sh
# shellcheck disable=SC1090,SC1091
#,SC2001,SC2009,SC2181

synogroupmoduser() {
    # example:
    # synogroupmoduser add administrators synOCR
    # synogroupmoduser delete administrators synOCR

    local ACTION="$1"
    local GROUP="$2"
    local USER="$3"
    local CURRENTUSERS
    local -a USERLIST
    local BACKUP_FILE="/tmp/${GROUP}_members.bak"

    # check parameter
    if [[ "$ACTION" != "add" && "$ACTION" != "delete" ]] || [[ -z "$GROUP" ]] || [[ -z "$USER" ]]; then
        echo "Usage: $0 [add|delete] [group] [user]"
        return 1
    fi

    # Group existence test
    if ! synogroup --get "$GROUP" >/dev/null 2>&1; then
        echo "Error: Group $GROUP does not exist." >&2
        return 1
    fi

    # list user at group
    CURRENTUSERS=$(synogroup --get "$GROUP" | 
        awk -F'[][]' '/^[0-9]+:/ {print $2}' | 
        tr '\n' ',' | 
        sed 's/,$//'
    )

    # Backup erstellen
    echo "$CURRENTUSERS" > "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo "Error: Backup of group $GROUP failed." >&2
        return 1
    fi

    # Parse members
    IFS=',' read -ra USERLIST <<< "$CURRENTUSERS"
    local user_found=0

    # Depending on the action, process
    case "$ACTION" in
        "add")
            # Duplicate check
            for u in "${USERLIST[@]}"; do
                if [[ "$u" == "$USER" ]]; then
                    echo "User $USER already in $GROUP."
                    rm "$BACKUP_FILE"
                    return 0
                fi
            done
            USERLIST+=("$USER")
            ;;

        "delete")
            # Create new list without the user
            local -a NEWLIST=()
            for u in "${USERLIST[@]}"; do
            echo "user: $u"
                if [[ "$u" == "$USER" ]]; then
                    user_found=1
                else
                    NEWLIST+=("$u")
                fi
            done

            if [[ $user_found -eq 0 ]]; then
                echo "User $USER not in $GROUP."
                rm "$BACKUP_FILE"
                return 0
            fi
            USERLIST=("${NEWLIST[@]}")
            ;;
    esac

    # update group
    if ! synogroup --member "$GROUP" "${USERLIST[@]}"; then
        echo "CRITICAL ERROR: Group update failed! Restore from backup …" >&2

        # Restore
        IFS=',' read -ra RESTORE_LIST <<< "$(cat "$BACKUP_FILE")"
        if ! synogroup --member "$GROUP" "${RESTORE_LIST[@]}"; then
            echo "FATAL ERROR: Restore failed! Backup: $BACKUP_FILE" >&2
            return 2
        fi

        rm "$BACKUP_FILE"
        return 1
    fi

    # success message
    case "$ACTION" in
        "add") echo "User $USER successfully added to $GROUP." ;;
        "delete") echo "User $USER successfully removed from $GROUP." ;;
    esac

    rm "$BACKUP_FILE"
    return 0
}

synogroupmoddocker() {
# Check docker group and permissions

    # Create group if not existing
    if ! synogroup --get docker >/dev/null 2>&1; then
        echo -n "Creating docker group … "
        if synogroup --add docker; then
            chown root:docker /var/run/docker.sock
            synogroupmoduser add docker synOCR
            echo "OK"
        else
            echo "FAILED to create docker group!" >&2
            exit 1
        fi
    else
        # Check permissions
        if [ "$(stat -c '%G' /var/run/docker.sock)" != "docker" ]; then
            echo -n "Fixing docker socket permissions... "
            chown root:docker /var/run/docker.sock
        fi

        # Check user membership with synogroupmoduser
        if ! synogroup --get docker | grep -qw "synOCR"; then
            echo -n "Adding synOCR to docker group... "
            synogroupmoduser add docker synOCR
        else
            echo -n "OK [$(synogroup --get docker | sed -n 's/.*\[\(.*\)\].*/\1/p')]"
        fi
    fi

}

# -------------------------------------------------------------------------- #
# native URL encode & decode:
# https://gist.github.com/cdown/1163649
urlencode() {
    # urlencode <string>
    old_lc_collate="${LC_COLLATE}"
    LC_COLLATE=C

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:$i:1}"
        case $c in
            [a-zA-Z0-9._-]) printf '%s' "$c" ;;
            " ") echo -n "%20" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done

    LC_COLLATE=$old_lc_collate
}

urldecode() {
# urldecode <string>
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}


# -------------------------------------------------------------------------- #
language() {
    # ---------------------------------------------------------------------- #
    # Configure language settings                                            #
    # ---------------------------------------------------------------------- #
    # Load English language file
    source "lang/lang_enu.txt"

    #********************************************************************#
    #  Description: Script get the current used dsm language             #
    #  Author:      QTip from the german Synology support forum          #
    #  Copyright:   2016-2018 by QTip                                    #
    #  License:     GNU GPLv3                                            #
    #  ----------------------------------------------------------------  #
    #  Version:     0.15 - 2018-06-11                                    #
    #  Version:     0.16 - 2018-08-07                                    #
    #********************************************************************#

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
    # fehlende Sprachen: Tai, 'Portuguese Brazilian' ('ptb','PT-BR')

# DSM Sprache ermitteln
    deflang="enu"
    lang=$(grep language /etc/synoinfo.conf | sed 's/language=//;s/\"//g' | grep -Eo "^.{3}")

# Browsersprache ermitteln
    if [[ "${lang}" == "def" ]] ; then
        if [ -n "${HTTP_ACCEPT_LANGUAGE}" ] ; then
            bl=$(echo "${HTTP_ACCEPT_LANGUAGE}" | cut -d "," -f1)
            bl=${bl:0:2}
            lang=${ISO2SYNO[${bl}]}
        else
            lang=${deflang}
        fi
    fi

# Persönliche DSM Sprache ermitteln
    # shellcheck disable=SC2154
    usersettingsfile="/usr/syno/etc/preference/${login_user}/usersettings"
    if [ -f "${usersettingsfile}" ] ; then
        userlanguage=$(jq -r ".Personal.lang" "${usersettingsfile}")
        if [ -n "${userlanguage}" ] && [ "${userlanguage}" != "def" ] && [ "${userlanguage}" != "null" ]; then
            lang="${userlanguage}"
        fi
    fi

# Sprachdatei laden
    if [ -f "lang/lang_${lang}.txt" ] && [[ "${lang}" != "enu" ]]; then
        source "lang/lang_${lang}.txt"
    fi
}
