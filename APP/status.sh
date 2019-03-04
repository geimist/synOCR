#!/bin/bash
# status.sh

    APPDIR=$(cd $(dirname $0);pwd)
    CONFIG=etc/Konfiguration.txt
    source ${APPDIR}/${CONFIG}


# docker images | grep -q "jbarlow83/ocrmypdf"
    
    
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
    count_inputpdf=$( ls -t "${INPUTDIR}" | egrep -oi "${SearchPraefix}.*.pdf$" | wc -l ) # wie viele Dateien 

# Installationsstatus auslesen:
# ---------------------------------------------------------------------



# manueller synOTR-Start:
# ---------------------------------------------------------------------
    if [[ "$page" == "status-run-synocr" ]]; then
    	echo '
    	<div class="Content_1Col_full">'
    	    /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh GUI
    #	echo $refreshtime
    	echo '<meta http-equiv="refresh" content="2; URL=index.cgi?page=status"></div>'
    fi


# synOCR beenden erzwingen:
# ---------------------------------------------------------------------
    if [[ "$page" == "status-kill-synocr" ]]; then
    	killall synOCR.sh
    	echo '<meta http-equiv="refresh" content="0; URL=index.cgi?page=status">'
    fi


if [[ "$page" == "status" ]]; then
    
# Body:
# ---------------------------------------------------------------------
echo '  <div class="Content_1Col_full">
    	<div class="title">'

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
    
echo '  synOCR Statusseite</div>
    	<br><br><br><p class="center"><button name="page" class="blue_button" value="status-run-synocr">jetzt manuellen synOCR Durchlauf starten</button></p><br />'
	
# Abschnitt LOG-Protokoll:	
#    echo '<fieldset>
#    	<hr style="border-style: dashed; size: 1px;">
#    	<br />
#    	<details><p>
#        <summary>
#            <span class="detailsitem">LOG-Protokoll:</span>
#        </summary></p>
#            <p>
#                Hier werden die LOGs zu finden sein …
#                <br>(noch nicht implementiert)
#    	    </p>
#        </details>
#        </fieldset>'
	
# Abschnitt Status / Statistik:	
echo '<fieldset>
	<hr style="border-style: dashed; size: 1px;">
	<br />
	<details><p>
    <summary>
        <span class="detailsitem">Status:</span>
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

    echo '
    </table>
        <!-- <p>Hier wird in Zukunft noch eine Statusübersicht / Statistik zu finden sein …<br>
        - https://developers.google.com/chart/interactive/docs/quick_start<br>
        - http://jsfiddle.net/api/post/jquery/1.6/ (http://elycharts.com/examples) </p>
        <br><div class="tab"><p>'$dbinfo'</p></div>-->
    
    </details>
    
    <br>
	<hr style="border-style: dashed; size: 1px;">
    </fieldset>'	
		
	echo '
		</div>
    </div>
    <br /></p><p style="text-align:center;"><br /><br /></p>'
			
    echo '</div><div class="clear"></div>'
fi
