#!/bin/bash
# main.sh


# Dateizähler:
# ---------------------------------------------------------------------
    if [ ! -f ./etc/counter ] ; then
        touch ./etc/counter
        echo "startcount=\"$(date +%Y)-$(date +%m)-$(date +%d)\"" >> ./etc/counter
        echo "ocrcount=\"0\"" >> ./etc/counter
        echo "pagecount=\"0\"" >> ./etc/counter
    else
        if ! cat ./etc/counter | grep -q "pagecount" ; then
            echo "pagecount=\"$(get_key_value ./etc/counter ocrcount)\"" >> ./etc/counter
        fi
    fi
    
# Dateistatus auslesen:
# ---------------------------------------------------------------------
    # Anzahl unfertiger PDF-Files:    
    
    count_inputpdf=0
    
    sSQL="SELECT INPUTDIR, SearchPraefix FROM config WHERE active='1' "
    sqlerg=`sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL"`

    IFS=$'\012'
    for entry in $sqlerg; do
        IFS=$OLDIFS
        INPUTDIR=$(echo "$entry" | awk -F'\t' '{print $1}')
        SearchPraefix=$(echo "$entry" | awk -F'\t' '{print $2}')
        count_inputpdf=$( expr $(ls -t "${INPUTDIR}" | egrep -oi "${SearchPraefix}.*.pdf$" | wc -l) + $count_inputpdf ) # wie viele Dateien 
    done
    
# Installationsstatus auslesen:
# ---------------------------------------------------------------------



# manueller synOTR-Start:
# ---------------------------------------------------------------------
    if [[ "$page" == "main-run-synocr" ]]; then
    	echo '
    	<div class="Content_1Col_full">'
    	    /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh GUI
    #	echo $refreshtime
    	echo '<meta http-equiv="refresh" content="2; URL=index.cgi?page=main"></div>'
    fi

# synOCR beenden erzwingen:
# ---------------------------------------------------------------------
    if [[ "$page" == "status-kill-synocr" ]]; then
    	killall synOCR.sh
    	echo '<meta http-equiv="refresh" content="0; URL=index.cgi?page=main">'
    fi

# Body:
# ---------------------------------------------------------------------
if [[ "$page" == "main" ]] || [[ "$page" == "" ]]; then
    echo '<div id="Content_1Col">
		<div class="Content_1Col_full"> 
            <br><br><p style="text-align:center"> <span style="color:#BD0010;font-weight:bold;font-size:1.1em; ">OCR auf Synology DiskStation</span> </p>'


if [[ "$count_inputpdf" == 0 ]]; then
    echo '<div class="image-right"> </div>
        <img class="imageStyle"
        src="images/status_green@geimist.svg"
        height="120"
        width="120"
        style="float:right;padding: 10px">'   	    
else	    
    echo '<div class="image-right"> </div>
        <img class="imageStyle"
        src="images/sanduhr_blue@geimist.svg"
        height="120"
        width="120"
        style="float:right;padding: 10px">'    	    
fi  	    
    echo '<span class="title">Beschreibung:</span>
        <p style="text-align:left;"> <br>
          SynOCR liefert eine einfache GUI für den Dockercontainer OCRmyPDF.</p>
          <p>Es können derzeit wahrscheinlich nicht alle Parameter in Verbindung mit 
          OCRmyPDF genutzt werden, aber die wichtigsten. Einfach in der <a href="index.cgi?page=edit" style="'$synotrred';">Konfiguration</a> den 
          Quell- und Zielordner eintragen. Jetzt ist schon über den Button unten ein manueller 
          Programmlauf möglich. Der automatische Programmlauf ist (wie in der <a href="index.cgi?page=help" style="'$synotrred';">Hilfe</a> beschrieben) 
          entweder über den <a href="index.cgi?page=timer" style="'$synotrred';">Zeitplaner</a> oder den DSM-Aufgabenplaner einzustellen.'

    echo '<br><br><br><p class="center"><button name="page" class="blue_button" value="main-run-synocr">jetzt manuellen synOCR Durchlauf starten</button></p><br />'

# Abschnitt Status / Statistik:	
    echo '<fieldset>
    	<hr style="border-style: dashed; size: 1px;">
    	<br />
    	<details><p>
        <summary>
            <span class="detailsitem">Status / Statistik:</span>
        </summary></p>'

    echo '<table style="width: 700px;" >
        <tr>   
            <th style="width: 1;"></th><th style="width: 250px;"></th><th></th><th style="width: 250px;"></th>
        </tr>
        <tr>
            <td class="td_color" colspan="2"><b>Offene Aufgaben:</b></td><td></td><td></td>
        </tr>'
 
    if [[ "$count_inputpdf" == 0 ]]; then
        echo '<tr><td class="td_color"></td><td><span style="color:#0086E5;font-weight:normal; ">Dateien zu bearbeiten: </span></td>
        <td><span style="color:green;">Alles erledigt</span></td></tr>'
    else
        echo '<tr><td class="td_color"></td><td><span style="color:#0086E5;font-weight:normal; ">Dateien zu bearbeiten: </span></td>
        <td><span style="color:#BD0010;">'$count_inputpdf'</span></td></tr>'
    fi
    
    echo '<tr><td class="td_color" bgcolor=#fff></td><td><span style="color:#0086E5;font-weight:normal; ">Gesamt seit '$(get_key_value ./etc/counter startcount)' PDF/Pages:</td><td><span style="color:green;">'$(get_key_value ./etc/counter ocrcount)'/'$(get_key_value ./etc/counter pagecount)'</span></td></tr>'

    echo '</table>
        <!-- <p>Hier wird in Zukunft noch eine Statusübersicht / Statistik zu finden sein …<br>
        - https://developers.google.com/chart/interactive/docs/quick_start<br>
        - http://jsfiddle.net/api/post/jquery/1.6/ (http://elycharts.com/examples) </p>
        <br><div class="tab"><p>'$dbinfo'</p></div>-->

        </details>

        <br>
    	<hr style="border-style: dashed; size: 1px;">
        </fieldset>'

    echo '</div></div><br /></p><p style="text-align:center;"><br /><br /></p>'
    echo '</div></div><div class="clear"></div>'
fi
