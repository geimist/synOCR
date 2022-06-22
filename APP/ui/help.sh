#!/bin/bash
# /usr/syno/synoman/webman/3rdparty/synOCR/help.sh

# -> Headline
echo '
<h2 class="synocr-text-blue mt-3">synOCR '$lang_page4'</h2>
<p>&nbsp;</p>'

# -> Section configuration:
echo '
<div class="accordion" id="Accordion-01">
    <div class="accordion-item border-start-0 border-end-0" style="border-style: dashed none dashed none; size: 1px;">
        <h2 class="accordion-header" id="Heading-01">
            <button class="accordion-button collapsed bg-white synocr-accordion-glow-off" type="button" data-bs-toggle="collapse" data-bs-target="#Collapse-01" aria-expanded="false" aria-controls="collapseTwo">
                <span class="synocr-text-blue">'$lang_help_title_QS'</span>
            </button>
        </h2>
        <div id="Collapse-01" class="accordion-collapse collapse border-white" aria-labelledby="Heading-01" data-bs-parent="#Accordion-01">
            <div class="accordion-body">
                <ol style="list-style:decimal">
                    <li>'$lang_help_QS_1_beforelink' <a href="index.cgi?page=edit" style="'$synocrred';">'$lang_page2'</a> '$lang_help_QS_1_afterlink'</li>
                    <li>'$lang_help_QS_1b' <a href="https://synocommunity.com/package/inotify-tools" onclick="window.open(this.href); return false;" style="'$synocrred';"><b>(DOWNLOAD inotify-tools)</b></a></li>
                    <li>'$lang_help_QS_2'<br /><br />
                        <h6 class="synocr-text-blue">'$lang_help_QS_sub1_tit'</h6>
                        <ul class="li_standard">
                            <li>'$lang_help_QS_sub1_1'</li>
                            <li>'$lang_button' <i>'$lang_help_QS_sub1_2'</i></li>
                            <li><i>'$lang_help_QS_sub1_3'</i></li>
                            <li><i>'$lang_help_QS_sub1_4'</i></li>
                        </ul><br />
                        <h6 class="synocr-text-blue">'$lang_tab' &quot;'$lang_help_QS_sub2_tit'&quot;:</h6>
                        <ul class="li_standard">
                            <li>'$lang_help_QS_sub2_1' <i>root</i></li>
                            <li>'$lang_help_QS_sub2_2'</li>
                            <li>'$lang_help_QS_sub2_3'</li>
                        </ul><br />
                        <h6 class="synocr-text-blue">'$lang_tab' &quot;'$lang_help_QS_sub3_tit'&quot;:</h6>
                        <ul class="li_standard">
                            <li>'$lang_help_QS_sub3_1'</li>
                        </ul><br />
                        <h6 class="synocr-text-blue">'$lang_tab' &quot;'$lang_help_QS_sub4_tit'&quot;:</h6>
                        <ul class="li_standard">
                            <li>'$lang_help_QS_sub4_1'</li><br />
                            <code><span style="background-color:#cccccc;font-hight:1.1em;">/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh start</span></code>
                        </ul><br />
                </ol>
            </div>
        </div>
    </div>
</div>'

# -> Section FAQ:
echo '
<div class="accordion" id="Accordion-02">
    <div class="accordion-item border-start-0 border-end-0" style="border-style: dashed none dashed none; size: 1px;">
        <h2 class="accordion-header" id="Heading-02">
            <button class="accordion-button collapsed bg-white synocr-accordion-glow-off" type="button" data-bs-toggle="collapse" data-bs-target="#Collapse-02" aria-expanded="false" aria-controls="collapseTwo">
                <span class="synocr-text-blue">'$lang_help_title_FAQ'</span>
            </button>
        </h2>
        <div id="Collapse-02" class="accordion-collapse collapse border-white" aria-labelledby="Heading-02" data-bs-parent="#Accordion-02">
            <div class="accordion-body">

                <h6 class="synocr-text-blue">'$lang_help_FAQ_sub1_tit'</h6>
                <ul>
                    <li>'$lang_help_FAQ_sub1_1_beforelink' <a href="https://ocrmypdf.readthedocs.io" onclick="window.open(this.href); return false;" style="'$synocrred';">'$lang_help_FAQ_sub1_1_linktitle'</a>'$lang_help_FAQ_sub1_1_afterlink'</li>
                </ul>
                <br />

                <h6 class="synocr-text-blue">'$lang_help_FAQ_sub2_tit'</h6>
                <ul>
                    <li>'$lang_help_FAQ_sub2_1': &quot;<i>'$lang_help_FAQ_sub2_2'</i>&quot; ('$lang_help_FAQ_sub2_3')</li>
                </ul>
                <br />

                <h6 class="synocr-text-blue">'$lang_help_FAQ_sub3_tit'</h6>
                <ul>
                    <li>'$lang_help_FAQ_sub3_1'</li>
                    <li>'$lang_help_FAQ_sub3_2'</li>
                </ul>
                <br />

                <h6 class="synocr-text-blue">'$lang_help_FAQ_sub4_tit'</h6>
                <ul>
                    <li>'$lang_help_FAQ_sub4_1'</li>
                    <li>'$lang_help_FAQ_sub4_2'</li>
                </ul>
                <br />

                <h6 class="synocr-text-blue">'$lang_help_FAQ_sub5_tit'</h6>
                <ul>
                    <li><a href="https://git.geimist.eu/geimist/synOCR/wiki/04_FAQ_de" onclick="window.open(this.href); return false;" style="'$synocrred';">synOCR Wiki</a></li>
                    <li>'$lang_help_FAQ_sub5_beforelink' <a href="https://www.synology-forum.de/showthread.html?99647-synOCR-GUI-f%C3%BCr-OCRmyPDF" onclick="window.open(this.href); return false;" style="'$synocrred';">'$lang_help_FAQ_sub5_linktitle'</a>'$lang_help_FAQ_sub5_afterlink'</li>
                </ul>
            </div>
        </div>
    </div>
</div>'

# -> Section other:
echo '
<div class="accordion" id="Accordion-03">
    <div class="accordion-item border-start-0 border-end-0" style="border-style: dashed none dashed none; size: 1px;">
        <h2 class="accordion-header" id="Heading-03">
            <button class="accordion-button collapsed bg-white synocr-accordion-glow-off" type="button" data-bs-toggle="collapse" data-bs-target="#Collapse-03" aria-expanded="false" aria-controls="collapseTwo">
                <span class="synocr-text-blue">'$lang_help_about_title'</span>
            </button>
        </h2>
        <div id="Collapse-03" class="accordion-collapse collapse border-white" aria-labelledby="Heading-03" data-bs-parent="#Accordion-03">
            <div class="accordion-body">
                <p>
                    '$lang_help_about_1'<br />
                    '$lang_help_about_2'<br />
                    '$lang_help_about_3'<br />
                    <a href="https://www.paypal.me/geimist" onclick="window.open(this.href); return false;">
                        <img src="images/paypal.png" alt="PayPal" style="float:right;padding:10px" height="60" width="200"/>
                    </a><br />
                    '$lang_help_about_3'
                </p><br>
            </div>
        </div>
    </div>
</div>'
