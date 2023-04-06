#!/bin/bash
#
#######
project="synOCR"
beta_status=""              # will be set by script
#######
#----------------------------------------------------------------------------------------
# Folder structure:
#----------------------------------------------------------------------------------------
# ./APP --> Working environment
# ./PKG  --> Archive folder for building the SPK (start scripts etc.)

# Usage info
# ---------------------------------------------------------------------
show_help () {
cat << EOF
Without arguments, the script creates the SPK from the current master-branch from the server for DSM7.

Usage:      ./${0##*/} -v=<synOCR-Version> --dsm=<target DSM-Version>
Example:    ./${0##*/} -v=1.2.0 --dsm=7

    -v= --version=          specifies which synOCR version is to be built
                            "local" will be used the local files without git interaction
        --DSM=              specifies for which DSM version is to be built

    -h  --help              display this help and exit

EOF
exit 1
}


# read arguments:
# ---------------------------------------------------------------------
    for i in "$@" ; do
        case $i in
            -dsm=*|--dsm=*|-DSM=*|--DSM=*)
            # ToDo: Test, ob Zahl - derzeit 6 oder 7
            TargetDSM="${i#*=}"
            shift
            ;;
            -v=*|--version=*)
            buildversion="${i#*=}"
            shift
            ;;
            -h|--help)
            show_help
            ;;
            *)
            printf "ERROR - unknown argument ($1)!\n\n"
            show_help
            ;;
        esac
    done

    [ -z $buildversion ] && echo "wrong or empty value for synOCR version - set to \"latest\"" && buildversion="latest"
    [ ! "$TargetDSM" = 6 ] && [ ! "$TargetDSM" = 7 ] && echo "wrong or empty value for target DSM version - set to 7" && TargetDSM=7

    if [ -x "$(command -v git)" ]; then
        echo "requested synOCR version: $buildversion"
    else
        buildversion=local
        echo "git is not installed – use build version \"local\""
    fi

    echo "target DSM version:       $TargetDSM"

    shopt -s expand_aliases

    # adjust sed to compatible with macOS
    # https://stackoverflow.com/questions/19456518/error-when-using-sed-with-find-command-on-os-x-invalid-command-code

#   if echo $(uname -a) grep -q "Darwin" >>/dev/null ; then
    if [ $(uname -s) = Darwin ]; then
        alias sed_i='sed -i ""'
    else
        alias sed_i='sed -i'
    fi

    # adjust synosetkeyvalue and get_key_value for different OS
    # at DSM set alias with full path, otherwise call only the same named function
    if [ -x "$(which synosetkeyvalue)" ]; then
        alias synosetkeyvalue='$(which synosetkeyvalue)'
    else
        alias synosetkeyvalue='synosetkeyvalue'
    fi

    if [ -x "$(which get_key_value)" ]; then
        alias get_key_value='$(which get_key_value)'
    else
        alias get_key_value='get_key_value'
    fi

    synosetkeyvalue() {
    # this function is a workaround replacement of synology DSM binary synosetkeyvalue
    # $1 = file
    # $2 = key
    # $3 = value
    sed_i 's~^'$2'=.*~key='$3'~' "$1"
    }

    get_key_value() {
    # this function is a workaround replacement of synology DSM binary get_key_value
    # $1 = file
    # $2 = key
    cat "$1" | grep "^$2" | sed -e 's~^'$2'=~~;s~^"~~g;s~"$~~g'   
    }

# preparation:
# ---------------------------------------------------------------------
    set -E -o functrace     # for function failure()

    failure() {
    # this function show error line
    # --------------------------------------------------------------
        # https://unix.stackexchange.com/questions/462156/how-do-i-find-the-line-number-in-bash-when-an-error-occured
        local lineno=$1
        local msg=$2
        echo "ERROR at line $lineno: $msg"
    }
    trap 'failure ${LINENO} "$BASH_COMMAND"' ERR
    
    set -euo pipefail
    IFS=$'\n\t'

    build_tmp=$(mktemp -d -t tmp.XXXXXXXXXX)

    function finish {
        [ "$buildversion" != local ] && git worktree remove --force "$build_tmp"
        rm -rf "$build_tmp"
    }
    trap finish EXIT

    if ! [ -x "$(command -v fakeroot)" ]; then
        if [ $(whoami) != "root" ]; then
            echo "ERROR: fakeroot are not installed and you are not root!" >&2
            exit 1
        else
            FAKEROOT=""
        fi
    else
        FAKEROOT=$(command -v fakeroot)
    fi


# read working directory and change into it:
# ---------------------------------------------------------------------
    APPDIR=$(cd "$(dirname $0)";pwd)
    cd "${APPDIR}"

    printf "\n-----------------------------------------------------------------------------------\n"
    printf " - INFO: Create the temporary build folder and copy sources into it ..."
    printf "\n-----------------------------------------------------------------------------------\n\n"

	if [ "$buildversion" = local ]; then
	    cp -r ./ "$build_tmp"
	else
        git pull
        git worktree add --force "$build_tmp" "$(git rev-parse --abbrev-ref HEAD)"
    fi

#   buildversion=${1:-latest}
    taggedversions=$(git tag)
    set_spk_version=""

    pushd "$build_tmp"	>>/dev/null

    if echo "$taggedversions" | egrep -q "$buildversion"; then
        echo "git checkout to $buildversion"
        git checkout "$buildversion"
        set_spk_version="$buildversion"
    elif [ "$buildversion" = local ]; then
    	set_spk_version="$buildversion"
    else
        echo "ATTENTION: The requested version was not found in the repository!"
        echo "The $(git rev-parse --abbrev-ref HEAD)-branch will be used!"
    fi

    printf "\n - INFO: collect the DSM specific files ...\n"
    if [ $TargetDSM -eq 7 ]; then
        PKG=PKG_DSM7
        mv $build_tmp/APP/ui/config_DSM7 $build_tmp/APP/ui/config
        rm -f $build_tmp/APP/ui/config_DSM6
        mv $build_tmp/APP/ui/images_DSM7 $build_tmp/APP/ui/images
        rm -rf $build_tmp/APP/ui/images_DSM6
    else
        PKG=PKG_DSM6
        mv $build_tmp/APP/ui/config_DSM6 $build_tmp/APP/ui/config
        rm -f $build_tmp/APP/ui/config_DSM7
        mv $build_tmp/APP/ui/images_DSM6 $build_tmp/APP/ui/images
        rm -rf $build_tmp/APP/ui/images_DSM7
    fi


    create_notify_file() {
        {   echo '[app]'
            echo 'app_name="synOCR"'
            echo 'job_successful="lang_notify_file_job_successful [{0}]"'
            echo 'update_available="lang_notify_file_update_available lang_notify_file_update_version_installed: {0} lang_notify_file_update_version_online: {1}"'
        } > "$1"
    }

    create_install_uifile() {
        {   echo '['
            echo '   {'
            echo '      "step_title" : "lang_wizui_install_title",'
            echo '      "items" : ['
            echo '         {'
            echo '            "desc" : "<p>lang_wizui_install_desc</p>"'
            echo '         }'
            echo '      ]'
            echo '   }'
            echo ']'
        } > "$1"
    }

    create_uninstall_uifile() {
        {   echo '['
            echo '   {'
            echo '      "step_title" : "lang_wizui_uninstall_title",'
            echo '      "items" : ['
            echo '         {'
            echo '            "desc" : "<p>lang_wizui_uninstall_desc_1</p><p><br>lang_wizui_uninstall_desc_2</p>"'
            echo '         }'
            echo '      ]'
            echo '   }'
            echo ']'
       }  > "$1"
    
    }

    create_upgrade_uifile() {
        {   echo '['
            echo '   {'
            echo '      "step_title" : "lang_wizui_upgrade_title",'
            echo '      "items" : ['
            echo '         {'
            echo '            "desc" : "<p>lang_wizui_upgrade_desc</p>"'
            echo '         }'
            echo '      ]'
            echo '   }'
            echo ']'
        } > "$1"
    }

    printf "\n - INFO: create diverse files and insert language strings ...\n"
    languages=()
    while read line; do
        languages+=($line)
    done <<<"$(ls -tp "$build_tmp/APP/ui/lang/" | egrep -v '/$' | cut -f 1 -d '.' | cut -f 2 -d '_')"
    echo "         dedected languages: ${languages[@]}"

    defaultSourceLang="$build_tmp/APP/ui/lang/lang_enu.txt"
    # PKG_DSMx/INFO

    synosetkeyvalue "$build_tmp/$PKG/INFO" description $(get_key_value "$defaultSourceLang" lang_INFO_description)

    # install_uifile
    install_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/install_uifile"
    create_install_uifile "$install_uifile_lang"

    sed_i "s|lang_wizui_install_title|$(get_key_value "$defaultSourceLang" lang_wizui_install_title)|"  "$install_uifile_lang"
    sed_i "s|lang_wizui_install_desc|$(get_key_value "$defaultSourceLang" lang_wizui_install_desc)|"  "$install_uifile_lang"

    # uninstall_uifile
    uninstall_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/uninstall_uifile"
    create_uninstall_uifile "$uninstall_uifile_lang"
    sed_i "s|lang_wizui_uninstall_title|$(get_key_value "$defaultSourceLang" lang_wizui_uninstall_title)|" "$uninstall_uifile_lang"
    sed_i "s|lang_wizui_uninstall_desc_1|$(get_key_value "$defaultSourceLang" lang_wizui_uninstall_desc_1)|" "$uninstall_uifile_lang"
    sed_i "s|lang_wizui_uninstall_desc_2|$(get_key_value "$defaultSourceLang" lang_wizui_uninstall_desc_2)|" "$uninstall_uifile_lang"

    # upgrade_uifile
    if [ "$TargetDSM" = 6 ]; then
        upgrade_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/upgrade_uifile"
        create_upgrade_uifile "$upgrade_uifile_lang"
        sed_i "s|lang_wizui_upgrade_title|$(get_key_value "$defaultSourceLang" lang_wizui_upgrade_title)|" "$upgrade_uifile_lang"
        sed_i "s|lang_wizui_upgrade_desc|$(get_key_value "$defaultSourceLang" lang_wizui_upgrade_desc)|" "$upgrade_uifile_lang"
    fi

    for lang in ${languages[@]}; do
        # PKG_DSMx/INFO
        synosetkeyvalue "$build_tmp/$PKG/INFO" description_${lang} $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_INFO_description)
        
        # i18n notification files
        langDir="$build_tmp/APP/ui/texts/${lang}"
        notifyFileLang="$build_tmp/APP/ui/texts/${lang}/strings"
        mkdir -p "$langDir"
        create_notify_file "$notifyFileLang"

        sed_i "s|lang_notify_file_job_successful|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_notify_file_job_successful)|" "${notifyFileLang}"
        sed_i "s|lang_notify_file_update_available|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_notify_file_update_available)|" "${notifyFileLang}"
        sed_i "s|lang_notify_file_update_version_installed|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_notify_file_update_version_installed)|" "${notifyFileLang}"
        sed_i "s|lang_notify_file_update_version_online|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_notify_file_update_version_online)|" "${notifyFileLang}"

        # PKG_DSMx/scripts/lang/${lang}
        scripts_lang_lang="$build_tmp/$PKG/scripts/lang/${lang}"
        if [ ! -f "${scripts_lang_lang}" ]; then
            # add language variables in script language file:
            echo 'PKG_NOINSTALL_ERROR_PART1="lang_PKG_NOINSTALL_ERROR_PART1"' > "${scripts_lang_lang}"
            echo 'PKG_NOINSTALL_ERROR_PART2="lang_PKG_NOINSTALL_ERROR_PART2"' >> "${scripts_lang_lang}"
            echo 'PKG_NOINSTALL_ERROR_PART3="lang_PKG_NOINSTALL_ERROR_PART3"' >> "${scripts_lang_lang}"
            echo 'PKG_NOINSTALL_MISSING_DOCKER_ERROR="lang_PKG_NOINSTALL_MISSING_DOCKER_ERROR"' >> "${scripts_lang_lang}"
            echo 'PKG_DELETE_TIMER="lang_PKG_DELETE_TIMER"' >> "${scripts_lang_lang}"
        fi
        synosetkeyvalue "${scripts_lang_lang}" PKG_NOINSTALL_ERROR_PART1 $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_PKG_NOINSTALL_ERROR_PART1)
        synosetkeyvalue "${scripts_lang_lang}" PKG_NOINSTALL_ERROR_PART2 $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_PKG_NOINSTALL_ERROR_PART2)
        synosetkeyvalue "${scripts_lang_lang}" PKG_NOINSTALL_ERROR_PART3 $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_PKG_NOINSTALL_ERROR_PART3)
        synosetkeyvalue "${scripts_lang_lang}" PKG_NOINSTALL_MISSING_DOCKER_ERROR $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_PKG_NOINSTALL_MISSING_DOCKER_ERROR)
        synosetkeyvalue "${scripts_lang_lang}" PKG_DELETE_TIMER $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_PKG_DELETE_TIMER)

        # install_uifile:
        install_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/install_uifile_${lang}"
        create_install_uifile "${install_uifile_lang}"
        sed_i "s|lang_wizui_install_title|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_install_title)|" "${install_uifile_lang}"
        sed_i "s|lang_wizui_install_desc|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_install_desc)|" "${install_uifile_lang}"

        # uninstall_uifile:
        uninstall_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/uninstall_uifile_${lang}"
        create_uninstall_uifile "${uninstall_uifile_lang}"
        sed_i "s|lang_wizui_uninstall_title|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_uninstall_title)|" "${uninstall_uifile_lang}"
        sed_i "s|lang_wizui_uninstall_desc_1|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_uninstall_desc_1)|" "${uninstall_uifile_lang}"
        sed_i "s|lang_wizui_uninstall_desc_2|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_uninstall_desc_2)|" "${uninstall_uifile_lang}"
 
        # upgrade_uifile (only for refresh notify after upgrade):
        # (currently without fallback to plain english file)
        if [ "$TargetDSM" = 6 ]; then
            upgrade_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/upgrade_uifile_${lang}"
            create_upgrade_uifile "${upgrade_uifile_lang}"
            [ -f "$build_tmp/$PKG/WIZARD_UIFILES/upgrade_uifile_${lang}" ] && sed_i "s|lang_wizui_upgrade_title|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_upgrade_title)|" "${upgrade_uifile_lang}"
            [ -f "$build_tmp/$PKG/WIZARD_UIFILES/upgrade_uifile_${lang}" ] && sed_i "s|lang_wizui_upgrade_desc|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_upgrade_desc)|" "${upgrade_uifile_lang}"
        fi
    done

    build_version=$(grep version "$build_tmp/$PKG/INFO" | awk -F '"' '{print $2}')
    if [[ $(grep beta "$build_tmp/$PKG/INFO" | awk -F '"' '{print $2}') == yes ]]; then
        beta_status="_BETA"
        # write changelog to INFO:
        echo "changelog=\"$(cat "$build_tmp/$PKG/CHANGELOG_CURRENT_BETA" | awk -v RS="" '{gsub (/\n/,"<br/>")}1')\"" >> "$build_tmp/$PKG/INFO"
    else
        # write changelog to INFO:
        echo "changelog=\"$(cat "$build_tmp/$PKG/CHANGELOG_CURRENT_RELEASE" | awk -v RS="" '{gsub (/\n/,"<br/>")}1')\"" >> "$build_tmp/$PKG/INFO"
    fi

    rm -f "$build_tmp/$PKG/CHANGELOG_CURRENT_BETA"
    rm -f "$build_tmp/$PKG/CHANGELOG_CURRENT_RELEASE"

    printf "\n-----------------------------------------------------------------------------------\n"
    printf "   SPK will be created ..."
    printf "\n-----------------------------------------------------------------------------------\n\n"
    printf "\n - INFO: The following version is loaded and built:\n"

    if [ -z "$set_spk_version" ]; then
        #set_spk_version="latest-$(date +%s)-$(git log -1 --format="%h")"
        set_spk_version="$(git branch --show-current)_latest_[$build_version]_($(date +%Y)-$(date +%m)-$(date +%d)_$(date +%H)-$(date +%M))_$(git log -1 --format="%h")"
    fi

    echo "    $set_spk_version - BUILD-Version (INFO-File): $build_version"

# Falls versteckter Ordners /.helptoc vorhanden, diesen nach /helptoc umbenennen
    printf "\n - INFO: handle .helptoc files ...\n"
    if test -d "${build_tmp}/.helptoc"; then
        echo ""
        echo " - INFO: Versteckter Ordner /.helptoc wurde lokalisiert und nach /helptoc umbenannt"
        mv "${build_tmp}/.helptoc" "${build_tmp}/helptoc"
    fi

    printf "\n - INFO: create empty dirs ...\n"
    [ ! -d "${build_tmp}/APP/cfg" ] && echo "    create dir ${build_tmp}/APP/cfg" && mkdir "${build_tmp}/APP/cfg"
    [ ! -d "${build_tmp}/APP/log" ] && echo "    create dir ${build_tmp}/APP/log" && mkdir "${build_tmp}/APP/log"
    [ ! -d "${build_tmp}/APP/ui/etc" ] && echo "    create dir ${build_tmp}/APP/ui/etc" && mkdir "${build_tmp}/APP/ui/etc"
 #  [ ! -d "${build_tmp}/APP/ui/usersettings" ] && echo "    create dir ${build_tmp}/APP/ui/usersettings" && mkdir "${build_tmp}/APP/ui/usersettings"

    printf "\n - INFO: adjust permissions ...\n"
    chmod -R 755 "${build_tmp}/APP/"
    chmod -R 755 "${build_tmp}/$PKG/"
    chmod -R 755 "${build_tmp}/APP/ui/texts/"

# Packing and dropping the current installation into the appropriate /Pack folder
    printf "\n - INFO: The archive package.tgz will be created ...\n"

    $FAKEROOT tar -C "${build_tmp}/APP" -czf "${build_tmp}/$PKG"/package.tgz .

# Change to the storage location of package.tgz regarding the structure of the SPKs
    cd "${build_tmp}/${PKG}"

# Creating the final SPK
    printf "\n - INFO: the SPK will be created ...\n"
    TargetName="${project}_DSM${TargetDSM}_${set_spk_version}${beta_status}.spk"
    # $build_version
    $FAKEROOT tar -cf "$TargetName" *
    cp -f "$TargetName" "${APPDIR}"

    printf "\n-----------------------------------------------------------------------------------\n"
    printf "   The SPK was created and can be found at:\n"
    printf "   ${APPDIR}/$TargetName\n"
    printf "\n-----------------------------------------------------------------------------------\n\n"

exit 0
