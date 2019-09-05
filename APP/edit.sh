#!/bin/bash
# edit.sh
# OLDIFS=$IFS

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
    sqlinst="CREATE TABLE \"config\" (\"profile_ID\" INTEGER PRIMARY KEY ,\"timestamp\" timestamp NOT NULL DEFAULT (CURRENT_TIMESTAMP) ,\"profile\" varchar ,\"active\" varchar DEFAULT ('1') ,\"INPUTDIR\" varchar DEFAULT ('/volume1/<PATH>/_INPUT') ,\"OUTPUTDIR\" varchar DEFAULT ('/volume1/<PATH>/_OUTPUT') ,\"BACKUPDIR\" varchar DEFAULT ('/volume1/<PATH>/_BACKUP') ,\"LOGDIR\" varchar DEFAULT ('/volume1/<PATH>/_LOG') ,\"LOGmax\" varchar DEFAULT ('10') ,\"SearchPraefix\" varchar ,\"delSearchPraefix\" varchar(5) DEFAULT ('yes') ,\"taglist\" varchar ,\"searchAll\" varchar DEFAULT ('no') ,\"moveTaggedFiles\" varchar DEFAULT ('useCatDir') ,\"NameSyntax\" varchar DEFAULT ('§y-§m-§d_§tag_§tit') , \"ocropt\" varchar DEFAULT ('-srd -l deu') ,\"dockercontainer\" varchar DEFAULT ('jbarlow83/ocrmypdf') ,\"PBTOKEN\" varchar ,\"dsmtextnotify\" varchar DEFAULT ('on') ,\"MessageTo\" varchar DEFAULT ('admin') ,\"dsmbeepnotify\" varchar DEFAULT ('on') ,\"loglevel\" varchar DEFAULT ('1') );"
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


# aktuelles Profil löschen: 
if [[ "$page" == "edit-del_profile-query" ]] || [[ "$page" == "edit-del_profile" ]]; then
    if [[ "$page" == "edit-del_profile-query" ]]; then
        echo '<p class="center" style="'$synotrred';">
            Soll das aktuelle Profil (<b>'$profile'</b>) gelöscht werden?<br /><br /><br />
            <a href="index.cgi?page=edit-del_profile" class="red_button">Ja</a>&nbsp;&nbsp;&nbsp;<a href="index.cgi?page=edit" class="button">Nein</a></p>'  >> "$stop"
    elif [[ "$page" == "edit-del_profile" ]]; then
        sqlite3 ./etc/synOCR.sqlite "DELETE FROM config WHERE profile_ID='$profile_ID';"
        
    # das erste Profil der DB als nächstes aktiv schalten (sonst würde ein Profilname mit leeren Daten angezeigt)
        getprofile=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT profile_ID FROM config ORDER BY profile_ID ASC LIMIT 1" | awk -F'\t' '{print $1}')
        # getprofile (ohne GUI nach $var schreiben):
    	encode_value=$getprofile
    	decode_value=$(echo "$encode_value" | sed -f ./includes/decode.sed)
    	"$set_var" "./usersettings/var.txt" "getprofile" "$decode_value"
    	"$set_var" "./usersettings/var.txt" "encode_getprofile" "$encode_value"
    
        sleep 1
        if [ $(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT count(profile_ID) FROM config WHERE profile_ID='$profile_ID' ") = "0" ] ; then
            echo '<p class="center" style="'$green';"><b>Das Profil <b>'$profile'</b> wurde gelöscht.</b></p>
                <br /><p class="center"><button name="page" value="edit" class="blue_button">Weiter...</button></p><br />' >> "$stop"
        else
            echo '<p class="center" style="'$green';">Fehler beim Löschen des Profils (<b>'$profile'</b>)!</p>
                <br /><p class="center"><button name="page" value="edit" class="blue_button">Weiter...</button></p><br />' >> "$stop"
        fi
    fi
fi


# Profil duplizieren:
if [[ "$page" == "edit-dup-profile-query" ]] || [[ "$page" == "edit-dup-profile" ]]; then
    if [[ "$page" == "edit-dup-profile-query" ]]; then
        echo '<div class="Content_1Col_full">'
        echo '<p><br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">Gib bitte einen Namen für das duplizierte Profil ein:</p><br />
        <label style="width: auto;padding: 0.5em 0.5em 0.25em 0.25em;"><b>Profilname: </b></label>' #style="vertical-align: bottom;" style="width: 200px;"
        if [ -n "$new_profile_value" ]; then
            echo '<input type="text" style="width: 200px;" name="new_profile_value" value="'$new_profile_value'" />'
        else
            echo '<input type="text" style="width: 200px;" name="new_profile_value" value="" />'
        fi
        echo '</p></div><br /><p class="center"><button name="page" value="edit-dup-profile" class="blue_button">erstellen...</button></p><br />
            </div><div class="clear"></div>'
    elif [[ "$page" == "edit-dup-profile" ]]; then
        echo '<div class="Content_1Col_full">'
        if [ ! -z "$new_profile_value" ] ; then
            sSQL="SELECT count(profile_ID) FROM config WHERE profile='$new_profile_value' "
            if [ $(sqlite3 ./etc/synOCR.sqlite "$sSQL") = "0" ] ; then
                sSQL="INSERT INTO config ( profile, active, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix, taglist, searchAll, 
                                    moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN, dsmtextnotify, MessageTo, dsmbeepnotify, loglevel 
                                    ) VALUES ( 
                                    '$new_profile_value', '$active', '$INPUTDIR', '$OUTPUTDIR', '$BACKUPDIR', '$LOGDIR', '$LOGmax', '$SearchPraefix', '$delSearchPraefix', 
                                    '$taglist', '$searchAll', '$moveTaggedFiles', '$NameSyntax', '$ocropt', '$dockercontainer', '$PBTOKEN', '$dsmtextnotify', 
                                    '$MessageTo', '$dsmbeepnotify', '$loglevel' )" #)
                sqlite3 ./etc/synOCR.sqlite "$sSQL"

                sSQL2="SELECT count(profile_ID) FROM config WHERE profile='$new_profile_value' "
                if [ $(sqlite3 ./etc/synOCR.sqlite "$sSQL2") = "1" ] ; then
                    echo '<br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">Das Profil <b>'$profile'</b> wurde zum Profil <b>'$new_profile_value'</b> geclont.</p><br /></div>'
                else
                    echo '<br /><div class="warning"><br /><p class="center">Fehler beim Duplizieren des Profils!</p><br /></div>'
                fi
            else
                echo '<br /><div class="warning"><br /><p class="center">Das Profil konnte nicht geclont werden,
                <br>da der Profilname <b>'$new_profile_value'</b> bereits vorhanden ist!</p><br /></div>'
            fi
        else
            echo '<br /><div class="warning"><br /><p class="center">Das Profil konnte nicht geclont werden,
            <br>da kein Profilname definiert wurde!</p><br /></div>'
        fi
        echo '<br /><p class="center"><button name="page" value="edit" class="blue_button">Weiter...</button></p><br />'
        echo '</div><div class="clear"></div>'
    fi
fi


# neues Profil erstellen: 
if [[ "$page" == "edit-new_profile-query" ]] || [[ "$page" == "edit-new_profile" ]]; then
    if [[ "$page" == "edit-new_profile-query" ]]; then
        echo '<div class="Content_1Col_full">'
        echo '<p><br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">Gib bitte einen Namen für das neue Profil ein:</p><br />
        <label style="width: auto;padding: 0.5em 0.5em 0.25em 0.25em;"><b>Profilname: </b></label>' #style="vertical-align: bottom;" style="width: 200px;"
        if [ -n "$new_profile_value" ]; then
            echo '<input type="text" style="width: 200px;" name="new_profile_value" value="'$new_profile_value'" />'
        else
            echo '<input type="text" style="width: 200px;" name="new_profile_value" value="" />'
        fi
        echo '</p></div><br /><p class="center"><button name="page" value="edit-new_profile" class="blue_button">erstellen...</button></p><br />
            </div><div class="clear"></div>'
    elif [[ "$page" == "edit-new_profile" ]]; then
        echo '<div class="Content_1Col_full">'
        if [ ! -z "$new_profile_value" ] ; then
            sSQL="SELECT count(profile_ID) FROM config WHERE profile='$new_profile_value' "
            if [ $(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL") = "0" ] ; then
                new_profile "$new_profile_value"
                if [ $(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL") = "1" ] ; then
                    echo '<br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">Ein neues Profil mit dem Namen <b>'$new_profile_value'</b> wurde erstellt.</p><br /></div>'
                else
                    echo '<br /><div class="warning"><br /><p class="center">Fehler beim Erstellen des Profils!</p><br /></div>'
                fi
            else
                echo '<br /><div class="warning"><br /><p class="center">Das neue Profil konnte nicht erstellt werden,
                <br>da der Profilname <b>'$new_profile_value'</b> bereits vorhanden ist!</p><br /></div>'
            fi
        else
            echo '<br /><div class="warning"><br /><p class="center">Das neue Profil konnte nicht erstellt werden,
            <br>da kein Profilname definiert wurde!</p><br /></div>'
        fi
        echo '<br /><p class="center"><button name="page" value="edit" class="blue_button">Weiter...</button></p><br />'
        echo '</div><div class="clear"></div>'
    fi
fi


# Datensatz in DB schreiben:
if [[ "$page" == "edit-save" ]]; then
    sSQLupdate="UPDATE config SET profile='$profile', active='$active', INPUTDIR='$INPUTDIR', OUTPUTDIR='$OUTPUTDIR', BACKUPDIR='$BACKUPDIR', 
        LOGDIR='$LOGDIR', LOGmax='$LOGmax', SearchPraefix='$SearchPraefix', delSearchPraefix='$delSearchPraefix', taglist='$taglist', searchAll='$searchAll', 
        moveTaggedFiles='$moveTaggedFiles', NameSyntax='$NameSyntax', ocropt='$ocropt', dockercontainer='$dockercontainer', PBTOKEN='$PBTOKEN', 
        dsmtextnotify='$dsmtextnotify', MessageTo='$MessageTo', dsmbeepnotify='$dsmbeepnotify', loglevel='$loglevel' WHERE profile_ID='$profile_ID' "
    sqlite3 ./etc/synOCR.sqlite "$sSQLupdate"
    
    echo '<div class="Content_1Col_full">'
    echo '<br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">Änderungen wurden gespeichert</p><br /></div>'
    echo '<br /><p class="center"><button name="page" value="edit" class="blue_button">Weiter...</button></p><br />'
    echo '</div><div class="clear"></div>'
fi


if [[ "$page" == "edit" ]]; then
    # Dateiinhalt einlesen für Variablenverwertung
    if [ -z "$getprofile" ] ; then
        sSQL="SELECT profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, 
            delSearchPraefix, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN, 
            dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, active FROM config WHERE profile_ID='1' "
    else
        sSQL="SELECT profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, 
            delSearchPraefix, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN, 
            dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, active FROM config WHERE profile_ID='$getprofile' "
    fi
    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL")

    # Datensatzfelder separieren:
        profile_ID=$(echo "$sqlerg" | awk -F'\t' '{print $1}')
        timestamp=$(echo "$sqlerg" | awk -F'\t' '{print $2}')
        profile=$(echo "$sqlerg" | awk -F'\t' '{print $3}')
        INPUTDIR=$(echo "$sqlerg" | awk -F'\t' '{print $4}')
        OUTPUTDIR=$(echo "$sqlerg" | awk -F'\t' '{print $5}')
        BACKUPDIR=$(echo "$sqlerg" | awk -F'\t' '{print $6}')
        LOGDIR=$(echo "$sqlerg" | awk -F'\t' '{print $7}')
        LOGmax=$(echo "$sqlerg" | awk -F'\t' '{print $8}')
        SearchPraefix=$(echo "$sqlerg" | awk -F'\t' '{print $9}')
        delSearchPraefix=$(echo "$sqlerg" | awk -F'\t' '{print $10}')
        taglist=$(echo "$sqlerg" | awk -F'\t' '{print $11}')
        searchAll=$(echo "$sqlerg" | awk -F'\t' '{print $12}')
        moveTaggedFiles=$(echo "$sqlerg" | awk -F'\t' '{print $13}')
        NameSyntax=$(echo "$sqlerg" | awk -F'\t' '{print $14}')
        ocropt=$(echo "$sqlerg" | awk -F'\t' '{print $15}')
        dockercontainer=$(echo "$sqlerg" | awk -F'\t' '{print $16}')
        PBTOKEN=$(echo "$sqlerg" | awk -F'\t' '{print $17}')
        dsmtextnotify=$(echo "$sqlerg" | awk -F'\t' '{print $18}')
        MessageTo=$(echo "$sqlerg" | awk -F'\t' '{print $19}')
        dsmbeepnotify=$(echo "$sqlerg" | awk -F'\t' '{print $20}')
        loglevel=$(echo "$sqlerg" | awk -F'\t' '{print $21}')
        active=$(echo "$sqlerg" | awk -F'\t' '{print $22}')

    echo '
    <div id="Content_1Col">
    <div class="Content_1Col_full">
        <div class="title">
            synOCR Einstellungen
        </div>Trage hier deine Einstellungen ein und passe die Pfade an.
        <br>Hilfe für die einzelnen Felder erhältst du über das blaue Info-Symbol am rechten Rand.
        <br>
        <br>Über die Profile kannst du beliebig viele Konfigurationen anlegen, welche bei alle jedem 
        Programmlauf abgearbeitet werden. Man kann jedes Profil über das entsprechende Feld auch deaktivieren.
        <br>
        <br>Achte unbedingt darauf, die kompletten Pfade inkl. Volume (z.B. <code>/volume1/…</code>) einzutragen und achte auf korrekte Groß- und Kleinschreibung. 
        Das sicherste ist, wenn du in der Filestation den gewünschten Ordner suchst und du dir über Rechtsklick die Eigenschaften anzeigen lässt. 
        In diesem Dialog kannst du dir den korrekten Pfad kopieren.
        <br><br>'

# Profilauswahl:
    sSQL="SELECT profile_ID, profile FROM config "
    sqlerg=`sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL"`
    echo '<p>
        <label style="width: 200px;padding: 0.5em 0.5em 0.25em 0.25em;"><b>wechsle zu Profil</b></label>
        <select name="getprofile" style="width: 200px;">'

        IFS=$'\012'
        for entry in $sqlerg; do
            IFS=$OLDIFS

            profile_ID_DB=$(echo "$entry" | awk -F'\t' '{print $1}')
            profile_DB=$(echo "$entry" | awk -F'\t' '{print $2}')
            
            if [[ "$profile_ID" == $profile_ID_DB ]]; then
                echo '<option value='$profile_ID_DB' selected>'$profile_DB'</option>'
            else
                echo '<option value='$profile_ID_DB'>'$profile_DB'</option>'
            fi
        done

    echo '</select><button name="page" value="edit" class="blue_button" style="float:right;">wechseln</button>&nbsp;'

    # -> Abschnitt Allgemein

# Aufklappbar:
    echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;">
    <br />
    <details><p>
    <summary>
        <span class="detailsitem">Allgemein</span>
    </summary></p>
    <p>' #ab hier steht der Text, der auf- und zugeklappt werden soll.
    # <span style="color:#FFFFFF;">_</span>
    # <div id="ExpFieldset">    </div>
    
    # Profilname
    echo '
        <p>
        <label>Profilname</label>'
        if [ -n "$profile" ]; then
            echo '<input type="text" name="profile" value="'$profile'" />'
        else
            echo '<input type="text" name="profile" value="" />'
        fi
        echo '<a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Profile können individuell benannt werden (z.B. Geschäft, Max)</span></a></p>'

    # Profil aktiviert?
    echo '
        <p>
        <label>Profil aktivieren / deaktivieren</label>
        <select name="active">'
        if [[ "$active" == "1" ]]; then
            echo '<option value="1" selected>Profil aktiviert</option>'
        else
            echo '<option value="1">Profil aktiviert</option>'
        fi
        if [[ "$active" == "0" ]]; then
            echo '<option value="0" selected>Profil deaktiviert</option>'
        else
            echo '<option value="0">Profil deaktiviert</option>'
        fi

    echo '
        </select>
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Profile können aktiviert, oder deaktiviert werden.<br>
            Deaktivierte Profile können zwar modifiziert werden, werden aber von synOCR nicht ausgeführt.</span></a>
        </p>'
    
    # Profile-ID (ohne GUI nach $var schreiben)
    	encode_value=$profile_ID
    	decode_value=$(echo "$encode_value" | sed -f ./includes/decode.sed)
    	"$set_var" "./usersettings/var.txt" "profile_ID" "$decode_value"
    	"$set_var" "./usersettings/var.txt" "encode_profile_ID" "$encode_value"
	
    # SOURCEDIR
    echo '
        <p>
        <label>Quellverzeichnis</label>'
        if [ -n "$INPUTDIR" ]; then
            echo '<input type="text" name="INPUTDIR" value="'$INPUTDIR'" />'
        else
            echo '<input type="text" name="INPUTDIR" value="" />'
        fi
        echo '
            <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>In diesem Verzeichnis wird nach PDF-Dateien gesucht (nicht rekursiv).</span></a>
            </p>'

    # OUTPUTDIR
    echo '
        <p>
        <label>Zielverzeichnis</label>'
        if [ -n "$OUTPUTDIR" ]; then
            echo '<input type="text" name="OUTPUTDIR" value="'$OUTPUTDIR'" />'
        else
            echo '<input type="text" name="OUTPUTDIR" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Ausgabeverzeichnis der fertigen PDF-Dateien (wird ggf. erstellt)</span></a>
        </p>'

    # BACKUPDIR
    echo '
        <p>
        <label>Backup-Verzeichnis</label>'
        if [ -n "$BACKUPDIR" ]; then
            echo '<input type="text" name="BACKUPDIR" value="'$BACKUPDIR'" />'
        else
            echo '<input type="text" name="BACKUPDIR" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Sofern hier ein gültiger Pfad eingetragen wird, werden die Originaldateien hier gesichert (wird ggf. erstellt).<br>
            Ist kein gültiges Verzeichnis hinterlegt, werden die Originaldateien endgültig gelöscht.</span></a>
        </p>'

    # LOGDIR 
    echo '
        <p>
        <label>Verzeichnis für LOG-Dateien</label>'
        if [ -n "$LOGDIR" ]; then
            echo '<input type="text" name="LOGDIR" value="'$LOGDIR'" />'
        else
            echo '<input type="text" name="LOGDIR" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Verzeichnis der LOG-Dateien (wird ggf. erstellt)</span></a>
        </p>'


    echo '
    </details>
        </fieldset>
    </p>'


    # -> Abschnitt OCR:
    echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;">
    <br />
    <details><p>
    <summary>
        <span class="detailsitem">OCR Optionen und Umbenennung</span>
    </summary></p>
    <p>'

    # ocropt
    echo '
        <p>
        <label>OCR Optionen</label>'
        if [ -n "$ocropt" ]; then
            echo '<input type="text" name="ocropt" value="'$ocropt'" />'
        else
            echo '<input type="text" name="ocropt" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Hier können individuelle Parameter für OCRmyPDF angegeben werden<br><br>
            -s            PDF-Dateien mit vorhandenem Textlayer nicht erneut OCRen<br>
            --force-ocr   erneutes OCRen erzwingen<br>
            -r            automatisches drehen von Seiten<br>
            -l            Sprache (deu,enu,...)<br>
            -d            schiefe Scans entzerren<br></span></a>
        </p>'

    # dockercontainer
    echo '
        <p>
        <label>zuverwendendes Dockerimage</label>
        <select name="dockercontainer">'
        
        imagelist=("jbarlow83/ocrmypdf:latest" "jbarlow83/ocrmypdf:v9.0.2" "jbarlow83/ocrmypdf-alpine:latest" "jbarlow83/ocrmypdf-alpine:v8.2.3" "jbarlow83/ocrmypdf-alpine:v9.0.2" "jbarlow83/ocrmypdf-polyglot:latest")
        
        for entry in ${imagelist[@]}; do
            if [[ "$dockercontainer" == "${entry}" ]]; then
                echo "<option value=${entry} selected>${entry}</option>"
            else
                echo "<option value=${entry}>${entry}</option>"
            fi
        done
        
    echo '
        </select>
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Welches Dockerimage soll verwendet werden?<br>
            jbarlow83/ocrmypdf ist das Standardimage, enthält aber nur die Sprachen: English, German and Simplified Chinese<br>
            Das Image jbarlow83/ocrmypdf-polyglot enthält alle möglichen Sprachen, ist aber größer!</span></a>
        </p>'

    # SearchPraefix
    echo '
        <p>
        <label>OCR Such-Präfix</label>'
        if [ -n "$SearchPraefix" ]; then
            echo '<input type="text" name="SearchPraefix" value="'$SearchPraefix'" />'
        else
            echo '<input type="text" name="SearchPraefix" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Nur PDFs mit definiertem Präfix bearbeiten (z.B. "SCAN_")<br>
            leerlassen, wenn alle Dokumente verarbeitet werden sollen</span></a>
        </p>'

    # delSearchPraefix
    echo '
        <p>
        <label><span style="color: #FFFFFF;">.</span></label>
        <select name="delSearchPraefix">'
        if [[ "$delSearchPraefix" == "no" ]]; then
            echo '<option value="no" selected>Suchpräfix erhalten</option>'
        else
            echo '<option value="no">Suchpräfix erhalten</option>'
        fi
        if [[ "$delSearchPraefix" == "yes" ]]; then
            echo '<option value="yes" selected>Suchpräfix entfernen</option>'
        else
            echo '<option value="yes">Suchpräfix entfernen</option>'
        fi
    echo '
        </select>
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Soll der Suchpräfix im Anschluss entfernt werden?<br>
            Nur so und in Verbindung mit einem Suchpräfix kann der Quellordner auch gleichzeitig der Zielordner sein!</span></a>
        </p>'

    # Taglist
    echo '
        <p>
        <label>zu suchende Tags</label>'
        if [ -n "$taglist" ]; then
        #    echo '<input type="text" name="taglist" value="'$taglist'" />'
            echo '<textarea id="text" name="taglist" cols="35" rows="4">'$taglist'</textarea>'
        else
        #    echo '<input type="text" name="taglist" value="" />'
            echo '<textarea id="text" name="taglist" cols="35" rows="4"></textarea>'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Hier angegebene Tags werden im Dokument gesucht und stehen für die Umbenennung zur Verfügung.
            Einzelne Tags werdendurch Semikolon getrennt.<br>
            <strong>! ! ! KEINEN ZEILENUMBRUCH VERWENDEN ! ! !</strong><br>
            Tags und Kategorien können auch Leerzeichen enthalten.<br>
            Soll ein Tag nur alleinstehend gefunden werden, ist ein Paragrafenzeichen voranzustellen (eine Suche nach "<code>§Rechnung</code>" findet so nicht fälschlicherweise "<code>Rechnungsstellung</code>")<br><br>
            z.B.: <b>Rechnung;Arbeit;Versicherung</b><br>
            <br>
            Tags können auch durch ein Gleichheitszeichen einer Kategorie (für Unterordner) zugeordnet werden 
            (greift nur, sofern man auch die Kategorieordner  [nachstehende Option] verwendet).<br><br>
            z.B.: <b>Rechnung;HUK24=Versicherung;Allianz=Versicherung</b><br>
            <br>
            <br></span></a>
        </p>'

    # searchAll
    echo '
        <p>
        <label>Suchbereich für Tags</label>
        <select name="searchAll">'
        if [[ "$searchAll" == "no" ]]; then
            echo '<option value="no" selected>Bereich: nur erste Seite</option>'
        else
            echo '<option value="no">Bereich: nur erste Seite</option>'
        fi
        if [[ "$searchAll" == "searchAll" ]]; then
            echo '<option value="searchAll" selected>Bereich: gesamtes Dokument</option>'
        else
            echo '<option value="searchAll">Bereich: gesamtes Dokument</option>'
        fi
    echo '
        </select>
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>In welchem Bereich soll nach Tags gesucht werden?
            Standard ist nur auf erster Seite. Je größer der Suchbereich, desto mehr false positive gibt es.</span></a>
        </p>'

    # moveTaggedFiles
    echo '
        <p>
        <label><span style="color: #FFFFFF;">Tag-Unterverzeichnisse nutzen</span></label>
        <select name="moveTaggedFiles">'
        if [[ "$moveTaggedFiles" == "no" ]]; then
            echo '<option value="no" selected>im Zielordner behalten</option>'
        else
            echo '<option value="no">im Zielordner behalten</option>'
        fi
        if [[ "$moveTaggedFiles" == "useCatDir" ]]; then
            echo '<option value="useCatDir" selected>Ziel-PDF in Kategorieordner einsortieren</option>'
        else
            echo '<option value="useCatDir">Ziel-PDF in Kategorieordner einsortieren</option>'
        fi
        if [[ "$moveTaggedFiles" == "useTagDir" ]]; then
            echo '<option value="useTagDir" selected>Ziel-PDF in Tagordner einsortieren</option>'
        else
            echo '<option value="useTagDir">Ziel-PDF in Tagordner einsortieren</option>'
        fi
    echo '
        </select>
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Sollen Tag-Unterverzeichnisse, bzw. Kategorieordner genutzt werden?<br>
            Bei mehreren zutreffenden Tags werden Hardlinks gesetzt.</span></a>
        </p>'

    # OCR Rename-Syntax
    echo '
        <p>
        <label>OCR Rename-Syntax</label>'
        if [ -n "$NameSyntax" ]; then
            echo '<input type="text" name="NameSyntax" value="'$NameSyntax'" />'
        else
            echo '<input type="text" name="NameSyntax" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Fertige PDFs mit einer Bestimmten Syntax umbenennen.<br><br>
            Folgende Variablen sind in Kombination mit Fließtext möglich<br>
            (Sonderzeichen können unvorhersehbare Folgen haben!):<br>
            <b>§d</b> (Datum / Tag)<br>
            <b>§m</b> (Datum / Monat)<br>
            <b>§y</b> (Datum / Jahr)<br>
            <b>§tag</b> (gefundene, oben angegebene Tags)<br>
            <b>§tit</b> (Titel der Originaldatei)<br>
            <br>
            >><b>§y-§m-§d_§tag_§tit</b><< erzeugt<br>
            z.B. >><b>2018-12-09_#Rechnung_00376.pdf</b><<<br>
            <br>
            Datumsangaben werden zuerst im Dokument gesucht. Wenn erfolglos, wird das Dateidatum verwendet.<br>
            <br>
            <br>
            <br>
            <br></span></a>
        </p>'

    echo '
    </details>
        </fieldset>
    </p>'

    # -> Abschnitt DSM-Benachrichtigung und sonstige Einstellungen
    echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;">
    <br />
    <details><p>
    <summary>
        <span class="detailsitem">DSM-Benachrichtigung und sonstige Einstellungen</span>
    </summary></p>
    <p>'

    # LOGmax
    echo '
        <p>
        <label>maximale LOG-Dateien</label>'
        if [ -n "$LOGmax" ]; then
            echo '<input type="text" name="LOGmax" value="'$LOGmax'" />'
        else
            echo '<input type="text" name="LOGmax" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>maximale Anzahl der LOG-Dateien (leere Logs werden sofort gelöscht)</span></a>
        </p>'

    # dsmtextnotify
    echo '
        <p>
        <label>Systembenachrichtigung (Text)</label>
        <select name="dsmtextnotify">'
        if [[ "$dsmtextnotify" == "off" ]]; then
            echo '<option value="off" selected>aus</option>'
        else
            echo '<option value="off">aus</option>'
        fi
        if [[ "$dsmtextnotify" == "on" ]]; then
            echo '<option value="on" selected>ein</option>'
        else
            echo '<option value="on">ein</option>'
        fi
    echo '
        </select>
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>ein => Benachrichtigung per Text aktiv im Benachrichtigungszentrum<br>aus => keine Textbenachrichtigung</span></a>
        </p>'

    # MessageTo
    echo '
        <p>
        <label>Benachrichtigung an User</label>'
        if [ -n "$MessageTo" ]; then
            echo '<input type="text" name="MessageTo" value="'$MessageTo'" />'
        else
            echo '<input type="text" name="MessageTo" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>User, an den die Benachrichtigungen gesendet werden.
            <br>Auf diese Art kann man sich in Verbindung mit dem Paket "Notification Forwarder" über synOCR-Ereignisse z.B. über einen Pushdienst benachrichtigen lassen.
            <br>Bleibt der Wert leer, so wird die Gruppe "administrators" benachrichtigt.
        </span></a></p>'

    # PushBullet-Token
    echo '
        <p>
        <label>PushBullet-Token</label>'
        if [ -n "$PBTOKEN" ]; then
            echo '<input type="text" name="PBTOKEN" value="'$PBTOKEN'" />'
        else
            echo '<input type="text" name="PBTOKEN" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Dein persönlicher PushBullet-Token.
            <br>Benachrichtigungen werden an den entsprechenden Account gesendet.
            <br>Bei Nichtgebrauch leer lassen.
        </span></a></p>'

    # dsmbeepnotify
    echo '
        <p>
        <label>Systembenachrichtigung (Piep)</label>
        <select name="dsmbeepnotify">'
        if [[ "$dsmbeepnotify" == "off" ]]; then
            echo '<option value="off" selected>aus</option>'
        else
            echo '<option value="off">aus</option>'
        fi
        if [[ "$dsmbeepnotify" == "on" ]]; then
            echo '<option value="on" selected>ein</option>'
        else
            echo '<option value="on">ein</option>'
        fi
    echo '
        </select>
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>Ein kurzer Piep, sobald ein Film fertig bearbeitet wurde.</span></a>
        </p>'

    # LOGlevel
    echo '
        <p>
        <label>LOGlevel (0,1,2)</label>
        <select name="loglevel">'
        if [[ "$loglevel" == "0" ]]; then
            echo '<option value="0" selected>aus</option>'
        else
            echo '<option value="0">aus</option>'
        fi
        if [[ "$loglevel" == "1" ]]; then
            echo '<option value="1" selected>1 (standard)</option>'
        else
            echo '<option value="1">1 (standard)</option>'
        fi
        if [[ "$loglevel" == "2" ]]; then
            echo '<option value="2" selected>2 (erweitert)</option>'
        else
            echo '<option value="2">2 (erweitert)</option>'
        fi

    echo '
        </select>
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>0  => es wird keine Log-Datei erstellt<br>1 => normales Log (standard)<br>2 => erweitertes Log</span></a>
        </p>'

    echo '
        </p>
        </details>
        <br><hr style="border-style: dashed; size: 1px;">
    </fieldset>'

    echo '
    </div>
    </div><div class="clear"></div>
    <div id="minheight"></div>
'
fi
