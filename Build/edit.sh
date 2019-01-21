#!/bin/bash
# edit.sh


if [[ "$page" == "edit-save" ]]; then
	"$set_var" "$dir/etc/Konfiguration.txt" "INPUTDIR" "$INPUTDIR"
	"$set_var" "$dir/etc/Konfiguration.txt" "OUTPUTDIR" "$OUTPUTDIR"
	"$set_var" "$dir/etc/Konfiguration.txt" "BACKUPDIR" "$BACKUPDIR"
	"$set_var" "$dir/etc/Konfiguration.txt" "LOGmax" "$LOGmax"
	"$set_var" "$dir/etc/Konfiguration.txt" "LOGDIR" "$LOGDIR"
	"$set_var" "$dir/etc/Konfiguration.txt" "SearchPraefix" "$SearchPraefix"
	"$set_var" "$dir/etc/Konfiguration.txt" "delSearchPraefix" "$delSearchPraefix"
	"$set_var" "$dir/etc/Konfiguration.txt" "taglist" "$taglist"
	"$set_var" "$dir/etc/Konfiguration.txt" "moveTaggedFiles" "$moveTaggedFiles"
	"$set_var" "$dir/etc/Konfiguration.txt" "NameSyntax" "$NameSyntax"
	"$set_var" "$dir/etc/Konfiguration.txt" "ocropt" "$ocropt"
	"$set_var" "$dir/etc/Konfiguration.txt" "PBTOKEN" "$PBTOKEN"
	"$set_var" "$dir/etc/Konfiguration.txt" "dsmtextnotify" "$dsmtextnotify"
	"$set_var" "$dir/etc/Konfiguration.txt" "MessageTo" "$MessageTo"
	"$set_var" "$dir/etc/Konfiguration.txt" "dsmbeepnotify" "$dsmbeepnotify"
	"$set_var" "$dir/etc/Konfiguration.txt" "loglevel" "$loglevel"
	
	echo '<div class="Content_1Col_full">'
	echo '<br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">Änderungen wurden gespeichert</p><br /></div>'
	echo '<br /><p class="center"><button name="page" value="edit" class="blue_button">Weiter...</button></p><br />'
	echo '</div><div class="clear"></div>'
fi


if [[ "$page" == "edit-import-query" ]] || [[ "$page" == "edit-import" ]]; then
#        echo '<div class="Content_1Col_full">'
	if [[ "$page" == "edit-import-query" ]]; then
		echo '
	    <p class="center">
			Sollen die aktuellen Einstellungen überschrieben werden?<br /><br />
			Um eine frühere Konfigurationsdatei zu importieren, lege zunächst in den <a href="index.cgi?page=edit" style="'$synotrred';">Einstellungen</a> 
			das Quellverzeichnis fest. Die zu importierende Konfigurationsdatei muss den Namen "Konfiguration.txt" 
			haben und in das Quellverzeichnis gelegt werden. Klicke dann auf weiter.<br /><br />
			<a href="index.cgi?page=edit-import" class="blue_button">Weiter</a>&nbsp;&nbsp;&nbsp;<a href="index.cgi?page=edit" class="button">Abbrechen</a></p>'  >> "$stop"
	elif [[ "$page" == "edit-import" ]]; then
    	if [ ! -z "$INPUTDIR" ] && [ -d "$INPUTDIR" ]; then
        #	echo '<p class="center"><br><b>Konfiguration wurde importiert.</b></p>'
            SOURCECONFIG="${INPUTDIR%/}/Konfiguration.txt"
            if [ -f "$SOURCECONFIG" ] ; then
                source $SOURCECONFIG
    
            	"$set_var" "$dir/etc/Konfiguration.txt" "INPUTDIR" "$INPUTDIR"
            	"$set_var" "$dir/etc/Konfiguration.txt" "OUTPUTDIR" "$OUTPUTDIR"
            	"$set_var" "$dir/etc/Konfiguration.txt" "BACKUPDIR" "$BACKUPDIR"
            	"$set_var" "$dir/etc/Konfiguration.txt" "LOGmax" "$LOGmax"
            	"$set_var" "$dir/etc/Konfiguration.txt" "LOGDIR" "$LOGDIR"
            	"$set_var" "$dir/etc/Konfiguration.txt" "SearchPraefix" "$SearchPraefix"
            	"$set_var" "$dir/etc/Konfiguration.txt" "delSearchPraefix" "$delSearchPraefix"
            	"$set_var" "$dir/etc/Konfiguration.txt" "taglist" "$taglist"
	            "$set_var" "$dir/etc/Konfiguration.txt" "moveTaggedFiles" "$moveTaggedFiles"
            	"$set_var" "$dir/etc/Konfiguration.txt" "NameSyntax" "$NameSyntax"
            	"$set_var" "$dir/etc/Konfiguration.txt" "ocropt" "$ocropt"
            	"$set_var" "$dir/etc/Konfiguration.txt" "PBTOKEN" "$PBTOKEN"
            	"$set_var" "$dir/etc/Konfiguration.txt" "dsmtextnotify" "$dsmtextnotify"
            	"$set_var" "$dir/etc/Konfiguration.txt" "MessageTo" "$MessageTo"
            	"$set_var" "$dir/etc/Konfiguration.txt" "dsmbeepnotify" "$dsmbeepnotify"
            	"$set_var" "$dir/etc/Konfiguration.txt" "loglevel" "$loglevel"
            
                # neue Konfiguration laden:
                source $dir/etc/Konfiguration.txt
                
    	        echo '<br /><p class="center">Die Konfiguration wurde importiert</p><br />' >> "$stop"
            else
                echo '<p class="center">Die Quellkonfiguration konnte nicht im angegebenen Verzeichnis gefunden werden!</p>' >> "$stop"
            fi
        else
        	echo '<p class="center"><br><b>Konfiguration konnte nicht importiert werden,
        	<br>da kein korrektes Quellverzeichnis in den Einstellungen definiert wurde!</b></p>' >> "$stop"
        fi
    	echo '<br /><p class="center"><button name="page" value="edit" class="blue_button">Fertig ...</button></p><br />
            <div class="clear"></div>' >> "$stop"
    fi
fi


if [[ "$page" == "edit-export" ]]; then
    echo '<div class="Content_1Col_full">'
	if [ ! -z "$INPUTDIR" ] ; then
    	cp "$dir/etc/Konfiguration.txt" "${INPUTDIR%/}/Konfiguration.txt"
    #	cp "$dir/etc/counter" "${INPUTDIR%/}/counter"
    	echo '<br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">Konfigurationsdatei wurde in das Quellverzeichnis gesichert.</p><br /></div>'
    else
    	echo '<br /><div class="warning"><br /><p class="center">Konfigurationsdatei konnte nicht in das Quellverzeichnis gesichert werden,
    	<br>da kein Quellverzeichnis in den Einstellungen definiert wurde!</p><br /></div>'
    fi
	echo '<br /><p class="center"><button name="page" value="edit" class="blue_button">Weiter...</button></p><br />'
	echo '
	</div>
	<div class="clear"></div>'
fi


if [[ "$page" == "edit-restore-query" ]] || [[ "$page" == "edit-restore" ]]; then
	if [[ "$page" == "edit-restore-query" ]]; then
		echo '
	    <p class="center" style="'$synotrred';">
			Sollen die Werkseinstellungen geladen werden?<br /><br /><br />
			<a href="index.cgi?page=edit-restore" class="red_button">Ja</a>&nbsp;&nbsp;&nbsp;<a href="index.cgi?page=edit" class="button">Nein</a></p>'  >> "$stop"
	elif [[ "$page" == "edit-restore" ]]; then
    	if [ -f "$dir/etc/Konfiguration.txt" ]; then
    		rm "$dir/etc/Konfiguration.txt"
    		cp "$dir/usersettings/Konfiguration_org.txt" "$dir/etc/Konfiguration.txt"
    		chmod 755 "$dir/etc/Konfiguration.txt"
    	fi	
    	echo '<p class="center" style="'$green';"><b>Werkseinstellungen wurden wiederhergestellt</b></p>
    	    <br /><p class="center"><button name="page" value="edit" class="blue_button">Weiter...</button></p><br />' >> "$stop"
	fi
fi


if [[ "$page" == "edit" ]]; then
	# Dateiinhalt einlesen für Variablenverwertung
	if [ -f "$dir/etc/Konfiguration.txt" ]; then
		source "$dir/etc/Konfiguration.txt"
	fi

	echo '
	<div id="Content_1Col">
	<div class="Content_1Col_full">
    	<div class="title">
    	    synOCR Einstellungen
    	</div>
    	Trage hier deine Einstellungen ein und passe die Pfade an.
	    <br>Hilfe für die einzelnen Felder erhältst du über das blaue Info-Symbol am rechten Rand.
	    <br>
	    <br>Achte unbedingt darauf, die kompletten Pfade inkl. Volume (z.B. <code>/volume1/…</code>) einzutragen und achte auf korrekte Groß- und Kleinschreibung. 
	    Das sicherste ist, wenn du in der Filestation den gewünschten Ordner suchst und du dir über Rechtsklick die Eigenschaften anzeigen lässt. 
	    In diesem Dialog kannst du dir den korrekten Pfad kopieren.
	    <br><br>'

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
			<span>In diesem Verzeichnis wird nach PDF-Dateien gesucht.</span></a>
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
			<span>Nur PDFs mit definiertem Präfix bearbeiten (z.B. "SCAN_")<br></span></a>
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
			echo '<input type="text" name="taglist" value="'$taglist'" />'
		else
			echo '<input type="text" name="taglist" value="" />'
		fi
	echo '
		<a class="helpbox" href="#HELP">
			<img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
			<span>Hier angegebene Tags werden im Dokument gesucht und stehen für die Umbenennung zur Verfügung.
			Tags sollten aus einzelnen Wörtern bestehen und durch Semikolon getrennt werden.<br><br>
			z.B.: <b>Rechnung;Arbeit;Versicherung</b><br>
			<br>
			Tags können auch durch ein Gleichheitszeichen einer Kategorie (für Unterordner) zugeordnet werden 
			(greift nur, sofern man auch die Kategorieordner  [nachstehende Option] verwendet).<br><br>
			z.B.: <b>Rechnung;HUK24=Versicherung;Allianz=Versicherung</b><br>
			<br>
			<br></span></a>
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
		if [[ "$moveTaggedFiles" == "yes" ]]; then
			echo '<option value="yes" selected>Ziel-PDF nach Tag-Ordner einsortieren</option>'
		else
			echo '<option value="yes">Ziel-PDF nach Tag-Ordner einsortieren</option>'
		fi
	echo '
		</select>
		<a class="helpbox" href="#HELP">
			<img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
			<span>Sollen Tag-Unterverzeichnisse genutzt werden?<br>
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
			<b>§tag</b> (gefundene, oben angegebene Taggs)<br>
			<b>§tit</b> (Titel der Originaldatei)<br>
			<br>
			>><b>§y-§m-§d_§tag_§tit</b><< erzeugt z.B. >><b>2018-12-09_#Rechnung_00376.pdf</b><<<br>
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
