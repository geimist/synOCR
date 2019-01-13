#!/bin/bash
# main.sh

# Body:
# ---------------------------------------------------------------------

    echo '
	<div id="Content_1Col">
		<div class="Content_1Col_full"> 
            <br><br><p style="text-align:center"> <span style="color:#BD0010;font-weight:bold;font-size:1.1em; ">OCR auf Synology DiskStation</span> </p>'

    echo '  
    <span class="title">Beschreibung:</span>
        <p style="text-align:left;"> <br>
          SynOCR liefert eine einfache GUI für den Dockercontainer OCRmyPDF.</p>
          <p>Es können derzeit wahrscheinlich nicht alle Parameter in Verbindung mit 
          OCRmyPDF genutzt werden, aber die wichtigsten. Einfach in der <a href="index.cgi?page=edit" style="'$synotrred';">Konfiguration</a> den 
          Quell- und Zielordner eintragen. Jetzt ist schon über die <a href="index.cgi?page=status" style="'$synotrred';">Status-Seite</a> ein manueller 
          Programmlauf möglich. Der automatische Programmlauf ist (wie in der <a href="index.cgi?page=help" style="'$synotrred';">Hilfe</a> beschrieben) 
          entweder über den <a href="index.cgi?page=timer" style="'$synotrred';">Zeitplaner</a> oder den DSM-Aufgabenplaner einzustellen.
          '
          echo '</div>
    </div>
<br /></p><p style="text-align:center;"><br /><br /></p>'
			

echo '
		</div>
	</div><div class="clear"></div>'