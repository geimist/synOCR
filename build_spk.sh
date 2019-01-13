#!/bin/bash
#----------------------------------------------------------------------------------------
# Scriptaufruf:
#----------------------------------------------------------------------------------------
# erstellt das SPK aus dem aktuellen master-branch vom Server:
# sh ./build_spk.sh 
#
# erstellt das SPK aus dem als Parameter übergebenen Release vom Server:
# sh ./build_spk.sh 4.0.7
#
#----------------------------------------------------------------------------------------
# Ordnerstruktur:
#----------------------------------------------------------------------------------------
# ./[NAME-DES-SPK]/Build --> Arbeitsumgebung (erstellen/editieren/verschieben)
# ./[NAME-DES-SPK]/Pack  --> Archivordner zum Aufbau des SPK (Startscripte etc.)
#

project="synOCR"


skriptuser=`whoami`
if [ ${skriptuser} != "root" ]; then
    echo "Dieses Skript muss von Root ausgeführt werden!"
    exit 1
fi

# Arbeitsverzeichnis auslesen und hineinwechseln:
# ---------------------------------------------------------------------
APPDIR=$(cd $(dirname $0);pwd)
cd ${APPDIR}

build_tmp="${APPDIR}/build_tmp"
dir=${APPDIR}

gitpull() 
{
#########################################################################################
# Diese Funktion bereinigt ältere Logfiles                                               #
#########################################################################################

gitpath=`which git`
if [ -z ${gitpath} ]; then
    echo "Das Programm git konnte nicht gefunden werden."
    exit 1
fi

# Ausführung: Erstellen des SPK
	echo ""
	echo "-----------------------------------------------------------------------------------"
	echo "   git holt die aktuelle Version ..."
	echo "-----------------------------------------------------------------------------------"

if [ -d "./${project}" ] ; then
    cd ${project}
    git pull
    versions=`git tag`
    cd ${APPDIR}
else
    git clone https://geimist.eu:30443/geimist/${project}.git
fi


build_version=`cat "${APPDIR}/${project}/Pack/INFO" | grep version | awk -F '"' '{print $2}'`

# welche Version soll gebaut werden:
if [ -z $1 ]; then
     echo "git checkout zu master-branch"
    cd ${project}
    git checkout master
    cd ${APPDIR}
    set_spk_version="latest_(`date +%Y`-`date +%m`-`date +%d`_`date +%H`-`date +%M`)"
else
    if echo "$versions" | egrep -q "$1"; then
        echo "git checkout zu $1"
        cd ${project}
        git checkout "$1"
        set_spk_version="$1"
        cd ${APPDIR}
    else
        echo "ACHTUNG: Die gewünschte Version wurde im Repository nicht gefunden!"
        echo "Der master-branch wird verwendet!"
        cd ${project}
        git checkout master
        cd ${APPDIR}
        set_spk_version="latest_(`date +%Y`-`date +%m`-`date +%d`_`date +%H`-`date +%M`)"
    fi
fi
}

#    gitpull


build_version=`cat "${APPDIR}/${project}/Pack/INFO" | grep version | awk -F '"' '{print $2}'`
set_spk_version=$build_version

echo " - INFO: Es wird foldende Version geladen und gebaut: $set_spk_version - BUILD-Version (INFO-File): $build_version"

echo " - INFO: Erstelle den temporären Buildordner und kopiere Sourcen hinein ..."
if [ -d "./build_tmp" ] ; then
	rm -rf "./build_tmp"
fi
mkdir "${build_tmp}"

cp -r "${APPDIR}/${project}"/* "${build_tmp}/"

# Ausführung: Erstellen des SPK
	echo ""
	echo "-----------------------------------------------------------------------------------"
	echo "   SPK wird erstellt..."
	echo "-----------------------------------------------------------------------------------"

# Falls versteckter Ordners /.helptoc vorhanden, diesen nach /helptoc umbenennen
	if test -d "${build_tmp}/.helptoc"; then
		echo ""
		echo " - INFO: Versteckter Ordner /.helptoc wurde lokalisiert und nach /helptoc umbenannt"
		mv ${build_tmp}/.helptoc ${build_tmp}/helptoc
	fi

# Rechte anpassen
	echo ""
	echo " - INFO: Dateirechte anpassen ..."
	for i in $(find "${build_tmp}/Pack/" -type f)
        do
            echo "ändere Pack: $i"
            chmod 755 "$i"
            chown root:root "$i"
        done
	
	for i in $(find "${build_tmp}/Build/" -type f)
        do
            echo "ändere Build: $i"
            chmod 755 "$i"
            chown root:root "$i"
        done

# Packen und Ablegen der aktuellen Installation in den entsprechenden /Pack - Ordner
	echo ""
	echo " - INFO: Das Archiv package.tgz wird erstellt..."
	
    tar -C ${build_tmp}/Build -czf ${build_tmp}/Pack/package.tgz .
    
# Wechsel in den Ablageort von package.tgz bezüglich Aufbau des SPK's
	cd ${build_tmp}/Pack

# Erstellen des eigentlichen SPK's
	echo ""
	echo " - INFO: Das SPK wird erstellt..."
	tar -cf ${project}_$set_spk_version.spk *
    mv ${project}_$set_spk_version.spk ${APPDIR}
    
# Löschen der temporären Daten
	echo ""
	echo " - INFO: Der temporäre Ordner wird wieder geschlöscht ..."
	cd ${APPDIR}
	if [ -d "./build_tmp" ] ; then
    	rm -rf "./build_tmp"
    fi

echo ""
echo "-----------------------------------------------------------------------------------"
echo "   Das SPK wurde erstellt und befindet sich unter..."
echo "-----------------------------------------------------------------------------------"
echo ""
echo "   ${APPDIR}/${project}_$set_spk_version.spk"
echo ""

exit 0
