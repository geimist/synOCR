#!/bin/bash

    #######################################################################################################
    # automatic translation script with DeepL                                                             #
    #     v1.0.6 © 2023 by geimist                                                                        #
    #                                                                                                     #
    #######################################################################################################

DeepLapiKey="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx:xx"


# Mastersprache:
#---------------------------------------------------------------------------------------------------
    # diese Datei im ini-Format definiert die Variablen und dient als Sprachvorlage:
    # sollen nur einzelne Strings aktualisiert werden oder es wurden Variablen hinzugefügt, 
    # werden nur diese Werte im File benötigt. Bestehende gleiche Werte werden übersprungen.
    # Aufbau: variablename="value"
    masterFile="/usr/syno/synoman/webman/3rdparty/synOCR/lang/lang_ger.txt"
        
    # die Version wird für die Mastertabelle gesetzt und zeigt, ob einzelne Übersetzungs-Strings aktuell oder veraltet sind
    langVersion=1
    
    # Sprachcode der Mustersprache (Sprache der Mastertabelle) / verwende den Synology Sprachcode:
    # diese Sprache dient als Ausgangsübersetzung für DeepL.
    masterSynoShortName="ger"

# Datenbank:
#---------------------------------------------------------------------------------------------------
    # Pfad für die Sprach-DB
    # - in dieser DB werden alle Strings aufbewahrt.
    # - die benötigten Sprachdateien für das SPK werden daraus generiert (Funktion: export_langfiles)
    # - ist die DB nicht vorhanden, so wird sie neu erstellt
    i18n_DB="/volume3/DEV/SPK_DEVELOPING/synOCR_BUILD/i18n.sqlite"

# Export der übersetzten Sprachdateien
#---------------------------------------------------------------------------------------------------
    # sollen abschließend die Sprachdateien exportiert werden?:
    exportLangFiles=1
    exportPath="/usr/syno/synoman/webman/3rdparty/synOCR/lang/"
    
    # sollen bereits vorhandene Sprachdateien überschrieben werden?:
    overwrite=0

# manueller Import bereits vorhandener Sprachdateien
#---------------------------------------------------------------------------------------------------
    # das Masterfile "masterFile" für die Variablendefinition sollte dennoch oben angegeben werden
    manualImport=0
    
    # Ordner mit den zu importierenden Sprachdateien - dieser Pfad ist anzupassen:
    manFilePath="/usr/syno/synoman/webman/3rdparty/synOCR/lang/imp/"

####################################################################################################

cCount=0
error=0
date_start=$(date +%s)
exportPath="${exportPath%/}/"
manFilePath="${manFilePath%/}/"

if ! uname -a | grep -q synology ; then
    echo "! ! ! F E H L E R ! ! !"
    echo "Dieses Skript greift auf Programme zurück, welche nur im Synology DSM vorhanden sind."
    echo "(synosetkeyvalue und get_key_value)"
    echo "Ersetze ggf. diese Programme durch sed, awk und grep und deaktiviere diese Prüfung."

    exit 1
fi

sec_to_time () {
# this function converts a second value to hh:mm:ss
# call: sec_to_time "string"
# https://blog.jkip.de/in-bash-sekunden-umrechnen-in-stunden-minuten-und-sekunden/
#-------------------------------------------------------------------------------
    local seconds=$1
    local sign=""
    if [[ ${seconds:0:1} == "-" ]]; then
        seconds=${seconds:1}
        sign="-"
    fi
    local hours=$(( seconds / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    seconds=$(( seconds % 60 ))
    printf "%s%02d:%02d:%02d" "$sign" $hours $minutes $seconds
}
trap 'echo "Laufzeit: $(sec_to_time $(expr $(date +%s)-${date_start}) )" ; exit' EXIT

progressbar() {
# https://blog.cscholz.io/bash-progress-or-spinner/
# Um die Progressbar darzustellen, muss ein Zähler (_start) und der Maximalwert (_end) definiert werden.
#   _start=0
#   _end=$(wc -l $1)
#######################################
# Display a progress bar
# Arguments:
#   $1 Current loop number
#   $2 max. no of loops (1005)
# Returns:
#   None
#######################################

# Process data
let _progress=(${1}*100/${2}*100)/100
let _done=(${_progress}*4)/10
let _left=40-$_done

# Build progressbar string lengths
_fill=$(printf "%${_done}s")
_empty=$(printf "%${_left}s")

printf "\rProgress :    [${_fill// /#}${_empty// /-}] ${_progress}%% ($1/$2)"

}

create_db() {
# diese Funktion erstellt die Datenbank, sofern sie nicht vorhandne ist oder leer ist

if [ $(stat -c %s "$i18n_DB") -eq 0 ] || [ ! -f "$i18n_DB" ]; then
    printf "\n\nEs wurde keine Datenbank gefunden - sie wird jetzt erstellt ...\n\n"

    sqlite3 "$i18n_DB" "BEGIN TRANSACTION;
                        DROP TABLE IF EXISTS \"strings\";
                        CREATE TABLE IF NOT EXISTS \"strings\" (
                        	\"ID\"	INTEGER,
                        	\"varID\"	INTEGER,
                        	\"langID\"	INTEGER,
                        	\"version\"	INTEGER,
                        	\"langstring\"	TEXT,
                        	PRIMARY KEY(\"ID\" AUTOINCREMENT),
                        	FOREIGN KEY(\"varID\") REFERENCES \"variables\"(\"varID\")
                        );
                        DROP TABLE IF EXISTS \"master_template\";
                        CREATE TABLE IF NOT EXISTS \"master_template\" (
                        	\"ID\"	INTEGER,
                        	\"varID\"	INTEGER,
                        	\"langID\"	INTEGER DEFAULT 1,
                        	\"version\"	INTEGER,
                        	\"timestamp\"	TEXT,
                        	\"langstring\"	TEXT,
                        	PRIMARY KEY(\"ID\" AUTOINCREMENT)
                        );
                        DROP TABLE IF EXISTS \"languages\";
                        CREATE TABLE IF NOT EXISTS \"languages\" (
                        	\"langID\"	INTEGER,
                        	\"longname\"	TEXT UNIQUE,
                        	\"synoshortname\"	TEXT UNIQUE,
                        	\"deeplshortname\"	TEXT,
                        	PRIMARY KEY(\"langID\" AUTOINCREMENT)
                        );
                        DROP TABLE IF EXISTS \"variables\";
                        CREATE TABLE IF NOT EXISTS \"variables\" (
                        	\"varID\"	INTEGER,
                        	\"varname\"	TEXT UNIQUE,
                        	\"verified\"	INTEGER DEFAULT 0,
                        	PRIMARY KEY(\"varID\" AUTOINCREMENT)
                        );
                        INSERT INTO \"languages\" VALUES (1,'German','ger','DE'),
                         (2,'English US','enu','EN-US'),
                         (3,'Chinese simplified','chs','ZH'),
                         (4,'Chinese traditional','cht',''),
                         (5,'Czech','csy','CS'),
                         (6,'Japanese','jpn','JA'),
                         (7,'Korean','krn','KO'),
                         (8,'Danish','dan','DA'),
                         (9,'French','fre','FR'),
                         (10,'Italian','ita','IT'),
                         (11,'Dutch','nld','NL'),
                         (12,'Norwegian','nor','NB'),
                         (13,'Polish','plk','PL'),
                         (14,'Russian','rus','RU'),
                         (15,'Spanish','spn','ES'),
                         (16,'Swedish','sve','SV'),
                         (17,'Hungarian','hun','HU'),
                         (18,'Tai','tha',''),
                         (19,'Turkish','trk','TR'),
                         (20,'Portuguese European','ptg','PT-PT'),
                         (21,'Portuguese Brazilian','ptb','PT-BR');
                        COMMIT;"
fi

}

create_master() {
    # diese Funktion liest die Musterdatei, definiert daraus die benötigten Variablennamen und deren Werte und schreibt sie in die DB
    # sind Variablennamen bereits vorhanden, werden die Werte aktualisiert und der Versionszähler der Variable um 1 erhöht

    # set progressbar:
    printf "\n\nImportiere / aktualisiere Mastertabelle ...\n"
    printf "[Masterfile: $masterFile]\n\n"

    progress_start=0
#   progress_end=$(cat "$masterFile" | grep -v "^$" | grep -v "^#" | wc -l)
    progress_end=$(cat "$masterFile" | grep -v "^$" | grep -v ^[[:space:]]*# | wc -l)
    
    cCount=0
    insertCount=0
    synoLangCode=$( echo "$masterFile" | cut -f 1 -d '.' | cut -f 2 -d '_')
    langID=$(sqlite3 "$i18n_DB" "SELECT langID FROM languages WHERE synoshortname='$synoLangCode'")

    # Schleife über jede Zeile im ini-File, welche nicht auskommentiert oder leer ist:
    while read line; do
        key=$(echo "$line" | awk -F= '{print $1}')
        value=$(get_key_value "$masterFile" "$key")

        # Progressbar:
        let cCount=$cCount+1
        progressbar ${cCount} ${progress_end}

        # schreibe den Variablennamen der Zeile in die DB / überspringe vorhandenen:
        sqlite3 "$i18n_DB" "INSERT OR IGNORE INTO variables ( varname ) VALUES ( '$key' )"
        if [ $? -ne 0 ]; then
            echo "! ! ! ERROR @ LINE: INSERT OR IGNORE INTO variables ( varname ) VALUES ( '$key' )"
        fi

        # identifiziere die ID des aktuellen Variable um sie mit der anderen Tabelle zu verknüpfen:
        varID=$(sqlite3 "$i18n_DB" "SELECT varID FROM variables WHERE varname='$key'")

        # lese Info einer ggf. vorhandenen Version - prüfen, ob eine Aktualisierung nötig ist und erhöhe ggf. die Version:
        checkValue=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT ID, version, langstring FROM master_template WHERE varID='$varID' AND langID='$langID'" | head -n1)

        # ist die Zeile vorhanden, dann wird sie aktualisiert, sonst eine neue erstellt ("INSERT OR REPLACE …"):
        rowID=$(echo "$checkValue" | awk -F'\t' '{print $1}')
        if [ -n "$rowID" ]; then
            IDname="ID, "
            rowID="'$rowID',"
        else
            IDname=""
            rowID=""
        fi

        # wird der Datensatz lediglich aktualisiert, dann erhöht sich dessen Version um 1 / ist er neu, wird die Version 1 definiert:
        checkVersion=$(echo "$checkValue" | awk -F'\t' '{print $2}')
        if [ -z "$checkVersion" ]; then
            langVersion=1
        else
            let langVersion=$checkVersion+1
        fi

        # vergleiche neuen mit vorhandenem Datensatz - weiter wenn keine Änderung:
        checkLangstring=$(echo "$checkValue" | awk -F'\t' '{print $3}')
        if [ "$checkLangstring" == "$value" ]; then
            continue
        fi

        # speichere die Werte in der Mastertabelle:
        sqlite3 "$i18n_DB" "INSERT OR REPLACE INTO master_template ( $IDname varID, langID, version, timestamp, langstring  ) VALUES (  $rowID '$varID','$langID','$langVersion',(datetime('now','localtime')),'$value' ) "
        if [ $? -ne 0 ]; then
            echo "! ! ! ERROR @ LINE: INSERT OR REPLACE INTO master_template ( $IDname varID, langID, version, timestamp, langstring  ) VALUES (  $rowID '$varID','$langID','$langVersion',(datetime('now','localtime')),'$value' )"
        else
            let insertCount=$insertCount+1
        fi
    done <<<"$(cat "$masterFile" | grep -v "^$" | grep -v ^[[:space:]]*# )" #| grep lang_PKG_NOINSTALL_MISSING_DOCKER_ERROR )"
    
    printf "\n\nEs wurden $insertCount Datensätze in die Mastertabelle eingefügt, bzw. aktualisiert.\n"
}

manual_import() {

    # Diese Funktion ist nicht Teil des regulären Workflows, sondern dient dem erstmaligen Befüllen der DB, 
    # sofern bereits übersetzte Sprachdateien vorhanden sind. 
    # Desweiteren dient es dem Import von verifizierten Sprachdateien.
    # Liest alle Dateien im angegebenen Ordner ($manFilePath) ein und speichert deren Werte in der DB.
    # Die Sprachdateien müssen ini-Files mit folgendem Namensschema sein: lang_<synoLangCode>.txt
    
    
    # ToDo:
    # sollten manuell importierte Werte den Status 'verified' erhalten?
    
    printf "\n\nmanueller Import - importiere / aktualisiere bestehende Sprachdateien ... \n\n"
    
    while read file; do
        unset skipped
        masterFile="${manFilePath}${file}"
        progress_start=0
        progress_end=$(cat "$masterFile" | grep -v "^$" | grep -v ^[[:space:]]*# | wc -l)
        cCount=0
        insertCount=0
        synoLangCode=$( echo "$masterFile" | cut -f 1 -d '.' | cut -f 2 -d '_')
        printf "language: $synoLangCode\n"
        langID=$(sqlite3 "$i18n_DB" "SELECT langID FROM languages WHERE synoshortname='$synoLangCode'")
        
        
        # Schleife über jede Zeile im ini-File, welche nicht auskommentiert oder leer ist:
        while read line; do
            key=$(echo "$line" | awk -F= '{print $1}')
            value=$(get_key_value "$masterFile" "$key")
    
            # Progressbar:
            let cCount=$cCount+1
            progressbar ${cCount} ${progress_end}
    
            # identifiziere die ID des aktuellen Variable um sie mit der anderen Tabelle zu verknüpfen:
            varID=$(sqlite3 "$i18n_DB" "SELECT varID FROM variables WHERE varname='$key'")
            if [ -z "$varID" ]; then
#                printf "\nDie Variable $key konnte nicht in der DB gefunden werden.\nüberspringen ...\n"
                skipped="$( [ -n "$skipped" ] && printf "${skipped}\n")\n    ➜ Die Variable $key konnte nicht in der DB gefunden werden ➜ überspringen ...\n"
                continue
            fi
    
            # lese Info eines ggf. vorhandenen Datensatzes:
            checkValue=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT ID, version, langstring FROM strings WHERE varID='$varID' AND langID='$langID'" | head -n1) # head sollte eigentlich nicht nötig sein
    
            # ist die Zeile vorhanden, dann wird sie aktualisiert, sonst eine neue erstellt ("INSERT OR REPLACE …"):
            rowID=$(echo "$checkValue" | awk -F'\t' '{print $1}')
            if [ -n "$rowID" ]; then
                IDname="ID, "
                rowID="'$rowID',"
            else
                IDname=""
                rowID=""
            fi
    
            # wird der Datensatz lediglich aktualisiert, dann erhöht sich dessen Version um 1 / ist er neu, wird die Version 1 definiert:
            checkVersion=$(echo "$checkValue" | awk -F'\t' '{print $2}')
            if [ -z "$checkVersion" ]; then
                langVersion=1
            else
                let langVersion=$checkVersion+1
            fi
    
            # nächster Datensatz wenn keine Änderung:
            checkLangstring=$(echo "$checkValue" | awk -F'\t' '{print $3}')
            if [ "$checkLangstring" == "$value" ]; then
                continue
            fi

            # maskiere single quotes:
            value=$(echo "$value" | sed -e "s/'/''/g")

            # speichere die Werte in der strings-Tabelle:
            sqlite3 "$i18n_DB" "INSERT OR REPLACE INTO strings ( $IDname varID, langID, version, verified, langstring  ) VALUES (  $rowID '$varID','$langID','$langVersion','1','$value' ) "
            if [ $? -ne 0 ]; then
                printf "\n! ! ! ERROR @ LINE: INSERT OR REPLACE INTO strings ( $IDname varID, langID, version, verified, langstring  ) VALUES (  $rowID '$varID','$langID','$langVersion','1','$value' )\n"
            else
                let insertCount=$insertCount+1
            fi
        done <<<"$(cat "$masterFile" | grep -v "^$" | grep -v ^[[:space:]]*# )"
        
        if [ -n "$skipped" ]; then
            printf "\n! ! ! F E H L E R ! ! !\n"
            printf "${skipped}\n"
        fi

        printf "\n\nEs wurden $insertCount Datensätze eingefügt, bzw. aktualisiert.\n\n"
        
    done <<<"$(ls -tp "$manFilePath" | egrep -v '/$' )"

}

translate() {
    # diese Funktion list die Musterübersetzung und übersetzt sie, sofern sie in der Zielsprache fehlt 
    # oder deren Version nicht mit der Version in der Mastertabelle übereinstimmt

    printf "\n\nPrüfe auf fehlende oder veraltete Übersetzungen und aktualisiere sie ggf. ... \n"
    printf "    Master Sprach-ID:     $masterLangID [$masterLongName]\n\n"

    while read langID; do
        unset skipped  # verifizierte Einträge werde nicht automatisch übersetzt aber abschließend ausgegeben
        languages=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT deeplshortname, longname FROM languages WHERE langID='$langID'")
        targetDeeplShortName="$(echo "$languages" | awk -F'\t' '{print $1}')"
        targetLongName="$(echo "$languages" | awk -F'\t' '{print $2}')"
        printf "\n\nverarbeite Sprach-ID: $langID [$targetLongName]\n"

        # lese aktuelle Version der Mastertabelle und der Übersetzungstabelle
        masterList=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT varID, version FROM master_template WHERE langID='$masterLangID'" | sort -g)
        langList=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT varID, version FROM strings WHERE langID='$langID'" | sort -g)
        
        # gibt es eine Variable mit Namen >machinetranslate<? Welche ID hat sie? 
        # Sie wird bei einer automatischen Übersetzung auf 1 gesetzt / bei einer Kopie aus der Mastertabelle auf 0
        machinetranslateID=$(sqlite3 "$i18n_DB" "SELECT varID FROM variables WHERE varname='machinetranslate'")
        
        # suche Unterschiede:
        diff=$(diff -d <(echo "$langList") <(echo "$masterList"))
        diffNew=$(echo "$diff" | grep ">" | sed -e 's/^> //g')
#       diffDel=$(echo "$diff" | grep "<" | sed -e 's/^< //g')

        # set progressbar:
        progress_start=0
        progress_end="$(printf %s "$diffNew" | grep -v "^$" | wc -l)"
        cCount=0
        [ "$progress_end" -eq 0 ] && continue

        if [ "$masterLangID" = "$langID" ]; then
            # keine Übersetzung nötig - kopiere die Sprache aus der Mastertabelle in die Übersetzungstabelle:
            
            while read varID; do

                # Progressbar:
                let cCount=$cCount+1
                progressbar ${cCount} ${progress_end}

                # lese die Quelldaten:
                sourceRow=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT version, langstring FROM master_template WHERE langID='$masterLangID' AND varID='$varID'" )
                # separiere die Sprachversion:
                langVersion="$(echo "$sourceRow" | awk -F'\t' '{print $1}')"
                # separiere den Sprachstring und maskierte single quotes:
                value="$(echo "$sourceRow" | awk -F'\t' '{print $2}' | sed -e "s/'/''/g")" 

                # setzte Kennzeichnung auf NICHT automatisch übersetzt:
                if [ "$machinetranslateID" -eq "$varID" ]; then
                    value="0"
                fi

                # ToDo: $langList & $masterList mit ID auslesen und für den diff-Vergleich die Spalte ID abschneiden - so erspart man sich die erneute Abfrage
                # ist die Zeile vorhanden (rowID = Zahl), dann wird sie aktualisiert, sonst wird ein neuer Datensatz erstellt ("INSERT OR REPLACE …"):
                rowID=$(sqlite3 "$i18n_DB" "SELECT ID FROM strings WHERE varID='$varID' AND langID='$langID'" | head -n1)
                if [ -n "$rowID" ]; then
                    IDname="ID, "
                    rowID="'$rowID',"
                else
                    IDname=""
                    rowID=""
                fi
                sqlite3 "$i18n_DB" "INSERT OR REPLACE INTO strings ( $IDname varID, langID, version, langstring  ) VALUES (  $rowID '$varID','$langID','$langVersion', '$value' ) "

            done <<<"$(echo "$diffNew" | awk -F'\t' '{print $1}')"
        else
            # Übersetzung nötig - Zielsprache weicht von Quellsprache ab - es wird übersetzt und in die Übersetzungstabelle geschrieben:

            while read varID; do

                # Progressbar:
                progressbar ${cCount} ${progress_end}

                # lese Quelldatensatz:
                sourceRow=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT version, langstring FROM master_template WHERE langID='$masterLangID' AND varID='$varID'" )
                # separiere die Sprachversion:
                langVersion="$(echo "$sourceRow" | awk -F'\t' '{print $1}')"
                # separiere den Sprachstring:
                value="$(echo "$sourceRow" | awk -F'\t' '{print $2}')" 
                
                # lese Zieldatensatz:
                targetRow=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT ID, version, verified, langstring FROM strings WHERE varID='$varID' AND langID='$langID'")
                rowID="$(echo "$targetRow" | awk -F'\t' '{print $1}')"
                # separiere die Sprachversion:
                targetVersion="$(echo "$targetRow" | awk -F'\t' '{print $2}')"
                # separiere den verified-Flag:
                verified="$(echo "$targetRow" | awk -F'\t' '{print $3}')"
                # separiere den verifizierten Sprachstring:
                verifiedValue="$(echo "$targetRow" | awk -F'\t' '{print $4}')"

                # gesperrte (verifizierte) Strings überspringen:
                if [ "$verified" = 1 ]; then
                    varName="$(sqlite3 "$i18n_DB" "SELECT varname FROM variables WHERE varID='$varID'" )"
                    skipped="$( [ -n "$skipped" ] && printf "${skipped}\n")\n    ➜ Name:     ${varName}\n      master:   \"$value\"\n      verified: \"$verifiedValue\""
                    continue
                fi

                # call API / translate
                # https://www.deepl.com/de/docs-api/translating-text/
                request_start=$(date +%s)
                transValue=$(curl -s  --connect-timeout 5 \
                    --max-time 5 \
                    --retry 5 \
                    --retry-delay 0 \
                    --retry-max-time 30 \
                    https://api-free.deepl.com/v2/translate \
                	-d auth_key="$DeepLapiKey" \
                	-d "text=$value"  \
                	-d "source_lang=$masterDeeplShortName" \
                	-d "tag_handling=xml" \
                	-d "target_lang=$targetDeeplShortName" | jq -r .translations[].text)

                if [ "$?" -ne 0 ]; then
                    printf "    ÜBERSETZUNGSFEHLER - überspringen ..."
                    error=1
                    continue
                elif [ -z "$transValue" ] && [ -n "$value" ]; then
                    printf "    ÜBERSETZUNGSFEHLER (leere Rückgabe | varID: $varID ) - überspringen ..."
                    error=1
                    continue
                fi

                # Hinweis bei langsamen DeepL:
                requestTime=$(($(date +%s)-$request_start))
                [ "$requestTime" -gt 10 ] && printf "  lange DeepL Antwortzeit [$requestTime Sekunden] | Ergebnis: $transValue"

                # separiere den Sprachstring und maskierte single quotes:
                transValue="$(echo "$transValue" | sed -e "s/'/''/g")" 

                # setzte Kennzeichnung auf automatisch übersetzt:
                if [ "$machinetranslateID" -eq "$varID" ]; then
                    transValue="1"
                fi

                # ToDo: $langList & $masterList mit ID auslesen und für den diff-Vergleich die Spalte ID abschneiden - so erspart man sich die erneute Abfrage
                # ist die Zeile vorhanden (rowID = Zahl), dann wird sie aktualisiert, sonst wird ein neuer Datensatz erstellt ("INSERT OR REPLACE …"):

#               if echo "$rowID" | grep -q ^[[:digit:]]$; then # funktioniert nicht zuverlässig
                if [ -n "$rowID" ]; then
                    IDname="ID, "
                    rowID="'$rowID',"
                else
                    IDname=""
                    rowID=""
                fi
                sqlite3 "$i18n_DB" "INSERT OR REPLACE INTO strings ( $IDname varID, langID, version, langstring  ) VALUES (  $rowID '$varID','$langID','$langVersion', '$transValue' ) "

                # Progressbar:
                let cCount=$cCount+1
                progressbar ${cCount} ${progress_end}

            done <<<"$(echo "$diffNew" | awk -F'\t' '{print $1}')"

            if [ -n "$skipped" ]; then
                printf "\n\nFolgende Übersetzungen wurden geändert, haben jedoch in der bestehenden Version den Status 'verifiziert' und wurden daher nicht automatisch übersetzt / aktualisiert:"
                printf "\n${skipped}\n"
            fi
        fi
    done <<<"$(sqlite3 "$i18n_DB" "SELECT langID FROM languages WHERE deeplshortname IS NOT ''")"

}

export_langfiles() {
    # Diese Funktion exportiert alle Werte aus der Übersetzungstabelle der DB in die entsprechenden Sprachdateien im Format: lang_<synoLangCode>.txt
    printf "\n\nExportiere die Sprachdateien ... \n"

    while read langID; do
        languages=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT synoshortname, longname FROM languages WHERE langID='$langID'")
        synoShortName="$(echo "$languages" | awk -F'\t' '{print $1}')"
        targetLongName="$(echo "$languages" | awk -F'\t' '{print $2}')"
        langFile="${exportPath}lang_${synoShortName}.txt"
        printf "\nverarbeite Sprach-ID: $langID [$targetLongName]\n"

        if [ "$overwrite" = 0 ] && [ -f "$langFile" ]; then
            echo "    ➜ Sprachdatei ist bereits vorhanden und das Überschreiben ist deaktiviert ..."
            continue
        fi

        {   echo "    #######################################################################################################"
            printf "    # %-100s#\n"  "$targetLongName language file for synOCR-GUI"
            printf "    # %-100s#\n"  ""
            printf "    # %-100s#\n"  "Path:"
            printf "    # %-100s#\n"  "    /usr/syno/synoman/webman/3rdparty/synOCR/lang/lang_${synoShortName}.txt"
            printf "    # %-100s#\n"  ""
            printf "    # %-100s#\n"  "translation instructions can you found here: "
            printf "    # %-100s#\n"  "    https://git.geimist.eu/geimist/synOCR/src/branch/master/translation_instruction.md"
            printf "    # %-100s#\n"  ""
            printf "    # %-101s#\n"  "    © $(date +%Y) by geimist"
            echo "    #######################################################################################################"
            echo -e
        } > "${langFile}"
        
        chmod 755 "${langFile}"
        
        content=$(sqlite3 -separator $'="' "$i18n_DB" "SELECT varname, langstring FROM strings INNER JOIN variables ON variables.varID = strings.varID WHERE strings.langID='$langID'" )
        
        while read line; do
            echo "$line\"" >> "${langFile}"
        done <<<"$content"
    done <<<"$(sqlite3 "$i18n_DB" "SELECT DISTINCT langID FROM strings ORDER by langID ASC")"
}

# lese den aktuellen Status des Übersetzungskontigents von DeepL (verbrauchte Zeichen im aktuellen Zeitraum):
limitStateStart=$(curl -sH "Authorization: DeepL-Auth-Key $DeepLapiKey" https://api-free.deepl.com/v2/usage)

# Informationen der definierten Mastersprache zusammentragen:
languages=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT langID, deeplshortname, longname FROM languages WHERE SynoShortName='$masterSynoShortName'")
masterLangID="$(echo "$languages" | awk -F'\t' '{print $1}')"
masterDeeplShortName="$(echo "$languages" | awk -F'\t' '{print $2}')"
masterLongName="$(echo "$languages" | awk -F'\t' '{print $3}')"


#######################
# Funktionsaufrufe:
    create_db
    create_master
    [ "$manualImport" = 1 ] && manual_import
    translate
    [ "$exportLangFiles" = 1 ] && export_langfiles
#######################

printf "\n\nStatistik:\n"
[ "$error" -ne 0 ] && echo "    Es gab bei der Ausführung Fehler - bitte erneut aufrufen."
limitState=$(curl -sH "Authorization: DeepL-Auth-Key $DeepLapiKey" https://api-free.deepl.com/v2/usage)
printf "    Für die Übersetzung wurden $(( $(jq -r .character_count <<<"$limitState" )-$(jq -r .character_count <<<"$limitStateStart" ))) Zeichen berechnet.\n"
printf "    Im aktuellen Zeitraum wurden $(jq -r .character_count <<<"$limitState" ) Zeichen von $(jq -r .character_limit <<<"$limitState" ) verbraucht.\n    "
