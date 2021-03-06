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
#
#buildversion=
# git fetch --all;git reset --hard origin/DSM_unibuild;git checkout DSM_unibuild


# Usage info
# ---------------------------------------------------------------------
show_help () {
cat << EOF
Without arguments, the script creates the SPK from the current master-branch from the server for DSM7.

Usage:      ./${0##*/} -v=<synOCR-Version> --dsm=<target DSM-Version>
Example:    ./${0##*/} -v=1.2.0 --dsm=7

    -v= --version=          specifies which synOCR version is to be built
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
    [[ ! $TargetDSM = 6 ]] && [[ ! $TargetDSM = 7 ]] && echo "wrong or empty value for target DSM version - set to 7" && TargetDSM=7

    echo "requested synOCR version: $buildversion"
    echo "target DSM version:       $TargetDSM"


# preparation:
# ---------------------------------------------------------------------
    set -euo pipefail
    IFS=$'\n\t'

    build_tmp=$(mktemp -d -t tmp.XXXXXXXXXX)

    function finish {
        git worktree remove --force "$build_tmp"
        rm -rf "$build_tmp"
    }
    trap finish EXIT

    if ! [ -x "$(command -v git)" ]; then
        echo 'Error: git is not installed.' >&2
        exit 1
    fi

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

    git pull

#   buildversion=${1:-latest}
    taggedversions=$(git tag)

    printf "\n-----------------------------------------------------------------------------------\n"
    printf " - INFO: Create the temporary build folder and copy sources into it ..."
    printf "\n-----------------------------------------------------------------------------------\n\n"

    git worktree add --force "$build_tmp" "$(git rev-parse --abbrev-ref HEAD)"
    pushd "$build_tmp"
    #set_spk_version="latest-$(date +%s)-$(git log -1 --format="%h")"
    set_spk_version="$(git branch --show-current)_latest_($(date +%Y)-$(date +%m)-$(date +%d)_$(date +%H)-$(date +%M))_$(git log -1 --format="%h")"

    if echo "$taggedversions" | egrep -q "$buildversion"; then
        echo "git checkout zu $buildversion"
        git checkout "$buildversion"
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
            echo 'job_successful="lang_notify_file_job_successful"'
            echo 'update_available="lang_notify_file_update_available (https://geimist.eu/synocr)"'
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
    sed -i "s|lang_wizui_install_title|$(get_key_value "$defaultSourceLang" lang_wizui_install_title)|"  "$install_uifile_lang"
    sed -i "s|lang_wizui_install_desc|$(get_key_value "$defaultSourceLang" lang_wizui_install_desc)|"  "$install_uifile_lang"

    # uninstall_uifile
    uninstall_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/uninstall_uifile"
    create_uninstall_uifile "$uninstall_uifile_lang"
    sed -i "s|lang_wizui_uninstall_title|$(get_key_value "$defaultSourceLang" lang_wizui_uninstall_title)|" "$uninstall_uifile_lang"
    sed -i "s|lang_wizui_uninstall_desc_1|$(get_key_value "$defaultSourceLang" lang_wizui_uninstall_desc_1)|" "$uninstall_uifile_lang"
    sed -i "s|lang_wizui_uninstall_desc_2|$(get_key_value "$defaultSourceLang" lang_wizui_uninstall_desc_2)|" "$uninstall_uifile_lang"

    # upgrade_uifile
    if [ "$TargetDSM" = 6 ]; then
        upgrade_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/upgrade_uifile"
        create_upgrade_uifile "$upgrade_uifile_lang"
        sed -i "s|lang_wizui_upgrade_title|$(get_key_value "$defaultSourceLang" lang_wizui_upgrade_title)|" "$upgrade_uifile_lang"
        sed -i "s|lang_wizui_upgrade_desc|$(get_key_value "$defaultSourceLang" lang_wizui_upgrade_desc)|" "$upgrade_uifile_lang"
    fi

    for lang in ${languages[@]}; do
        # PKG_DSMx/INFO
        synosetkeyvalue "$build_tmp/$PKG/INFO" description_${lang} $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_INFO_description)
        
        # i18n notification files
        langDir="$build_tmp/APP/ui/texts/${lang}"
        notifyFileLang="$build_tmp/APP/ui/texts/${lang}/strings"
        mkdir -p "$langDir"
        create_notify_file "$notifyFileLang"

        sed -i "s|lang_notify_file_job_successful|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_notify_file_job_successful)|" "${notifyFileLang}"
        sed -i "s|lang_notify_file_update_available|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_notify_file_update_available)|" "${notifyFileLang}"

        # PKG_DSMx/scripts/lang/${lang}
        scripts_lang_lang="$build_tmp/$PKG/scripts/lang/${lang}"
        if [ ! -f "${scripts_lang_lang}" ]; then
            echo 'PKG_NOINSTALL_ERROR_PART1="lang_PKG_NOINSTALL_ERROR_PART1"' > "${scripts_lang_lang}"
            echo 'PKG_NOINSTALL_ERROR_PART2="lang_PKG_NOINSTALL_ERROR_PART2"' >> "${scripts_lang_lang}"
            echo 'PKG_NOINSTALL_ERROR_PART3="lang_PKG_NOINSTALL_ERROR_PART3"' >> "${scripts_lang_lang}"
            echo 'PKG_DELETE_TIMER="lang_PKG_DELETE_TIMER"' >> "${scripts_lang_lang}"
        fi
        synosetkeyvalue "${scripts_lang_lang}" PKG_NOINSTALL_ERROR_PART1 $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_PKG_NOINSTALL_ERROR_PART1)
        synosetkeyvalue "${scripts_lang_lang}" PKG_NOINSTALL_ERROR_PART2 $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_PKG_NOINSTALL_ERROR_PART2)
        synosetkeyvalue "${scripts_lang_lang}" PKG_NOINSTALL_ERROR_PART3 $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_PKG_NOINSTALL_ERROR_PART3)
        synosetkeyvalue "${scripts_lang_lang}" PKG_DELETE_TIMER $(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_PKG_DELETE_TIMER)

        # install_uifile:
        install_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/install_uifile_${lang}"
        create_install_uifile "${install_uifile_lang}"
#        if [ ! -f "${install_uifile_lang}" ]; then
#            {   echo '['
#                echo '   {'
#                echo '      "step_title" : "lang_wizui_install_title",'
#                echo '      "items" : ['
#                echo '         {'
#                echo '            "desc" : "<p>lang_wizui_install_desc</p>"'
#                echo '         }'
#                echo '      ]'
#                echo '   }'
#                echo ']'
#            } > "${install_uifile_lang}"
#            fi
        sed -i "s|lang_wizui_install_title|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_install_title)|" "${install_uifile_lang}"
        sed -i "s|lang_wizui_install_desc|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_install_desc)|" "${install_uifile_lang}"

        # uninstall_uifile:
        uninstall_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/uninstall_uifile_${lang}"
        create_uninstall_uifile "${uninstall_uifile_lang}"
#        if [ ! -f "${uninstall_uifile_lang}" ]; then
#            {   echo '['
#                echo '   {'
#                echo '      "step_title" : "lang_wizui_uninstall_title",'
#                echo '      "items" : ['
#                echo '         {'
#                echo '            "desc" : "<p>lang_wizui_uninstall_desc</p>"'
#                echo '         }'
#                echo '      ]'
#                echo '   }'
#                echo ']'
#           }  > "${uninstall_uifile_lang}"
#        fi
        sed -i "s|lang_wizui_uninstall_title|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_uninstall_title)|" "${uninstall_uifile_lang}"
        sed -i "s|lang_wizui_uninstall_desc_1|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_uninstall_desc_1)|" "${uninstall_uifile_lang}"
        sed -i "s|lang_wizui_uninstall_desc_2|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_uninstall_desc_2)|" "${uninstall_uifile_lang}"
 
        # upgrade_uifile (only for refresh notify after upgrade):
        # (currently without fallback to plain english file)
        if [ "$TargetDSM" = 6 ]; then
            upgrade_uifile_lang="$build_tmp/$PKG/WIZARD_UIFILES/upgrade_uifile_${lang}"
            create_upgrade_uifile "${upgrade_uifile_lang}"
#            if [ ! -f "${upgrade_uifile_lang}" ]; then
#                {   echo '['
#                    echo '   {'
#                    echo '      "step_title" : "lang_wizui_upgrade_title",'
#                    echo '      "items" : ['
#                    echo '         {'
#                    echo '            "desc" : "<p>lang_wizui_upgrade_desc</p>"'
#                    echo '         }'
#                    echo '      ]'
#                    echo '   }'
#                    echo ']'
#                } > "${upgrade_uifile_lang}"
#            fi
            [ -f "$build_tmp/$PKG/WIZARD_UIFILES/upgrade_uifile_${lang}" ] && sed -i "s|lang_wizui_upgrade_title|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_upgrade_title)|" "${upgrade_uifile_lang}"
            [ -f "$build_tmp/$PKG/WIZARD_UIFILES/upgrade_uifile_${lang}" ] && sed -i "s|lang_wizui_upgrade_desc|$(get_key_value "$build_tmp/APP/ui/lang/lang_${lang}.txt" lang_wizui_upgrade_desc)|" "${upgrade_uifile_lang}"
        fi
    done

    build_version=$(grep version "$build_tmp/$PKG/INFO" | awk -F '"' '{print $2}')
    [[ $(grep beta "$build_tmp/$PKG/INFO" | awk -F '"' '{print $2}') == yes ]] && beta_status="_BETA"

    printf "\n-----------------------------------------------------------------------------------\n"
    printf "   SPK will be created ..."
    printf "\n-----------------------------------------------------------------------------------\n\n"
    printf "\n - INFO: The following version is loaded and built:\n"
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
    $FAKEROOT tar -cf "$TargetName" *
    cp -f "$TargetName" "${APPDIR}"

    printf "\n-----------------------------------------------------------------------------------\n"
    printf "   The SPK was created and can be found at:\n"
    printf "   ${APPDIR}/$TargetName\n"
    printf "\n-----------------------------------------------------------------------------------\n\n"

exit 0

