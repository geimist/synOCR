#!/bin/sh
# /usr/syno/synoman/webman/3rdparty/synOCR/upgradeconfig.sh
# checks the configuration DB for new variables and adds them if necessary

log=""
error=0
mig_count_err=0
OLDIFS=$IFS

# Read working directory and change into it:
# ---------------------------------------------------------------------

    APPDIR=$(cd $(dirname $0);pwd)
    cd ${APPDIR}
    
    new_profile () 
    {
    # In this function a new profile record is written to the DB
    # Call: new_profile "profile name"
    # --------------------------------------------------------------
        sqliteinfo=$(sqlite3 ./etc/synOCR.sqlite "INSERT INTO config ( profile ) VALUES ( '$1' )")
    }

# Create DB if necessary:
# ---------------------------------------------------------------------
    if [ $(stat -c %s "./etc/synOCR.sqlite") -eq 0 ] || [ ! -f "./etc/synOCR.sqlite" ]; then

        # table config:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "CREATE TABLE \"config\" 
                    (
                        \"profile_ID\" INTEGER PRIMARY KEY ,
                        \"timestamp\" timestamp NOT NULL DEFAULT (CURRENT_TIMESTAMP) ,
                        \"profile\" varchar ,
                        \"active\" varchar DEFAULT ('1') ,
                        \"INPUTDIR\" varchar DEFAULT ('/volume1/<PATH>/_INPUT') ,
                        \"OUTPUTDIR\" varchar DEFAULT ('/volume1/<PATH>/_OUTPUT') ,
                        \"BACKUPDIR\" varchar DEFAULT ('/volume1/<PATH>/_BACKUP') ,
                        \"LOGDIR\" varchar DEFAULT ('/volume1/<PATH>/_LOG') ,
                        \"LOGmax\" varchar DEFAULT ('10') ,
                        \"SearchPraefix\" varchar ,
                        \"delSearchPraefix\" varchar(5) DEFAULT ('yes') ,
                        \"taglist\" varchar ,
                        \"searchAll\" varchar DEFAULT ('no') ,
                        \"moveTaggedFiles\" varchar DEFAULT ('useCatDir') ,
                        \"NameSyntax\" varchar DEFAULT ('§yocr-§mocr-§docr_§tag_§tit') ,
                        \"ocropt\" varchar DEFAULT ('-srd -l deu+eng') ,
                        \"dockercontainer\" varchar DEFAULT ('geimist/ocrmypdf-polyglot') ,
                        \"PBTOKEN\" varchar ,
                        \"dsmtextnotify\" varchar DEFAULT ('on') ,
                        \"MessageTo\" varchar DEFAULT ('admin') ,
                        \"dsmbeepnotify\" varchar DEFAULT ('on') ,
                        \"loglevel\" varchar DEFAULT ('1') ,
                        \"filedate\" VARCHAR DEFAULT ('ocr') ,
                        \"tagsymbol\" VARCHAR DEFAULT ('#') ,
                        \"documentSplitPattern\" varchar ,
                        \"ignoredDate\" varchar DEFAULT ('2021-02-29;2020-11-31') ,
                        \"backup_max\" VARCHAR ,
                        \"backup_max_type\" VARCHAR DEFAULT ('files') ,
                        \"pagecount\" VARCHAR DEFAULT ('0') ,
                        \"ocrcount\" VARCHAR  DEFAULT ('0') ,
                        \"search_nearest_date\" VARCHAR  DEFAULT ('false') ,
                        \"date_search_method\" VARCHAR  DEFAULT ('python') ,
                        \"clean_up_spaces\" VARCHAR  DEFAULT ('false') ,
                        \"accept_cpdf_license\" VARCHAR  DEFAULT ('false')
                    ) ;"
        sleep 1

        # table system:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "CREATE TABLE \"system\" 
                    (
                        \"rowid\" INTEGER PRIMARY KEY ,
                        \"key\" VARCHAR ,
                        \"value_1\" VARCHAR ,
                        \"value_2\" VARCHAR ,
                        \"value_3\" VARCHAR ,
                        \"value_4\" VARCHAR 
                    );"

        # write default data:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system (key, value_1) VALUES ('timestamp', '(datetime('now','localtime'))')"
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system (key, value_1) VALUES ('db_version', '6')"
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system (key, value_1) VALUES ('checkmon', '')"
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system (key, value_1) VALUES ('dockerimageupdate', '1')"
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system (key, value_1) VALUES ('global_pagecount', '0')"
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system (key, value_1) VALUES ('global_ocrcount', '0')"
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system (key, value_1) VALUES ('count_start_date', '$(date +%Y-%m-%d)')"
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system (key, value_1) VALUES ('online_version', '')"
        sleep 1

        # table dockerupdate / Docker-Image-Update - check date:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "CREATE TABLE \"dockerupdate\" 
                    (
                        \"rowid\" INTEGER PRIMARY KEY ,
                        \"image\" varchar,
                        \"date_checked\" varchar 
                    );"
        sleep 1

        # Create / migrate profile:
        # ---------------------------------------------------------------------
        if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT count(*) FROM config") -eq 0 ] ; then
            if [ -f "./etc/Konfiguration.txt" ]; then
                # Migration from text-based to DB-based configuration
                source "./etc/Konfiguration.txt"
                sqlite3 "./etc/synOCR.sqlite" "INSERT INTO config 
                    ( 
                        profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix, taglist, searchAll, 
                        moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN, dsmtextnotify, MessageTo, dsmbeepnotify, loglevel 
                    ) 
                        VALUES 
                    ( 
                        'default', '$INPUTDIR', '$OUTPUTDIR', '$BACKUPDIR', '$LOGDIR', '$LOGmax', '$SearchPraefix', '$delSearchPraefix', '$taglist', '$searchAll', 
                        '$moveTaggedFiles', '$NameSyntax', '$ocropt', '$dockercontainer', '$PBTOKEN', '$dsmtextnotify', '$MessageTo', '$dsmbeepnotify', '$loglevel'
                    )"

                mv "./etc/Konfiguration.txt" "./etc/Konfiguration_imported.txt"
                log="$log 
                ➜ Configuration was migrated to DB"
            else
                new_profile "default"
                log="$log 
                ➜ the default profile was created"
            fi
        fi
    fi


if $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(system)" | awk -F'|' '{print $2}' | grep -q DB_Version ) ; then
# DB-Update von v1 auf v2:
# ----------------------------------------------------------
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT DB_Version FROM system WHERE rowid=1") -eq 1 ] ; then
            # filedate at OCR:
            # ---------------------------------------------------------------------
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                           ADD COLUMN \"filedate\" varchar DEFAULT ('ocr') "
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q filedate ) ; then
                log="$log 
                ➜ ERROR: the DB column could not be created (filedate)"
                error=1
            fi

            # tag indicator:
            # ---------------------------------------------------------------------
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                           ADD COLUMN \"tagsymbol\" varchar DEFAULT ('#') "
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q tagsymbol ) ; then
                log="$log 
                ➜ ERROR: the DB column could not be created (tagsymbol)"
                error=1
            fi

            # checkmon
            # ---------------------------------------------------------------------
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE system 
                                           ADD COLUMN \"checkmon\" varchar "
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
                                           SET checkmon='$(get_key_value ./etc/counter checkmon)' 
                                           WHERE rowid=1"
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(system)" | awk -F'|' '{print $2}' | grep -q checkmon ) ; then
                log="$log
                ➜ ERROR: the DB column could not be created (checkmon)"
                error=1
            else
                sed -i '/checkmon/d' ./etc/counter
            fi

        if [[ "$error" == "0" ]]; then
            # lift DB version:
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
                                           SET DB_Version='2', timestamp=(datetime('now','localtime')) 
                                           WHERE rowid=1"
            log="$log 
            DB-Upgrade successfully processed (v1 ➜ v2)"
        fi
        error=0
    fi

# DB-Update von v2 auf v3:
# ---------------------------------------------------------------------
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT DB_Version FROM system WHERE rowid=1") -eq 2 ] ; then
            # Docker-Image-Update - no (0) or yes (1):
            # ---------------------------------------------------------------------
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE system 
                                           ADD COLUMN \"dockerimageupdate\" varchar DEFAULT ('1') "
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(system)" | awk -F'|' '{print $2}' | grep -q dockerimageupdate ) ; then
                log="$log 
                ➜ ERROR: the DB column could not be created (dockerimageupdate)"
                error=1
            fi

            # Docker-Image-Update - check date:
            # ---------------------------------------------------------------------
            sqlite3 "./etc/synOCR.sqlite" "CREATE TABLE \"dockerupdate\" 
                                            (
                                                \"rowid\" INTEGER PRIMARY KEY ,
                                                \"image\" varchar,
                                                \"date_checked\" varchar 
                                            );"
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(dockerupdate)" | awk -F'|' '{print $2}' | grep -q image ) ; then
                log="$log 
                ➜ ERROR: the DB table could not be created (dockerupdate)"
                error=1
            fi

        if [[ "$error" == "0" ]]; then
            # lift DB version:
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
                                           SET DB_Version='3', timestamp=(datetime('now','localtime')) 
                                           WHERE rowid=1"
            log="$log
            DB-Upgrade successfully processed (v2 ➜ v3)"
        fi
        error=0
    fi

# DB-Update von v3 auf v4:
# ---------------------------------------------------------------------
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT DB_Version FROM system WHERE rowid=1") -eq 3 ] ; then
            # documentSplitPattern:
            # ---------------------------------------------------------------------
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                           ADD COLUMN \"documentSplitPattern\" varchar"
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q documentSplitPattern ) ; then
                log="$log 
                ➜ ERROR: the DB column could not be created (documentSplitPattern)"
                error=1
            fi

            # ignoredDate:
            # ---------------------------------------------------------------------
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                           ADD COLUMN \"ignoredDate\" varchar DEFAULT ('2021-02-29;2020-11-31')"
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q ignoredDate ) ; then
                log="$log 
                ➜ ERROR: the DB column could not be created (ignoredDate)"
                error=1
            fi

        if [[ "$error" == "0" ]]; then
            # lift DB version:
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
                                           SET DB_Version='4', timestamp=(datetime('now','localtime')) 
                                           WHERE rowid=1"
            log="$log
            DB-Upgrade successfully processed (v3 ➜ v4)"
        fi
        error=0
    fi


# DB-Update von v4 auf v5:
# ---------------------------------------------------------------------
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT DB_Version FROM system WHERE rowid=1") -eq 4 ] ; then
            # rotate backup file configuration:
            # ---------------------------------------------------------------------
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                           ADD COLUMN \"backup_max\" VARCHAR"
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q backup_max ) ; then
                log="$log 
                ➜ ERROR: the DB column could not be created (backup_max"
                error=1
            fi
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                           ADD COLUMN \"backup_max_type\" VARCHAR DEFAULT ('files')"
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q backup_max_type ) ; then
                log="$log 
                ➜ ERROR: the DB column could not be created (backup_max_type)"
                error=1
            fi

            # reorganize table system:
            # create new table:
            # ---------------------------------------------------------------------
            sqlite3 "./etc/synOCR.sqlite" "CREATE TABLE \"system_new\" 
                                            (
                                                \"rowid\" INTEGER PRIMARY KEY ,
                                                \"key\" VARCHAR ,
                                                \"value_1\" VARCHAR ,
                                                \"value_2\" VARCHAR ,
                                                \"value_3\" VARCHAR ,
                                                \"value_4\" VARCHAR 
                                            );"
            # read stored data:
            sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT timestamp, DB_Version, checkmon, dockerimageupdate 
                                                                   FROM system 
                                                                   WHERE rowid=1")
            # rewrite data:
            sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('timestamp', '$(echo "$sqlerg" | awk -F'\t' '{print $1}')')"
            sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('db_version', '$(echo "$sqlerg" | awk -F'\t' '{print $2}')')"
            sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('checkmon', '$(echo "$sqlerg" | awk -F'\t' '{print $3}')')"
            sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('dockerimageupdate', '$(echo "$sqlerg" | awk -F'\t' '{print $4}')')"
            sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('online_version', '')"

            # migrate global data from 'counter' file:
            if [ -f ./etc/counter ] ; then
                sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('global_pagecount', '$(get_key_value ./etc/counter pagecount)')"
                sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('global_ocrcount', '$(get_key_value ./etc/counter ocrcount)')"
                sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('count_start_date', '$(get_key_value ./etc/counter startcount)')"
            else
                sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('global_pagecount', '0')"
                sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('global_ocrcount', '0')"
                sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system_new (key, value_1) VALUES ('count_start_date', '$(date +%Y-%m-%d)')"
            fi

            # check tables / reorder names:
            if echo $(sqlite3 "./etc/synOCR.sqlite" .tables) | grep -q system_new ; then
                sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE system 
                                               RENAME TO system_archived;"
                sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE system_new 
                                               RENAME TO system;"
            fi

            # migrate profile specific data from 'counter' file to DB:
            # create new columns:
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                           ADD COLUMN \"pagecount\" VARCHAR DEFAULT ('0')"
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q pagecount ) ; then
                log="$log 
                ➜ ERROR: the DB column could not be created (pagecount)"
                error=1
                mig_count_err=1
            fi
            sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                           ADD COLUMN \"ocrcount\" VARCHAR DEFAULT ('0')"
            # check:
            if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q ocrcount ) ; then
                log="$log 
                ➜ ERROR: the DB column could not be created (ocrcount)"
                error=1
                mig_count_err=1
            fi
            # copy date from counter file to DB:
            if [ -f ./etc/counter ] && [[ $mig_count_err -eq 0 ]]; then
                sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT profile_ID FROM config")
                IFS=$'\012'
                for entry in $sqlerg; do
                    IFS=$OLDIFS
                    profile_ID_DB=$(echo "$entry" | awk -F'\t' '{print $1}')
                    sqlite3 "./etc/synOCR.sqlite" "UPDATE config 
                                                   SET pagecount='$(get_key_value ./etc/counter pagecount_ID${profile_ID_DB} )' 
                                                   WHERE profile_ID='$profile_ID_DB'"
                    sqlite3 "./etc/synOCR.sqlite" "UPDATE config 
                                                   SET ocrcount='$(get_key_value ./etc/counter ocrcount_ID${profile_ID_DB} )' 
                                                   WHERE profile_ID='$profile_ID_DB'"
                done
                mv ./etc/counter ./etc/counter_archived
            fi

        if [[ "$error" == "0" ]]; then
            # lift DB version:
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
                                           SET value_1='5' 
                                           WHERE key='db_version'"
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
                                           SET value_1=(datetime('now','localtime')) 
                                           WHERE key='timestamp'"
            log="$log
            DB-Upgrade successfully processed (v4 ➜ v5)"
        fi
        error=0
    fi
fi


# DB-update from v5 to v6:
# ---------------------------------------------------------------------
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='db_version'") -eq 5 ] ; then
        # search_nearest_date:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"search_nearest_date\" VARCHAR DEFAULT ('firstfound')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q search_nearest_date ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (search_nearest_date)"
            error=1
        fi

        # date_search_method:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"date_search_method\" VARCHAR DEFAULT ('regex')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q date_search_method ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (date_search_method)"
            error=1
        fi

        # clean_up_spaces:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"clean_up_spaces\" VARCHAR DEFAULT ('false')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q clean_up_spaces ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (clean_up_spaces)"
            error=1
        fi
    fi


# DB-update from v6 to v7:
# ---------------------------------------------------------------------
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='db_version'") -eq 60000 ] ; then
        echo ""




        # accept_cpdf_license / maybe not needed:
        # ---------------------------------------------------------------------
#        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
#                                       ADD COLUMN \"accept_cpdf_license\" VARCHAR DEFAULT ('false')"
        # check:
#        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q accept_cpdf_license ) ; then
#            log="$log 
#            ➜ ERROR: the DB column could not be created (accept_cpdf_license)"
#            error=1
#        fi

#        if [[ "$error" == "0" ]]; then
            # lift DB version:
#            sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
#                                           SET value_1='6' 
#                                           WHERE key='db_version'"
#            sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
#                                           SET value_1=(datetime('now','localtime')) 
#                                           WHERE key='timestamp'"
#            log="$log
#            DB-Upgrade successfully processed (v5 ➜ v6)"
#        fi
#        error=0




        if [[ "$error" == "0" ]]; then
            # lift DB version:
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
                                           SET value_1='7' 
                                           WHERE key='db_version'"
            sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
                                           SET value_1=(datetime('now','localtime')) 
                                           WHERE key='timestamp'"
            log="$log
            DB-Upgrade successfully processed (v6 ➜ v7)"
        fi
#        error=0
    fi


# adjust permissions:
# ---------------------------------------------------------------------
    chmod 766 ./etc/synOCR.sqlite

echo "$log"

exit 0

# bei DB-Upgrade auch …
# ➜ upgradeconfig.sh: das initiales DB-Createstatement anpassen (inkl. DB-Version)
# ➜ edit.sh: Parameter in 'Profil duplizieren' anpassen (bei Änderungen an Tabelle config)
# ➜ edit.sh: Parameter in 'Datensatz in DB schreiben' anpassen
# ➜ edit.sh: "$page" == "edit" Profil einlesen anpassen

# ➜ synOCR.sh: DB-Einlesen anpassen
'
ToDo:

    '
