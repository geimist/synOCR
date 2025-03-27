#!/bin/bash
# shellcheck disable=SC2154,SC2016,SC2034

#################################################################################
#   description:    - generates the configuration page for the GUI              #
#   path:            /usr/syno/synoman/webman/3rdparty/synOCR/edit.sh           #
#   © 2025 by geimist                                                           #
#################################################################################


dev_mode=false #true # false # show field in development ...
# if [ "$dev_mode" = "true" ]; then
# fi

APPDIR=$(cd "$(dirname "$0")" || exit 1;pwd)
cd "${APPDIR}" || exit 1
IFSsaved=IFS
dbPath="./etc/synOCR.sqlite"

new_profile ()
{
# In this function a new profile record is written to the DB
# Call: new_profile "profile name"
# --------------------------------------------------------------
    sqlite3 "${dbPath}" "INSERT INTO config ( profile ) VALUES ( '$1' )" >/dev/null
}


# Check DB (create if necessary / upgrade):
    DBupgradelog=$(./upgradeconfig.sh)

convert2YAML ()
{
# In this function the existing tag list is written to a YAML file
# --------------------------------------------------------------

if [ -f "${SAMPLECONFIGFILE}" ]; then
    echo "${SAMPLECONFIGFILE} already exists"
    return 1
fi

if [ -f "${taglist}" ]; then
    taglist=$( cat "${taglist}" )
else
    # BackUp of the database entry
    echo "➜ BackUp the database entry of the tag list"
    BackUp_taglist="${INPUTDIR%/}/_BackUp_taglist_[profile_$(echo "${profile}" | tr -dc "[a-z][A-Z][0-9] .-_")]_$(date +%s).txt"
    echo "${taglist}" > "${BackUp_taglist}"
    chmod 755 "${BackUp_taglist}"
fi

IFS=" " read -r -a tagarray <<< "$( echo "${taglist}" | sed -e "s/ /%20/g" | sed -e "s/;/ /g" )"; IFS="${IFSsaved}"

count=1

samplefilecontent="    ##############################################################################################################################
    #
    #                        ${lang_edit_yamlsample_02}
    #
    #   - ${lang_edit_yamlsample_03}
    #       - ${lang_edit_yamlsample_04}
    #       - ${lang_edit_yamlsample_05}
    #   - ${lang_edit_yamlsample_06}
    #   - ${lang_edit_yamlsample_07}
    #   - ${lang_edit_yamlsample_08} >synOCR_YAMLRULEFILE<
    #
    #   - ${lang_edit_yamlsample_09}
    #       > \"sampletagrulename\"
    #           - \"sampletagrulename\" ${lang_edit_yamlsample_10}
    #           - ${lang_edit_yamlsample_11}
    #           - ${lang_edit_yamlsample_12}
    #           - ${lang_edit_yamlsample_12b}
    #           - ${lang_edit_yamlsample_13}
    #           - ${lang_edit_yamlsample_14}
    #       > \"tagname:\"
    #           - ${lang_edit_yamlsample_15} >tagname: VALUE< (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_17}
    #           - ${lang_edit_yamlsample_17a}
    #           - ${lang_edit_yamlsample_18} (>tagname:<)
    #       > \"tagname_RegEx:\"
    #           - ${lang_edit_yamlsample_15} >tagname_RegEx: RegEx< (${lang_edit_yamlsample_16b})
    #           - ${lang_edit_yamlsample_17c}
    #           - ${lang_edit_yamlsample_17b}
    #           - ${lang_edit_yamlsample_18} (>tagname_RegEx:<)
    #       > \"tagname_multiline_RegEx:\"
    #           - ${lang_edit_yamlsample_15} >tagname_multiline_RegEx: VALUE<  (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_36} \"true\" / \"false\"
    #             ${lang_edit_yamlsample_39} (\"false\")
    #       > \"postscript:\"
    #           - ${lang_edit_yamlsample_15} >postscript: command or path< (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_43}
    #       > \"multilineregex:\"
    #           - ${lang_edit_yamlsample_15} >multilineregex: VALUE<  (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_36} \"true\" / \"false\"
    #             ${lang_edit_yamlsample_39} (\"false\")
    #       > \"targetfolder:\"
    #           - ${lang_edit_yamlsample_19}
    #           - ${lang_edit_yamlsample_15} >targetfolder: VALUE< (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_20}
    #           - ${lang_edit_yamlsample_21} (/volume1/...)
    #           - ${lang_edit_yamlsample_22a}
    #             ${lang_edit_yamlsample_22b}
    #           - ${lang_edit_yamlsample_18} (>targetfolder:<)
    #       > \"dirname_RegEx:\"
    #           - ${lang_edit_yamlsample_15} >dirname_RegEx: RegEx< (${lang_edit_yamlsample_16b})
    #           - ${lang_edit_yamlsample_17d} >§dirname_RegEx<
    #           - ${lang_edit_yamlsample_18} (>dirgname_RegEx:<)
    #       > \"dirname_multiline_RegEx:\"
    #           - ${lang_edit_yamlsample_15} >dirname_multiline_RegEx: VALUE<  (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_36} \"true\" / \"false\"
    #             ${lang_edit_yamlsample_39} (\"false\")
    #       > \"condition:\"
    #           - ${lang_edit_yamlsample_24}
    #           - ${lang_edit_yamlsample_15} >condition: VALUE<  (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_25} \"all\" / \"any\" / \"none\"
    #               - \"condition: all\"  > ${lang_edit_yamlsample_26}
    #               - \"condition: any\"  > ${lang_edit_yamlsample_27}
    #               - \"condition: none\" > ${lang_edit_yamlsample_28}
    #           - ${lang_edit_yamlsample_18} (>condition:<)
    #       > \"subrules:\"
    #           - ${lang_edit_yamlsample_29} (${lang_edit_yamlsample_30} \"subrules:\")
    #           - ${lang_edit_yamlsample_31}
    #           - ${lang_edit_yamlsample_32}
    #       > \"- searchstring:\"
    #           - ${lang_edit_yamlsample_15} >- searchstring: VALUE<
    #             ${lang_edit_yamlsample_33}
    #             ${lang_edit_yamlsample_16}
    #           - ${lang_edit_yamlsample_34}
    #           - ${lang_edit_yamlsample_35}
    #       > \"searchtyp:\"
    #           - ${lang_edit_yamlsample_15} >searchtyp: VALUE<  (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_36} \"contains\", \"does not contain\",             (${lang_edit_yamlsample_37})
    #                           \"is\", \"is not\"                              (${lang_edit_yamlsample_38})
    #                           \"starts with\", \"does not starts with\",
    #                           \"ends with\", \"does not ends with\",
    #             ${lang_edit_yamlsample_39}, (\"contains\")
    #       > \"isRegEx:\"
    #           - ${lang_edit_yamlsample_40}
    #           - ${lang_edit_yamlsample_15} >isRegEx: VALUE<  (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_36} \"true\" / \"false\"
    #             ${lang_edit_yamlsample_39} (\"false\")
    #       > \"source:\"
    #           - ${lang_edit_yamlsample_15} >source: VALUE<  (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_36} \"content\" / \"filename\"
    #             ${lang_edit_yamlsample_39} (\"content\")
    #       > \"casesensitive:\"
    #           - ${lang_edit_yamlsample_15} >casesensitive: VALUE<  (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_36} \"true\" / \"false\"
    #             ${lang_edit_yamlsample_39} (\"false\")
    #       > \"multilineregex:\"
    #           - ${lang_edit_yamlsample_15} >multilineregex: VALUE<  (${lang_edit_yamlsample_16})
    #           - ${lang_edit_yamlsample_36} \"true\" / \"false\"
    #             ${lang_edit_yamlsample_39} (\"false\")
    #
    #   - ${lang_edit_yamlsample_41}:
    #       https://codebeautify.org/yaml-validator
    #
    ##############################################################################################################################"

writesamplefile() {

echo "# synOCR_YAMLRULEFILE   # keep this line!
# ${lang_edit_yamlsample_01}:
# ${SAMPLECONFIGFILE}

" > "${SAMPLECONFIGFILE}"

# Help text with fixed width and closing #:
    echo "➜ write description"
    echo "${samplefilecontent}" | while read -r data; do
        # Correct counting:
        lenRAW=${#data}
        stringCLEAN=${data//[äöüßÄÜÖ]/}
        lenCLEAN=${#stringCLEAN}

        DIFF=$((lenRAW - lenCLEAN))
        DIFF=$((DIFF / 2))
        len=$((130 + DIFF))
        printf "    %-${len}s#\n" "${data}" >> "${SAMPLECONFIGFILE}"
    done

    sed -i '/^#/ s/ > / ➜ /g; /^#/ s/ - / • /g' "${SAMPLECONFIGFILE}"

echo "➜ write sample entry"
echo "

#sample:

#sampletagrulename1:
#    tagname: target_tag §tagname_RegEx
#    tagname_RegEx: \"HUK[[:digit:]]{2}\"
#    tagname_multiline_RegEx: false
#    targetfolder: \"/<path>/§dirname_RegEx\"
#    dirname_RegEx: \"HUK[[:digit:]]{2}\"
#    dirname_multiline_RegEx: false
#    multilineregex: false
#    postscript: 
#    apprise_call: 
#    apprise_attachment: 
#    notify_lang: 
#    condition: all
#    subrules:
#    - searchstring: foundme
#      searchtyp: contains
#      isRegEx: false
#      source: content
#      casesensitive: true
#      multilineregex: false
#    - searchstring: dontfoundme
#      searchtyp: is not
#      isRegEx: false
#      source: content
#      casesensitive: false
#      multilineregex: false

#-----------------------------------------------------------
# ${lang_edit_yamlsample_42}
#-----------------------------------------------------------
" >> "${SAMPLECONFIGFILE}"

}
writesamplefile

# convert / write the user config:
echo "➜ convert / write the userconfig"
for i in "${tagarray[@]}"; do

    if echo "${i}" | grep -q "=" ;then
        # for combination of tag and category
        if echo "${i}" | awk -F'=' '{print $1}' | grep -q "^§" ;then
            searchtyp=is
        else
            searchtyp=contains
        fi
        i="${i#§}"
        tagname=$(echo "${i}" | awk -F'=' '{print $1}' | sed -e "s/%20/ /g")
        targetfolder=$(echo "${i}" | awk -F'=' '{print $2}' | sed -e "s/%20/ /g")
     else
        if echo "${i}" | awk -F'=' '{print $1}' | grep -q "^§" ;then
            searchtyp=is
        else
            searchtyp=contains
        fi
        i="${i#§}"
        tagname="${i// /%20}"
    fi

# write YAML:
    # shellcheck disable=SC2129,SC2001
    echo "$(echo "${tagname}" | sed 's/[^0-9a-zA-Z#!§%&\._-]*//g')_${count}:" >> "${SAMPLECONFIGFILE}"
    echo "    tagname: ${tagname}" >> "${SAMPLECONFIGFILE}"
    echo "    targetfolder: ${targetfolder}" >> "${SAMPLECONFIGFILE}"
    echo "    postscript: " >> "${SAMPLECONFIGFILE}"
    echo "    multilineregex: false" >> "${SAMPLECONFIGFILE}"
    echo "    condition: any" >> "${SAMPLECONFIGFILE}"
    echo "    subrules:" >> "${SAMPLECONFIGFILE}"
    echo "    - searchstring: ${tagname}" >> "${SAMPLECONFIGFILE}"
    echo "      searchtyp: ${searchtyp}" >> "${SAMPLECONFIGFILE}"
    echo "      multilineregex: false" >> "${SAMPLECONFIGFILE}"
    echo "      isRegEx: false" >> "${SAMPLECONFIGFILE}"
    echo "      source: content" >> "${SAMPLECONFIGFILE}"
    echo "      casesensitive: false" >> "${SAMPLECONFIGFILE}"

    count=$((count + 1))
    echo "    - rule No. ${count}"
done
chmod 755 "${SAMPLECONFIGFILE}"

# Write path to new configfile in DB:
    echo "➜ Write path to the new configfile in DB"
    sSQLupdate="UPDATE config SET taglist='${SAMPLECONFIGFILE}' WHERE profile_ID='${profile_ID}' "
    sqlite3 "${dbPath}" "${sSQLupdate}"

    return 0
}

# --------------------------------------------------------------
# -> convert existing tag list to YAML file:
# --------------------------------------------------------------
if [[ "${page}" == "edit-convert2YAML" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'"${lang_popup_note}"'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>
                <div class="modal-body text-center">'

                    SAMPLECONFIGFILE="${INPUTDIR%/}/_TagConfig_[profile_$(echo "${profile}" | tr -dc "[a-z][A-Z][0-9] .-_")].txt"
                    SAMPLECONFIGLOGFILE="${SAMPLECONFIGFILE}_$(date +%s)_convert.log"

                    if [ "${loglevel}" = "2" ] ; then
                        convert2YAML > "${SAMPLECONFIGLOGFILE}"
                        chmod 755 "${SAMPLECONFIGLOGFILE}"
                    else
                        convert2YAML > /dev/null  2>&1
                    fi

                    if [ "$?" -eq 1 ]; then
                        echo '
                        <p class="text-danger">
                            '"${lang_edit_yamlsample_gui_01}"'<br />
                            '"${lang_edit_yamlsample_gui_02}"'<br /><br />
                            ('"${SAMPLECONFIGFILE}"')
                        </p>'
                    else
                        echo '
                        <p>
                            '"${lang_edit_yamlsample_gui_03}"'<br /><br />
                            ('"${SAMPLECONFIGFILE}"')
                        </p>'
                    fi

                    echo '
                </div>
                <div class="modal-footer bg-light">
                    <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_buttonnext}"'...</button>
                </div>
            </div>
        </div>
    </div>
    <script type="text/javascript">
        $(window).on("load", function() {
            $("#popup-validation").modal("show");
        });
    </script>'
fi

# --------------------------------------------------------------
# -> Delete current profile:
# --------------------------------------------------------------
if [[ "${page}" == "edit-del_profile-query" ]] || [[ "${page}" == "edit-del_profile" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'"${lang_popup_note}"'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>'

                if [[ "${page}" == "edit-del_profile-query" ]]; then
                    echo '
                    <div class="modal-body text-center">
                        <p>'"${lang_edit_delques_1}"' (<strong>'"${profile}"'</strong>) '"${lang_edit_delques_2}"'</p>
                    </div>
                    <div class="modal-footer bg-light">
                        <a href="index.cgi?page=edit-del_profile" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_yes}"'</a>&nbsp;&nbsp;&nbsp;
                        <a href="index.cgi?page=edit&value=" class="btn btn-secondary btn-sm">'"${lang_button_abort}"'</a>
                    </div>'

                elif [[ "${page}" == "edit-del_profile" ]]; then
                    sqlite3 "${dbPath}" "DELETE FROM config WHERE profile_ID='${profile_ID}';"

                    # make the first profile of the DB active next (otherwise a profile name with empty data would be displayed)
                    getprofile=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT profile_ID FROM config ORDER BY profile_ID ASC LIMIT 1" | awk -F'\t' '{print $1}')
                    # getprofile (write to $var without GUI):
                    encode_value="${getprofile}"
                    decode_value=$(urldecode "${encode_value}")
                    "${set_var}" "$var" "getprofile" "${decode_value}"
                    "${set_var}" "$var" "encode_getprofile" "${encode_value}"
                    sleep 0.1

                    echo '
                    <div class="modal-body text-center">'
                        if [ "$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT count(profile_ID) FROM config WHERE profile_ID='${profile_ID}' ")" = "0" ] ; then
                            echo '
                            <p>
                                '"${lang_edit_delfin1}"' <strong>'"${profile}"'</strong> '"${lang_edit_delfin2}"'
                            </p>'
                        else
                            echo '
                            <p class="text-danger">
                                '"${lang_edit_deler}"' (<strong>'"${profile}"'</strong>)!
                            </p>'
                        fi
                        echo '
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_buttonnext}"'...</button>
                    </div>'

                fi
                echo '
            </div>
        </div>
    </div>
    <script type="text/javascript">
        $(window).on("load", function() {
            $("#popup-validation").modal("show");
        });
    </script>'
fi

# --------------------------------------------------------------
# -> Duplicate profile:
# --------------------------------------------------------------
if [[ "${page}" == "edit-dup-profile-query" ]] || [[ "${page}" == "edit-dup-profile" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'"${lang_popup_note}"'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>'

                if [[ "${page}" == "edit-dup-profile-query" ]]; then
                    echo '
                    <div class="modal-body">
                        <p>'"${lang_edit_dup1}"'</p>
                        <div class="row mb-3">
                            <div class="col">
                                <label for="new_profile_value">'"${lang_edit_profname}"'</label>
                            </div>
                            <div class="col">'
                                if [ -n "${new_profile_value}" ]; then
                                    echo '<input type="text" name="new_profile_value" id="new_profile_value" class="form-control form-control-sm" value="'"${new_profile_value}"'" />'
                                else
                                    echo '<input type="text" name="new_profile_value" id="new_profile_value" class="form-control form-control-sm" value="" />'
                                fi
                                echo '
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit-dup-profile" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_edit_create}"'...</button>&nbsp;&nbsp;&nbsp;
                        <a href="index.cgi?page=edit&value=" class="btn btn-secondary btn-sm">'"${lang_button_abort}"'</a>
                    </div>'

                elif [[ "${page}" == "edit-dup-profile" ]]; then
                    echo '
                    <div class="modal-body text-center">'
                        if [ -n "${new_profile_value}" ] ; then
                            sSQL="SELECT count(profile_ID) FROM config WHERE profile='${new_profile_value}' "
                            if [ "$(sqlite3 "${dbPath}" "${sSQL}")" = 0 ] ; then
                                sqlite3 "${dbPath}" "INSERT INTO config 
                                    ( 
                                        profile, active, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix, documentSplitPattern, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, apprise_call, apprise_attachment, notify_lang, dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, filedate, tagsymbol, ignoredDate, backup_max, backup_max_type, search_nearest_date, date_search_method, clean_up_spaces, img2pdf, DateSearchMinYear, DateSearchMaxYear, splitpagehandling, blank_page_detection_switch, blank_page_detection_mainThreshold, blank_page_detection_widthCropping, blank_page_detection_hightCropping, blank_page_detection_interferenceMaxFilter, blank_page_detection_interferenceMinFilter, blank_page_detection_black_pixel_ratio, blank_page_detection_ignoreText, adjustColorBWthreshold, adjustColorDPI, adjustColorContrast, adjustColorSharpness
                                    ) 
                                        VALUES 
                                    ( 
                                        '${new_profile_value}', '${active}', '${INPUTDIR}', '${OUTPUTDIR}', '${BACKUPDIR}', '${LOGDIR}', '${LOGmax}', '${SearchPraefix}', '${delSearchPraefix}', '${documentSplitPattern}', '${taglist}', '${searchAll}', '${moveTaggedFiles}', '${NameSyntax}', '${ocropt//\'/\'\'}', '${dockercontainer}', '${apprise_call}', '${apprise_attachment}', '${notify_lang}', '${dsmtextnotify}', '${MessageTo}', '${dsmbeepnotify}', '${loglevel}', '${filedate}', '${tagsymbol}', '${ignoredDate}', '${backup_max}', '${backup_max_type}', '${search_nearest_date}', '${date_search_method}', '${clean_up_spaces}', '${img2pdf}', '${DateSearchMinYear}', '${DateSearchMaxYear}', '${splitpagehandling}', '${blank_page_detection_switch}', '${blank_page_detection_mainThreshold}', '${blank_page_detection_widthCropping}', '${blank_page_detection_hightCropping}', '${blank_page_detection_interferenceMaxFilter}', '${blank_page_detection_interferenceMinFilter}', '${blank_page_detection_black_pixel_ratio}', '${blank_page_detection_ignoreText}', '${adjustColorBWthreshold}', '${adjustColorDPI}', '${adjustColorContrast}', '${adjustColorSharpness}'
                                    )"

                                sSQL2="SELECT count(profile_ID) FROM config WHERE profile='${new_profile_value}' "

                                if [ "$(sqlite3 "${dbPath}" "${sSQL2}")" = "1" ] ; then
                                    echo '
                                    <p>
                                        '"${lang_edit_profname}"' <strong>'"${profile}"'</strong> '"${lang_edit_dup2}"' <strong>'"${new_profile_value}"'</strong> '"${lang_edit_dup3}"'.
                                    </p>'
                                    # profile ID (write to $var without GUI)
                                    getprofile=$(sqlite3 -separator $'\t' "${dbPath}" "SELECT profile_ID FROM config WHERE profile='${new_profile_value}'" | awk -F'\t' '{print $1}')
                                    "${set_var}" "${var}" "profile_ID" "$(urldecode "${getprofile}")"
                                    "${set_var}" "${var}" "encode_profile_ID" "${getprofile}"
                                    "${set_var}" "${var}" "getprofile" "${getprofile}"
                                else
                                    echo '
                                    <p class="text-danger">
                                        '"${lang_edit_dup4}"'
                                    </p>'
                                fi
                            else
                                echo '
                                <p class="text-danger">
                                    '"${lang_edit_dup4}"'<br />
                                    '"${lang_edit_dup5}"' <strong>'"${new_profile_value}"'</strong> '"${lang_edit_dup6}"'
                                </p>'
                            fi
                        else
                            echo '
                            <p class="text-warning">
                                '"${lang_edit_dup4}"'<br />
                                '"${lang_edit_dup7}"'
                            </p>'
                        fi
                        echo '
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_buttonnext}"'...</button>
                    </div>'
                fi
                echo '
            </div>
        </div>
    </div>
    <script type="text/javascript">
        $(window).on("load", function() {
            $("#popup-validation").modal("show");
        });
    </script>'
fi

# --------------------------------------------------------------
# -> create new profile:
# --------------------------------------------------------------
if [[ "${page}" == "edit-new_profile-query" ]] || [[ "${page}" == "edit-new_profile" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'"${lang_popup_note}"'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>'

                if [[ "${page}" == "edit-new_profile-query" ]]; then
                    echo '
                    <div class="modal-body">
                        <p>'"${lang_edit_new1}"'</p>
                        <div class="row mb-3">
                            <div class="col">
                                <label for="new_profile_value">'"${lang_edit_profname}"'</label>
                            </div>
                            <div class="col">'

                                if [ -n "${new_profile_value}" ]; then
                                    echo '<input type="text" name="new_profile_value" id="new_profile_value" class="form-control form-control-sm" value="'"${new_profile_value}"'" />'
                                else
                                    echo '<input type="text" name="new_profile_value" id="new_profile_value" class="form-control form-control-sm" value="" />'
                                fi
                                echo '
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit-new_profile" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_edit_create}"'...</button>&nbsp;&nbsp;&nbsp;
                        <a href="index.cgi?page=edit&value=" class="btn btn-secondary btn-sm">'"${lang_button_abort}"'</a>
                    </div>'
                elif [[ "${page}" == "edit-new_profile" ]]; then
                    echo '
                    <div class="modal-body text-center">'
                        if [ -n "${new_profile_value}" ] ; then
                            sSQL="SELECT count(profile_ID) FROM config WHERE profile='${new_profile_value}' "
                            if [ "$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "${sSQL}")" = 0 ] ; then
                                new_profile "${new_profile_value}"

                                if [ "$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "${sSQL}")" = 1 ] ; then
                                    echo '
                                    <p>
                                        '"${lang_edit_new2}"' <strong>'"${new_profile_value}"'</strong> '"${lang_edit_new3}"'.
                                    </p>'
                                    # profile ID (write to $var without GUI)
                                    getprofile=$(sqlite3 -separator $'\t' "${dbPath}" "SELECT profile_ID FROM config WHERE profile='${new_profile_value}'" | awk -F'\t' '{print $1}')
                                    "${set_var}" "${var}" "profile_ID" "$(urldecode "${getprofile}")"
                                    "${set_var}" "${var}" "encode_profile_ID" "${getprofile}"
                                    "${set_var}" "${var}" "getprofile" "${getprofile}"
                                else
                                    echo '
                                    <p class="text-danger">
                                        '"${lang_edit_new4}"'
                                    </p>'
                                fi
                            else
                                echo '
                                <p class="text-danger">
                                    '"${lang_edit_new4}"'<br />
                                    '"${lang_edit_dup5}"' <strong>'"${new_profile_value}"'</strong> '"${lang_edit_dup6}"'
                                </p>'
                            fi
                        else
                            echo '
                            <p class="text-danger">
                                '"${lang_edit_new4}"'<br />
                                '"${lang_edit_dup7}"'
                            </p>'
                        fi
                        echo '
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_buttonnext}"'...</button>
                    </div>'
                fi
                echo '
            </div>
        </div>
    </div>
    <script type="text/javascript">
        $(window).on("load", function() {
            $("#popup-validation").modal("show");
        });
    </script>'
fi

# --------------------------------------------------------------
# -> Write record to DB:
# --------------------------------------------------------------
if [[ "${page}" == "edit-save" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'"${lang_popup_note}"'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>
                <div class="modal-body text-center">'

                sqlite3 "${dbPath}" "
                            UPDATE 
                                config 
                            SET 
                                profile='${profile}', 
                                active='${active}', 
                                INPUTDIR='${INPUTDIR}', 
                                OUTPUTDIR='${OUTPUTDIR}', 
                                BACKUPDIR='${BACKUPDIR}',
                                LOGDIR='${LOGDIR}', 
                                LOGmax='${LOGmax}', 
                                SearchPraefix='${SearchPraefix}', 
                                delSearchPraefix='${delSearchPraefix}', 
                                taglist='${taglist}', 
                                searchAll='${searchAll}',
                                moveTaggedFiles='${moveTaggedFiles}', 
                                NameSyntax='${NameSyntax}', 
                                ocropt='${ocropt//\'/\'\'}',
                                dockercontainer='${dockercontainer}', 
                                apprise_call='${apprise_call}',
                                notify_lang='${notify_lang}',
                                dsmtextnotify='${dsmtextnotify}', 
                                MessageTo='${MessageTo}', 
                                dsmbeepnotify='${dsmbeepnotify}', 
                                loglevel='${loglevel}', 
                                filedate='${filedate}', 
                                tagsymbol='${tagsymbol}',
                                documentSplitPattern='${documentSplitPattern}', 
                                ignoredDate='${ignoredDate}', 
                                backup_max='${backup_max}', 
                                backup_max_type='${backup_max_type}',
                                search_nearest_date='${search_nearest_date}',
                                date_search_method='${date_search_method}',
                                clean_up_spaces='${clean_up_spaces}',
                                img2pdf='${img2pdf}',
                                DateSearchMinYear='${DateSearchMinYear}',
                                DateSearchMaxYear='${DateSearchMaxYear}',
                                splitpagehandling='${splitpagehandling}',
                                apprise_attachment='${apprise_attachment}',
                                blank_page_detection_switch='${blank_page_detection_switch}',
                                blank_page_detection_mainThreshold='${blank_page_detection_mainThreshold}',
                                blank_page_detection_widthCropping='${blank_page_detection_widthCropping}',
                                blank_page_detection_hightCropping='${blank_page_detection_hightCropping}',
                                blank_page_detection_interferenceMaxFilter='${blank_page_detection_interferenceMaxFilter}',
                                blank_page_detection_interferenceMinFilter='${blank_page_detection_interferenceMinFilter}',
                                blank_page_detection_black_pixel_ratio='${blank_page_detection_black_pixel_ratio}',
                                blank_page_detection_ignoreText='${blank_page_detection_ignoreText}',
                                adjustColorBWthreshold='${adjustColorBWthreshold}',
                                adjustColorDPI='${adjustColorDPI}',
                                adjustColorContrast='${adjustColorContrast}',
                                adjustColorSharpness='${adjustColorSharpness}'
                            WHERE 
                                profile_ID='${profile_ID}';"

                # write global change to table system:
                sqlite3 "${dbPath}" "
                            UPDATE 
                                system 
                            SET 
                                value_1='${dockerimageupdate}' 
                            WHERE 
                                key='dockerimageupdate';
                            UPDATE 
                                system 
                            SET 
                                value_1='${inotify_delay}' 
                            WHERE 
                                key='inotify_delay'; "

                    echo '
                    <p>
                        '"${lang_edit_savefin}"'
                    </p>
                </div>
                <div class="modal-footer bg-light">
                    <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_buttonnext}"'...</button>
                </div>
            </div>
        </div>
    </div>
    <script type="text/javascript">
        $(window).on("load", function() {
            $("#popup-validation").modal("show");
        });
    </script>'
fi


if [[ "${page}" == "edit" ]]; then

    # Read file contents for variable utilization
    if [ -z "${getprofile}" ] ; then
        sSQL="SELECT 
                profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix, taglist, searchAll, moveTaggedFiles, 
                NameSyntax, ocropt, dockercontainer, apprise_call, notify_lang, dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, active, filedate, tagsymbol, documentSplitPattern, 
                ignoredDate, backup_max, backup_max_type, search_nearest_date, date_search_method, clean_up_spaces, img2pdf, DateSearchMinYear, DateSearchMaxYear, splitpagehandling, 
                apprise_attachment, blank_page_detection_switch, blank_page_detection_mainThreshold, blank_page_detection_widthCropping, blank_page_detection_hightCropping, 
                blank_page_detection_interferenceMaxFilter, blank_page_detection_interferenceMinFilter, blank_page_detection_black_pixel_ratio, blank_page_detection_ignoreText, 
                adjustColorBWthreshold, adjustColorDPI, adjustColorContrast, adjustColorSharpness
            FROM 
                config 
            WHERE 
                profile_ID='1' "
    else
        sSQL="SELECT 
                profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix, taglist, searchAll, moveTaggedFiles, 
                NameSyntax, ocropt, dockercontainer, apprise_call, notify_lang, dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, active, filedate, tagsymbol, documentSplitPattern, 
                ignoredDate, backup_max, backup_max_type, search_nearest_date, date_search_method, clean_up_spaces, img2pdf, DateSearchMinYear, DateSearchMaxYear, splitpagehandling, 
                apprise_attachment, blank_page_detection_switch, blank_page_detection_mainThreshold, blank_page_detection_widthCropping, blank_page_detection_hightCropping, 
                blank_page_detection_interferenceMaxFilter, blank_page_detection_interferenceMinFilter, blank_page_detection_black_pixel_ratio, blank_page_detection_ignoreText, 
                adjustColorBWthreshold, adjustColorDPI, adjustColorContrast, adjustColorSharpness
            FROM 
                config 
            WHERE 
                profile_ID='${getprofile}' "
    fi

    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "${sSQL}")

    # Separate record fields:
        profile_ID=$(echo "${sqlerg}" | awk -F'\t' '{print $1}')
        profile=$(echo "${sqlerg}" | awk -F'\t' '{print $3}')
        INPUTDIR=$(echo "${sqlerg}" | awk -F'\t' '{print $4}')
        OUTPUTDIR=$(echo "${sqlerg}" | awk -F'\t' '{print $5}')
        BACKUPDIR=$(echo "${sqlerg}" | awk -F'\t' '{print $6}')
        LOGDIR=$(echo "${sqlerg}" | awk -F'\t' '{print $7}')
        LOGmax=$(echo "${sqlerg}" | awk -F'\t' '{print $8}')
        SearchPraefix=$(echo "${sqlerg}" | awk -F'\t' '{print $9}')
        delSearchPraefix=$(echo "${sqlerg}" | awk -F'\t' '{print $10}')
        taglist=$(echo "${sqlerg}" | awk -F'\t' '{print $11}')
        searchAll=$(echo "${sqlerg}" | awk -F'\t' '{print $12}')
        moveTaggedFiles=$(echo "${sqlerg}" | awk -F'\t' '{print $13}')
        NameSyntax=$(echo "${sqlerg}" | awk -F'\t' '{print $14}')
        ocropt=$(echo "${sqlerg}" | awk -F'\t' '{print $15}')
        dockercontainer=$(echo "${sqlerg}" | awk -F'\t' '{print $16}')
        apprise_call=$(echo "${sqlerg}" | awk -F'\t' '{print $17}')
        notify_lang=$(echo "${sqlerg}" | awk -F'\t' '{print $18}')
        dsmtextnotify=$(echo "${sqlerg}" | awk -F'\t' '{print $19}')
        MessageTo=$(echo "${sqlerg}" | awk -F'\t' '{print $20}')
        dsmbeepnotify=$(echo "${sqlerg}" | awk -F'\t' '{print $21}')
        loglevel=$(echo "${sqlerg}" | awk -F'\t' '{print $22}')
        active=$(echo "${sqlerg}" | awk -F'\t' '{print $23}')
        filedate=$(echo "${sqlerg}" | awk -F'\t' '{print $24}')
        tagsymbol=$(echo "${sqlerg}" | awk -F'\t' '{print $25}')
        documentSplitPattern=$(echo "${sqlerg}" | awk -F'\t' '{print $26}')
        ignoredDate=$(echo "${sqlerg}" | awk -F'\t' '{print $27}')
        backup_max=$(echo "${sqlerg}" | awk -F'\t' '{print $28}')
        backup_max_type=$(echo "${sqlerg}" | awk -F'\t' '{print $29}')
        search_nearest_date=$(echo "${sqlerg}" | awk -F'\t' '{print $30}')
        date_search_method=$(echo "${sqlerg}" | awk -F'\t' '{print $31}')
        clean_up_spaces=$(echo "${sqlerg}" | awk -F'\t' '{print $32}')
        img2pdf=$(echo "${sqlerg}" | awk -F'\t' '{print $33}')
        DateSearchMinYear=$(echo "${sqlerg}" | awk -F'\t' '{print $34}')
        DateSearchMaxYear=$(echo "${sqlerg}" | awk -F'\t' '{print $35}')
        splitpagehandling=$(echo "${sqlerg}" | awk -F'\t' '{print $36}')
        apprise_attachment=$(echo "${sqlerg}" | awk -F'\t' '{print $37}')
        blank_page_detection_switch=$(echo "${sqlerg}" | awk -F'\t' '{print $38}')
        blank_page_detection_mainThreshold=$(echo "${sqlerg}" | awk -F'\t' '{print $39}')
        blank_page_detection_widthCropping=$(echo "${sqlerg}" | awk -F'\t' '{print $40}')
        blank_page_detection_hightCropping=$(echo "${sqlerg}" | awk -F'\t' '{print $41}')
        blank_page_detection_interferenceMaxFilter=$(echo "${sqlerg}" | awk -F'\t' '{print $42}')
        blank_page_detection_interferenceMinFilter=$(echo "${sqlerg}" | awk -F'\t' '{print $43}')
        blank_page_detection_black_pixel_ratio=$(echo "${sqlerg}" | awk -F'\t' '{print $44}')
        blank_page_detection_ignoreText=$(echo "${sqlerg}" | awk -F'\t' '{print $45}')
        adjustColorBWthreshold=$(echo "${sqlerg}" | awk -F'\t' '{print $46}')
        adjustColorDPI=$(echo "${sqlerg}" | awk -F'\t' '{print $47}')
        adjustColorContrast=$(echo "${sqlerg}" | awk -F'\t' '{print $48}')
        adjustColorSharpness=$(echo "${sqlerg}" | awk -F'\t' '{print $49}')

    # read global values:
        inotify_delay=$(sqlite3 "${dbPath}" "SELECT value_1 FROM system WHERE key='inotify_delay' ")
        dockerimageupdate=$(sqlite3 "${dbPath}" "SELECT value_1 FROM system WHERE key='dockerimageupdate' ")

    # -> Headline
    echo '
    <h2 class="synocr-text-blue mt-3">synOCR '"${lang_page2}"'</h2>
    <p>&nbsp;</p>
    <p>'"${lang_edit_summary1}"'</p>
    <p>'"${lang_edit_summary2}"'</p>
    <p>'"${lang_edit_summary3}"'</p>
    <p>'"${lang_edit_summary4}"' ('"${lang_example}"' <code>/volume1/…</code>)</p>'

        if [ -n "${DBupgradelog}" ] ; then
            DBupgradelog=$(echo "${DBupgradelog}" | tr "\n" "@" | sed -e "s/@/<br>/g")
            if echo "${DBupgradelog}" | grep -q ERROR ; then
                message_color="color: #BD0010;"
            else
                message_color="color: green;"
            fi
            echo '<p style="'"${message_color}"';">'"${lang_edit_dbupdate}"': '"${DBupgradelog}"' </p>'
        fi

    # Profile selection:
    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT profile_ID, profile FROM config;" )

    echo '
    <p>&nbsp;</p>
    <div class="row mb-3">
        <div class="col-sm-5">
            <label for="getprofile" class="ms-4">'"${lang_edit_change_profile}"'</label>
        </div>
        <div class="col-sm-5">
            <select name="getprofile" id="getprofile" class="form-select form-select-sm" onchange="document.getElementById('"'"'loading'"'"').style.display='"'"'inline-block'"'"';this.form.submit()">
                '

                while read -r entry; do
                    profile_ID_DB=$(echo "${entry}" | awk -F'\t' '{print $1}')
                    profile_DB=$(echo "${entry}" | awk -F'\t' '{print $2}')

                    if [[ "${profile_ID}" == "${profile_ID_DB}" ]]; then
                        echo '<option value='"${profile_ID_DB}"' selected>'"${profile_DB}"'</option>'
                    else
                        echo '<option value='"${profile_ID_DB}"'>'"${profile_DB}"'</option>'
                    fi
                done <<< "${sqlerg}"

                echo '
            </select>
            <input type="hidden" name="page" value="edit" />
        </div>
        <div class="col-sm-2">
            <div class="float-end">
                <img src="./images/status_loading.gif" id="loading" style="display: none;">
            </div>
        </div>
    </div><br />'


    # --------------------------------------------------------------
    # -> General section
    # --------------------------------------------------------------
    echo '
    <div class="accordion" id="Accordion-01">
        <div class="accordion-item border-start-0 border-end-0" style="border-style: dashed none dashed none; size: 1px;">
            <h2 class="accordion-header" id="Heading-01">
                <button class="accordion-button collapsed bg-white synocr-accordion-glow-off" type="button" data-bs-toggle="collapse" data-bs-target="#Collapse-01" aria-expanded="false" aria-controls="collapseTwo">
                    <span class="synocr-text-blue">'"${lang_edit_set1_title}"'</span>
                </button>
            </h2>
            <div id="Collapse-01" class="accordion-collapse collapse border-white" aria-labelledby="Heading-01" data-bs-parent="#Accordion-01">
                <div class="accordion-body">'

                    # Profil name
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="profile">'"${lang_edit_profname}"'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "${profile}" ]; then
                                echo '<input type="text" name="profile" id="profile" class="form-control form-control-sm" value="'"${profile}"'" />'
                            else
                                echo '<input type="text" name="profile" id="profile" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#profile-info" role="button" aria-expanded="false" aria-controls="profile-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="profile-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set1_profilename_help}"' ('"${lang_example}"' Shop, John)
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # Profile activated?
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="active">'"${lang_edit_set1_profile_activ_title}"'</label>
                        </div>

                        <div class="col-sm-5">
                            <div class="form-check form-switch">
                                <input type="hidden" name="active" value="0">
                                <input class="form-check-input" type="checkbox" role="switch" id="active" 
                                    name="active" value="1"'; \
                                    [[ "${active}" == "1" ]] && echo -n ' checked'; \
                                    echo '>
                            </div>
                        </div>

                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#active-info" role="button" aria-expanded="false" aria-controls="active-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="active-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set1_profile_activ_help1}"'<br />
                                        '"${lang_edit_set1_profile_activ_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'
                    # profile ID (write to $var without GUI)
                    "${set_var}" "${var}" "profile_ID" "$(urldecode "${profile_ID}")"
                    "${set_var}" "${var}" "encode_profile_ID" "${profile_ID}"

                    # SOURCEDIR
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="INPUTDIR">'"${lang_edit_set1_sourcedir_title}"'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "${INPUTDIR}" ]; then
                                echo '<input type="text" name="INPUTDIR" id="INPUTDIR" class="form-control form-control-sm" value="'"${INPUTDIR}"'" />'
                            else
                                echo '<input type="text" name="INPUTDIR" id="INPUTDIR" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "${INPUTDIR}" ]; then
                                    echo '<img src="images/status_green@geimist.svg" height="18" width="18" class="me-3"/>'
                                else
                                    echo '<img src="images/status_error@geimist.svg" height="18" width="18" class="me-3"/>'
                                fi
                                echo '

                                <a data-bs-toggle="collapse" href="#INPUTDIR-info" role="button" aria-expanded="false" aria-controls="INPUTDIR-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="INPUTDIR-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set1_sourcedir_help1}"'<br />
                                        '"${lang_edit_set1_sourcedir_help2}"' ('"${lang_example}"' /volume1/homes/username/scan/input/)
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # OUTPUTDIR
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="OUTPUTDIR">'"${lang_edit_set1_targetdir_title}"'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "${OUTPUTDIR}" ]; then
                                echo '<input type="text" name="OUTPUTDIR" id="OUTPUTDIR" class="form-control form-control-sm" value="'"${OUTPUTDIR}"'" />'
                            else
                                echo '<input type="text" name="OUTPUTDIR" id="OUTPUTDIR" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "${OUTPUTDIR}" ]; then
                                    echo '<img src="images/status_green@geimist.svg" height="18" width="18" class="me-3"/>'
                                else
                                    echo '<img src="images/status_error@geimist.svg" height="18" width="18" class="me-3"/>'
                                fi
                                echo '

                                <a data-bs-toggle="collapse" href="#OUTPUTDIR-info" role="button" aria-expanded="false" aria-controls="OUTPUTDIR-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="OUTPUTDIR-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set1_targetdir_help1}"'<br />
                                        '"${lang_edit_set1_targetdir_help2}"' ('"${lang_example}"' /volume1/homes/username/scan/output/)
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # BACKUPDIR
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="BACKUPDIR">'"${lang_edit_set1_backupdir_title}"'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "${BACKUPDIR}" ]; then
                                echo '<input type="text" name="BACKUPDIR" id="BACKUPDIR" class="form-control form-control-sm" value="'"${BACKUPDIR}"'" />'
                            else
                                echo '<input type="text" name="BACKUPDIR" id="BACKUPDIR" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "${BACKUPDIR}" ]; then
                                    echo '<img src="images/status_green@geimist.svg" height="18" width="18" class="me-3"/>'
                                else
                                    echo '<img src="images/status_error@geimist.svg" height="18" width="18" class="me-3"/>'
                                fi
                                echo '

                                <a data-bs-toggle="collapse" href="#BACKUPDIR-info" role="button" aria-expanded="false" aria-controls="BACKUPDIR-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="BACKUPDIR-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set1_backupdir_help1}"'<br />
                                        '"${lang_edit_set1_backupdir_help2}"'<br />
                                        '"${lang_edit_set1_backupdir_help3}"' ('"${lang_example}"' /volume1/homes/username/scan/backup/)
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # LOGDIR
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="LOGDIR">'"${lang_edit_set1_logdir_title}"'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "${LOGDIR}" ]; then
                                echo '<input type="text" name="LOGDIR" id="LOGDIR" class="form-control form-control-sm" value="'"${LOGDIR}"'" />'
                            else
                                echo '<input type="text" name="LOGDIR" id="LOGDIR" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "${LOGDIR}" ]; then
                                    echo '<img src="images/status_green@geimist.svg" height="18" width="18" class="me-3"/>'
                                else
                                    echo '<img src="images/status_error@geimist.svg" height="18" width="18" class="me-3"/>'
                                fi
                                echo '

                                <a data-bs-toggle="collapse" href="#LOGDIR-info" role="button" aria-expanded="false" aria-controls="LOGDIR-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="LOGDIR-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set1_logdir_help1}"'<br />
                                        '"${lang_edit_set1_logdir_help2}"' ('"${lang_example}"' /volume1/homes/username/scan/log/)
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    echo '
                </div>
            </div>
        </div>
    </div>'

    # --------------------------------------------------------------
    # -> OCR section
    # --------------------------------------------------------------
    echo '
    <div class="accordion" id="Accordion-02">
        <div class="accordion-item border-start-0 border-end-0" style="border-style: dashed none dashed none; size: 1px;">
            <h2 class="accordion-header" id="Heading-02">
                <button class="accordion-button collapsed bg-white synocr-accordion-glow-off" type="button" data-bs-toggle="collapse" data-bs-target="#Collapse-02" aria-expanded="false" aria-controls="collapseTwo">
                    <span class="synocr-text-blue">'"${lang_edit_set2_title}"'</span>
                </button>
            </h2>
            <div id="Collapse-02" class="accordion-collapse collapse border-white" aria-labelledby="Heading-02" data-bs-parent="#Accordion-02">
                <div class="accordion-body">'

                    # ocropt
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="ocropt">'"${lang_edit_set2_ocropt_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <code>'
                            if [ -n "${ocropt}" ]; then
                                echo '<input type="text" name="ocropt" id="ocropt" class="form-control form-control-sm" value="'"${ocropt}"'" />'
                            else
                                echo '<input type="text" name="ocropt" id="ocropt" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
                            </code>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#ocropt-info" role="button" aria-expanded="false" aria-controls="ocropt-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="ocropt-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_ocropt_help1}"'<br /><br />
                                        <code>-l</code>&nbsp;&nbsp;'"${lang_edit_set2_ocropt_help5}"' (deu, eng, deu+eng, ...)<br />
                                        <code>-s</code>&nbsp;&nbsp;'"${lang_edit_set2_ocropt_help2}"'<br />
                                        <code>-f</code>&nbsp;&nbsp;'"${lang_edit_set2_ocropt_help3}"'<br />
                                        <code>-r</code>&nbsp;&nbsp;'"${lang_edit_set2_ocropt_help4}"'<br />
                                        <code>-d</code>&nbsp;&nbsp;'"${lang_edit_set2_ocropt_help6}"'<br /><br />
                                        <code>--keep_hash</code>&nbsp;&nbsp;'"${lang_edit_set2_ocropt_help8}"'<br />
                                        '"${lang_edit_set2_ocropt_help9}"'<br />
                                        <br /><a href="https://ocrmypdf.readthedocs.io/en/latest/cookbook.html" onclick="window.open(this.href); return false;" style="color: #BD0010;">'"${lang_edit_set2_ocropt_help7}"'</a><br />
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # docker container
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="dockercontainer">'"${lang_edit_set2_dockerimage_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="dockercontainer" id="dockercontainer" class="form-select form-select-sm">'

                                # local ocrmypdf images:
                                IFS=$'\n' read -r -d '' -a imagelist < <(docker images | sort | awk '/ocrmypdf/ && !/<none>/ {print $1 ":" $2}' && printf '\0'); IFS=$IFSsaved

                                # check for default images and add if necessary:
                                if ! echo "${imagelist[@]}" | grep -q "jbarlow83/ocrmypdf:latest" ; then
                                    imagelist+=("jbarlow83/ocrmypdf:latest")
                                fi
                                if ! echo "${imagelist[@]}" | grep -q "jbarlow83/ocrmypdf:v12.7.2" ; then
                                    imagelist+=("jbarlow83/ocrmypdf:v12.7.2")
                                fi
                                if ! echo "${imagelist[@]}" | grep -q "geimist/ocrmypdf-polyglot:latest" ; then
                                    imagelist+=("geimist/ocrmypdf-polyglot:latest")
                                fi

                                for entry in "${imagelist[@]}"; do
                                    if [[ "${dockercontainer}" == "${entry}" ]]; then
                                        echo "<option value=${entry} selected>${entry}</option>"
                                    else
                                        echo "<option value=${entry}>${entry}</option>"
                                    fi
                                done

                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#dockercontainer-info" role="button" aria-expanded="false" aria-controls="dockercontainer-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="dockercontainer-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_dockerimage_help1}"'<br />
                                        jbarlow83/ocrmypdf '"${lang_edit_set2_dockerimage_help2}"' chi_sim,deu,eng,fra,osd,por,spa.<br />
                                        '"${lang_edit_set2_dockerimage_help3}"'<br />
                                        '"${lang_edit_set2_dockerimage_help4}"'&quot;ocrmypdf&quot;
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # update docker image?:
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="dockerimageupdate">'"${lang_edit_set2_dockerimageupdate_title}"'</label>
                        </div>

                        <div class="col-sm-5">
                            <div class="form-check form-switch">
                                <input type="hidden" name="dockerimageupdate" value="0">
                                <input class="form-check-input" type="checkbox" role="switch" id="dockerimageupdate" 
                                    name="dockerimageupdate" value="1"'; \
                                    [[ "${dockerimageupdate}" == "1" ]] && echo -n ' checked'; \
                                    echo '>
                            </div>
                        </div>

                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#dockerimageupdate-info" role="button" aria-expanded="false" aria-controls="dockerimageupdate-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="dockerimageupdate-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_dockerimageupdate_help1}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # inotify_delay
                    inotify_delay_current_value="${inotify_delay:-0}" # Determine the current value or set default to 0
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="inotify_delay">'"${lang_edit_set2_inotify_delay_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" class="form-range" min="0" max="120" name="inotify_delay" id="inotify_delay" value="'"${inotify_delay_current_value}"'" oninput="document.getElementById('\''inotify_delay_value'\'').textContent = this.value" />
                                <div class="mt-1">
                                    <span id="inotify_delay_value" class="badge bg-primary">'"${inotify_delay_current_value}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#inotify_delay-info" role="button" aria-expanded="false" aria-controls="inotify_delay-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="inotify_delay-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_inotify_delay_help1}"'<br /><br />
                                        '"${lang_edit_set2_inotify_delay_help2}"'<br />
                                        '"${lang_edit_set2_inotify_delay_help3}"'<br /><br />
                                        '"${lang_edit_set2_inotify_delay_help4}"'<br />
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    echo '<hr><br>'

                    echo '
                    <div class="row mb-3">
                        <span class="synocr-text-blue">'"${lang_edit_set2_adjustColor_title}"'</span>
                            <p>'"${lang_edit_set2_adjustColor_desc}"'</p><br />
                    </div>'

                    # adjustColorBWthreshold
                    adjustColorBWthreshold_current_value="${adjustColorBWthreshold:-0}" # Aktuellen Wert ermitteln oder Standard 127 setzen
                    # Angezeigten Text bestimmen (off oder Zahl)
                    if [ "$adjustColorBWthreshold_current_value" -eq 0 ]; then
                        adjustColorBWthreshold_display="${lang_deactivated}"
                    else
                        adjustColorBWthreshold_display="$adjustColorBWthreshold_current_value"
                    fi
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="adjustColorBWthreshold">'"${lang_edit_set2_adjustColorBWthreshold_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" class="form-range" min="0" max="255" name="adjustColorBWthreshold" id="adjustColorBWthreshold" value="'"${adjustColorBWthreshold_current_value}"'" oninput="document.getElementById('\''adjustColorBWthreshold_value'\'').textContent = this.value == 0 ? '\'"${lang_deactivated}"\'' : this.value" />
                                <div class="mt-1">
                                    <span id="adjustColorBWthreshold_value" class="badge bg-primary">'"${adjustColorBWthreshold_display}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#adjustColorBWthreshold-info" role="button" aria-expanded="false" aria-controls="adjustColorBWthreshold-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="adjustColorBWthreshold-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_adjustColorBWthreshold_help1}"'<br />
                                        '"${lang_edit_set2_adjustColorBWthreshold_help2}"'<br />
                                        '"${lang_edit_set2_adjustColorBWthreshold_help3}"'<br />
                                        '"${lang_edit_set2_adjustColorBWthreshold_help4}"'&nbsp;<code>40</code><br /><br />
                                        <code>'"${lang_deactivated}"'&nbsp;</code>'"➜ ${lang_edit_set2_adjustColorBWthreshold_help5}"'<br />
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # adjustColorDPI
                    predefined_values="0 72 75 100 150 200 300 400 450 600"
                    adjustColorDPI_current_value="${adjustColorDPI:-0}"

                    # Validierung: Falls Wert nicht in der Liste, auf 0 setzen
                    if ! echo "$predefined_values" | grep -qw "$adjustColorDPI_current_value"; then
                        adjustColorDPI_current_value=0
                    fi

                    # Anzeigetext vorbereiten
                    if [ "$adjustColorDPI_current_value" -eq 0 ]; then
                        adjustColorDPI_display="${lang_deactivated}"
                    else
                        adjustColorDPI_display="$adjustColorDPI_current_value"
                    fi

                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="adjustColorDPI">'"${lang_edit_set2_adjustColorDPI_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" 
                                       class="form-range" 
                                       min="0" 
                                       max="600" 
                                       name="adjustColorDPI" 
                                       id="adjustColorDPI" 
                                       value="'"${adjustColorDPI_current_value}"'" 
                                       list="adjustColorDPI_marks"
                                       oninput="updateDPIValue(this.value)" />
                                <datalist id="adjustColorDPI_marks">
                                    <option value="0"></option>
                                    <option value="72"></option>
                                    <option value="75"></option>
                                    <option value="100"></option>
                                    <option value="150"></option>
                                    <option value="200"></option>
                                    <option value="300"></option>
                                    <option value="400"></option>
                                    <option value="450"></option>
                                    <option value="600"></option>
                                </datalist>
                                <div class="mt-1">
                                    <span id="adjustColorDPI_value" class="badge bg-primary">'"${adjustColorDPI_display}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#adjustColorDPI-info" role="button" aria-expanded="false" aria-controls="adjustColorDPI-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="adjustColorDPI-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_adjustColorDPI_help1}"'<br />
                                        '"${lang_edit_set2_adjustColorDPI_help2}"'<br />
                                        '"${lang_edit_set2_adjustColorDPI_help3}"'<br /><br />
                                        <code>'"${lang_deactivated}"'&nbsp;</code>'"➜ ${lang_edit_set2_adjustColorDPI_help4}"'<br />
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>
                    <script>
                    function updateDPIValue(val) {
                        const allowedValues = [0, 72, 75, 100, 150, 200, 300, 400, 450, 600];
                        const closest = allowedValues.reduce((prev, curr) => 
                            Math.abs(curr - val) < Math.abs(prev - val) ? curr : prev
                        );
                        document.getElementById("adjustColorDPI").value = closest;
                        document.getElementById("adjustColorDPI_value").textContent = 
                            closest === 0 ? "'"${lang_deactivated}"'" : closest;
                    }
                    </script>'

                    # adjustColorContrast
                    adjustColorContrast_current_value="${adjustColorContrast:-1.0}"
                    
                    # Shell-Vergleich mit Float-Werten
                    if awk -v val="$adjustColorContrast_current_value" 'BEGIN { exit (val != 1.0) }'; then
                        adjustColorContrast_display="${lang_deactivated}"
                    else
                        adjustColorContrast_display="$adjustColorContrast_current_value"
                    fi

                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="adjustColorContrast">'"${lang_edit_set2_adjustColorContrast_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" 
                                       class="form-range" 
                                       min="1.0" 
                                       max="10.0" 
                                       step="0.1" 
                                       name="adjustColorContrast" 
                                       id="adjustColorContrast" 
                                       value="'"${adjustColorContrast_current_value}"'" 
                                       oninput="document.getElementById('\''adjustColorContrast_value'\'').textContent = parseFloat(this.value).toFixed(1) === '\''1.0'\'' ? '\'"${lang_deactivated}"\'' : parseFloat(this.value).toFixed(1)" />
                                <div class="mt-1">
                                    <span id="adjustColorContrast_value" class="badge bg-primary">'"${adjustColorContrast_display}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#adjustColorContrast-info" role="button" aria-expanded="false" aria-controls="adjustColorContrast-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="adjustColorContrast-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_adjustColorContrast_help1}"'<br />
                                        <code>'"${lang_deactivated}"'&nbsp;</code>'"➜ ${lang_edit_set2_adjustColorContrast_help2}"'<br />
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # adjustColorSharpness
                    adjustColorSharpness_current_value="${adjustColorSharpness:-1.0}"
                    
                    # Shell-Vergleich mit Float-Werten
                    if awk -v val="$adjustColorSharpness_current_value" 'BEGIN { exit (val != 1.0) }'; then
                        adjustColorSharpness_display="${lang_deactivated}"
                    else
                        adjustColorSharpness_display="$adjustColorSharpness_current_value"
                    fi

                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="adjustColorSharpness">'"${lang_edit_set2_adjustColorSharpness_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" 
                                       class="form-range" 
                                       min="1.0" 
                                       max="20.0" 
                                       step="0.5" 
                                       name="adjustColorSharpness" 
                                       id="adjustColorSharpness" 
                                       value="'"${adjustColorSharpness_current_value}"'" 
                                       oninput="document.getElementById('\''adjustColorSharpness_value'\'').textContent = parseFloat(this.value).toFixed(1) === '\''1.0'\'' ? '\'"${lang_deactivated}"\'' : parseFloat(this.value).toFixed(1)" />
                                <div class="mt-1">
                                    <span id="adjustColorSharpness_value" class="badge bg-primary">'"${adjustColorSharpness_display}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#adjustColorSharpness-info" role="button" aria-expanded="false" aria-controls="adjustColorSharpness-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="adjustColorSharpness-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_adjustColorSharpness_help1}"'<br />
                                        <code>'"${lang_deactivated}"'&nbsp;</code>'"➜ ${lang_edit_set2_adjustColorSharpness_help2}"'<br />
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'


                    echo '<hr><br>'

                    # convert images to pdf?:
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="img2pdf">'"${lang_edit_set2_img2pdf_title}"'</label>
                        </div>

                        <div class="col-sm-5">
                            <div class="form-check form-switch">
                                <input type="hidden" name="img2pdf" value="false">
                                <input class="form-check-input" type="checkbox" role="switch" id="img2pdf" 
                                    name="img2pdf" value="true"'; \
                                    [[ "${img2pdf}" == "true" ]] && echo -n ' checked'; \
                                    echo '>
                            </div>
                        </div>

                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#img2pdf-info" role="button" aria-expanded="false" aria-controls="img2pdf-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="img2pdf-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_img2pdf_help1}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    echo '<hr><br>'

                    # SearchPraefix
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="SearchPraefix">'"${lang_edit_set2_searchpref_title}"'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "${SearchPraefix}" ]; then
                                echo '<input type="text" name="SearchPraefix" id="SearchPraefix" class="form-control form-control-sm" value="'"${SearchPraefix}"'" />'
                            else
                                echo '<input type="text" name="SearchPraefix" id="SearchPraefix" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#SearchPraefix-info" role="button" aria-expanded="false" aria-controls="SearchPraefix-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="SearchPraefix-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_searchpref_help1}"'  ('"${lang_example}"' &quot;SCAN_&quot;)<br />
                                        '"${lang_edit_set2_searchpref_help2}"'<br />
                                        <code>!</code> '"${lang_edit_set2_searchpref_help3}"' ( <code>!value</code> )<br />
                                        <code>$</code> '"${lang_edit_set2_searchpref_help4}"' ( <code>value$</code> )
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # delSearchPraefix
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="delSearchPraefix">'"${lang_edit_set2_delsearchpref_title}"'</label>
                        </div>
                        
                        <div class="col-sm-5">
                            <input class="form-check-input" type="radio" id="delSearchPraefix-yes" name="delSearchPraefix" value='; \
                                [[ "${delSearchPraefix}" == "yes" ]] && echo -n '"yes" checked />' || echo -n '"yes" />'
                            echo '<label for="delSearchPraefix-yes" class="form-check-label ps-2 pe-4">'"${lang_edit_set2_delsearchpref_delete}"'</label>'
                            echo -n '
                            <input class="form-check-input" type="radio" id="delSearchPraefix-no" name="delSearchPraefix" value='; \
                                [[ "${delSearchPraefix}" == "no" ]] && echo -n '"no" checked />' || echo -n '"no" />'
                            echo '<label for="delSearchPraefix-no" class="form-check-label ps-2">'"${lang_edit_set2_delsearchpref_keep}"'</label>
                        </div>
                        
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#delSearchPraefix-info" role="button" aria-expanded="false" aria-controls="delSearchPraefix-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="delSearchPraefix-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_delsearchpref_help1}"'<br />
                                        '"${lang_edit_set2_delsearchpref_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # Document split pattern
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="documentSplitPattern">'"${lang_edit_set2_documentSplitPattern_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <select id="splitPatternSelect" class="form-select form-select-sm" onchange="handleSplitPatternChange(this)">'

                                if [[ "${documentSplitPattern}" == "<split each page>" ]]; then
                                    echo '<option value="default" selected>'"${lang_edit_set2_documentSplitPattern_eachPage}"'</option>'
                                else
                                    echo '<option value="default">'"${lang_edit_set2_documentSplitPattern_eachPage}"'</option>'
                                fi

                                if [[ "${documentSplitPattern}" != "<split each page>" ]]; then
                                    echo '<option value="custom" selected>'"${lang_edit_set2_documentSplitPattern_userDefined}"'</option>'
                                else
                                    echo '<option value="custom">'"${lang_edit_set2_documentSplitPattern_userDefined}"'</option>'
                                fi

                                echo '
                            </select>'

                            if [[ "${documentSplitPattern}" != "<split each page>" ]]; then
                                echo '<input type="text" name="documentSplitPattern" id="customSplitPattern" 
                                      class="form-control form-control-sm mt-2" 
                                      value="'"${documentSplitPattern}"'" />'
                            else
                                echo '<input type="hidden" name="documentSplitPattern" value="<split each page>" id="defaultSplitPattern" />
                                <input type="text" id="customSplitPattern" 
                                      class="form-control form-control-sm mt-2" 
                                      style="display:none;" />'
                            fi

                            echo '
                            <script>
                            function handleSplitPatternChange(selectElement) {
                                var customInput = document.getElementById("customSplitPattern");
                                var hiddenInput = document.getElementById("defaultSplitPattern") || document.createElement("input");
                                var splitPageHandlingBlock = document.getElementById("splitPageHandlingBlock");
                                
                                if (!hiddenInput.id) {
                                    hiddenInput.type = "hidden";
                                    hiddenInput.id = "defaultSplitPattern";
                                    hiddenInput.value = "<split each page>";
                                    selectElement.parentNode.appendChild(hiddenInput);
                                }
                                
                                if (selectElement.value === "custom") {
                                    customInput.style.display = "block";
                                    if (splitPageHandlingBlock) splitPageHandlingBlock.style.display = "block";
                                    customInput.focus();
                                    customInput.name = "documentSplitPattern";
                                    hiddenInput.name = "";
                                } else {
                                    customInput.style.display = "none";
                                    if (splitPageHandlingBlock) splitPageHandlingBlock.style.display = "none";
                                    customInput.value = "";
                                    customInput.name = "";
                                    hiddenInput.name = "documentSplitPattern";
                                }
                            }
                            </script>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#documentSplitPattern-info" role="button" aria-expanded="false" aria-controls="documentSplitPattern-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="documentSplitPattern-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        <b>'"${lang_edit_set2_documentSplitPattern_userDefined}"':</b><br>
                                        '"${lang_edit_set2_documentSplitPattern_help1}"'<br><br>
                                        <b>'"${lang_edit_set2_documentSplitPattern_eachPage}"':</b><br>
                                        '"${lang_edit_set2_documentSplitPattern_help2}"'<br><br>
                                         '"${lang_edit_set2_documentSplitPattern_help3}" '<a href="https://geimist.eu/synOCR/SYNOCR_SEPARATOR_SHEET.pdf.html" onclick="window.open(this.href); return false;" style="color: #BD0010;"><b>(DOWNLOAD)</b></a>
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # splitpagehandling
                    echo '
                    <div id="splitPageHandlingBlock" style="display: '

                    if [[ "${documentSplitPattern}" != "<split each page>" ]]; then
                        echo 'block'
                    else
                        echo 'none'
                    fi

                    echo '">
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="splitpagehandling">'"${lang_edit_set2_splitpagehandling_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="splitpagehandling" id="splitpagehandling" class="form-select form-select-sm">'
                    
                                if [[ "${splitpagehandling}" == "discard" ]]; then
                                    echo '<option value="discard" selected>'"${lang_edit_set2_splitpagehandling_discard}"'</option>'
                                else
                                    echo '<option value="discard">'"${lang_edit_set2_splitpagehandling_discard}"'</option>'
                                fi
                                if [[ "${splitpagehandling}" == "isLastPage" ]]; then
                                    echo '<option value="isLastPage" selected>'"${lang_edit_set2_splitpagehandling_isLastPage}"'</option>'
                                else
                                    echo '<option value="isLastPage">'"${lang_edit_set2_splitpagehandling_isLastPage}"'</option>'
                                fi
                                if [[ "${splitpagehandling}" == "isFirstPage" ]]; then
                                    echo '<option value="isFirstPage" selected>'"${lang_edit_set2_splitpagehandling_isFirstPage}"'</option>'
                                else
                                    echo '<option value="isFirstPage">'"${lang_edit_set2_splitpagehandling_isFirstPage}"'</option>'
                                fi
                    
                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#filedate_nearest-info" role="button" aria-expanded="false" aria-controls="filedate_nearest-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="filedate_nearest-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_splitpagehandling_help1}"'<br>
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>
                    </div>'

                    echo '<hr><br>'

                    # blank_page_detection
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="blank_page_detection_switch">'"${lang_edit_set2_blank_page_detection_switch_title}"'</label>
                        </div>

                        <div class="col-sm-5">
                            <div class="form-check form-switch">
                                <input type="hidden" name="blank_page_detection_switch" value="false">
                                <input class="form-check-input" type="checkbox" role="switch" id="blank_page_detection_switch" 
                                    name="blank_page_detection_switch" value="true"'; \
                                    [[ "${blank_page_detection_switch}" == "true" ]] && echo -n ' checked'; \
                                    echo '>
                            </div>
                        </div>

                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#blank_page_detection_switch-info" role="button" aria-expanded="false" aria-controls="blank_page_detection_switch-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="blank_page_detection_switch-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_blank_page_detection_switch_help1}"'<br />
                                        '"${lang_edit_set2_blank_page_detection_switch_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'


                    # blank_page_detection_mainThreshold
                    blank_page_detection_mainThreshold_current_value="${blank_page_detection_mainThreshold:-50}"
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="blank_page_detection_mainThreshold">'"${lang_edit_set2_blank_page_detection_mainThreshold_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" class="form-range" min="-100" max="0" name="blank_page_detection_mainThreshold" id="blank_page_detection_mainThreshold" value="'"${blank_page_detection_mainThreshold_current_value}"'" oninput="document.getElementById('\''blank_page_detection_mainThreshold_value'\'').textContent = this.value" />
                                <div class="mt-1">
                                    <span id="blank_page_detection_mainThreshold_value" class="badge bg-primary">'"${blank_page_detection_mainThreshold_current_value}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#blank_page_detection_mainThreshold-info" role="button" aria-expanded="false" aria-controls="blank_page_detection_mainThreshold-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="blank_page_detection_mainThreshold-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_blank_page_detection_mainThreshold_help1}"'<br /><br />
                                        '"${lang_edit_set2_blank_page_detection_mainThreshold_help2}"'<br />
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'


    echo '
    <div class="accordion" id="Accordion-01-2">
        <div class="accordion-item border-start-0 border-end-0" style="border-style: dashed none dashed none; size: 1px;">
            <h2 class="accordion-header" id="Heading-01">
                <button class="accordion-button collapsed bg-white synocr-accordion-glow-off" type="button" data-bs-toggle="collapse" data-bs-target="#Collapse-01" aria-expanded="false" aria-controls="collapseTwo">
                    <span class="synocr-text-blue" style="color: #BD0010;">'"${lang_edit_set1_blank_page_detection_expert_title}"'</span>
                </button>
            </h2>
            <div id="Collapse-01" class="accordion-collapse collapse border-white" aria-labelledby="Heading-01" data-bs-parent="#Accordion-01-2">
                <div class="accordion-body">'







                    # blank_page_detection_ignoreText
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="blank_page_detection_ignoreText">'"${lang_edit_set2_blank_page_detection_ignoreText_title}"'</label>
                        </div>

                        <div class="col-sm-5">


                            <div class="form-check form-switch">
                                <input type="hidden" name="blank_page_detection_ignoreText" value="false">
                                <input class="form-check-input" type="checkbox" role="switch" id="blank_page_detection_ignoreText" 
                                    name="blank_page_detection_ignoreText" value="true"'; \
                                    [[ "${blank_page_detection_ignoreText}" == "true" ]] && echo -n ' checked'; \
                                    echo '>
                            </div>


                        </div>

                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#blank_page_detection_ignoreText-info" role="button" aria-expanded="false" 
                                    aria-controls="blank_page_detection_ignoreText-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="blank_page_detection_ignoreText-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_blank_page_detection_ignoreText_help1}"'<br />
                                        '"${lang_edit_set2_blank_page_detection_ignoreText_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'











                    # blank_page_detection_widthCropping
                    blank_page_detection_widthCropping_current_value="${blank_page_detection_widthCropping:-0.1}"
                    blank_page_detection_widthCropping_display="$blank_page_detection_widthCropping_current_value"
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="blank_page_detection_widthCropping">'"${lang_edit_set2_blank_page_detection_widthCropping_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" 
                                       class="form-range" 
                                       min="0.0" 
                                       max="0.5" 
                                       step="0.01" 
                                       name="blank_page_detection_widthCropping" 
                                       id="blank_page_detection_widthCropping" 
                                       value="'"${blank_page_detection_widthCropping_current_value}"'" 
                                       oninput="document.getElementById('\''blank_page_detection_widthCropping_value'\'').textContent = parseFloat(this.value).toFixed(2)" />
                                <div class="mt-1">
                                    <span id="blank_page_detection_widthCropping_value" class="badge bg-primary">'"${blank_page_detection_widthCropping_display}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#blank_page_detection_widthCropping-info" role="button" aria-expanded="false" aria-controls="blank_page_detection_widthCropping-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="blank_page_detection_widthCropping-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                         '"${lang_edit_set2_blank_page_detection_widthCropping_help1}"'<br><br>
                                         '"${lang_edit_set2_blank_page_detection_widthCropping_help2}"'<br><br>
                                         '"${lang_default}"': <code><span style="font-hight:1.1em;">'0.1'</span></code>
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # blank_page_detection_hightCropping
                    blank_page_detection_hightCropping_current_value="${blank_page_detection_hightCropping:-0.05}"
                    blank_page_detection_hightCropping_display="$blank_page_detection_hightCropping_current_value"

                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="blank_page_detection_hightCropping">'"${lang_edit_set2_blank_page_detection_hightCropping_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" 
                                       class="form-range" 
                                       min="0.0" 
                                       max="0.5" 
                                       step="0.01" 
                                       name="blank_page_detection_hightCropping" 
                                       id="blank_page_detection_hightCropping" 
                                       value="'"${blank_page_detection_hightCropping_current_value}"'" 
                                       oninput="document.getElementById('\''blank_page_detection_hightCropping_value'\'').textContent = parseFloat(this.value).toFixed(2)" />
                                <div class="mt-1">
                                    <span id="blank_page_detection_hightCropping_value" class="badge bg-primary">'"${blank_page_detection_hightCropping_display}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#blank_page_detection_hightCropping-info" role="button" aria-expanded="false" aria-controls="blank_page_detection_hightCropping-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="blank_page_detection_hightCropping-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                         '"${lang_edit_set2_blank_page_detection_hightCropping_help1}"'<br><br>
                                         '"${lang_edit_set2_blank_page_detection_hightCropping_help2}"'<br><br>
                                         '"${lang_default}"': <code><span style="font-hight:1.1em;">'0.05'</span></code>
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # blank_page_detection_interferenceMaxFilter
                    blank_page_detection_interferenceMaxFilter_current_value="${blank_page_detection_interferenceMaxFilter:-1}" # Aktuellen Wert ermitteln oder Standard 127 setzen
                    # Angezeigten Text bestimmen (off oder Zahl)
                    if [ "$blank_page_detection_interferenceMaxFilter_current_value" -eq 0 ]; then
                        blank_page_detection_interferenceMaxFilter_display="${lang_deactivated}"
                    else
                        blank_page_detection_interferenceMaxFilter_display="$blank_page_detection_interferenceMaxFilter_current_value"
                    fi
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="blank_page_detection_interferenceMaxFilter">'"${lang_edit_set2_blank_page_detection_interferenceMaxFilter_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" class="form-range" min="1" max="5" name="blank_page_detection_interferenceMaxFilter" id="blank_page_detection_interferenceMaxFilter" value="'"${blank_page_detection_interferenceMaxFilter_current_value}"'" oninput="document.getElementById('\''blank_page_detection_interferenceMaxFilter_value'\'').textContent = this.value == 0 ? '\'"${lang_deactivated}"\'' : this.value" />
                                <div class="mt-1">
                                    <span id="blank_page_detection_interferenceMaxFilter_value" class="badge bg-primary">'"${blank_page_detection_interferenceMaxFilter_display}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#blank_page_detection_interferenceMaxFilter-info" role="button" aria-expanded="false" aria-controls="blank_page_detection_interferenceMaxFilter-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="blank_page_detection_interferenceMaxFilter-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                         '"${lang_edit_set2_blank_page_detection_interferenceMaxFilter_help1}"'<br><br>
                                         '"${lang_edit_set2_blank_page_detection_interferenceMaxFilter_help2}"'<br><br>
                                         '"${lang_default}"': <code><span style="font-hight:1.1em;">1</span></code> (='"${lang_deactivated}"')
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # blank_page_detection_interferenceMinFilter
                    blank_page_detection_interferenceMinFilter_current_value="${blank_page_detection_interferenceMinFilter:-3}" # Aktuellen Wert ermitteln oder Standard 127 setzen
                    # Angezeigten Text bestimmen (off oder Zahl)
                    if [ "$blank_page_detection_interferenceMinFilter_current_value" -eq 0 ]; then
                        blank_page_detection_interferenceMinFilter_display="${lang_deactivated}"
                    else
                        blank_page_detection_interferenceMinFilter_display="$blank_page_detection_interferenceMinFilter_current_value"
                    fi
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="blank_page_detection_interferenceMinFilter">'"${lang_edit_set2_blank_page_detection_interferenceMinFilter_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" class="form-range" min="1" max="7" name="blank_page_detection_interferenceMinFilter" id="blank_page_detection_interferenceMinFilter" value="'"${blank_page_detection_interferenceMinFilter_current_value}"'" oninput="document.getElementById('\''blank_page_detection_interferenceMinFilter_value'\'').textContent = this.value == 0 ? '\'"${lang_deactivated}"\'' : this.value" />
                                <div class="mt-1">
                                    <span id="blank_page_detection_interferenceMinFilter_value" class="badge bg-primary">'"${blank_page_detection_interferenceMinFilter_display}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#blank_page_detection_interferenceMinFilter-info" role="button" aria-expanded="false" aria-controls="blank_page_detection_interferenceMinFilter-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="blank_page_detection_interferenceMinFilter-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                         '"${lang_edit_set2_blank_page_detection_interferenceMinFilter_help1}"'<br><br>
                                         '"${lang_default}"': <code><span style="font-hight:1.1em;">3</span></code>
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # blank_page_detection_black_pixel_ratio
                    blank_page_detection_black_pixel_ratio_current_value="${blank_page_detection_black_pixel_ratio:-0.005}"
                    blank_page_detection_black_pixel_ratio_display="$blank_page_detection_black_pixel_ratio_current_value"

                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="blank_page_detection_black_pixel_ratio">'"${lang_edit_set2_blank_page_detection_black_pixel_ratio_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="mt-2">
                                <input type="range" 
                                       class="form-range" 
                                       min="0.001" 
                                       max="0.02" 
                                       step="0.001" 
                                       name="blank_page_detection_black_pixel_ratio" 
                                       id="blank_page_detection_black_pixel_ratio" 
                                       value="'"${blank_page_detection_black_pixel_ratio_current_value}"'" 
                                       oninput="document.getElementById('\''blank_page_detection_black_pixel_ratio_value'\'').textContent = parseFloat(this.value).toFixed(3)" />
                                <div class="mt-1">
                                    <span id="blank_page_detection_black_pixel_ratio_value" class="badge bg-primary">'"${blank_page_detection_black_pixel_ratio_display}"'</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#blank_page_detection_black_pixel_ratio-info" role="button" aria-expanded="false" aria-controls="blank_page_detection_black_pixel_ratio-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="blank_page_detection_black_pixel_ratio-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                         '"${lang_edit_set2_blank_page_detection_black_pixel_ratio_help1}"'<br><br>
                                         '"${lang_edit_set2_blank_page_detection_black_pixel_ratio_help2}"'<br><br>
                                         '"${lang_default}"': <code><span style="font-hight:1.1em;">'0.005'</span></code>
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    echo '
                </div>
            </div>
        </div>
    </div>'


                    echo '<hr><br>'

                    # Taglist
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="taglist">'"${lang_edit_set2_taglist_title}"''
                                # ("taglist" does not refer to an external file OR refers to an external file and has max. one line) AND input directory is a valid path
                                if { [[ ! -f "${taglist}" ]] || { [[ -f "${taglist}" ]] && [[ $( wc -l "${taglist}" | awk '{print $1}' ) -le 1 ]]; } } && [ -d "${INPUTDIR}" ]; then
                                    echo '
                                        <br /><br />
                                        <button name="page" value="edit-convert2YAML" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_edit_yamlsample_button}"'</button>&nbsp;&nbsp;
                                    <a data-bs-toggle="collapse" href="#convert2YAML" role="button" aria-expanded="false" aria-controls="convert2YAML">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>'
                                fi

                                echo '
                            </label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "${taglist}" ]; then
                                echo '<textarea name="taglist" id="taglist" class="form-control" cols="35" rows="4">'"${taglist}"'</textarea>'
                            else
                                echo '<textarea name="taglist" id="taglist" class="form-control" cols="35" rows="4"></textarea>'
                            fi
                            echo '

                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#taglist-info" role="button" aria-expanded="false" aria-controls="taglist-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="convert2YAML">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        <strong>'"${lang_edit_yamlsample_button_help_headline}"'</strong><br /><br />
                                        '"${lang_edit_yamlsample_button_help_01}"'<br />
                                        '"${lang_edit_yamlsample_button_help_02}"'<br />
                                        '"${lang_edit_yamlsample_button_help_03}"'<br />
                                    </span>
                                </div>
                            </div>

                            <div class="collapse" id="taglist-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_taglist_help1}"'<br />
                                        '"${lang_edit_set2_taglist_help2}"'<br />
                                        '"${lang_edit_set2_taglist_help2_1}"'<br />
                                        <strong>'"${lang_edit_set2_taglist_help3}"'</strong><br />
                                        '"${lang_edit_set2_taglist_help4}"'<br />
                                        '"${lang_edit_set2_taglist_help5}"'<br /><br />
                                        '"${lang_example}"' <b>'"${lang_edit_set2_taglist_help6}"'</b><br />
                                        <br />
                                        '"${lang_edit_set2_taglist_help7}"'<br /><br />
                                        '"${lang_example}"' <b>'"${lang_edit_set2_taglist_help8}"'</b><br /><br />
                                        '"${lang_edit_set2_taglist_help9}"'<br />
                                        '"${lang_edit_set2_taglist_help10}"'<br />
                                        ('"${lang_example}"' /volume1/ocr/taglist.txt)<br /><br />
                                        <strong>'"${lang_edit_yamlsample_button_help_headline}"'</strong><br />
                                        '"${lang_edit_set2_taglist_help11}"'<a href="https://github.com/geimist/synOCR/wiki/03_YAML-(de)" onclick="window.open(this.href); return false;" style="color: #BD0010;"><b>WIKI</b></a><br />
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # searchArea
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="searchAll">'"${lang_edit_set2_searchall_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="searchAll" id="searchAll" class="form-select form-select-sm">'

                                if [[ "${searchAll}" == "no" ]]; then
                                    echo '<option value="no" selected>'"${lang_edit_set2_searchall_1page}"'</option>'
                                else
                                    echo '<option value="no">'"${lang_edit_set2_searchall_1page}"'</option>'
                                fi
                                if [[ "${searchAll}" == "searchAll" ]]; then
                                    echo '<option value="searchAll" selected>'"${lang_edit_set2_searchall_all}"'</option>'
                                else
                                    echo '<option value="searchAll">'"${lang_edit_set2_searchall_all}"'</option>'
                                fi

                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#searchAll-info" role="button" aria-expanded="false" aria-controls="searchAll-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="searchAll-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_searchall_help1}"'<br />
                                        '"${lang_edit_set2_searchall_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # moveTaggedFiles
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="moveTaggedFiles" class="text-white">'"${lang_edit_set2_moveTaggedFiles_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="moveTaggedFiles" id="moveTaggedFiles" class="form-select form-select-sm">'

                                if [[ "${moveTaggedFiles}" == "no" ]]; then
                                    echo '<option value="no" selected>'"${lang_edit_set2_moveTaggedFiles_targetdir}"'</option>'
                                else
                                    echo '<option value="no">'"${lang_edit_set2_moveTaggedFiles_targetdir}"'</option>'
                                fi
                                if [[ "${moveTaggedFiles}" == "useCatDir" ]]; then
                                    echo '<option value="useCatDir" selected>'"${lang_edit_set2_moveTaggedFiles_useCatDir}"'</option>'
                                else
                                    echo '<option value="useCatDir">'"${lang_edit_set2_moveTaggedFiles_useCatDir}"'</option>'
                                fi
                                if [[ "${moveTaggedFiles}" == "useTagDir" ]]; then
                                    echo '<option value="useTagDir" selected>'"${lang_edit_set2_moveTaggedFiles_useTagDir}"'</option>'
                                else
                                    echo '<option value="useTagDir">'"${lang_edit_set2_moveTaggedFiles_useTagDir}"'</option>'
                                fi
                                if [[ "${moveTaggedFiles}" == "useYearDir" ]]; then
                                    echo '<option value="useYearDir" selected>'"${lang_edit_set2_moveTaggedFiles_useYearDir}"'</option>'
                                else
                                    echo '<option value="useYearDir">'"${lang_edit_set2_moveTaggedFiles_useYearDir}"'</option>'
                                fi
                                if [[ "${moveTaggedFiles}" == "useYearMonthDir" ]]; then
                                    echo '<option value="useYearMonthDir" selected>'"${lang_edit_set2_moveTaggedFiles_useYearMonthDir}"'</option>'
                                else
                                    echo '<option value="useYearMonthDir">'"${lang_edit_set2_moveTaggedFiles_useYearMonthDir}"'</option>'
                                fi

                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#moveTaggedFiles-info" role="button" aria-expanded="false" aria-controls="moveTaggedFiles-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="moveTaggedFiles-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_moveTaggedFiles_help1}"'
                                        <br>-&nbsp;'"${lang_edit_set2_moveTaggedFiles_help2}"'
                                        <br>-&nbsp;'"${lang_edit_set2_moveTaggedFiles_help3}"'
                                        <br>-&nbsp;'"${lang_edit_set2_moveTaggedFiles_help4}"'
                                        <br>-&nbsp;'"${lang_edit_set2_moveTaggedFiles_help5}"'
                                        <br><br>'"${lang_edit_set2_moveTaggedFiles_help6}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # OCR Rename-Syntax
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="NameSyntax">'"${lang_edit_set2_renamesyntax_title}"'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "${NameSyntax}" ]; then
                                echo '<input type="text" name="NameSyntax" id="NameSyntax" class="form-control form-control-sm" value="'"${NameSyntax}"'" />'
                            else
                                echo '<input type="text" name="NameSyntax" id="NameSyntax" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#NameSyntax-info" role="button" aria-expanded="false" aria-controls="NameSyntax-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="NameSyntax-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_renamesyntax_help1}"'<br /><br />
                                        '"${lang_edit_set2_renamesyntax_help2}"'<br />
                                        '"${lang_edit_set2_renamesyntax_help3}"':<br />
                                        <strong>§docr</strong> ('"${lang_edit_set2_renamesyntax_help4}"')<br />
                                        <strong>§mocr</strong> ('"${lang_edit_set2_renamesyntax_help5}"')<br />
                                        <strong>§yocr2</strong> ('"${lang_edit_set2_renamesyntax_help6a}"')<br />
                                        <strong>§yocr4</strong> ('"${lang_edit_set2_renamesyntax_help6b}"')<br />
                                        <strong>§ssnow</strong> ('"${lang_edit_set2_renamesyntax_help22}"')<br />
                                        <strong>§mmnow</strong> ('"${lang_edit_set2_renamesyntax_help23}"')<br />
                                        <strong>§hhnow</strong> ('"${lang_edit_set2_renamesyntax_help24}"')<br />
                                        <strong>§dnow</strong> ('"${lang_edit_set2_renamesyntax_help7}"')<br />
                                        <strong>§mnow</strong> ('"${lang_edit_set2_renamesyntax_help8}"')<br />
                                        <strong>§ynow2</strong> ('"${lang_edit_set2_renamesyntax_help9a}"')<br />
                                        <strong>§ynow4</strong> ('"${lang_edit_set2_renamesyntax_help9b}"')<br />
                                        <strong>§sssource</strong> ('"${lang_edit_set2_renamesyntax_help25}"')<br />
                                        <strong>§mmsource</strong> ('"${lang_edit_set2_renamesyntax_help26}"')<br />
                                        <strong>§hhsource</strong> ('"${lang_edit_set2_renamesyntax_help27}"')<br />
                                        <strong>§dsource</strong> ('"${lang_edit_set2_renamesyntax_help10}"')<br />
                                        <strong>§msource</strong> ('"${lang_edit_set2_renamesyntax_help11}"')<br />
                                        <strong>§ysource2</strong> ('"${lang_edit_set2_renamesyntax_help12a}"')<br />
                                        <strong>§ysource4</strong> ('"${lang_edit_set2_renamesyntax_help12b}"')<br />
                                        <strong>§tag</strong> ('"${lang_edit_set2_renamesyntax_help13}"')<br />
                                        <strong>§tit</strong> ('"${lang_edit_set2_renamesyntax_help14}"')<br />
                                        <strong>§pagecount</strong> ('"${lang_edit_set2_renamesyntax_help18a}"')<br />
                                        <strong>§pagecounttotal</strong> ('"${lang_edit_set2_renamesyntax_help18}"')<br />
                                        <strong>§filecounttotal</strong> ('"${lang_edit_set2_renamesyntax_help19}"')<br />
                                        <strong>§pagecountprofile</strong> ('"${lang_edit_set2_renamesyntax_help20}"')<br />
                                        <strong>§filecountprofile</strong> ('"${lang_edit_set2_renamesyntax_help21}"')<br /><br />
                                        >><strong>§yocr4-§mocr-§docr_§tag_§tit</strong><< '"${lang_edit_set2_renamesyntax_help15}"'<br />
                                        '"${lang_example}"' >><strong>2018-12-09_#Rechnung_00376.pdf</strong><<<br />
                                        <br />'"${lang_edit_set2_renamesyntax_help17}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # Tagkennzeichnung
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="tagsymbol">'"${lang_edit_set2_tagsymbol_title}"'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "${tagsymbol}" ]; then
                                echo '<input type="text" name="tagsymbol" id="tagsymbol" class="form-control form-control-sm" value="'"${tagsymbol}"'" />'
                            else
                                echo '<input type="text" name="tagsymbol" id="tagsymbol" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#tagsymbol-info" role="button" aria-expanded="false" aria-controls="tagsymbol-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="tagsymbol-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_tagsymbol_help1}"' ('"${lang_example}"': #)<br />
                                        '"${lang_edit_set2_tagsymbol_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    echo '<hr><br>'

                    # Filedate
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="filedate">'"${lang_edit_set2_filedate_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="filedate" id="filedate" class="form-select form-select-sm">'

                               if [[ "${filedate}" == "now" ]]; then
                                    echo '<option value="now" selected>'"${lang_edit_set2_filedate_now}"'</option>'
                                else
                                    echo '<option value="now">'"${lang_edit_set2_filedate_now}"'</option>'
                                fi
                                if [[ "${filedate}" == "ocr" ]]; then
                                    echo '<option value="ocr" selected>'"${lang_edit_set2_filedate_ocr}"'</option>'
                                else
                                    echo '<option value="ocr">'"${lang_edit_set2_filedate_ocr}"'</option>'
                                fi
                                if [[ "${filedate}" == "source" ]]; then
                                    echo '<option value="source" selected>'"${lang_edit_set2_filedate_source}"'</option>'
                                else
                                    echo '<option value="source">'"${lang_edit_set2_filedate_source}"'</option>'
                                fi

                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#filedate-info" role="button" aria-expanded="false" aria-controls="filedate-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="filedate-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_filedate_help1}"'<br />
                                        '"${lang_edit_set2_filedate_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # ignoredDate
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="ignoredDate">'"${lang_edit_set2_ignoredDate_title}"'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "${ignoredDate}" ]; then
                                echo '<input type="text" name="ignoredDate" id="ignoredDate" class="form-control form-control-sm" value="'"${ignoredDate}"'" />'
                            else
                                echo '<input type="text" name="ignoredDate" id="ignoredDate" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#ignoredDate-info" role="button" aria-expanded="false" aria-controls="ignoredDate-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="ignoredDate-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_ignoredDate_help1}"'<br /><br />
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'


                    # DateSearchMinYear
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="DateSearchMinYear">'"${lang_edit_set2_DateSearchMinYear_title}"'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "${DateSearchMinYear}" ]; then
                                echo '<input type="text" name="DateSearchMinYear" id="DateSearchMinYear" class="form-control form-control-sm" value="'"${DateSearchMinYear}"'" />'
                            else
                                echo '<input type="text" name="DateSearchMinYear" id="DateSearchMinYear" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#DateSearchMinYear-info" role="button" aria-expanded="false" aria-controls="DateSearchMinYear-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="DateSearchMinYear-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_DateSearchMinYear_help1}"'<br />
                                        '"${lang_edit_set2_DateSearchMinYear_help2}"'<br /><br />
                                        '"${lang_edit_set2_DateSearchMinYear_help3}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # DateSearchMaxYear
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="DateSearchMaxYear">'"${lang_edit_set2_DateSearchMaxYear_title}"'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "${DateSearchMaxYear}" ]; then
                                echo '<input type="text" name="DateSearchMaxYear" id="DateSearchMaxYear" class="form-control form-control-sm" value="'"${DateSearchMaxYear}"'" />'
                            else
                                echo '<input type="text" name="DateSearchMaxYear" id="DateSearchMaxYear" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#DateSearchMaxYear-info" role="button" aria-expanded="false" aria-controls="DateSearchMaxYear-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="DateSearchMaxYear-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_DateSearchMaxYear_help1}"'<br /><br />
                                        '"${lang_edit_set2_DateSearchMaxYear_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # search_nearest_date
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="search_nearest_date">'"${lang_edit_set2_filedate_search_nearest_date_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="search_nearest_date" id="search_nearest_date" class="form-select form-select-sm">'

                                if [[ "${search_nearest_date}" == "firstfound" ]]; then
                                    echo '<option value="firstfound" selected>'"${lang_edit_set2_filedate_search_nearest_firstfound}"'</option>'
                                else
                                    echo '<option value="firstfound">'"${lang_edit_set2_filedate_search_nearest_firstfound}"'</option>'
                                fi
                                if [[ "${search_nearest_date}" == "nearest" ]]; then
                                    echo '<option value="nearest" selected>'"${lang_edit_set2_filedate_search_nearest_nearest}"'</option>'
                                else
                                    echo '<option value="nearest">'"${lang_edit_set2_filedate_search_nearest_nearest}"'</option>'
                                fi

                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#filedate_nearest-info" role="button" aria-expanded="false" aria-controls="filedate_nearest-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="filedate_nearest-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_filedate_search_nearest_help1}"'<br>
                                        '"${lang_edit_set2_filedate_search_nearest_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # date_search_method
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="date_search_method">'"${lang_edit_set2_date_search_method_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="date_search_method" id="date_search_method" class="form-select form-select-sm">'

                                if [[ "${date_search_method}" == "python" ]]; then
                                    echo '<option value="python" selected>'"${lang_edit_set2_date_search_method_python}"'</option>'
                                else
                                    echo '<option value="python">'"${lang_edit_set2_date_search_method_python}"'</option>'
                                fi
                                if [[ "${date_search_method}" == "regex" ]]; then
                                    echo '<option value="regex" selected>'"${lang_edit_set2_date_search_method_regex}"'</option>'
                                else
                                    echo '<option value="regex">'"${lang_edit_set2_date_search_method_regex}"'</option>'
                                fi

                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#date_search_method-info" role="button" aria-expanded="false" aria-controls="date_search_method-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="date_search_method-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_date_search_method_help1}"'<br><br><b>Python:</b><br>
                                        '"${lang_edit_set2_date_search_method_help2}"'<br><br><b>RegEx:</b><br>
                                        '"${lang_edit_set2_date_search_method_help3}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    echo '<hr><br>'

                    # clean_up_spaces
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="clean_up_spaces">'"${lang_edit_set2_clean_up_spaces_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="clean_up_spaces" id="clean_up_spaces" class="form-select form-select-sm">'

                                if [[ "${clean_up_spaces}" == "true" ]]; then
                                    echo '<option value="true" selected>'"${lang_edit_set2_clean_up_spaces_true}"'</option>'
                                else
                                    echo '<option value="true">'"${lang_edit_set2_clean_up_spaces_true}"'</option>'
                                fi
                                if [[ "${clean_up_spaces}" == "false" ]]; then
                                    echo '<option value="false" selected>'"${lang_edit_set2_clean_up_spaces_false}"'</option>'
                                else
                                    echo '<option value="false">'"${lang_edit_set2_clean_up_spaces_false}"'</option>'
                                fi

                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#clean_up_spaces-info" role="button" aria-expanded="false" aria-controls="clean_up_spaces-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="clean_up_spaces-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set2_clean_up_spaces_help1}"'<br><br>
                                        '"${lang_edit_set2_clean_up_spaces_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    echo '
                </div>
            </div>
        </div>
    </div>'

    # --------------------------------------------------------------
    # -> Section DSM notification and other settings
    # --------------------------------------------------------------
    echo '
    <div class="accordion" id="Accordion-03">
        <div class="accordion-item border-start-0 border-end-0" style="border-style: dashed none dashed none; size: 1px;">
            <h2 class="accordion-header" id="Heading-03">
                <button class="accordion-button collapsed bg-white synocr-accordion-glow-off" type="button" data-bs-toggle="collapse" data-bs-target="#Collapse-03" aria-expanded="false" aria-controls="collapseTwo">
                    <span class="synocr-text-blue">'"${lang_edit_set3_title}"'</span>
                </button>
            </h2>
            <div id="Collapse-03" class="accordion-collapse collapse border-white" aria-labelledby="Heading-03" data-bs-parent="#Accordion-03">
                <div class="accordion-body">'

                    # BACKUP ROTATION
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="backup_max">'"${lang_edit_set3_backuprotate_title}"'</label>
                        </div>
                        <div class="col-sm-2">'

                            if [ -n "${backup_max}" ]; then
                                echo '<input type="text" name="backup_max" id="ignoredDate" class="form-control form-control-sm" value="'"${backup_max}"'" />'
                            else
                                echo '<input type="text" name="backup_max" id="ignoredDate" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>'

                        # Ausgeblendeter Label-Tag: $lang_edit_set3_backuprotatetype_title
                        echo '
                        <div class="col-sm-3">
                            <input class="form-check-input" type="radio" id="backup_max_type-files" name="backup_max_type" value='; \
                                [[ "${backup_max_type}" == "files" ]] && echo -n '"files" checked />' || echo -n '"files" />'
                            echo '<label for="backup_max_type-files" class="form-check-label ps-2 pe-4">'"${lang_edit_set3_backuprotatetype_files}"'</label>'
                            echo -n '
                            <input class="form-check-input" type="radio" id="backup_max_type-days" name="backup_max_type" value='; \
                                [[ "${backup_max_type}" == "days" ]] && echo -n '"days" checked />' || echo -n '"days" />'
                            echo '<label for="backup_max_type-days" class="form-check-label ps-2">'"${lang_edit_set3_backuprotatetype_days}"'</label>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#backup_max_type-info" role="button" aria-expanded="false" aria-controls="backup_max_type-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="backup_max_type-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_backuprotate_help1}"'<br /><br />
                                        '"${lang_edit_set3_backuprotate_help2}"'<br />
                                        '"${lang_edit_set3_backuprotate_help3}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # LOGmax
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="LOGmax">'"${lang_edit_set3_logmax_title}"'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "${LOGmax}" ]; then
                                echo '<input type="text" name="LOGmax" id="LOGmax" class="form-control form-control-sm" value="'"${LOGmax}"'" />'
                            else
                                echo '<input type="text" name="LOGmax" id="LOGmax" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#LOGmax-info" role="button" aria-expanded="false" aria-controls="LOGmax-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="LOGmax-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_logmax_help}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # LOGlevel
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="loglevel">'"${lang_edit_set3_loglevel_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <input class="form-check-input" type="radio" id="loglevel-0" name="loglevel" value='; \
                                [[ "${loglevel}" == "0" ]] && echo -n '"0" checked />' || echo -n '"0" />'
                            echo '<label for="loglevel-0" class="form-check-label ps-2 pe-4">'"${lang_edit_set3_loglevel_off}"'</label>'
                            echo -n '
                            <input class="form-check-input" type="radio" id="loglevel-1" name="loglevel" value='; \
                                [[ "${loglevel}" == "1" ]] && echo -n '"1" checked />' || echo -n '"1" />'
                            echo '<label for="loglevel-1" class="form-check-label ps-2">'"${lang_edit_set3_loglevel_1}"'</label>'
                            echo -n '
                            <input class="form-check-input" type="radio" id="loglevel-2" name="loglevel" value='; \
                                [[ "${loglevel}" == "2" ]] && echo -n '"2" checked />' || echo -n '"2" />'
                            echo '<label for="loglevel-2" class="form-check-label ps-2">'"${lang_edit_set3_loglevel_2}"'</label>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#loglevel-info" role="button" aria-expanded="false" aria-controls="loglevel-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="loglevel-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_loglevel_help1}"'<br />
                                        '"${lang_edit_set3_loglevel_help2}"'<br />
                                        '"${lang_edit_set3_loglevel_help3}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    echo '<hr><br>'

                    # dsmbeepnotify
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="dsmbeepnotify">'"${lang_edit_set3_dsmbeepnotify_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="form-check form-switch">
                                <input type="hidden" name="dsmbeepnotify" value="off">
                                <input class="form-check-input" type="checkbox" role="switch" id="dsmbeepnotify" 
                                    name="dsmbeepnotify" value="on"'; \
                                    [[ "${dsmbeepnotify}" == "on" ]] && echo -n ' checked'; \
                                    echo '>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#dsmbeepnotify-info" role="button" aria-expanded="false" aria-controls="dsmbeepnotify-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="dsmbeepnotify-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_dsmbeepnotify_help1}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # dsmtextnotify
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="dsmtextnotify">'"${lang_edit_set3_dsmtextnotify_title}"'</label>
                        </div>
                    
                        <div class="col-sm-5">
                            <div class="form-check form-switch">
                                <input type="hidden" name="dsmtextnotify" value="off">
                                <input class="form-check-input" type="checkbox" role="switch" id="dsmtextnotify" 
                                    name="dsmtextnotify" value="on"'; \
                                    [[ "${dsmtextnotify}" == "on" ]] && echo -n ' checked'; \
                                    echo '>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#dsmtextnotify-info" role="button" aria-expanded="false" aria-controls="dsmtextnotify-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="dsmtextnotify-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_dsmtextnotify_help1}"'<br />
                                        '"${lang_edit_set3_dsmtextnotify_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # MessageTo
                    user_list=$(cat /etc/passwd)
                    user_list_array=()
                    user_list_array+=( "-" )

                    while read -r user; do
                        user_name=$(echo "${user}" | awk -F: '{print $1}')
                        user_id=$( id -u "${user_name}" )
                        # sort out system user:
                        if [ "${user_id}" -ge 1000 ] && [ "${user_id}" -le 100000 ] ; then
                            user_list_array+=( "${user_name}" )
                        fi
                    done <<< "${user_list}"

                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="MessageTo">'"${lang_edit_set3_MessageTo_title}"' (DSM)</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="MessageTo" id="MessageTo" class="form-select form-select-sm">'

                                for entry in "${user_list_array[@]}"; do
                                    if [[ "${MessageTo}" == "${entry}" ]]; then
                                        echo "<option value=${entry} selected>${entry}</option>"
                                    else
                                        echo "<option value=${entry}>${entry}</option>"
                                    fi
                                done

                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#MessageTo-info" role="button" aria-expanded="false" aria-controls="MessageTo-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="MessageTo-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_MessageTo_help1}"'<br />
                                        '"${lang_edit_set3_MessageTo_help2}"'<br />
                                        '"${lang_edit_set3_MessageTo_help3}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # Apprise notify service
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="apprise_call">'"${lang_edit_set3_APPRISE_title}"'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "${apprise_call}" ]; then
                                echo '<input type="text" name="apprise_call" id="apprise_call" class="form-control form-control-sm" value="'"${apprise_call}"'" />'
                            else
                                echo '<input type="text" name="apprise_call" id="apprise_call" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#apprise_call-info" role="button" aria-expanded="false" aria-controls="apprise_call-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="apprise_call-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_APPRISE_help1}"'<br />
                                        <code><span style="font-hight:1.1em;">ifttt://webhooksID/Event mqtts://user:pass@hostname:9883/topic ...</span></code><br><br>
                                        '"${lang_edit_set3_APPRISE_help2}"' <a href="https://github.com/caronc/apprise#productivity-based-notifications" onclick="window.open(this.href); return false;" style="'"${synocrred}"';">github.com/caronc/apprise</a><br /><br />
                                        '"${lang_edit_set3_APPRISE_help3}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # apprise_attachment
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="apprise_attachment">'"${lang_edit_set3_apprise_attachment_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="form-check form-switch">
                                <input type="hidden" name="apprise_attachment" value="false">
                                <input class="form-check-input" type="checkbox" role="switch" id="apprise_attachment" 
                                    name="apprise_attachment" value="true"'; \
                                    [[ "${apprise_attachment}" == "true" ]] && echo -n ' checked'; \
                                    echo '>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#apprise_attachment-info" role="button" aria-expanded="false" aria-controls="apprise_attachment-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="apprise_attachment-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_apprise_attachment_help1}"'<br><br>
                                        '"${lang_edit_set3_apprise_attachment_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # notify language:
                    languages=()
                    while read -r line; do
                        languages+=("${line}")
                    done <<< "$(find "./lang/" -maxdepth 1 -type f -printf "%f\n" | grep -vE '/$' | cut -f 1 -d '.' | cut -f 2 -d '_' | grep -vE '^$' | sort)"

                    chs="${lang_langname_chs}"
                    csy="${lang_langname_csy}"
                    dan="${lang_langname_dan}"
                    enu="${lang_langname_enu}"
                    fre="${lang_langname_fre}"
                    ger="${lang_langname_ger}"
                    hun="${lang_langname_hun}"
                    ita="${lang_langname_ita}"
                    jpn="${lang_langname_jpn}"
                    krn="${lang_langname_krn}"
                    nld="${lang_langname_nld}"
                    nor="${lang_langname_nor}"
                    plk="${lang_langname_plk}"
                    ptb="${lang_langname_ptb}"
                    ptg="${lang_langname_ptg}"
                    rus="${lang_langname_rus}"
                    spn="${lang_langname_spn}"
                    sve="${lang_langname_sve}"
                    trk="${lang_langname_trk}"

                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="notify_lang">'"${lang_edit_set3_notify_lang_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="notify_lang" id="notify_lang" class="form-select form-select-sm">'

                                for entry in "${languages[@]}"; do
                                    # combine language code with translatet variable:
                                    eval langvar=\$"${entry}"

                                    if [[ "${notify_lang}" == "${entry}" ]]; then
                                        echo "<option value=${entry} selected>${langvar}</option>"
                                    else
                                        echo "<option value=${entry}>${langvar}</option>"
                                    fi
                                done

                                eval ownlangvar=\$"${lang}"

                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#notify_lang-info" role="button" aria-expanded="false" aria-controls="notify_lang-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="notify_lang-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_notify_lang_help1}"'<br />
                                        '"${lang_edit_set3_notify_lang_help2}"' <code><span style="font-hight:1.1em;">'"${ownlangvar}"'</span></code><br />
                                        '"${lang_edit_set3_notify_lang_help3}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

    if [ "${dev_mode}" = "true" ]; then
                    # accept_cpdf_license
                    lang_edit_set3_accept_cpdf_license_help4="Now we're releasing the tools for free, under a special not-for-commercial-use license. If you like the tools and want to use them commercially, or need support, licenses are available from Coherent Graphics Ltd. Commercial use involves anything other than private, personal use. Charities and educational institutions still require a license, but one may be obtained at greatly reduced cost - ask us. If you're still not sure if you need a license, ask us."

                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="accept_cpdf_license"><a href="https://community.coherentpdf.com/" onclick="window.open(this.href); return false;" style="color: #BD0010;">cpdf '"${lang_edit_set3_accept_cpdf_license_title}"'</a></label>
                        </div>
                        <div class="col-sm-5">
                            <select name="accept_cpdf_license" id="accept_cpdf_license" class="form-select form-select-sm">'

                                if [[ "${accept_cpdf_license}" == "not_accepted" ]]; then
                                    echo '<option value="not_accepted" selected>'"${lang_edit_set3_accept_cpdf_license_no}"'</option>'
                                else
                                    echo '<option value="not_accepted">'"${lang_edit_set3_accept_cpdf_license_no}"'</option>'
                                fi
                                if [[ "${accept_cpdf_license}" == "accepted" ]]; then
                                    echo '<option value="accepted" selected>'"${lang_edit_set3_accept_cpdf_license_yes}"'</option>'
                                else
                                    echo '<option value="accepted">'"${lang_edit_set3_accept_cpdf_license_yes}"'</option>'
                                fi

                                echo '
                            </select>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#accept_cpdf_license-info" role="button" aria-expanded="false" aria-controls="accept_cpdf_license-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="accept_cpdf_license-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_accept_cpdf_license_help1}"'<br>
                                        '"${lang_edit_set3_accept_cpdf_license_help2}"'<br><br>
                                        <b>'"${lang_edit_set3_accept_cpdf_license_help3}"'</b><br>
                                        <i>"'"${lang_edit_set3_accept_cpdf_license_help4}"'"</i>
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'
    fi

                    echo '
                </div>
            </div>
        </div>
    </div>
    <p>&nbsp;</p><p>&nbsp;</p>'

fi
