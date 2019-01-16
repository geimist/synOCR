#!/bin/sh
# prüft die benutzerangepasste Datei Konfiguration.txt auf neue Variablen und ergänzt ggf. selbige
# /volume*/@appstore/synOCR/upgradeconfig.sh

# Arbeitsverzeichnis auslesen und hineinwechseln:
# ---------------------------------------------------------------------
	APPDIR=$(cd $(dirname $0);pwd)
	cd ${APPDIR}
	
	CONFIG=etc/Konfiguration.txt

    lastrow=`cat ./$CONFIG | tail -n1`  # letzte Zeile eine Leerzeile?
#    [ ! "$lastrow" == "" ] && echo -e "\n" >> ./$CONFIG

    if [ ! -z "$lastrow" ]; then
        echo -e "\n" >> ./$CONFIG
    fi
    
    # Prüfe die Konfiguration.txt auf fehlende Parameter:
    # ---------------------------------------------------------------------
    	if ! cat ./$CONFIG | grep -q "delSearchPraefix" ; then
    	    echo "delSearchPraefix=\"no\"" >> ./$CONFIG
        fi

exit 0
