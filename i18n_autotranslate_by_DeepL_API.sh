#!/bin/bash
# shellcheck disable=SC2181,SC2317

    #######################################################################################################
    # automatic translation script with DeepL                                                             #
    #     v1.1.2 © 2026 by geimist                                                                        #
    #     /volume3/DEV/SPK_DEVELOPING/synOCR_BUILD/i18n_autotranslate_by_DeepL_API.sh                     #
    #######################################################################################################

DeepLapiKey=""
# Fallback key from external file:
[ -z "${DeepLapiKey}" ] && DeepLapiKey="${DeepLapiKey:-$(head -n1 "$(realpath "${0%/*}/../../DeepL_api-Key_synOCR.txt")")}"
# Leerzeichen / CR / LF aus der Key-Datei entfernen (sonst 403 trotz gültigem Key)
DeepLapiKey=$(printf '%s' "${DeepLapiKey}" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# DeepL-Übersetzungsaufrufe (curl): Verbindungs- und Gesamt-Timeout in Sekunden.
# Bei Exit 28 (Zeitüberschreitung) ggf. DeepL_curl_max_time erhöhen, z. B.:
#   DeepL_curl_max_time=180 bash i18n_autotranslate_by_DeepL_API.sh
: "${DeepL_curl_connect_timeout:=20}"
: "${DeepL_curl_max_time:=120}"

# DeepL API-Host: Free (api-free) vs. Pro (api). Falscher Host → oft HTTP 403.
# Free-Authentifizierungsschlüssel enden bei DeepL mit »:fx« (siehe Doku).
# Manuell setzen z. B.: DeepL_api_base_url="https://api.deepl.com" bash …
if [[ -z "${DeepL_api_base_url:-}" ]]; then
    if [[ "${DeepLapiKey}" == *:fx ]]; then
        DeepL_api_base_url="https://api-free.deepl.com"
    else
        DeepL_api_base_url="https://api.deepl.com"
    fi
fi
DeepL_api_base_url="${DeepL_api_base_url%/}"

# ToDo:
#   - SPK Versionen mit abbilden 
#   - machinetranslateID muss noch mal überprüft werden

# Mastersprache:
#---------------------------------------------------------------------------------------------------
    # diese Datei im ini-Format definiert die Variablen und dient als Sprachvorlage:
    # sollen nur einzelne Strings aktualisiert werden oder es wurden Variablen hinzugefügt, 
    # werden nur diese Werte im File benötigt. Bestehende gleiche Werte werden übersprungen.
    # Aufbau: variablename="value"
#   masterFile="/usr/syno/synoman/webman/3rdparty/synOCR/lang/lang_ger.txt"
    masterFile="/Users/stephangeisler/Documents/Computer/Code_Projekte/GitHub/synOCR/synOCR/APP/ui/lang/lang_ger.txt"
        
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
#   i18n_DB="/volume3/DEV/SPK_DEVELOPING/synOCR_BUILD/i18n.sqlite"
    i18n_DB="${0%/*}/i18n.sqlite"

# Export der übersetzten Sprachdateien
#---------------------------------------------------------------------------------------------------
    # sollen abschließend die Sprachdateien exportiert werden?:
    exportLangFiles=1
#   exportPath="/usr/syno/synoman/webman/3rdparty/synOCR/lang/"
    exportPath="${0%/*}/APP/ui/lang/"
    
    # sollen bereits vorhandene Sprachdateien überschrieben werden?:
    overwrite=1

# manueller Import bereits vorhandener Sprachdateien
#---------------------------------------------------------------------------------------------------
    # das Masterfile "masterFile" für die Variablendefinition sollte dennoch oben angegeben werden
    manualImport=0
    
    # Ordner mit den zu importierenden Sprachdateien - dieser Pfad ist anzupassen:
    manFilePath="/usr/syno/synoman/webman/3rdparty/synOCR/lang/imp/"

####################################################################################################

set -E -o functrace     # for function failure()

cCount=0
error=0
date_start=$(date +%s)
exportPath="${exportPath%/}/"
manFilePath="${manFilePath%/}/"

# DB speichert den logischen Wert (nach bash source). Dateien brauchen Maskierung für source.
# Import muss daher unescapen; Export escapen — sonst verdoppeln sich Backslashes bei jedem Lauf.

# Umkehrung von i18n_escape_for_double_quoted_assign: \" → " und \\ → \  (rein Bash)
i18n_unescape_from_double_quoted_assign() {
    local s="$1" out="" i=0 c n
    local len=${#s}
    while (( i < len )); do
        c="${s:i:1}"
        if [[ "${c}" == '\' ]] && (( i + 1 < len )); then
            n="${s:i+1:1}"
            if [[ "${n}" == '\' || "${n}" == '"' ]]; then
                out+="${n}"
                i=$((i + 2))
                continue
            fi
        fi
        out+="${c}"
        i=$((i + 1))
    done
    printf '%s' "${out}"
}

# Hilfe-Texte zeigen RegEx-Tokens (\K \R \N \s+ \b) — genau ein Backslash im logischen Wert.
# Verhindert/heilt Hochschaukeln durch wiederholte Import/Export-Zyklen. (rein Bash)
i18n_normalize_regex_escapes() {
    local s="$1" out="" i=0 c bs=0
    local len=${#s}
    while (( i < len )); do
        c="${s:i:1}"
        if [[ "${c}" == '\' ]]; then
            bs=$((bs + 1))
            i=$((i + 1))
            continue
        fi
        if (( bs > 0 )); then
            if [[ "${c}" == 'K' || "${c}" == 'R' || "${c}" == 'N' || "${c}" == 'b' ]]; then
                out+="\\${c}"
                i=$((i + 1))
                bs=0
                continue
            elif [[ "${s:i:2}" == 's+' ]]; then
                out+='\s+'
                i=$((i + 2))
                bs=0
                continue
            else
                while (( bs > 0 )); do
                    out+='\'
                    bs=$((bs - 1))
                done
            fi
        fi
        out+="${c}"
        i=$((i + 1))
    done
    while (( bs > 0 )); do
        out+='\'
        bs=$((bs - 1))
    done
    printf '%s' "${out}"
}

get_key_value() {
    # this function is a workaround replacement of synology DSM binary get_key_value
    # $1 = file
    # $2 = key
    # Liefert den logischen Wert (unescaped + RegEx-Backslash-Normalisierung).
    local raw
    raw=$(grep "^${2}=" "$1" | sed -e 's~^'"$2"'=~~;s~^"~~g;s~"$~~g')
    raw=$(i18n_unescape_from_double_quoted_assign "${raw}")
    raw=$(i18n_normalize_regex_escapes "${raw}")
    printf '%s' "${raw}"
}

# Wert für Ausgabezeilen varname="…" escapen (synOCR lädt Sprachdateien per source).
# Reihenfolge: RegEx-Normalisierung, dann Backslash, dann doppelte Anführungszeichen.
i18n_escape_for_double_quoted_assign() {
    local s
    s=$(i18n_normalize_regex_escapes "$1")
    printf '%s' "${s}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Ersetze ASCII-Anführungszeichen um ".." durch typografische Anführungszeichen (wie in lang_ger).
# Wichtig: nur das vollständige ".."-Token ersetzen — ein partielles Muster "\.\. würde die
# schließende " stehen lassen; i18n_escape_for_double_quoted_assign würde sie zu \"." machen.
i18n_normalize_display_quotes() {
    printf '%s' "$1" | sed -e 's/"\.\."/„..“/g'
}

# Schneller Batch-Pfad für export_langfiles: normalize quotes + regex escapes, dann escape.
i18n_format_langfile_body() {
    perl -F'\t' -ane '
        chomp(my $s = $F[1] // "");
        $s =~ s/"\.\."/„..“/g;
        $s =~ s/\\+(K|R|N|s\+|b)/\\$1/g;
        $s =~ s/\\/\\\\/g;
        $s =~ s/"/\\"/g;
        print "$F[0]=\"$s\"\n";
    '
}

sql_escape() {
    printf "%s" "$1" | sed "s/'/''/g"
}

# DeepL tag_handling=xml: bare & (z. B. Drag&Drop) ist kein gültiges XML → HTTP 400.
# Bestehende Entities (&quot; &amp; …) bleiben unverändert.
deepl_prepare_xml_text() {
    printf '%s' "$1" | perl -pe 's/&(?!amp;|lt;|gt;|quot;|apos;|#\d+;|#x[0-9a-fA-F]+;)/&amp;/g'
}

sec_to_time () {
# this function converts a second value to hh:mm:ss
# call: sec_to_time "string"
# https://blog.jkip.de/in-bash-sekunden-umrechnen-in-stunden-minuten-und-sekunden/
#-------------------------------------------------------------------------------
    local seconds="$1"
    local sign=""
    if [[ ${seconds:0:1} == "-" ]]; then
        seconds=${seconds:1}
        sign="-"
    fi
    local hours=$(( seconds / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    seconds=$(( seconds % 60 ))
    printf "%s%02d:%02d:%02d" "${sign}" "${hours}" "${minutes}" "${seconds}"
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
    _progress=$((($1 * 100) / $2))
    _done=$((_progress * 4 / 10))
    _left=$((40 - _done))

# Build progressbar string lengths
_fill=$(printf "%${_done}s")
_empty=$(printf "%${_left}s")

printf "\rProgress :    [${_fill// /#}${_empty// /-}] ${_progress}%% ($1/$2)"

}

create_db() {
# diese Funktion erstellt die Datenbank, sofern sie nicht vorhandne ist oder leer ist

if [ ! -s "${i18n_DB}" ]; then
    printf "\n\nEs wurde keine Datenbank gefunden - sie wird jetzt erstellt ...\n\n"

    sqlite3 "$i18n_DB" "BEGIN TRANSACTION;
                        DROP TABLE IF EXISTS \"strings\";
                        CREATE TABLE IF NOT EXISTS \"strings\" (
                            \"ID\" INTEGER,
                            \"varID\" INTEGER,
                            \"langID\" INTEGER,
                            \"version\" INTEGER,
                            \"langstring\" TEXT,
                            PRIMARY KEY(\"ID\" AUTOINCREMENT),
                            FOREIGN KEY(\"varID\") REFERENCES \"variables\"(\"varID\")
                        );
                        DROP TABLE IF EXISTS \"master_template\";
                        CREATE TABLE IF NOT EXISTS \"master_template\" (
                            \"ID\" INTEGER,
                            \"varID\" INTEGER,
                            \"langID\" INTEGER DEFAULT 1,
                            \"version\" INTEGER,
                            \"timestamp\" TEXT,
                            \"langstring\" TEXT,
                            PRIMARY KEY(\"ID\" AUTOINCREMENT)
                        );
                        DROP TABLE IF EXISTS \"languages\";
                        CREATE TABLE IF NOT EXISTS \"languages\" (
                            \"langID\" INTEGER,
                            \"longname\" TEXT UNIQUE,
                            \"synoshortname\" TEXT UNIQUE,
                            \"deeplshortname\" TEXT,
                            PRIMARY KEY(\"langID\" AUTOINCREMENT)
                        );
                        DROP TABLE IF EXISTS \"variables\";
                        CREATE TABLE IF NOT EXISTS \"variables\" (
                            \"varID\" INTEGER,
                            \"varname\" TEXT UNIQUE,
                            \"verified\" INTEGER DEFAULT 0, 
                            \"inuse\" VARCHAR DEFAULT ('true'),
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
    # sind Variablennamen bereits vorhanden und langstring geändert → Version +1; unveränderte Strings bleiben unberührt
    # Performance: Datei einmal parsen + ein SQLite-Batch (statt N× sqlite3 pro Key)

    printf "\n\n%s\n"  "Importiere / aktualisiere Mastertabelle ..."
    printf "%s\n\n" "[Masterfile: ${masterFile}]"

    progress_end=$(grep -v "^$" "${masterFile}" | grep -vc '^[[:space:]]*#')

    cCount=0
    # Synology-Sprachcode nur aus dem Dateinamen (lang_<code>.txt), nicht aus dem Pfad:
    # Enthält der Pfad Unterstriche (z. B. .../Code_Projekte/...), liefert
    # cut … am ganzen Pfad falsche Werte → leeres langID → master_template ohne langID → translate() überspringt.
    synoLangCode=$(basename "${masterFile}" .txt | sed -e 's/^lang_//')
    langID=$(sqlite3 "${i18n_DB}" "SELECT langID FROM languages WHERE synoshortname='${synoLangCode}'")

    if [ -z "${langID}" ]; then
        printf "%s\n" "! ! ! ERROR: langID für synoshortname '${synoLangCode}' nicht gefunden."
        return 1
    fi

    local sql_tmp key raw value key_sql value_sql
    sql_tmp=$(mktemp "${TMPDIR:-/tmp}/synocr_master_sql.XXXXXX") || return 1

    {
        echo "BEGIN IMMEDIATE;"
        echo "CREATE TEMP TABLE incoming (varname TEXT PRIMARY KEY, langstring TEXT NOT NULL);"
        # inuse als 0/1 — translate()/export filtern auf inuse='1'
        echo "UPDATE variables SET inuse = 0;"
    } > "${sql_tmp}"

    # Schleife: Progressbar live + Staging-INSERTs; DB-Schreiben erst danach in einem Rutsch
    # Wert direkt aus der Zeile (kein get_key_value / kein erneutes Datei-Grep)
    while read -r line; do
        key="${line%%=*}"
        raw="${line#*=}"
        if [[ "${raw}" == \"*\" ]]; then
            raw="${raw#\"}"
            raw="${raw%\"}"
        fi
        value=$(i18n_unescape_from_double_quoted_assign "${raw}")
        value=$(i18n_normalize_regex_escapes "${value}")

        cCount=$((cCount + 1))
        progressbar "${cCount}" "${progress_end}"

        # SQL-Escape ohne Fork. Nicht "${v//'/''}" — das zerbricht unter bash 3.2 (/bin/bash auf macOS).
        # Auch nicht //\'/\'\' — in "…" wird daraus literal \'\' (SQLite-Parse-Fehler).
        _i18n_sq="'"
        key_sql="${key//${_i18n_sq}/${_i18n_sq}${_i18n_sq}}"
        value_sql="${value//${_i18n_sq}/${_i18n_sq}${_i18n_sq}}"
        printf "INSERT OR REPLACE INTO incoming (varname, langstring) VALUES ('%s', '%s');\n" \
            "${key_sql}" "${value_sql}" >> "${sql_tmp}"
    done <<< "$(grep -v "^$" "${masterFile}" | grep -v '^[[:space:]]*#' )"

    cat >> "${sql_tmp}" <<EOF
INSERT OR IGNORE INTO variables (varname) SELECT varname FROM incoming;
UPDATE variables SET inuse = 1 WHERE varname IN (SELECT varname FROM incoming);

-- Anzahl neuer/geänderter Strings vor dem Schreiben (Version nur bei Diff)
CREATE TEMP TABLE _stats AS
SELECT COUNT(*) AS insert_count
FROM incoming AS i
JOIN variables AS v ON v.varname = i.varname
LEFT JOIN master_template AS m ON m.varID = v.varID AND m.langID = ${langID}
WHERE m.ID IS NULL OR m.langstring IS DISTINCT FROM i.langstring;

-- bestehend + geändert → Version +1, Timestamp/String aktualisieren
UPDATE master_template AS m
SET
    version = m.version + 1,
    timestamp = datetime('now', 'localtime'),
    langstring = i.langstring
FROM incoming AS i
JOIN variables AS v ON v.varname = i.varname
WHERE m.varID = v.varID
  AND m.langID = ${langID}
  AND m.langstring IS DISTINCT FROM i.langstring;

-- neu → Version 1
INSERT INTO master_template (varID, langID, version, timestamp, langstring)
SELECT v.varID, ${langID}, 1, datetime('now', 'localtime'), i.langstring
FROM incoming AS i
JOIN variables AS v ON v.varname = i.varname
WHERE NOT EXISTS (
    SELECT 1 FROM master_template AS m
    WHERE m.varID = v.varID AND m.langID = ${langID}
);

-- Legacy: Masterzeilen ohne langID der Mastersprache zuordnen
UPDATE master_template SET langID = ${langID} WHERE langID IS NULL OR langID = '';

SELECT insert_count FROM _stats;
COMMIT;
EOF

    insertCount=$(sqlite3 "${i18n_DB}" < "${sql_tmp}")
    sql_rc=$?
    rm -f "${sql_tmp}"
    # sql_rc bewusst ohne »local …=$?« — sonst überschreibt local den Exitcode

    if [ "${sql_rc}" -ne 0 ]; then
        printf "\n%s\n" "! ! ! ERROR: SQLite-Batch für Mastertabelle fehlgeschlagen (Exit ${sql_rc})."
        return 1
    fi

    printf "\n\n%s\n" "Es wurden ${insertCount:-0} Datensätze in die Mastertabelle eingefügt, bzw. aktualisiert."

}

manual_import() {

    # Diese Funktion ist nicht Teil des regulären Workflows, sondern dient dem erstmaligen Befüllen der DB, 
    # sofern bereits übersetzte Sprachdateien vorhanden sind. 
    # Desweiteren dient es dem Import von verifizierten Sprachdateien.
    # Liest alle Dateien im angegebenen Ordner ($manFilePath) ein und speichert deren Werte in der DB.
    # Die Sprachdateien müssen ini-Files mit folgendem Namensschema sein: lang_<synoLangCode>.txt
    
    
    # ToDo:
    # sollten manuell importierte Werte den Status 'verified' erhalten?
    
    printf "\n\n%s\n\n" "manueller Import - importiere / aktualisiere bestehende Sprachdateien ... "
    
    while read -r file; do
        unset skipped
        masterFile="${manFilePath}${file}"
        progress_end=$(grep -v "^$" "${masterFile}" | grep -vc '^[[:space:]]*#')
        cCount=0
        insertCount=0
        synoLangCode=$(basename "${masterFile}" .txt | sed -e 's/^lang_//')
        printf "%s\n" "language: ${synoLangCode}"
        langID=$(sqlite3 "${i18n_DB}" "SELECT langID FROM languages WHERE synoshortname='${synoLangCode}'")
        
        
        # Schleife über jede Zeile im ini-File, welche nicht auskommentiert oder leer ist:
        while read -r line; do
            key=$(echo "${line}" | awk -F= '{print $1}')
            value=$(get_key_value "${masterFile}" "${key}")

            # Progressbar:
            cCount=$((cCount+1))
            progressbar "${cCount}" "${progress_end}"

            # identifiziere die ID des aktuellen Variable um sie mit der anderen Tabelle zu verknüpfen:
            varID=$(sqlite3 "${i18n_DB}" "SELECT varID FROM variables WHERE varname='${key}'")
            if [ -z "${varID}" ]; then
#               printf "\nDie Variable $key konnte nicht in der DB gefunden werden.\nüberspringen ...\n"
                skipped="$( [ -n "${skipped}" ] && printf "%s\n" "${skipped}")\n    ➜ Die Variable ${key} konnte nicht in der DB gefunden werden ➜ überspringen ...\n"
                continue
            fi
    
            # lese Info eines ggf. vorhandenen Datensatzes:
            checkValue=$(sqlite3 -separator $'\t' "$i18n_DB" "SELECT ID, version, langstring FROM strings WHERE varID='$varID' AND langID='$langID'" | head -n1) # head sollte eigentlich nicht nötig sein
    
            # ist die Zeile vorhanden, dann wird sie aktualisiert, sonst eine neue erstellt ("INSERT OR REPLACE …"):
            rowID=$(echo "${checkValue}" | awk -F'\t' '{print $1}')
            if [ -n "${rowID}" ]; then
                IDname="ID, "
                rowID="'${rowID}',"
            else
                IDname=""
                rowID=""
            fi
    
            # wird der Datensatz lediglich aktualisiert, dann erhöht sich dessen Version um 1 / ist er neu, wird die Version 1 definiert:
            checkVersion=$(echo "${checkValue}" | awk -F'\t' '{print $2}')
            if [ -z "${checkVersion}" ]; then
                langVersion=1
            else
                langVersion=$((checkVersion+1))
            fi
    
            # nächster Datensatz wenn keine Änderung:
            checkLangstring=$(echo "${checkValue}" | awk -F'\t' '{print $3}')
            if [ "${checkLangstring}" == "${value}" ]; then
                continue
            fi

            # maskiere single quotes:
            value=$(sql_escape "${value}")

            # speichere die Werte in der strings-Tabelle:
            if ! sqlite3 "${i18n_DB}" "INSERT OR REPLACE INTO strings ( $IDname varID, langID, version, verified, langstring  ) VALUES (  $rowID '$varID','$langID','$langVersion','1','$value' ) "; then
                printf "\n%s\n" "! ! ! ERROR @ LINE: INSERT OR REPLACE INTO strings ( $IDname varID, langID, version, verified, langstring  ) VALUES (  $rowID '$varID','$langID','$langVersion','1','$value' )"
            else
                insertCount=$((insertCount+1))
            fi
        done <<< "$(grep -v "^$" "${masterFile}" | grep -v '^[[:space:]]*#' )"
        
        if [ -n "${skipped}" ]; then
            printf "\n%s\n" "! ! ! F E H L E R ! ! !"
            printf "%s\n" "${skipped}"
        fi

        printf "\n\n%s\n\n" "Es wurden ${insertCount} Datensätze eingefügt, bzw. aktualisiert."
        
    done <<< "$(ls -tp "${manFilePath}" | grep -vE '/$' )"

}

translate() {
    # diese Funktion list die Tabelle mit der Musterübersetzung und übersetzt sie, sofern sie in der 
    # Zielsprache fehlt oder deren Version nicht mit der Version in der Mastertabelle übereinstimmt

    printf "\n\n%s\n" "Prüfe auf fehlende oder veraltete Übersetzungen und aktualisiere sie ggf. ... "
    printf "%s\n\n" "    Master Sprach-ID:     ${masterLangID} [${masterLongName}]"

    while read -r langID; do
        unset skipped  # verifizierte Einträge werde nicht automatisch übersetzt aber abschließend ausgegeben
        languages=$(sqlite3 -separator $'\t' "${i18n_DB}" "SELECT deeplshortname, longname FROM languages WHERE langID='${langID}'")
        targetDeeplShortName="$(echo "${languages}" | awk -F'\t' '{print $1}')"
        targetLongName="$(echo "${languages}" | awk -F'\t' '{print $2}')"
        printf "\n\n%s\n" "verarbeite Sprach-ID: ${langID} [${targetLongName}]"

        # lese aktuelle Version der Mastertabelle und der Übersetzungstabelle
        masterList=$(sqlite3 -separator $'\t' "${i18n_DB}" "SELECT t1.varID, t1.version FROM (master_template t1, variables t2) WHERE t1.varID = t2.varID AND inuse='1' AND t1.langID='${masterLangID}';" | sort -g)
        langList=$(sqlite3 -separator $'\t' "${i18n_DB}" "SELECT varID, version FROM strings WHERE langID='${langID}'" | sort -g)

        # gibt es eine Variable mit Namen >machinetranslate<? Welche ID hat sie? 
        # Sie wird bei einer automatischen Übersetzung auf 1 gesetzt / bei einer Kopie aus der Mastertabelle auf 0
        machinetranslateID=$(sqlite3 "${i18n_DB}" "SELECT varID FROM variables WHERE varname='machinetranslate'")
        
        # suche Unterschiede:
        diffVar=$(diff -d <(echo "${langList}") <(echo "${masterList}"))
        diffNew=$(echo "${diffVar}" | grep ">" | sed -e 's/^> //g')

        # set progressbar:
        # shellcheck disable=SC2126
        progress_end="$(printf "%s" "${diffNew}" | grep -v "^$" | wc -l | sed -e 's/ //g')"

        cCount=0
        [ "${progress_end}" -eq 0 ] && continue

        if [ "${masterLangID}" = "${langID}" ]; then
            # keine Übersetzung nötig - kopiere die Sprache aus der Mastertabelle in die Übersetzungstabelle:
            
            while read -r varID; do

                # Progressbar:
                cCount=$((cCount+1))
                progressbar "${cCount}" "${progress_end}"

                # lese die Quelldaten:
                sourceRow=$(sqlite3 -separator $'\t' "${i18n_DB}" "SELECT version, langstring FROM master_template WHERE langID='${masterLangID}' AND varID='${varID}'" )
                # separiere die Sprachversion:
                langVersion="$(echo "${sourceRow}" | awk -F'\t' '{print $1}')"
                # separiere den Sprachstring und maskierte single quotes:
                value="$(echo "${sourceRow}" | awk -F'\t' '{print $2}' | sed -e "s/'/''/g")" 

                # setzte Kennzeichnung auf NICHT automatisch übersetzt:
                if [ "${machinetranslateID}" -eq "${varID}" ]; then
                    value="0"
                fi

                # ToDo: $langList & $masterList mit ID auslesen und für den diff-Vergleich die Spalte ID abschneiden - so erspart man sich die erneute Abfrage
                # ist die Zeile vorhanden (rowID = Zahl), dann wird sie aktualisiert, sonst wird ein neuer Datensatz erstellt ("INSERT OR REPLACE …"):
                rowID=$(sqlite3 "${i18n_DB}" "SELECT ID FROM strings WHERE varID='${varID}' AND langID='${langID}'" | head -n1)

                if [ -n "${rowID}" ]; then
                    IDname="ID, "
                    rowID="'${rowID}',"
                else
                    IDname=""
                    rowID=""
                fi
                sqlite3 "${i18n_DB}" "INSERT OR REPLACE INTO strings ( $IDname varID, langID, version, langstring  ) VALUES (  $rowID '$varID','$langID','$langVersion', '$value' ) "

            done <<< "$(echo "${diffNew}" | awk -F'\t' '{print $1}')"
        else
            # Übersetzung nötig - Zielsprache weicht von Quellsprache ab - es wird übersetzt und in die Übersetzungstabelle geschrieben:
            while read -r varID; do

                # Progressbar:
                progressbar "${cCount}" "${progress_end}"

                # lese Quelldatensatz:
                sourceRow=$(sqlite3 -separator $'\t' "${i18n_DB}" "SELECT version, langstring FROM master_template WHERE langID='${masterLangID}' AND varID='${varID}'" )
                # separiere die Sprachversion:
                langVersion="$(echo "${sourceRow}" | awk -F'\t' '{print $1}')"
                # separiere den Sprachstring:
                value="$(echo "${sourceRow}" | awk -F'\t' '{print $2}')" 
                
                # lese Zieldatensatz:
                targetRow=$(sqlite3 -separator $'\t' "${i18n_DB}" "SELECT ID, version, verified, langstring FROM strings WHERE varID='${varID}' AND langID='${langID}'")
                rowID="$(echo "${targetRow}" | awk -F'\t' '{print $1}')"
                # separiere die Sprachversion:
                # separiere den verified-Flag:
                verified="$(echo "${targetRow}" | awk -F'\t' '{print $3}')"
                # separiere den verifizierten Sprachstring:
                verifiedValue="$(echo "${targetRow}" | awk -F'\t' '{print $4}')"

                # gesperrte (verifizierte) Strings überspringen:
                if [ "${verified}" = 1 ]; then
                    varName="$(sqlite3 "${i18n_DB}" "SELECT varname FROM variables WHERE varID='${varID}'" )"
                    skipped="$( [ -n "${skipped}" ] && printf "%s\n" "${skipped}")\n    ➜ Name:     ${varName}\n      master:   \"${value}\"\n      verified: \"${verifiedValue}\""
                    continue
                fi

                # call API / translate
                # https://www.deepl.com/de/docs-api/translating-text/
                request_start=$(date +%s)

                max_retries=3
                backoff=1  # Starte mit 1 Sekunde
                transValue=""
                last_curl_rc=-1
                last_curl_msg=""
                last_api_hint=""

                deepl_text=$(deepl_prepare_xml_text "${value}")

                for ((i=0; i<=max_retries; i++)); do
                    _sdeepl_err=$(
                        mktemp "${TMPDIR:-/tmp}/synocr_deepl_err.XXXXXX" 2>/dev/null ||
                            echo "${TMPDIR:-/tmp}/synocr_deepl_err.$$.$i.log"
                    )
                    _sdeepl_body=$(
                        mktemp "${TMPDIR:-/tmp}/synocr_deepl_body.XXXXXX" 2>/dev/null ||
                            echo "${TMPDIR:-/tmp}/synocr_deepl_body.$$.$i.log"
                    )
                    : >"${_sdeepl_err}"
                    http_code=$(
                        curl -sS \
                            --connect-timeout "${DeepL_curl_connect_timeout}" \
                            --max-time "${DeepL_curl_max_time}" \
                            -o "${_sdeepl_body}" \
                            -w "%{http_code}" \
                            -H "Authorization: DeepL-Auth-Key ${DeepLapiKey}" \
                            -H "Content-Type: application/x-www-form-urlencoded" \
                            --data-urlencode "text=${deepl_text}" \
                            --data-urlencode "source_lang=${masterDeeplShortName}" \
                            --data-urlencode "tag_handling=xml" \
                            --data-urlencode "ignore_tags=x" \
                            --data-urlencode "target_lang=${targetDeeplShortName}" \
                            "${DeepL_api_base_url}/v2/translate" 2>"${_sdeepl_err}"
                    )
                    response=$(cat "${_sdeepl_body}" 2>/dev/null)
                    if [[ "${http_code}" =~ ^2 ]]; then
                        curl_rc=0
                    else
                        curl_rc=56
                        printf "curl: (%s) The requested URL returned error: %s \n" "${curl_rc}" "${http_code}" >>"${_sdeepl_err}"
                    fi
                    last_curl_rc=${curl_rc}
                    last_curl_msg=$(tr '\n' ' ' <"${_sdeepl_err}" | head -c 500)
                    rm -f "${_sdeepl_err}" "${_sdeepl_body}"

                    if [[ ${curl_rc} -eq 0 && -n "${response}" ]]; then
                        transValue=$(jq -r '(.translations // []) | .[].text // empty' <<<"${response}")
                        if [[ -n "${transValue}" ]]; then
                            last_api_hint=""
                            break
                        fi
                        last_api_hint=$(
                            jq -r '(.message // .error_message // .error // .) | tostring' <<<"${response}" 2>/dev/null |
                                head -c 400
                        )
                        printf "\n    [DeepL] JSON ohne translations[] (varID=%s, Versuch %d/%d): %s\n" \
                            "${varID}" "$((i + 1))" "$((max_retries + 1))" "${last_api_hint:-${response:0:300}}"
                    else
                        printf "\n    [DeepL] Anfrage fehlgeschlagen (varID=%s, Versuch %d/%d, connect=%ss max=%ss, curl-Exit=%d)\n        %s\n" \
                            "${varID}" "$((i + 1))" "$((max_retries + 1))" \
                            "${DeepL_curl_connect_timeout}" "${DeepL_curl_max_time}" "${curl_rc}" "${last_curl_msg:-unbekannt}"
                        if [[ ${curl_rc} -eq 28 ]]; then
                            printf "        (Exit 28 = Zeitüberschreitung — ggf. DeepL_curl_max_time vergrößern oder später erneut versuchen.)\n"
                        elif [[ "${last_curl_msg}" == *403* ]]; then
                            printf "        (HTTP 403 laut DeepL: oft ungültiger/leerer Key, oder falscher Host. Host: %s; /v2/usage nutzt den Header — translate ebenfalls.)\n" "${DeepL_api_base_url}"
                        fi
                    fi

                    if [[ ${i} -lt ${max_retries} ]]; then
                        printf "        → Warte %ss (Backoff), erneuter Versuch …\n" "${backoff}"
                        sleep "${backoff}"
                        backoff=$((backoff * 2))
                    fi
                done

                if [[ -z "$transValue" ]]; then
                    varNameFail=$(sqlite3 "${i18n_DB}" "SELECT varname FROM variables WHERE varID='${varID}'" 2>/dev/null)
                    printf "\n    ÜBERSETZUNGSFEHLER — überspringe (varID=%s, varname=%s, Ziel=%s / %s, Quelltext ca. %d Zeichen)\n" \
                        "${varID}" "${varNameFail:-?}" "${targetLongName}" "${targetDeeplShortName}" "${#value}"
                    printf "        letzter curl-Exit: %s | curl: %s\n" "${last_curl_rc}" "${last_curl_msg:-—}"
                    if [[ -n "${last_api_hint}" ]]; then
                        printf "        API-Hinweis: %s\n" "${last_api_hint}"
                    elif [[ -n "${response}" ]]; then
                        printf "        Antwort (gekürzt): %s\n" "${response:0:400}"
                    fi
                    error=1
                    continue
                fi

                # Hinweis bei langsamen DeepL:
                requestTime=$(($(date +%s)-request_start))
                [ "${requestTime}" -gt 10 ] && printf "%s" "  lange DeepL Antwortzeit [${requestTime} Sekunden] | Ergebnis: ${transValue}"

                # separiere den Sprachstring und maskierte single quotes:
                transValue="${transValue//\'/''}"

                # setzte Kennzeichnung auf automatisch übersetzt:
                if [ "${machinetranslateID}" -eq "${varID}" ]; then
                    transValue="1"
                fi

                # ToDo: $langList & $masterList mit ID auslesen und für den diff-Vergleich die Spalte ID abschneiden - so erspart man sich die erneute Abfrage
                # ist die Zeile vorhanden (rowID = Zahl), dann wird sie aktualisiert, sonst wird ein neuer Datensatz erstellt ("INSERT OR REPLACE …"):

                if [ -n "${rowID}" ]; then
                    IDname="ID, "
                    rowID="'${rowID}',"
                else
                    IDname=""
                    rowID=""
                fi
                sqlite3 "${i18n_DB}" "INSERT OR REPLACE INTO strings ( ${IDname} varID, langID, version, langstring  ) VALUES (  $rowID '$varID','$langID','$langVersion', '$transValue' ) "

                # Progressbar:
                cCount=$((cCount+1))
                progressbar "${cCount}" "${progress_end}"

            done <<< "$(echo "$diffNew" | awk -F'\t' '{print $1}')"

            if [ -n "${skipped}" ]; then
                printf "\n\n%s" "Folgende Übersetzungen wurden geändert, haben jedoch in der bestehenden Version den Status 'verifiziert' und wurden daher nicht automatisch übersetzt / aktualisiert:"
                printf "\n%s\n" "${skipped}"
            fi
        fi
    done <<< "$(sqlite3 "${i18n_DB}" "SELECT langID FROM languages WHERE deeplshortname IS NOT ''")"

}

export_langfiles() {
    # Diese Funktion exportiert alle Werte aus der Übersetzungstabelle der DB in die entsprechenden Sprachdateien im Format: lang_<synoLangCode>.txt
    printf "\n\n%s\n" "Exportiere die Sprachdateien ... "

    while read -r langID; do
        languages=$(sqlite3 -separator $'\t' "${i18n_DB}" "SELECT synoshortname, longname FROM languages WHERE langID='${langID}'")
        synoShortName="$(echo "${languages}" | awk -F'\t' '{print $1}')"
        targetLongName="$(echo "${languages}" | awk -F'\t' '{print $2}')"
        langFile="${exportPath}lang_${synoShortName}.txt"
        printf "\n%s\n" "verarbeite Sprach-ID: ${langID} [${targetLongName}]"

        if [ "${overwrite}" = 0 ] && [ -f "${langFile}" ]; then
            echo "    ➜ Sprachdatei ist bereits vorhanden und das Überschreiben ist deaktiviert ..."
            continue
        fi

        {
            echo "    #######################################################################################################"
            printf "    # %-100s#\n"  "${targetLongName} language file for synOCR-GUI"
            printf "    # %-100s#\n"  ""
            printf "    # %-100s#\n"  "Path:"
            printf "    # %-100s#\n"  "    /usr/syno/synoman/webman/3rdparty/synOCR/lang/lang_${synoShortName}.txt"
            printf "    # %-100s#\n"  ""
            printf "    # %-100s#\n"  "translation instructions can you found here: "
            printf "    # %-100s#\n"  "    https://github.com/geimist/synOCR/blob/master/translation_instruction.md"
            printf "    # %-100s#\n"  ""
            printf "    # %-101s#\n"  "    © $(date +%Y) by geimist"
            echo "    #######################################################################################################"
            echo -e
            sqlite3 -separator $'\t' "${i18n_DB}" \
                "SELECT varname, langstring FROM strings INNER JOIN variables ON variables.varID = strings.varID WHERE strings.langID='${langID}' AND variables.inuse='1' ORDER BY varname ASC" \
                | i18n_format_langfile_body
        } > "${langFile}"

        chmod 755 "${langFile}"
    done <<<"$(sqlite3 "${i18n_DB}" "SELECT DISTINCT langID FROM strings ORDER by langID ASC")"
}

# lese den aktuellen Status des Übersetzungskontigents von DeepL (verbrauchte Zeichen im aktuellen Zeitraum):
printf "\n%s\n" "DeepL-Endpunkt: ${DeepL_api_base_url}  (Override: DeepL_api_base_url=…)"
limitStateStart=$(curl -sH "Authorization: DeepL-Auth-Key ${DeepLapiKey}" "${DeepL_api_base_url}/v2/usage")

# Informationen der definierten Mastersprache zusammentragen:
languages=$(sqlite3 -separator $'\t' "${i18n_DB}" "SELECT langID, deeplshortname, longname FROM languages WHERE SynoShortName='${masterSynoShortName}'")
masterLangID="$(echo "${languages}" | awk -F'\t' '{print $1}')"
masterDeeplShortName="$(echo "${languages}" | awk -F'\t' '{print $2}')"
masterLongName="$(echo "${languages}" | awk -F'\t' '{print $3}')"


#######################
# Funktionsaufrufe:
    create_db
    create_master
    [ "${manualImport}" = 1 ] && manual_import
    translate
    [ "${exportLangFiles}" = 1 ] && export_langfiles
#######################

printf "\n\n%s\n" "Statistik:"
[ "${error}" -ne 0 ] && echo "    Es gab bei der Ausführung Fehler - bitte erneut aufrufen."
limitState=$(curl -sH "Authorization: DeepL-Auth-Key ${DeepLapiKey}" "${DeepL_api_base_url}/v2/usage")
printf "%s\n" "    Für die Übersetzung wurden $(( $(jq -r .character_count <<< "${limitState}" )-$(jq -r .character_count <<< "${limitStateStart}" ))) Zeichen berechnet."
printf "%s\n" "    Im aktuellen Zeitraum wurden $(jq -r .character_count <<< "${limitState}" ) Zeichen von $(jq -r .character_limit <<< "${limitState}" ) verbraucht.    "
