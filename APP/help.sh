#!/bin/bash
# help.sh


echo '
	<div id="Content_1Col">
	<div class="Content_1Col_full">
	<div class="title">
	    synOCR Hilfe
	</div>'
	    
# Aufklappbar:
    echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;">
    <br />
    <details><p>
    <summary>
        <span class="detailsitem">Schnellstart</span>
    </summary></p>
    <p>' 
    #ab hier steht der Text, der auf- und zugeklappt werden soll.
	
	echo '<ol style="list-style:decimal">
    <p>
    <li>Passe zunächst deine Installation in den <a href="index.cgi?page=edit" style="'$synotrred';">Einstellungen</a> an.
    </li></p>
    <p>
    <li>Um synOCR regelmäßig laufen zu lassen (was sich empfiehlt), erstelle als nächstes <br>einen automatisierten Programmaufruf.
      <div class="tab"><br>
      Dazu hast du 2 Möglichkeiten:<br>verwende den <a href="index.cgi?page=timer" style="'$synotrred';">Zeitplaner</a> für einen programmierten 
      synOCR-Start.<br><br>Hierbei ist zu beachten, dass der DSM-Sicherheitsbereater den Zusätzlichen Croneintrag (da für DSM unbekannt) bemängelt!</p><hr>
      <p>Oder, erstelle alternativ im Aufgabenplaner einen neuen Task mit diesem
      Programmpfad<br>(zu empfehlen, sofern du kürzere Intervalle als "stündlich" benötigst):</p>
    <p style="margin-left: 40px;"><code>/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh</code></p>
    <h3>Öffne dazu im DSM die Systemsteuerung </h3>
        <ul class="li_standard">
        <li>Aufgabenplaner </li>
        <li>Schaltfläche <i>Erstellen</i> </li>
        <li><i>geplante Aufgabe</i> </li>
        <li><i>Benutzerdefiniertes Skript</i></li>
        </ul><br>
    <h3>Registerkarte "Allgemein":</h3>
        <ul class="li_standard">
        <li>Benutzer root</li>
        <li>ein beliebiger Name unter <i>Vorgang</i></li>
        <li>Haken bei <i>aktiviert</i></li>
        </ul><br>
    <h3>Registerkarte "Zeitplan":</h3>
        <ul class="li_standard">
        <li>hier gewünschtes Intervall (z.B. stündlich)</li>
        </ul><br>
    <h3>Registerkarte "Aufgabeneinstellung":</h3>
        <ul class="li_standard">
        <li>hier den nachstehenden Pfad hineinkopieren:</li><br>
        <code><span style="background-color:#cccccc;font-hight:1.1em;">/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh</span></code>
      </ul><br>
    </ol>'

    echo '</details></fieldset></p>'

# -> Abschnitt OCRmyPDF:
echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;"><br />
    <details><p>
    <summary>
        <span class="detailsitem">OCRmyPDF Optionen</span>
    </summary></p>
    <p>'
    
    echo '<p>Detailiertere Hilfe zu OCRmyPDF findest du auf der <a href="https://ocrmypdf.readthedocs.io" onclick="window.open(this.href); return false;" style="'$synotrred';">OCRmyPDF Hilfeseite.</a></p>'
    
    echo '</details></fieldset></p>'

# -> Abschnitt sonstiges:
echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;"><br />
    <details><p>
    <summary>
        <span class="detailsitem">über synOCR</span>
    </summary></p>
    <p>'
    
echo '<p>Das Projekt hängt vor allem von meiner Zeit, Kraft und Lust ab, die ich dafür bereitstellen kann.<br>
    Begonnen, um meinen Arbeitsablauf mit PDF Dokumenten einfacher zu machen, ist es auch eine Freude für mich, wenn anderen dieses Projekt hilft. Daher erwarte ich keine Gegenleistung!<br>
    <a href="https://www.paypal.me/geimist" onclick="window.open(this.href); return false;"><img src="images/paypal.png" alt="PayPal" style="float:right;padding:10px" height="60" width="200"/></a><br>
    Sollte allerdings mir jemand eine finanzielle Freude machen wollen, so kann ihm das über diesen Button gelingen - DANKE: 
    </p>'
    
    echo '</details><br><hr style="border-style: dashed; size: 1px;"></fieldset></p>'


echo '
		</div>
	</div><div class="clear"></div>'
	