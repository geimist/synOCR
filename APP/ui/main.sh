#!/bin/bash
# /usr/syno/synoman/webman/3rdparty/synOCR/main.sh

PATH=$PATH:/usr/local/bin:/opt/usr/bin

# Read file status:
# ---------------------------------------------------------------------
    # Count of unfinished PDF files:
    count_inputpdf=0

    sSQL="SELECT INPUTDIR, SearchPraefix FROM config WHERE active='1' "
    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL")

    IFS=$'\012'
    for entry in $sqlerg; do
        IFS=$OLDIFS
        INPUTDIR=$(echo "$entry" | awk -F'\t' '{print $1}')
        SearchPraefix=$(echo "$entry" | awk -F'\t' '{print $2}')

        exclusion=false

        if echo "${SearchPraefix}" | grep -qE '^!' ; then
            # is the prefix / suffix an exclusion criterion?
            exclusion=true
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e 's/^!//')
        fi

        if echo "${SearchPraefix}" | grep -q "\$"$ ; then
            # is suffix
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            if [[ $exclusion = false ]] ; then
                count_inputpdf=$(( $(ls -t "${INPUTDIR}" | egrep -i "^.*${SearchPraefix}.pdf$" | wc -l) + $count_inputpdf ))
            elif [[ $exclusion = true ]] ; then
                count_inputpdf=$(( $(ls -t "${INPUTDIR}" | egrep -i "^.*.pdf$" | cut -f 1 -d '.' | egrep -iv "${SearchPraefix}$" | wc -l) + $count_inputpdf ))
            fi
        else
            # is prefix
            SearchPraefix=$(echo "${SearchPraefix}" | sed -e $'s/\$//' )
            if [[ $exclusion = false ]] ; then
                count_inputpdf=$(( $(ls -t "${INPUTDIR}" | egrep -i "^${SearchPraefix}.*.pdf$" | wc -l) + $count_inputpdf ))
            elif [[ $exclusion = true ]] ; then
                count_inputpdf=$(( $(ls -t "${INPUTDIR}" | egrep -i "^.*.pdf$" | egrep -iv "^${SearchPraefix}.*.pdf$" | wc -l) + $count_inputpdf ))
            fi
        fi
    done

# manual synOCR start:
# ---------------------------------------------------------------------
    if [[ "$page" == "main-run-synocr" ]]; then
      echo '
      <div class="Content_1Col_full">'
          /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh GUI
      echo '<meta http-equiv="refresh" content="2; URL=index.cgi?page=main"></div>'
    fi

# Force synOCR exit:
# ---------------------------------------------------------------------
    if [[ "$page" == "main-kill-synocr" ]]; then
        killall synOCR.sh
        docker stop -t 0 synOCR > /dev/null  2>&1
        echo '<meta http-equiv="refresh" content="0; URL=index.cgi?page=main">'
    fi

# Body:
# ---------------------------------------------------------------------
if [[ "$page" == "main" ]] || [[ "$page" == "" ]]; then
    echo '<div id="Content_1Col">
        <div class="Content_1Col_full">
            <br><br><p style="text-align:center"> <span style="color:#BD0010;font-weight:bold;font-size:1.1em; ">'$lang_main_title1'</span> </p>'

# check Docker:
    if [ ! $(which docker) ]; then
#   if ! $(docker --version | grep -q "version") ; then
    # the user synOCR cannot access docker under unknown circumstances, which falsely triggers the error message
        echo '<p class="center" style="'$synotrred';">'$lang_main_dockerfailed'<br /><br /></p>'
        echo '<div class="image-right"> </div>
            <img class="imageStyle"
            src="images/status_error@geimist.svg"
            height="120"
            width="120"
            style="float:right;padding: 10px">'
    elif [ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -ge 7 ] && $(! cat /etc/group | grep ^administrators | grep -q synOCR || ! cat /etc/group | grep ^docker: | grep -q synOCR ); then
        echo '<p class="center" style="'$synotrred';">'$lang_main_permissions_failed'<br /><br /><code>/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh</code><br /><br /></p>'
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

    if [ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -ge 6 ] || (cat /etc/group | grep ^administrators | grep -q synOCR && cat /etc/group | grep ^docker | grep -q synOCR) ; then
        echo '<br><br><br><p class="center"><button name="page" class="blue_button" value="main-run-synocr">'$lang_main_buttonrun'</button></p><br />'
    fi

# Section Status / Statistics:
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

    echo '<tr><td class="td_color" bgcolor=#fff></td><td><span style="color:#0086E5;font-weight:normal; ">'$lang_main_totalsince' '$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='count_start_date'")' (PDF / '$lang_main_pages'):</td><td><span style="color:green;">'$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_ocrcount'")' / '$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_pagecount'")'</span></td></tr>'

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

