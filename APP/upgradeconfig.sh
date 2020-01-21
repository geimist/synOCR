#!/bin/sh
# upgradeconfig.sh
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
        sqlinst="CREATE TABLE \"config\" (\"profile_ID\" INTEGER PRIMARY KEY ,\"timestamp\" timestamp NOT NULL DEFAULT (CURRENT_TIMESTAMP) ,\"profile\" varchar ,\"active\" varchar DEFAULT ('1') ,\"INPUTDIR\" varchar DEFAULT ('/volume1/<PATH>/_INPUT') ,\"OUTPUTDIR\" varchar DEFAULT ('/volume1/<PATH>/_OUTPUT') ,\"BACKUPDIR\" varchar DEFAULT ('/volume1/<PATH>/_BACKUP') ,\"LOGDIR\" varchar DEFAULT ('/volume1/<PATH>/_LOG') ,\"LOGmax\" varchar DEFAULT ('10') ,\"SearchPraefix\" varchar ,\"delSearchPraefix\" varchar(5) DEFAULT ('yes') ,\"taglist\" varchar ,\"searchAll\" varchar DEFAULT ('no') ,\"moveTaggedFiles\" varchar DEFAULT ('useCatDir') ,\"NameSyntax\" varchar DEFAULT ('§y-§m-§d_§tag_§tit') , \"ocropt\" varchar DEFAULT ('-srd -l deu') ,\"dockercontainer\" varchar DEFAULT ('jbarlow83/ocrmypdf') ,\"PBTOKEN\" varchar ,\"dsmtextnotify\" varchar DEFAULT ('on') ,\"MessageTo\" varchar DEFAULT ('admin') ,\"dsmbeepnotify\" varchar DEFAULT ('on') ,\"loglevel\" varchar DEFAULT ('1') ,\"filedate2ocr\" VARCHAR DEFAULT ('no') ,\"tagsymbol\" VARCHAR DEFAULT ('#') );"
        sqlite3 "./etc/synOCR.sqlite" "$sqlinst"
        sleep 1
        sqlinst="CREATE TABLE \"system\" (\"rowid\" INTEGER PRIMARY KEY ,\"timestamp\" timestamp NOT NULL DEFAULT (CURRENT_TIMESTAMP) ,\"DB_Version\" varchar DEFAULT ('1')  );"
        sqlite3 "./etc/synOCR.sqlite" "$sqlinst"
        sleep 1
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system ( DB_Version ) VALUES ( '1' )"
        sleep 1
        
        # Tabellen erstellen
        if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT count(*) FROM config") -eq 0 ] ; then
            if [ -f "./etc/Konfiguration.txt" ]; then
                # Migration von der textbasierten auf die DB-basierte Konfiguration
                source "./etc/Konfiguration.txt"
                sqlite3 ./etc/synOCR.sqlite "INSERT INTO config ( profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix, taglist, searchAll, 
                                    moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN, dsmtextnotify, MessageTo, dsmbeepnotify, loglevel 
                                    ) VALUES ( 
                                    'default', '$INPUTDIR', '$OUTPUTDIR', '$BACKUPDIR', '$LOGDIR', '$LOGmax', '$SearchPraefix', '$delSearchPraefix', 
                                    '$taglist', '$searchAll', '$moveTaggedFiles', '$NameSyntax', '$ocropt', '$dockercontainer', '$PBTOKEN', '$dsmtextnotify', 
                                    '$MessageTo', '$dsmbeepnotify', '$loglevel' )"
                mv "./etc/Konfiguration.txt" "./etc/Konfiguration_imported.txt"
            else
                new_profile "default"
            fi
        fi
    fi
    
# DB-Update von v1 auf v2:
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT DB_Version FROM system") -eq 1 ] ; then
    	# Parameter hinzufügen:
            # filedate auf OCR
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config ADD COLUMN \"filedate2ocr\" VARCHAR DEFAULT ('no') "
            # Tagkennzeichner
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config ADD COLUMN \"tagsymbol\" VARCHAR DEFAULT ('#') "
        # DB-Version anheben:
        sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET DB_Version='2', timestamp=(datetime('now','localtime')) WHERE rowid=1"        
    fi

exit 0

# bei DB-Upgrade auch …
# ➜ das initiales DB-Createstatement anpassen (inkl. DB-Version)
# ➜ Parameter in 'Profil duplizieren' in edit.sh anpassen
# ➜ Parameter in 'Datensatz in DB schreiben' in edit.sh anpassen
# ➜ "$page" == "edit" in edit.sh Profil einlesen anpassen
