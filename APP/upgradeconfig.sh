#!/bin/sh
# /usr/syno/synoman/webman/3rdparty/synOCR/upgradeconfig.sh
# prüft die Konfiguration-DB auf neue Variablen und ergänzt ggf. selbige

log=""
error=0

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
        sqlinst="CREATE TABLE \"config\" (\"profile_ID\" INTEGER PRIMARY KEY ,\"timestamp\" timestamp NOT NULL DEFAULT (CURRENT_TIMESTAMP) ,\"profile\" varchar ,\"active\" varchar DEFAULT ('1') ,\"INPUTDIR\" varchar DEFAULT ('/volume1/<PATH>/_INPUT') ,\"OUTPUTDIR\" varchar DEFAULT ('/volume1/<PATH>/_OUTPUT') ,\"BACKUPDIR\" varchar DEFAULT ('/volume1/<PATH>/_BACKUP') ,\"LOGDIR\" varchar DEFAULT ('/volume1/<PATH>/_LOG') ,\"LOGmax\" varchar DEFAULT ('10') ,\"SearchPraefix\" varchar ,\"delSearchPraefix\" varchar(5) DEFAULT ('yes') ,\"taglist\" varchar ,\"searchAll\" varchar DEFAULT ('no') ,\"moveTaggedFiles\" varchar DEFAULT ('useCatDir') ,\"NameSyntax\" varchar DEFAULT ('§y-§m-§d_§tag_§tit') , \"ocropt\" varchar DEFAULT ('-srd -l deu') ,\"dockercontainer\" varchar DEFAULT ('jbarlow83/ocrmypdf') ,\"PBTOKEN\" varchar ,\"dsmtextnotify\" varchar DEFAULT ('on') ,\"MessageTo\" varchar DEFAULT ('admin') ,\"dsmbeepnotify\" varchar DEFAULT ('on') ,\"loglevel\" varchar DEFAULT ('1') ,\"filedate\" VARCHAR DEFAULT ('ocr') ,\"tagsymbol\" VARCHAR DEFAULT ('#') );"
        sqlite3 "./etc/synOCR.sqlite" "$sqlinst"
        sleep 1
        sqlinst="CREATE TABLE \"system\" (\"rowid\" INTEGER PRIMARY KEY ,\"timestamp\" timestamp NOT NULL DEFAULT (CURRENT_TIMESTAMP) ,\"DB_Version\" varchar DEFAULT ('1')  );"
        sqlite3 "./etc/synOCR.sqlite" "$sqlinst"
        sleep 1
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system ( DB_Version ) VALUES ( '1' )"
        sleep 1
        
        # Profil erstellen / migrieren:
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
                log="$log ➜ Konfiguration wurde nach DB migriert"
            else
                new_profile "default"
                log="$log ➜ das Default-Profil wurde erstellt"
            fi
        fi
    fi

# DB-Update von v1 auf v2:
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT DB_Version FROM system WHERE rowid=1") -eq 1 ] ; then
    	# DB-Parameter hinzufügen:
            # filedate auf OCR
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config ADD COLUMN \"filedate\" varchar DEFAULT ('ocr') "
            # Prüfen:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q filedate ) ; then
                log="$log ➜ die DB-Spalte konnte nicht erstellt werden (filedate)"
                error=1
            fi
            # Tagkennzeichner
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config ADD COLUMN \"tagsymbol\" varchar DEFAULT ('#') "
            # Prüfen:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q tagsymbol ) ; then
                log="$log ➜ die DB-Spalte konnte nicht erstellt werden (tagsymbol)"
                error=1
            fi
            # checkmon
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE system ADD COLUMN \"checkmon\" varchar "
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET checkmon='$(get_key_value ./etc/counter checkmon)' WHERE rowid=1"
            # Prüfen:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(system)" | awk -F'|' '{print $2}' | grep -q checkmon ) ; then
                log="$log ➜ die DB-Spalte konnte nicht erstellt werden (checkmon)"
                error=1
            else
                sed -i '/checkmon/d' ./etc/counter
            fi
            
        if [[ "$error" == "0" ]]; then
            # DB-Version anheben:
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET DB_Version='2', timestamp=(datetime('now','localtime')) WHERE rowid=1"
            log="$log DB-Upgrade erfolgreich durchgeführt (v1 ➜ v2)"
        fi
    fi

# DB-Update von v2 auf v3:
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT DB_Version FROM system WHERE rowid=1") -eq 2 ] ; then
    	# DB-Parameter hinzufügen:
            # Docker-Image-Update - no (0) or yes (1):
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE system ADD COLUMN \"dockerimageupdate\" varchar DEFAULT ('1') "
            # Prüfen:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(system)" | awk -F'|' '{print $2}' | grep -q dockerimageupdate ) ; then
                log="$log ➜ die DB-Spalte konnte nicht erstellt werden (dockerimageupdate)"
                error=1
            fi
            # Docker-Image-Update - check date:
            sqlinst="CREATE TABLE \"dockerupdate\" (\"rowid\" INTEGER PRIMARY KEY ,\"image\" varchar,\"date_checked\" varchar );"
            sqlite3 "./etc/synOCR.sqlite" "$sqlinst"
            # Prüfen:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(dockerupdate)" | awk -F'|' '{print $2}' | grep -q image ) ; then
                log="$log ➜ die DB-Spalte konnte nicht erstellt werden (image)"
                error=1
            fi
            
        if [[ "$error" == "0" ]]; then
            # DB-Version anheben:
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system SET DB_Version='3', timestamp=(datetime('now','localtime')) WHERE rowid=1"
            log="$log
            DB-Upgrade successfully processed (v2 ➜ v3)"
        fi
    fi

echo "$log"

exit 0

# bei DB-Upgrade auch …
# ➜ upgradeconfig.sh: das initiales DB-Createstatement anpassen (inkl. DB-Version)
# ➜ edit.sh: Parameter in 'Profil duplizieren' anpassen
# ➜ edit.sh: Parameter in 'Datensatz in DB schreiben' anpassen
# ➜ edit.sh: "$page" == "edit" Profil einlesen anpassen
# ➜ synOCR.sh: DB-Einlesen anpassen
