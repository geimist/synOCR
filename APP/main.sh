#!/bin/bash
# /volume1/system/MOUNT_volume1/@appstore/synOCR/main.sh

# Dateizähler:
# ---------------------------------------------------------------------
    count_inputpdf=0
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

    sSQL="SELECT INPUTDIR, SearchPraefix FROM config WHERE active='1' "
    sqlerg=`sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL"`

    IFS=$'\012'
    for entry in $sqlerg; do
        IFS=$OLDIFS
        INPUTDIR=$(echo "$entry" | awk -F'\t' '{print $1}')
        SearchPraefix=$(echo "$entry" | awk -F'\t' '{print $2}')

        exclusion=false

        if echo "${SearchPraefix}" | grep -qE '^!' ; then
            # ist der prefix / suffix ein Ausschlusskriterium?
            exclusion=true
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e 's/^!//')
        fi

        if echo "${SearchPraefix}" | grep -q "\$"$ ; then
            # is suffix
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            if [[ $exclusion = false ]] ; then
                count_inputpdf=$( expr $(ls -t "${INPUTDIR}" | egrep -i "^.*${SearchPraefix}.pdf$" | wc -l) + $count_inputpdf )
            elif [[ $exclusion = true ]] ; then
                count_inputpdf=$( expr $(ls -t "${INPUTDIR}" | egrep -i "^.*.pdf$" | cut -f 1 -d '.' | egrep -iv "${SearchPraefix}$" | wc -l) + $count_inputpdf )
            fi
        else
            # is prefix
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            if [[ $exclusion = false ]] ; then
                count_inputpdf=$( expr $(ls -t "${INPUTDIR}" | egrep -i "^${SearchPraefix}.*.pdf$" | wc -l) + $count_inputpdf )
            elif [[ $exclusion = true ]] ; then
                count_inputpdf=$( expr $(ls -t "${INPUTDIR}" | egrep -i "^.*.pdf$" | egrep -iv "^${SearchPraefix}.*.pdf$" | wc -l) + $count_inputpdf )
            fi
        fi
    done

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
    if [[ "$page" == "main-kill-synocr" ]]; then
    	killall synOCR.sh
    	echo '<meta http-equiv="refresh" content="0; URL=index.cgi?page=main">'
    fi

# Body:
# ---------------------------------------------------------------------
if [[ "$page" == "main" ]] || [[ "$page" == "" ]]; then
    echo '<div id="Content_1Col">
		<div class="Content_1Col_full">
            <br><br><p style="text-align:center"> <span style="color:#BD0010;font-weight:bold;font-size:1.1em; ">'$lang_main_title1'</span> </p>'

# check Docker:
    if ! $(/usr/local/bin/docker --version | grep -q "version") ; then
        echo '<p class="center" style="'$synotrred';">'§lang_main_dockerfailed'<br /><br /></p>'
        echo '<div class="image-right"> </div>
            <img class="imageStyle"
            src="images/status_error@geimist.svg"
            height="120"
            width="120"
            style="float:right;padding: 10px">'
    elif [[ "$count_inputpdf" == 0 ]]; then
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

    echo '<span class="title">'$lang_main_title2':</span>
        <p style="text-align:left;"> <br><br>
          '$lang_main_desc1'</p><p>
          '$lang_main_desc2' <a href="index.cgi?page=edit" style="'$synocrred';">
          '$lang_main_desc3'</a>
          '$lang_main_desc4' <a href="index.cgi?page=help" style="'$synocrred';">
          '$lang_main_desc5'</a>
          '$lang_main_desc6' <a href="index.cgi?page=timer" style="'$synocrred';">
          '$lang_main_desc7'</a>
          '$lang_main_desc8' '$lang_main_desc9

    echo '<br><br><br><p class="center"><button name="page" class="blue_button" value="main-run-synocr">'$lang_main_buttonrun'</button></p><br />'

# Abschnitt Status / Statistik:	
    echo '<fieldset>
    	<hr style="border-style: dashed; size: 1px;">
    	<br />
    	<details><p>
        <summary>
            <span class="detailsitem">'$lang_main_statshead':</span>
        </summary></p>'

    echo '<table style="width: 700px;" >
        <tr>
            <th style="width: 1;"></th><th style="width: 250px;"></th><th></th><th style="width: 250px;"></th>
        </tr>
        <tr>
            <td class="td_color" colspan="2"><b>'$lang_main_openjobs':</b></td><td></td><td></td>
        </tr>'

    if [[ "$count_inputpdf" == 0 ]]; then
        echo '<tr><td class="td_color"></td><td><span style="color:#0086E5;font-weight:normal; ">'$lang_main_openfilecount': </span></td>
        <td><span style="color:green;">'$lang_main_alldone'</span></td></tr>'
    else
        echo '<tr><td class="td_color"></td><td><span style="color:#0086E5;font-weight:normal; ">'$lang_main_openfilecount': </span></td>
        <td><span style="color:#BD0010;">'$count_inputpdf'</span></td></tr>'
    fi

    echo '<tr><td class="td_color" bgcolor=#fff></td><td><span style="color:#0086E5;font-weight:normal; ">'$lang_main_totalsince' '$(get_key_value ./etc/counter startcount)' (PDF / '$lang_main_pages'):</td><td><span style="color:green;">'$(get_key_value ./etc/counter ocrcount)' / '$(get_key_value ./etc/counter pagecount)'</span></td></tr>'

    echo '</table>
        <!-- <p>Hier soll in Zukunft noch eine Statusübersicht / Statistik zu finden sein …<br>
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
