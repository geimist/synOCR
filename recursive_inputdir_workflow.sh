#!/bin/bash
# ./recursive_inputdir_workflow.sh
# Tutorial: https://www.synology-forum.de/threads/synocr-gui-fuer-ocrmypdf.99647/post-879535

SOURCEPARENTDIR=""
SYNOCR_INPUT=""
SYNOCR_OUTPUT=""

#-----------------------------------|
# ab hier nichts mehr ändern        |
#-----------------------------------|

preprocess() {
# verschiebe Quelldateien nach SYNOCR_INPUT:
    IFS=$'\012'
    for i in $(find "${SOURCEPARENTDIR}" -iname "*.pdf" -type f); do
        IFS=$OLDIFS
        FILEPATH=$(dirname "$i")
        FILENAME=$(basename "$i")
        ID="$(date +%s%N)_"
    
    # erstelle Indexeintrag:
        echo "${ID}§_§${FILEPATH}§_§${FILENAME}" >> "$INDEXFILE"
    
    # verschiebe Quelldatei:
        mv "$i" "${SYNOCR_INPUT}${ID}${FILENAME}"
    done
}

postprocess() {
# verarbeitete Dateien zurücksortieren:
    cat "$INDEXFILE" | while read data ; do
        FILEPATH=$(echo $data | awk -F'§_§' '{print $2}')
        FILENAME=$(echo $data | awk -F'§_§' '{print $3}')
        ID=$(echo $data | awk -F'§_§' '{print $1}')
        
        FILEHOME="${FILEPATH}/${FILENAME}"
        OCRFILE=$( find "${SYNOCR_OUTPUT}" -iname "${ID}*.pdf" )
        mv "$OCRFILE" "$FILEHOME"
    done
    
    mv "$INDEXFILE" "${INDEXFILE}_finish"
}

OLDIFS=$IFS

APPDIR=$(cd $(dirname $0);pwd)

if [ ! -d "$SOURCEPARENTDIR" ] || [ ! -d "$SYNOCR_INPUT" ] || [ ! -d "$SYNOCR_OUTPUT" ] ; then
    echo "Pfad ungültig!"
    exit
fi

SOURCEPARENTDIR="${SOURCEPARENTDIR%/}/"
SYNOCR_INPUT="${SYNOCR_INPUT%/}/"
SYNOCR_OUTPUT="${SYNOCR_OUTPUT%/}/"

INDEXFILE="$(cd $(dirname $0);pwd)/multidir_workflow_INDEX.txt"

if [ ! -f "$INDEXFILE" ] ; then
    # backup, damit durch erneutes Starten nicht die bisherigen IDs gelöscht werden
    touch "$INDEXFILE"
    echo "Index wird erstellt ➜ verschiebe Dateien in den Arbeitsordner"
    preprocess
else
    echo "Index bereits vorhanden ➜ sortiere verarbeitete Dateien zurück"
    postprocess
fi

