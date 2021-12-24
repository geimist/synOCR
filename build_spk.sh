#!/bin/bash
#
#######
project="synOCR"
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

printf "\n - INFO: collect the DSM specific files:\n"
    if [ $TargetDSM -eq 7 ]; then
        PKG=PKG_DSM7
        mv $build_tmp/APP/ui/config_DSM7 $build_tmp/APP/ui/config
        rm -f $build_tmp/APP/ui/config_DSM6
        mv $build_tmp/APP/ui/images_DSM7 $build_tmp/APP/ui/images
        rm -rf $build_tmp/APP/ui/images_DSM6
#       sed -i 's/VERSION_DSM/VERSION_DSM7/' "$build_tmp/APP/ui/synOCR-start.sh"
    else
        PKG=PKG_DSM6
        mv $build_tmp/APP/ui/config_DSM6 $build_tmp/APP/ui/config
        rm -f $build_tmp/APP/ui/config_DSM7
        mv $build_tmp/APP/ui/images_DSM6 $build_tmp/APP/ui/images
        rm -rf $build_tmp/APP/ui/images_DSM7
#       sed -i 's/VERSION_DSM/VERSION_DSM6/' "$build_tmp/APP/ui/synOCR-start.sh"
    fi

    build_version=$(grep version "$build_tmp/$PKG/INFO" | awk -F '"' '{print $2}')
    beta_status=""  #$(grep beta "$build_tmp/$PKG/INFO" | awk -F '"' '{print $2}')
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
    [ ! -d "${build_tmp}/APP/ui/usersettings" ] && echo "    create dir ${build_tmp}/APP/ui/usersettings" && mkdir "${build_tmp}/APP/ui/usersettings"

printf "\n - INFO: adjust permissions ...\n"
    chmod -R 755 "${build_tmp}/APP/"
    chmod -R 755 "${build_tmp}/$PKG/"
#   chmod -R 644 "${build_tmp}/APP/ui/texts/"

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
    echo "   The SPK was created and can be found at:"
    printf "\n-----------------------------------------------------------------------------------\n\n"

    printf "   ${APPDIR}/$TargetName\n"

exit 0









