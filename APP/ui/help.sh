#!/bin/bash
# /usr/syno/synoman/webman/3rdparty/synOCR/help.sh

echo '
    <div id="Content_1Col">
    <div class="Content_1Col_full">
    <div class="title">synOCR '$lang_page4'</div>'

# Expandable:
    echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;">
    <br />
    <details><p>
    <summary>
        <span class="detailsitem">'$lang_help_title_QS'</span>
    </summary></p><p>' # from here is the text to be expanded and collapsed.

# -> Section configuration:
    echo '<ol style="list-style:decimal">
    <li>'$lang_help_QS_1_beforelink' <a href="index.cgi?page=edit" style="'$synocrred';">'$lang_page2'</a> '$lang_help_QS_1_afterlink'</li>
    <p><li>'$lang_help_QS_2'<div class="tab"><br>
    <h3>'$lang_help_QS_sub1_tit'</h3>
        <ul class="li_standard">
        <li>'$lang_help_QS_sub1_1'</li>
        <li>'$lang_help_QS_sub1_2'</li>
        <li><i>'$lang_help_QS_sub1_3'</i></li>
        <li><i>'$lang_help_QS_sub1_4'</i></li>
        </ul><br>
    <h3>'$lang_help_QS_sub2_tit'</h3>
        <ul class="li_standard">
        <li>'$lang_help_QS_sub2_1' <i>root</i></li>
        <li>'$lang_help_QS_sub2_2'</li>
        <li>'$lang_help_QS_sub2_3'</li>
        </ul><br>
    <h3>'$lang_help_QS_sub3_tit'</h3>
        <ul class="li_standard">
        <li>'$lang_help_QS_sub3_1'</li>
        </ul><br>
    <h3>'$lang_help_QS_sub4_tit'</h3>
        <ul class="li_standard">
        <li>'$lang_help_QS_sub4_1'</li><br>
        <code><span style="background-color:#cccccc;font-hight:1.1em;">/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh</span></code>
      </ul><br>
    </ol>'
    echo '</details></fieldset></p>'

# -> Section FAQ:
    echo '<fieldset><hr style="border-style: dashed; size: 1px;"><br /><details><p><summary><span class="detailsitem">'$lang_help_title_FAQ'</span></summary></p>'
        echo '<fieldset>
        <details><p><summary><span class="detailsitem">'$lang_help_FAQ_sub1_tit'</span></summary></p>
        <ul class="li_standard"><li>'
        echo $lang_help_FAQ_sub1_1_beforelink' <a href="https://ocrmypdf.readthedocs.io" onclick="window.open(this.href); return false;" style="'$synocrred';">'$lang_help_FAQ_sub1_1_linktitle'</a>'$lang_help_FAQ_sub1_1_afterlink
        echo '</li></ul>'
        echo '</details></fieldset>'
    # ->
        echo '<fieldset>
        <details><p><summary><span class="detailsitem">'$lang_help_FAQ_sub2_tit'</span></summary></p>
        <ul class="li_standard"><li>'$lang_help_FAQ_sub2_1'</li></ul>'
        echo '</details></fieldset>'
    # ->
        echo '<fieldset>
        <details><p><summary><span class="detailsitem">'$lang_help_FAQ_sub3_tit'</span></summary></p><ul class="li_standard">'
        echo '<li>'$lang_help_FAQ_sub3_1'</li><li>'$lang_help_FAQ_sub3_2'</li></ul>'
        echo '</details></fieldset>'
    # ->
        echo '<fieldset>
        <details><p><summary><span class="detailsitem">'$lang_help_FAQ_sub4_tit'</span></summary></p><ul class="li_standard">'
        echo '<li>'$lang_help_FAQ_sub4_1'</li><li>'$lang_help_FAQ_sub4_2'</li></ul>'
        echo '</details></fieldset>'
    # ->
        echo '<fieldset>
        <details><p><summary><span class="detailsitem">'$lang_help_FAQ_sub5_tit'</span></summary></p><ul class="li_standard">'
        echo '<li>'$lang_help_FAQ_sub5_beforelink' <a href="https://www.synology-forum.de/showthread.html?99647-synOCR-GUI-f%C3%BCr-OCRmyPDF" onclick="window.open(this.href); return false;" style="'$synocrred';">'$lang_help_FAQ_sub5_linktitle'</a>'$lang_help_FAQ_sub5_afterlink'</li></ul>'
        echo '</details></fieldset>'
    echo '</details></fieldset></p>'

# -> Section other:
echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;"><br />
    <details><p>
    <summary>
        <span class="detailsitem">'$lang_help_about_title'</span>
    </summary></p>
    <p>'

echo '<p>'$lang_help_about_1'<br>'$lang_help_about_2'<br><a href="https://www.paypal.me/geimist" onclick="window.open(this.href); return false;">
        <img src="images/paypal.png" alt="PayPal" style="float:right;padding:10px" height="60" width="200"/></a><br>'$lang_help_about_3'</p>'

    echo '</details><br><hr style="border-style: dashed; size: 1px;"></fieldset></p>'

echo '</div></div><div class="clear"></div>'
