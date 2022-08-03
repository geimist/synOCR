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
            echo '
            <meta http-equiv="refresh" content="2; URL=index.cgi?page=main">
        </div>'
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
    # -> Headline
    echo '
    <h2 class="synocr-text-blue mt-3">synOCR '$lang_page1'</h2>
    <p>&nbsp;</p>'

    echo '
    <h5 class="text-center">
        <strong class="synocr-text-red">'$lang_main_title1'</strong>
    </h5>'

# check Docker:
    if [ ! $(which docker) ]; then
#   if ! $(docker --version | grep -q "version") ; then
    # the user synOCR cannot access docker under unknown circumstances, which falsely triggers the error message
        echo '
        <p class="text-center synocr-text-red mb-5">'$lang_main_dockerfailed'</p>
        <div class="float-end">
            <img src="images/status_error@geimist.svg" height="120" width="120" style="padding: 10px">
        </div>'
    elif [ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -ge 7 ] && $(! cat /etc/group | grep ^administrators | grep -q synOCR || ! cat /etc/group | grep ^docker: | grep -q synOCR ); then
        echo '
        <p class="text-center synocr-text-red">'$lang_main_permissions_failed'
            <code class="mb-5">/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh</code>
        </p>
        <div class="float-end">
            <img src="images/status_error@geimist.svg" height="120" width="120" style=";padding: 10px">
        </div>'
    elif [[ "$count_inputpdf" == 0 ]]; then
        #unseren dockercontainer löschen wenn alles passt
        docker container rm ocrroot_container
        echo '
        <div class="float-end">
            <img src="images/status_green@geimist.svg" height="120" width="120" style="padding: 10px">
        </div>'
    else
        echo '
        <div class="float-end">
            <img src="images/sanduhr_blue@geimist.svg" height="120" width="120" style="padding: 10px">
        </div>'
    fi

    echo '
    <p>&nbsp;</p>
    <h2 class="synocr-text-blue">'$lang_main_title2':</h2>
    <p>&nbsp;</p>
    <p>'$lang_main_desc1'</p>
    <p>'$lang_main_desc2'</p>
    <p>&nbsp;</p>'

    if [ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -ge 6 ] || (cat /etc/group | grep ^administrators | grep -q synOCR && cat /etc/group | grep ^docker | grep -q synOCR) ; then
        echo '
        <p class="text-center">
            <button name="page" class="btn btn-primary" style="background-color: #0086E5;" value="main-run-synocr">'$lang_main_buttonrun'</button>
        </p><br />'
    fi

# Section Status / Statistics:
echo '
<div class="accordion" id="Accordion-01">
    <div class="accordion-item border-start-0 border-end-0" style="border-style: dashed none dashed none; size: 1px;">
        <h2 class="accordion-header" id="Heading-01">
            <button class="accordion-button collapsed bg-white synocr-accordion-glow-off" type="button" data-bs-toggle="collapse" data-bs-target="#Collapse-01" aria-expanded="false" aria-controls="collapseTwo">
                <span class="synocr-text-blue">'$lang_main_statshead':</span>
            </button>
        </h2>
        <div id="Collapse-01" class="accordion-collapse collapse border-white" aria-labelledby="Heading-01" data-bs-parent="#Accordion-01">
            <div class="accordion-body">
                <table class="table table-borderless" style="width: 70%;">
                    <thead">
                        <tr>
                            <th scope="col">'$lang_main_openjobs':</th>
                            <th scope="col">&nbsp;</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>'
                            if [[ "$count_inputpdf" == 0 ]]; then
                                echo '
                                <td class="synocr-text-blue">'$lang_main_openfilecount':</td>
                                <td class="synocr-text-green">'$lang_main_alldone'</td>'
                            else
                                echo '
                                <td class="synocr-text-blue">'$lang_main_openfilecount': </td>
                                <td class="synocr-text-red">'$count_inputpdf'</td>'
                            fi
                            echo '
                        </tr>
                        <tr>
                            <td class="synocr-text-blue">'$lang_main_totalsince' '$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='count_start_date'")' (PDF / '$lang_main_pages'):</td>
                            <td class="synocr-text-green">'$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_ocrcount'")' / '$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='global_pagecount'")'</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>


        <!-- <p>Hier soll in Zukunft noch eine Statusübersicht / Statistik zu finden sein …<br>
        - https://developers.google.com/chart/interactive/docs/quick_start<br>
        - http://jsfiddle.net/api/post/jquery/1.6/ (http://elycharts.com/examples) </p>
        <br><div class="tab"><p>'$dbinfo'</p></div>-->'

fi

