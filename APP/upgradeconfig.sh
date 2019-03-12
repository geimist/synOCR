#!/bin/sh
# prüft die Konfiguration-DB auf neue Variablen und ergänzt ggf. selbige
# /volume*/@appstore/synOCR/upgradeconfig.sh

# Arbeitsverzeichnis auslesen und hineinwechseln:
# ---------------------------------------------------------------------
    APPDIR=$(cd $(dirname $0);pwd)
    cd ${APPDIR}
    
    new_profile () 
    {
    # In dieser Funktion wird ein neuer Profildatensatz in die DB geschrieben
    # Aufruf: new_profile "Profilname"
    # --------------------------------------------------------------
        sqliteinfo=$(sqlite3 ./etc/synOCR.sqlite "INSERT INTO config ( profile ) VALUES ( '$1' )")
    }

# DB ggf. erstellen:
    if [ $(stat -c %s "./etc/synOCR.sqlite") -eq 0 ] || [ ! -f "./etc/synOCR.sqlite" ]; then
        sqlinst="CREATE TABLE \"config\" (\"profile_ID\" INTEGER PRIMARY KEY ,\"timestamp\" timestamp NOT NULL DEFAULT (CURRENT_TIMESTAMP) ,\"profile\" varchar ,\"active\" varchar DEFAULT ('1') ,\"INPUTDIR\" varchar DEFAULT ('/volume1/homes/admin/Drive/SCANNER/_INPUT') ,\"OUTPUTDIR\" varchar DEFAULT ('/volume1/homes/admin/Drive/SCANNER/_OUTPUT') ,\"BACKUPDIR\" varchar DEFAULT ('/volume1/homes/admin/Drive/SCANNER/_BACKUP') ,\"LOGDIR\" varchar DEFAULT ('/volume1/homes/admin/Drive/SCANNER/_LOG') ,\"LOGmax\" varchar DEFAULT ('10') ,\"SearchPraefix\" varchar ,\"delSearchPraefix\" varchar(5) DEFAULT ('yes') ,\"taglist\" varchar ,\"searchAll\" varchar DEFAULT ('no') ,\"moveTaggedFiles\" varchar DEFAULT ('useCatDir') ,\"NameSyntax\" varchar DEFAULT ('§y-§m-§d_§tag_§tit') , \"ocropt\" varchar DEFAULT ('-srd -l deu') ,\"dockercontainer\" varchar DEFAULT ('jbarlow83/ocrmypdf') ,\"PBTOKEN\" varchar ,\"dsmtextnotify\" varchar DEFAULT ('on') ,\"MessageTo\" varchar DEFAULT ('admin') ,\"dsmbeepnotify\" varchar DEFAULT ('on') ,\"loglevel\" varchar DEFAULT ('1') );"
        sqliteinfo=$(sqlite3 "./etc/synOCR.sqlite" "$sqlinst")
        sqlinst="CREATE TABLE \"system\" (\"rowid\" INTEGER PRIMARY KEY ,\"timestamp\" timestamp NOT NULL DEFAULT (CURRENT_TIMESTAMP) ,\"DB_Version\" varchar  );"
        sqlite3 "./etc/synOCR.sqlite" "$sqlinst"
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system ( DB_Version ) VALUES ( '1' )"
    
    # Tabellen erstellen
        if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT count(*) FROM config") -eq 0 ] ; then
            if [ -f "./etc/Konfiguration.txt" ]; then
                source "./etc/Konfiguration.txt"
                sqliteinfo=$(sqlite3 ./etc/synOCR.sqlite 
                "INSERT INTO config ( profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix, taglist, searchAll, 
                                    moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN, dsmtextnotify, MessageTo, dsmbeepnotify, loglevel 
                                    ) VALUES ( 
                                    'default', '$INPUTDIR', '$OUTPUTDIR', '$BACKUPDIR', '$LOGDIR', '$LOGmax', '$SearchPraefix', '$delSearchPraefix', 
                                    '$taglist', '$searchAll', '$moveTaggedFiles', '$NameSyntax', '$ocropt', '$dockercontainer', '$PBTOKEN', '$dsmtextnotify', 
                                    '$MessageTo', '$dsmbeepnotify', '$loglevel' )")
                mv "./etc/Konfiguration.txt" "./etc/Konfiguration_imported.txt"
            else
                new_profile "default"
            fi
        fi
    fi

exit 0
