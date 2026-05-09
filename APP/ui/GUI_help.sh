#!/bin/bash
# shellcheck disable=SC2154

#################################################################################
#   description:    - generates the help page for the GUI                       #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/help.sh            #
#   © 2026 by geimist                                                           #
#################################################################################

# Donation configuration from VERSION (remote):
donation_version_info=$(curl -s --connect-timeout 10 --max-time 20 "https://raw.githubusercontent.com/geimist/synOCR/master/VERSION")
# Prefer distribution.donation (plan); fall back to root-level .donation (current upstream VERSION shape)
donation_url=$(echo "${donation_version_info}" | jq -r '(.distribution.donation.url // .donation.url // empty)' 2>/dev/null)
donation_image_url=$(echo "${donation_version_info}" | jq -r '(.distribution.donation.imageUrl // .donation.imageUrl // empty)' 2>/dev/null)

if [ -n "${donation_image_url}" ]; then
    donation_visual='<img src="'"${donation_image_url}"'" alt="donation" style="float:left;padding:10px" height="60" width="200"/>'
else
    donation_visual='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="60" viewBox="0 0 200 60" role="img" aria-label="donation" style="float:left;padding:10px"><title>donation</title><rect x="0.5" y="0.5" width="199" height="59" rx="12" ry="12" fill="#f5a623" stroke="#d97706" stroke-width="1"/><text x="100" y="37" text-anchor="middle" font-family="system-ui,-apple-system,sans-serif" font-size="18" font-weight="600" fill="#1f2937">Donation</text></svg>'
fi
donation_block=""
if [ -n "${donation_url}" ]; then
    donation_block='
        '"${lang_help_about_3}"'<br />
        <a href="'"${donation_url}"'" onclick="window.open(this.href); return false;">
            '"${donation_visual}"'
        </a><br /><br /><br />'
fi

# -> Headline
echo '
<h2 class="synocr-text-blue mt-3">synOCR '"${lang_page4}"'</h2>
<p>&nbsp;</p>'

# -> Section configuration:
echo '
<div class="accordion" id="Accordion-01">
    <div class="accordion-item border-start-0 border-end-0" style="border-style: dashed none dashed none; size: 1px;">
        <h2 class="accordion-header" id="Heading-01">
            <button class="accordion-button collapsed bg-white synocr-accordion-glow-off" type="button" data-bs-toggle="collapse" data-bs-target="#Collapse-01" aria-expanded="false" aria-controls="collapseTwo">
                <span class="synocr-text-blue">'"${lang_help_title_QS}"'</span>
            </button>
        </h2>
        <div id="Collapse-01" class="accordion-collapse collapse border-white" aria-labelledby="Heading-01" data-bs-parent="#Accordion-01">
            <div class="accordion-body">
                <ol style="list-style:decimal">
                    <li>'"${lang_help_QS_1_beforelink}"' <a href="index.cgi?page=edit" style="'"${synocrred}"';">'"${lang_page2}"'</a> '"${lang_help_QS_1_afterlink}"'</li>
                    <li>'"${lang_help_QS_1b}"' <a href="https://synocommunity.com/package/inotify-tools" onclick="window.open(this.href); return false;" style="'"${synocrred}"';"><b>(DOWNLOAD Inotify-Tools)</b></a></li>
                    <li>'"${lang_help_QS_2}"'<br /><br />
                        <h6 class="synocr-text-blue">'"${lang_help_QS_sub1_tit}"'</h6>
                        <ul class="li_standard">
                            <li>'"${lang_help_QS_sub1_1}"'</li>
                            <li>'"${lang_button}"' <i>'"${lang_help_QS_sub1_2}"'</i></li>
                            <li><i>'"${lang_help_QS_sub1_3}"'</i></li>
                            <li><i>'"${lang_help_QS_sub1_4}"'</i></li>
                        </ul><br />
                        <h6 class="synocr-text-blue">'"${lang_tab}"' &quot;'"${lang_help_QS_sub2_tit}"'&quot;:</h6>
                        <ul class="li_standard">
                            <li>'"${lang_help_QS_sub2_1}"' <i>root</i></li>
                            <li>'"${lang_help_QS_sub2_2}"'</li>
                            <li>'"${lang_help_QS_sub2_3}"'</li>
                        </ul><br />
                        <h6 class="synocr-text-blue">'"${lang_tab}"' &quot;'"${lang_help_QS_sub3_tit}"'&quot;:</h6>
                        <ul class="li_standard">
                            <li>'"${lang_help_QS_sub3_1}"'</li>
                            <li>'"${lang_help_QS_sub3_2}"'</li>
                        </ul><br />
                        <h6 class="synocr-text-blue">'"${lang_tab}"' &quot;'"${lang_help_QS_sub4_tit}"'&quot;:</h6>
                        <ul class="li_standard">
                            <li>'"${lang_help_QS_sub4_1}"'</li><br />
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
                <span class="synocr-text-blue">'"${lang_help_title_FAQ}"'</span>
            </button>
        </h2>
        <div id="Collapse-02" class="accordion-collapse collapse border-white" aria-labelledby="Heading-02" data-bs-parent="#Accordion-02">
            <div class="accordion-body">

                <h6 class="synocr-text-blue">'"${lang_help_FAQ_sub1_tit}"'</h6>
                <ul>
                    <li>'"${lang_help_FAQ_sub1_1_beforelink}"' <a href="https://ocrmypdf.readthedocs.io" onclick="window.open(this.href); return false;" style="'"${synocrred}"';">'"${lang_help_FAQ_sub1_1_linktitle}"'</a>'"${lang_help_FAQ_sub1_1_afterlink}"'</li>
                </ul>
                <br />

                <h6 class="synocr-text-blue">'"${lang_help_FAQ_sub4_tit}"'</h6>
                <ul>
                    <li>'"${lang_help_FAQ_sub4_1}"'</li>
                    <li>'"${lang_help_FAQ_sub4_2}"'</li>
                </ul>
                <br />

                <h6 class="synocr-text-blue">'"${lang_help_FAQ_sub5_tit}"'</h6>
                <ul>
                    <li><a href="https://github.com/geimist/synOCR/wiki/04_FAQ-(de)" onclick="window.open(this.href); return false;" style="'"${synocrred}"';">synOCR Wiki</a></li>
                    <li>'"${lang_help_FAQ_sub5_beforelink}"' <a href="https://www.synology-forum.de/threads/synocr-gui-fuer-ocrmypdf.99647/" onclick="window.open(this.href); return false;" style="'"${synocrred}"';">'"${lang_help_FAQ_sub5_linktitle}"'</a>'"${lang_help_FAQ_sub5_afterlink}"'</li>
                </ul>
            </div>
        </div>
    </div>
</div>'

# -> Section other:
    echo '
    <p>&nbsp;</p>
    <h5 class="synocr-text-blue mt-3">'"${lang_help_about_title}"'</h5>
    <p>&nbsp;</p>
    <p>
        '"${lang_help_about_1}"'<br />
        '"${lang_help_about_2}"'<br />
        '"${donation_block}"'
    </p>
    <p>
        <hr>
        <p><b>
            '"${lang_help_about_4}"':</b>
            <ul>
                <li><a href="https://github.com/ocrmypdf/OCRmyPDF" onclick="window.open(this.href); return false;" style="'"${synocrred}"';">jbarlow83 [OCRmyPDF]</a></li>
                <li><a href="https://www.synology-forum.de/members/tommes.8120/" onclick="window.open(this.href); return false;" style="'"${synocrred}"';">Tommes</a> [GUI]</li>
                <li><a href="https://www.synology-forum.de/members/gthorsten.118999/" onclick="window.open(this.href); return false;" style="'"${synocrred}"';">Gthorsten</a> [Python scripts]</li>
                <li><a href="https://www.synology-forum.de/members/struppix.5780/" onclick="window.open(this.href); return false;" style="'"${synocrred}"';">Struppix</a> [Tutorials / YAML-Support]</li>
            </ul>
        </p>
    </p><br>'
