#!/bin/bash

#################################################################################
#   description:    checks / create the configuration DB for new variables      #
#                   and adds them if necessary                                  #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/upgradeconfig.sh   #
#   © 2023 by geimist                                                           #
#################################################################################

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

    lift_db ()
    {
    # this function lift DB version
    # Call: lift_db "old Version" "new Version"
    # --------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
                                       SET value_1='$2' 
                                       WHERE key='db_version'"
        sqlite3 "./etc/synOCR.sqlite" "UPDATE system 
                                       SET value_1=(datetime('now','localtime')) 
                                       WHERE key='timestamp'"
        log="$log
        DB-Upgrade successfully processed ( v$1 ➜ v$2)"
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
                        \"profile\" VARCHAR ,
                        \"active\" VARCHAR DEFAULT ('1') ,
                        \"INPUTDIR\" VARCHAR DEFAULT ('/volume1/<PATH>/_INPUT') ,
                        \"OUTPUTDIR\" VARCHAR DEFAULT ('/volume1/<PATH>/_OUTPUT') ,
                        \"BACKUPDIR\" VARCHAR DEFAULT ('/volume1/<PATH>/_BACKUP') ,
                        \"LOGDIR\" VARCHAR DEFAULT ('/volume1/<PATH>/_LOG') ,
                        \"LOGmax\" VARCHAR DEFAULT ('10') ,
                        \"SearchPraefix\" VARCHAR ,
                        \"delSearchPraefix\" VARCHAR(5) DEFAULT ('yes') ,
                        \"taglist\" VARCHAR ,
                        \"searchAll\" VARCHAR DEFAULT ('no') ,
                        \"moveTaggedFiles\" VARCHAR DEFAULT ('useCatDir') ,
                        \"NameSyntax\" VARCHAR DEFAULT ('§yocr-§mocr-§docr_§tag_§tit') ,
                        \"ocropt\" VARCHAR DEFAULT ('-srd -l deu+eng') ,
                        \"dockercontainer\" VARCHAR DEFAULT ('jbarlow83/ocrmypdf:v12.7.2') ,
                        \"apprise_call\" VARCHAR ,
                        \"apprise_attachment\" VARCHAR DEFAULT ('false'),
                        \"notify_lang\" VARCHAR DEFAULT ('enu') ,
                        \"dsmtextnotify\" VARCHAR DEFAULT ('on') ,
                        \"MessageTo\" VARCHAR DEFAULT ('admin') ,
                        \"dsmbeepnotify\" VARCHAR DEFAULT ('on') ,
                        \"loglevel\" varchar DEFAULT ('1') ,
                        \"filedate\" VARCHAR DEFAULT ('ocr') ,
                        \"tagsymbol\" VARCHAR DEFAULT ('#') ,
                        \"documentSplitPattern\" varchar DEFAULT ('SYNOCR-SEPARATOR-SHEET') ,
                        \"ignoredDate\" varchar DEFAULT ('2021-02-29;2020-11-31') ,
                        \"backup_max\" VARCHAR ,
                        \"backup_max_type\" VARCHAR DEFAULT ('files') ,
                        \"pagecount\" VARCHAR DEFAULT ('0') ,
                        \"ocrcount\" VARCHAR  DEFAULT ('0') ,
                        \"search_nearest_date\" VARCHAR  DEFAULT ('false') ,
                        \"date_search_method\" VARCHAR  DEFAULT ('python') ,
                        \"clean_up_spaces\" VARCHAR  DEFAULT ('false') ,
                        \"img2pdf\" VARCHAR  DEFAULT ('false') ,
                        \"DateSearchMinYear\" VARCHAR DEFAULT ('0') ,
                        \"DateSearchMaxYear\" VARCHAR DEFAULT ('0') ,
                        \"splitpagehandling\" VARCHAR DEFAULT ('discard') ,
                        \"blank_page_detection_switch\" VARCHAR DEFAULT ('false') ,
                        \"blank_page_detection_threshold_bw\" VARCHAR DEFAULT ('150') ,
                        \"blank_page_detection_threshold_black_pxl\" VARCHAR DEFAULT ('10')
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
        sqlite3 "./etc/synOCR.sqlite" "INSERT INTO system (key, value_1) VALUES ('db_version', '9')"
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
                                           ADD COLUMN \"documentSplitPattern\" varchar DEFAULT ('SYNOCR-SEPARATOR-SHEET') "
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
            lift_db 4 5
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
                                       ADD COLUMN \"date_search_method\" VARCHAR DEFAULT ('python')"
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

        if [[ "$error" == "0" ]]; then
            # lift DB version:
            lift_db 5 6
        fi
        error=0
    fi


# DB-update from v6 to v7:
# ---------------------------------------------------------------------
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='db_version'") -eq 6 ] ; then

        # should convert images to pdf?:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"img2pdf\" VARCHAR DEFAULT ('false')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q img2pdf ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (img2pdf)"
            error=1
        fi

        if [[ "$error" == "0" ]]; then
            # lift DB version:
            lift_db 6 7
        fi
        error=0
    fi


# DB-update from v7 to v8:
# ---------------------------------------------------------------------
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='db_version'") -eq 7 ] ; then

        # DateSearchMinYear:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"DateSearchMinYear\" VARCHAR DEFAULT ('0')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q DateSearchMinYear ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (DateSearchMinYear)"
            error=1
        fi

        # DateSearchMaxYear: 
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"DateSearchMaxYear\" VARCHAR DEFAULT ('0')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q DateSearchMaxYear ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (DateSearchMaxYear)"
            error=1
        fi

        # splitpage handling: 
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"splitpagehandling\" VARCHAR DEFAULT ('discard')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q splitpagehandling ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (splitpagehandling)"
            error=1
        fi

        if [[ "$error" == "0" ]]; then
            # lift DB version:
            lift_db 7 8
        fi
        error=0
    fi


# DB-update from v8 to v9:
# ---------------------------------------------------------------------
    if [ $(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='db_version'") -eq 8 ] ; then

        # apprise - rename column PBTOKEN to apprise_call for apprise library:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       RENAME COLUMN \"PBTOKEN\" TO \"apprise_call\" "
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q apprise_call ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be renamed (PBTOKEN to apprise_call)"
            error=1
        else
            # delete old PushBullet token:
            sqlite3 "./etc/synOCR.sqlite" "UPDATE config SET apprise_call = NULL;"
        fi

        # apprise - notification language:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"notify_lang\" VARCHAR DEFAULT ('enu')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q notify_lang ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (notify_lang)"
            error=1
        fi

        # apprise use attachment:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"apprise_attachment\" VARCHAR DEFAULT ('false')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q apprise_attachment ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (apprise_attachment)"
            error=1
        fi

        # blank page detection - on/off:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"blank_page_detection_switch\" VARCHAR DEFAULT ('false')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q blank_page_detection_switch ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (blank_page_detection_switch)"
            error=1
        fi

        # blank page detection - threshold_bw:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"blank_page_detection_threshold_bw\" VARCHAR DEFAULT ('150')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q blank_page_detection_threshold_bw ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (blank_page_detection_threshold_bw)"
            error=1
        fi

        # blank page detection - threshold_black_pxl:
        # ---------------------------------------------------------------------
        sqlite3 "./etc/synOCR.sqlite" "ALTER TABLE config 
                                       ADD COLUMN \"blank_page_detection_threshold_black_pxl\" VARCHAR DEFAULT ('10')"
        # check:
        if ! $(sqlite3 "./etc/synOCR.sqlite" "PRAGMA table_info(config)" | awk -F'|' '{print $2}' | grep -q blank_page_detection_threshold_black_pxl ) ; then
            log="$log 
            ➜ ERROR: the DB column could not be created (blank_page_detection_threshold_black_pxl)"
            error=1
        fi

        if [[ "$error" == "0" ]]; then
            # lift DB version:
            lift_db 8 9
        fi
        error=0
    fi

# adjust permissions:
# ---------------------------------------------------------------------
    [ $(whoami) = root ] && chmod 766 ./etc/synOCR.sqlite

echo "$log"

exit 0

# ToDo-List bei DB-Upgrade:
# ➜ upgradeconfig.sh:   das initiales DB-Createstatement anpassen (inkl. DB-Version)
# ➜ edit.sh:            Parameter in 'Profil duplizieren' anpassen (bei Änderungen an Tabelle config)
# ➜ edit.sh:            Parameter in 'Datensatz in DB schreiben' anpassen
# ➜ edit.sh:            "$page" == "edit" Profil einlesen anpassen
# ➜ edit.sh:            GUI Element ggf. einfügen / anpassen
# ➜ synOCR.sh:          DB-Einlesen anpassen
