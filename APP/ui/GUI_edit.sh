#!/bin/bash
# shellcheck disable=SC2154,SC2016,SC2034

#################################################################################
#   description:    - generates the configuration page for the GUI              #
#   path:            /usr/syno/synoman/webman/3rdparty/synOCR/edit.sh           #
#   © 2026 by geimist                                                           #
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

restoreDatabaseFromInputDir ()
{
# Restore ./etc/synOCR.sqlite from current profile INPUTDIR
# --------------------------------------------------------------
    restore_result="error"
    restore_message=""

    restore_source_db="${INPUTDIR%/}/synOCR.sqlite"
    restore_target_db="${dbPath}"
    restore_timestamp=$(date +"%Y%m%d_%H%M%S")
    restore_backup_db="${INPUTDIR%/}/synOCR_(Backup ${restore_timestamp}).sqlite"
    restore_upgrade_log=""

    if [ -z "${INPUTDIR}" ] || [ ! -d "${INPUTDIR}" ]; then
        restore_message="${lang_edit_restore_error_inputdir}"
        return 1
    fi

    if [ ! -f "${restore_source_db}" ]; then
        restore_message="${lang_edit_restore_error_source_missing} (${restore_source_db})"
        return 1
    fi

    if [ ! -f "${restore_target_db}" ]; then
        restore_message="${lang_edit_restore_error_target_missing} (${restore_target_db})"
        return 1
    fi

    if ! cp -f "${restore_target_db}" "${restore_backup_db}" ; then
        restore_message="${lang_edit_restore_error_backup} (${restore_backup_db})"
        return 1
    fi

    if ! cp -f "${restore_source_db}" "${restore_target_db}" ; then
        restore_message="${lang_edit_restore_error_replace} (${restore_target_db})"
        return 1
    fi

    restore_upgrade_log=$(./upgradeconfig.sh 2>&1)
    if [ "$?" -ne 0 ]; then
        restore_message="${lang_edit_restore_error_upgrade}<br><small>${restore_upgrade_log}</small>"
        return 1
    fi

    /usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh start >/dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        restore_message="${lang_edit_restore_error_restart}"
        return 1
    fi

    restore_result="ok"
    restore_message="${lang_edit_restore_success}<br><small>${lang_edit_restore_success_backup}: ${restore_backup_db}</small>"
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
                                        profile, active, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix, documentSplitPattern, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, apprise_call, apprise_attachment, notify_lang, dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, filedate, tagsymbol, ignoredDate, backup_max, backup_max_type, backup_clean_orphaned, search_nearest_date, date_search_method, clean_up_spaces, img2pdf, DateSearchMinYear, DateSearchMaxYear, splitpagehandling, blank_page_detection_switch, blank_page_detection_mainThreshold, blank_page_detection_widthCropping, blank_page_detection_hightCropping, blank_page_detection_interferenceMaxFilter, blank_page_detection_interferenceMinFilter, blank_page_detection_black_pixel_ratio, blank_page_detection_ignoreText, adjustColorBWthreshold, adjustColorDPI, adjustColorContrast, adjustColorSharpness
                                    ) 
                                        VALUES 
                                    ( 
                                        '${new_profile_value}', '${active}', '${INPUTDIR}', '${OUTPUTDIR}', '${BACKUPDIR}', '${LOGDIR}', '${LOGmax}', '${SearchPraefix}', '${delSearchPraefix}', '${documentSplitPattern}', '${taglist}', '${searchAll}', '${moveTaggedFiles}', '${NameSyntax}', '${ocropt//\'/\'\'}', '${dockercontainer}', '${apprise_call}', '${apprise_attachment}', '${notify_lang}', '${dsmtextnotify}', '${MessageTo}', '${dsmbeepnotify}', '${loglevel}', '${filedate}', '${tagsymbol}', '${ignoredDate}', '${backup_max}', '${backup_max_type}', '${backup_clean_orphaned}', '${search_nearest_date}', '${date_search_method}', '${clean_up_spaces}', '${img2pdf}', '${DateSearchMinYear}', '${DateSearchMaxYear}', '${splitpagehandling}', '${blank_page_detection_switch}', '${blank_page_detection_mainThreshold}', '${blank_page_detection_widthCropping}', '${blank_page_detection_hightCropping}', '${blank_page_detection_interferenceMaxFilter}', '${blank_page_detection_interferenceMinFilter}', '${blank_page_detection_black_pixel_ratio}', '${blank_page_detection_ignoreText}', '${adjustColorBWthreshold}', '${adjustColorDPI}', '${adjustColorContrast}', '${adjustColorSharpness}'
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
# -> Restore DB from INPUTDIR:
# --------------------------------------------------------------
if [[ "${page}" == "edit-restore-query" ]] || [[ "${page}" == "edit-restore" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'"${lang_popup_note}"'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>'

                if [ -z "${getprofile}" ] ; then
                    restore_profile_id="1"
                else
                    restore_profile_id="${getprofile}"
                fi
                INPUTDIR=$(sqlite3 -separator $'\t' "${dbPath}" "SELECT INPUTDIR FROM config WHERE profile_ID='${restore_profile_id}' LIMIT 1;" | awk -F'\t' '{print $1}')
                restore_source_db="${INPUTDIR%/}/synOCR.sqlite"

                if [[ "${page}" == "edit-restore-query" ]]; then
                    if [ -f "${restore_source_db}" ]; then
                        echo '
                    <div class="modal-body text-center">
                        <p class="text-warning">
                            <strong>'"${lang_attention}"':</strong><br />
                            '"${lang_edit_restore_warn_all_profiles}"'
                        </p>
                        <p>
                            '"${lang_edit_restore_confirm_source}"'<br />
                            <code>'"${restore_source_db}"'</code>
                        </p>
                    </div>
                    <div class="modal-footer bg-light">
                        <a href="index.cgi?page=edit-restore" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_yes}"'</a>&nbsp;&nbsp;&nbsp;
                        <a href="index.cgi?page=edit&value=" class="btn btn-secondary btn-sm">'"${lang_button_abort}"'</a>
                    </div>'
                    else
                        echo '
                    <div class="modal-body text-center">
                        <p class="text-danger">
                            '"${lang_edit_restore_error_source_missing}"'<br />
                            <code>'"${restore_source_db}"'</code>
                        </p>
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_buttonnext}"'...</button>
                    </div>'
                    fi
                elif [[ "${page}" == "edit-restore" ]]; then
                    restoreDatabaseFromInputDir
                    # Persist restore result and show it as alert on page=edit after redirect
                    restore_edit_profile=$(sqlite3 "${dbPath}" "SELECT profile_ID FROM config ORDER BY profile_ID ASC LIMIT 1" 2>/dev/null)
                    [ -z "${restore_edit_profile}" ] && restore_edit_profile="1"

                    restore_notice=$(echo "${restore_message}" | sed -e 's/<[^>]*>//g' -e 's/[[:space:]]\+/ /g')
                    "${set_var}" "${var}" "restore_status" "${restore_result}"
                    "${set_var}" "${var}" "restore_notice" "${restore_notice}"
                    "${set_var}" "${var}" "getprofile" "${restore_edit_profile}"
                    "${set_var}" "${var}" "encode_getprofile" "${restore_edit_profile}"

                    echo '
                    <div class="modal-body text-center">
                        <p>'"${lang_main_reload_manualy}"' ...</p>
                        <p><a href="index.cgi?page=edit&getprofile='"${restore_edit_profile}"'" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_buttonnext}"'...</a></p>
                    </div>
                    <script type="text/javascript">
                        window.location.replace("index.cgi?page=edit&getprofile='"${restore_edit_profile}"'");
                    </script>'
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
                                backup_clean_orphaned='${backup_clean_orphaned}',
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
                adjustColorBWthreshold, adjustColorDPI, adjustColorContrast, adjustColorSharpness, backup_clean_orphaned
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
                adjustColorBWthreshold, adjustColorDPI, adjustColorContrast, adjustColorSharpness, backup_clean_orphaned
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
        backup_clean_orphaned=$(echo "${sqlerg}" | awk -F'\t' '{print $50}')
        [ -z "${backup_clean_orphaned}" ] && backup_clean_orphaned=false

    # read global values:
        inotify_delay=$(sqlite3 "${dbPath}" "SELECT value_1 FROM system WHERE key='inotify_delay' ")
        dockerimageupdate=$(sqlite3 "${dbPath}" "SELECT value_1 FROM system WHERE key='dockerimageupdate' ")
        backup_orphan_last_check=$(sqlite3 "${dbPath}" "SELECT value_1 FROM system WHERE key='backup_orphan_check_${profile_ID}';")
        backup_orphan_last_count=$(sqlite3 "${dbPath}" "SELECT value_2 FROM system WHERE key='backup_orphan_check_${profile_ID}';")
        [ -z "${backup_orphan_last_count}" ] && backup_orphan_last_count=0

    # -> Headline
    echo '
    <h2 class="synocr-text-blue mt-3">synOCR '"${lang_page2}"'</h2>
    <p>&nbsp;</p>
    <p>'"${lang_edit_summary1}"'</p>
    <p>'"${lang_edit_summary2}"'</p>
    <p>'"${lang_edit_summary3}"'</p>
    <p>'"${lang_edit_summary4}"' ('"${lang_example}"' <code>/volume1/…</code>)</p>'

        if [ -n "${restore_status}" ] ; then
            if [ "${restore_status}" = "ok" ]; then
                restore_alert_class="alert-success"
            else
                restore_alert_class="alert-danger"
            fi
            echo '<div class="alert '"${restore_alert_class}"' mt-2 mb-3" role="alert">'"${restore_notice}"'</div>'
            "${set_var}" "${var}" "restore_status" ""
            "${set_var}" "${var}" "restore_notice" ""
        fi

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
            <select name="getprofile" id="getprofile" class="form-select form-select-sm" onchange="handleProfileSelectionChange(this)">
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
                                echo '<input type="text" name="INPUTDIR" id="INPUTDIR" class="form-control form-control-sm" value="'"${INPUTDIR}"'" data-initial-path="'"${INPUTDIR}"'" onblur="updatePathStatusIcon('\''INPUTDIR'\'')" />'
                            else
                                echo '<input type="text" name="INPUTDIR" id="INPUTDIR" class="form-control form-control-sm" value="" data-initial-path="" onblur="updatePathStatusIcon('\''INPUTDIR'\'')" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "${INPUTDIR}" ]; then
                                    echo '<img id="INPUTDIR-status" data-server-valid="true" src="images/status_green@geimist.svg" height="18" width="18" class="me-3"/>'
                                else
                                    echo '<img id="INPUTDIR-status" data-server-valid="false" src="images/status_error@geimist.svg" height="18" width="18" class="me-3"/>'
                                fi
                                echo '

                                <button type="button" class="btn btn-outline-secondary btn-sm me-2" onclick="openFolderPicker('INPUTDIR')">🔎</button>
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
                                echo '<input type="text" name="OUTPUTDIR" id="OUTPUTDIR" class="form-control form-control-sm" value="'"${OUTPUTDIR}"'" data-initial-path="'"${OUTPUTDIR}"'" onblur="updatePathStatusIcon('\''OUTPUTDIR'\'')" />'
                            else
                                echo '<input type="text" name="OUTPUTDIR" id="OUTPUTDIR" class="form-control form-control-sm" value="" data-initial-path="" onblur="updatePathStatusIcon('\''OUTPUTDIR'\'')" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "${OUTPUTDIR}" ]; then
                                    echo '<img id="OUTPUTDIR-status" data-server-valid="true" src="images/status_green@geimist.svg" height="18" width="18" class="me-3"/>'
                                else
                                    echo '<img id="OUTPUTDIR-status" data-server-valid="false" src="images/status_error@geimist.svg" height="18" width="18" class="me-3"/>'
                                fi
                                echo '

                                <button type="button" class="btn btn-outline-secondary btn-sm me-2" onclick="openFolderPicker('OUTPUTDIR')">🔎</button>
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
                                echo '<input type="text" name="BACKUPDIR" id="BACKUPDIR" class="form-control form-control-sm" value="'"${BACKUPDIR}"'" data-initial-path="'"${BACKUPDIR}"'" onblur="updatePathStatusIcon('\''BACKUPDIR'\'')" />'
                            else
                                echo '<input type="text" name="BACKUPDIR" id="BACKUPDIR" class="form-control form-control-sm" value="" data-initial-path="" onblur="updatePathStatusIcon('\''BACKUPDIR'\'')" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "${BACKUPDIR}" ]; then
                                    echo '<img id="BACKUPDIR-status" data-server-valid="true" src="images/status_green@geimist.svg" height="18" width="18" class="me-3"/>'
                                else
                                    echo '<img id="BACKUPDIR-status" data-server-valid="false" src="images/status_error@geimist.svg" height="18" width="18" class="me-3"/>'
                                fi
                                echo '

                                <button type="button" class="btn btn-outline-secondary btn-sm me-2" onclick="openFolderPicker('BACKUPDIR')">🔎</button>
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
                                echo '<input type="text" name="LOGDIR" id="LOGDIR" class="form-control form-control-sm" value="'"${LOGDIR}"'" data-initial-path="'"${LOGDIR}"'" onblur="updatePathStatusIcon('\''LOGDIR'\'')" />'
                            else
                                echo '<input type="text" name="LOGDIR" id="LOGDIR" class="form-control form-control-sm" value="" data-initial-path="" onblur="updatePathStatusIcon('\''LOGDIR'\'')" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "${LOGDIR}" ]; then
                                    echo '<img id="LOGDIR-status" data-server-valid="true" src="images/status_green@geimist.svg" height="18" width="18" class="me-3"/>'
                                else
                                    echo '<img id="LOGDIR-status" data-server-valid="false" src="images/status_error@geimist.svg" height="18" width="18" class="me-3"/>'
                                fi
                                echo '

                                <button type="button" class="btn btn-outline-secondary btn-sm me-2" onclick="openFolderPicker('LOGDIR')">🔎</button>
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

                    # OCR Rename-Syntax (chip editor: hidden canonical value + visual + palette)
                    _ns_val="${NameSyntax//&/&amp;}"
                    _ns_val="${_ns_val//\"/&quot;}"
                    _ns_val="${_ns_val//</&lt;}"
                    _ns_val="${_ns_val//>/&gt;}"
                    # Token labels for the editor are read from the palette (data-token) in the browser; no server-side JSON required.

                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="NameSyntax-visual">'"${lang_edit_set2_renamesyntax_title}"'</label>
                        </div>
                        <div class="col-sm-5">'
                            echo '<input type="hidden" name="NameSyntax" id="NameSyntax-hidden" value="'"${_ns_val}"'" />
                            <div class="synocr-namesyntax-editor-wrap">
                                <div id="NameSyntax-visual" class="form-control form-control-sm synocr-namesyntax-editor" contenteditable="true" role="textbox" aria-multiline="false" spellcheck="false" tabindex="0"></div>
                            </div>
                            <div id="NameSyntax-palette" class="synocr-namesyntax-palette d-flex flex-wrap gap-1 mt-2">
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§docr" title="§docr">'"${lang_edit_set2_renamesyntax_chip_docr}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§mocr" title="§mocr">'"${lang_edit_set2_renamesyntax_chip_mocr}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§yocr2" title="§yocr2">'"${lang_edit_set2_renamesyntax_chip_yocr2}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§yocr4" title="§yocr4">'"${lang_edit_set2_renamesyntax_chip_yocr4}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§ssnow" title="§ssnow">'"${lang_edit_set2_renamesyntax_chip_ssnow}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§mmnow" title="§mmnow">'"${lang_edit_set2_renamesyntax_chip_mmnow}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§hhnow" title="§hhnow">'"${lang_edit_set2_renamesyntax_chip_hhnow}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§dnow" title="§dnow">'"${lang_edit_set2_renamesyntax_chip_dnow}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§mnow" title="§mnow">'"${lang_edit_set2_renamesyntax_chip_mnow}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§ynow2" title="§ynow2">'"${lang_edit_set2_renamesyntax_chip_ynow2}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§ynow4" title="§ynow4">'"${lang_edit_set2_renamesyntax_chip_ynow4}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§sssource" title="§sssource">'"${lang_edit_set2_renamesyntax_chip_sssource}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§mmsource" title="§mmsource">'"${lang_edit_set2_renamesyntax_chip_mmsource}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§hhsource" title="§hhsource">'"${lang_edit_set2_renamesyntax_chip_hhsource}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§dsource" title="§dsource">'"${lang_edit_set2_renamesyntax_chip_dsource}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§msource" title="§msource">'"${lang_edit_set2_renamesyntax_chip_msource}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§ysource2" title="§ysource2">'"${lang_edit_set2_renamesyntax_chip_ysource2}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§ysource4" title="§ysource4">'"${lang_edit_set2_renamesyntax_chip_ysource4}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§tag" title="§tag">'"${lang_edit_set2_renamesyntax_chip_tag}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§tit" title="§tit">'"${lang_edit_set2_renamesyntax_chip_tit}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§pagecount" title="§pagecount">'"${lang_edit_set2_renamesyntax_chip_pagecount}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§pagecounttotal" title="§pagecounttotal">'"${lang_edit_set2_renamesyntax_chip_pagecounttotal}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§filecounttotal" title="§filecounttotal">'"${lang_edit_set2_renamesyntax_chip_filecounttotal}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§pagecountprofile" title="§pagecountprofile">'"${lang_edit_set2_renamesyntax_chip_pagecountprofile}"'</span>
                                <span draggable="true" class="synocr-namesyntax-palette-item" data-token="§filecountprofile" title="§filecountprofile">'"${lang_edit_set2_renamesyntax_chip_filecountprofile}"'</span>
                            </div>'
                            echo '<script src="template/synocr_namesyntax_editor.js?v=8"></script>'
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
                                    <div class="synocr-namesyntax-help-text">
                                        <p class="mb-2">'"${lang_edit_set2_renamesyntax_help1}"'</p>
                                        <p class="mb-2">'"${lang_edit_set2_renamesyntax_help2}"'</p>
                                        <p class="mb-3 text-muted small">'"${lang_edit_set2_renamesyntax_help3}"'</p>
                                        <div class="table-responsive mb-3">
                                            <table class="table table-sm table-bordered synocr-namesyntax-help-table mb-0">
                                                <thead>
                                                    <tr>
                                                        <th scope="col">'"${lang_edit_set2_renamesyntax_help_th_gui}"'</th>
                                                        <th scope="col">'"${lang_edit_set2_renamesyntax_help_th_yaml}"'</th>
                                                        <th scope="col">'"${lang_edit_set2_renamesyntax_help_th_desc}"'</th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_docr}"'</td><td><code>§docr</code></td><td>'"${lang_edit_set2_renamesyntax_help4}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_mocr}"'</td><td><code>§mocr</code></td><td>'"${lang_edit_set2_renamesyntax_help5}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_yocr2}"'</td><td><code>§yocr2</code></td><td>'"${lang_edit_set2_renamesyntax_help6a}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_yocr4}"'</td><td><code>§yocr4</code></td><td>'"${lang_edit_set2_renamesyntax_help6b}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_ssnow}"'</td><td><code>§ssnow</code></td><td>'"${lang_edit_set2_renamesyntax_help22}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_mmnow}"'</td><td><code>§mmnow</code></td><td>'"${lang_edit_set2_renamesyntax_help23}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_hhnow}"'</td><td><code>§hhnow</code></td><td>'"${lang_edit_set2_renamesyntax_help24}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_dnow}"'</td><td><code>§dnow</code></td><td>'"${lang_edit_set2_renamesyntax_help7}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_mnow}"'</td><td><code>§mnow</code></td><td>'"${lang_edit_set2_renamesyntax_help8}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_ynow2}"'</td><td><code>§ynow2</code></td><td>'"${lang_edit_set2_renamesyntax_help9a}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_ynow4}"'</td><td><code>§ynow4</code></td><td>'"${lang_edit_set2_renamesyntax_help9b}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_sssource}"'</td><td><code>§sssource</code></td><td>'"${lang_edit_set2_renamesyntax_help25}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_mmsource}"'</td><td><code>§mmsource</code></td><td>'"${lang_edit_set2_renamesyntax_help26}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_hhsource}"'</td><td><code>§hhsource</code></td><td>'"${lang_edit_set2_renamesyntax_help27}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_dsource}"'</td><td><code>§dsource</code></td><td>'"${lang_edit_set2_renamesyntax_help10}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_msource}"'</td><td><code>§msource</code></td><td>'"${lang_edit_set2_renamesyntax_help11}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_ysource2}"'</td><td><code>§ysource2</code></td><td>'"${lang_edit_set2_renamesyntax_help12a}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_ysource4}"'</td><td><code>§ysource4</code></td><td>'"${lang_edit_set2_renamesyntax_help12b}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_tag}"'</td><td><code>§tag</code></td><td>'"${lang_edit_set2_renamesyntax_help13}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_tit}"'</td><td><code>§tit</code></td><td>'"${lang_edit_set2_renamesyntax_help14}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_pagecount}"'</td><td><code>§pagecount</code></td><td>'"${lang_edit_set2_renamesyntax_help18a}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_pagecounttotal}"'</td><td><code>§pagecounttotal</code></td><td>'"${lang_edit_set2_renamesyntax_help18}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_filecounttotal}"'</td><td><code>§filecounttotal</code></td><td>'"${lang_edit_set2_renamesyntax_help19}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_pagecountprofile}"'</td><td><code>§pagecountprofile</code></td><td>'"${lang_edit_set2_renamesyntax_help20}"'</td></tr>
                                                    <tr><td>'"${lang_edit_set2_renamesyntax_chip_filecountprofile}"'</td><td><code>§filecountprofile</code></td><td>'"${lang_edit_set2_renamesyntax_help21}"'</td></tr>
                                                </tbody>
                                            </table>
                                        </div>
                                        <p class="mb-1"><small>&gt;&gt;<strong>§yocr4-§mocr-§docr_§tag_§tit</strong>&lt;&lt; '"${lang_edit_set2_renamesyntax_help15}"'</small></p>
                                        <p class="mb-2"><small>'"${lang_example}"' &gt;&gt;<strong>2018-12-09_#Rechnung_00376.pdf</strong>&lt;&lt;</small></p>
                                        <p class="mb-0 small text-muted">'"${lang_edit_set2_renamesyntax_help17}"'</p>
                                    </div>
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

                    # BACKUP ORPHAN CLEANUP
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="backup_clean_orphaned">'"${lang_edit_set3_backup_clean_orphaned_title}"'</label>
                        </div>
                        <div class="col-sm-5">
                            <div class="form-check form-switch">
                                <input type="hidden" name="backup_clean_orphaned" value="false">
                                <input class="form-check-input" type="checkbox" role="switch" id="backup_clean_orphaned"
                                    name="backup_clean_orphaned" value="true"'; \
                                    [[ "${backup_clean_orphaned}" == "true" ]] && echo -n ' checked'; \
                                    echo '>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#backup_clean_orphaned-info" role="button" aria-expanded="false" aria-controls="backup_clean_orphaned-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="backup_clean_orphaned-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '"${lang_edit_set3_backup_clean_orphaned_help1}"'<br /><br />
                                        '"${lang_edit_set3_backup_clean_orphaned_help2}"'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>
                    <div class="row mb-3">
                        <div class="col-sm-10">
                            <small class="text-muted">'
                    if [ -n "${backup_orphan_last_check}" ]; then
                        printf "${lang_edit_set3_backup_orphan_status}" "${backup_orphan_last_count}" "${backup_orphan_last_check}"
                    else
                        echo "${lang_edit_set3_backup_orphan_status_never}"
                    fi
                    echo '</small>
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

                    # folder picker JS:
                    OUTPUT=$(cat << 'EOF'
                </div>
            </div>
        </div>
    </div>
    <!-- Folder Picker Modal -->
    <div class="modal fade" id="folderPickerModal" tabindex="-1" aria-labelledby="folderPickerModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-lg synocr-folderpicker-modal">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="folderPickerModalLabel">lang_edit_set1_folderpicker_titel</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div id="folderContent" class="border p-3 synocr-folderpicker-content" style="height: 300px; overflow-y: auto;">
                        <!-- Folder list will be loaded here -->
                    </div>
                    <div id="folderPickerCreateSection" class="mt-3 border-top pt-3">
                        <div class="form-check form-switch mb-2">
                            <input class="form-check-input" type="checkbox" role="switch" id="folderPickerCreateEnable" disabled onchange="updateFolderPickerCreateControls()">
                            <label class="form-check-label" for="folderPickerCreateEnable">lang_edit_set1_folderpicker_create_enable</label>
                        </div>
                        <div class="mb-0">
                            <label for="folderPickerCreateName" class="form-label small mb-1">lang_edit_set1_folderpicker_create_name_label</label>
                            <input type="text" class="form-control form-control-sm" id="folderPickerCreateName" disabled autocomplete="off">
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">lang_button_abort</button>
                    <button type="button" class="btn btn-primary" onclick="selectCurrentFolder()">lang_edit_set1_folderpicker_titel</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Folder Picker JavaScript -->
    <script type="text/javascript">
        var editPageIsDirty = false;
        var currentProfileSelection = "";
        var dirtyWarningMessage = "lang_edit_unsaved_changes_warning";

        function markEditPageDirty(event) {
            var target = event && event.target ? event.target : null;
            if (target && target.id === "getprofile") {
                return;
            }
            editPageIsDirty = true;
        }

        function resetEditPageDirty() {
            editPageIsDirty = false;
        }

        function handleProfileSelectionChange(selectElement) {
            if (!selectElement) return;
            var selectedValue = selectElement.value;

            if (!currentProfileSelection) {
                currentProfileSelection = selectedValue;
            }

            if (selectedValue === currentProfileSelection) {
                return;
            }

            if (editPageIsDirty) {
                var proceed = window.confirm(dirtyWarningMessage);
                if (!proceed) {
                    selectElement.value = currentProfileSelection;
                    return;
                }
            }

            currentProfileSelection = selectedValue;
            resetEditPageDirty();
            document.getElementById("loading").style.display = "inline-block";
            selectElement.form.submit();
        }

        window.addEventListener("beforeunload", function(event) {
            if (!editPageIsDirty) return;
            event.preventDefault();
            event.returnValue = dirtyWarningMessage;
            return dirtyWarningMessage;
        });

        document.addEventListener("DOMContentLoaded", function() {
            var profileSelect = document.getElementById("getprofile");
            if (profileSelect) {
                currentProfileSelection = profileSelect.value;
            }

            var editableFields = document.querySelectorAll("input, select, textarea");
            editableFields.forEach(function(field) {
                field.addEventListener("input", markEditPageDirty);
                field.addEventListener("change", markEditPageDirty);
            });

            var forms = document.querySelectorAll("form");
            forms.forEach(function(form) {
                form.addEventListener("submit", function(event) {
                    var submitter = event.submitter || document.activeElement;
                    if (submitter && submitter.name === "page" && submitter.value === "edit-save") {
                        resetEditPageDirty();
                        return;
                    }

                    if (submitter && submitter.id === "getprofile") {
                        return;
                    }

                    resetEditPageDirty();
                });
            });
        });

        var folderPickerCurrentInput = null;
        var currentFolderPath = "";
        var sharesMap = {};
        var sharesRealMap = {};
        var folderPickerTitles = {
            INPUTDIR: "FOLDERPICKER_TITLE_INPUTDIR",
            OUTPUTDIR: "FOLDERPICKER_TITLE_OUTPUTDIR",
            BACKUPDIR: "FOLDERPICKER_TITLE_BACKUPDIR",
            LOGDIR: "FOLDERPICKER_TITLE_LOGDIR"
        };
        var folderPickerDefaultTitle = "lang_edit_set1_folderpicker_titel";
        var folderPickerCreatePlaceholders = {
            INPUTDIR: "FOLDERPICKER_PLACEHOLDER_INPUTDIR",
            OUTPUTDIR: "FOLDERPICKER_PLACEHOLDER_OUTPUTDIR",
            BACKUPDIR: "FOLDERPICKER_PLACEHOLDER_BACKUPDIR",
            LOGDIR: "FOLDERPICKER_PLACEHOLDER_LOGDIR"
        };
        var folderPickerDefaultPlaceholder = "FOLDERPICKER_PLACEHOLDER_OUTPUTDIR";
        var folderPickerCreateMsg = {
            noParent: "lang_edit_set1_folderpicker_create_no_parent",
            nameEmpty: "lang_edit_set1_folderpicker_create_name_empty",
            nameInvalid: "lang_edit_set1_folderpicker_create_name_invalid",
            failed: "lang_edit_set1_folderpicker_create_failed",
            exists: "lang_edit_set1_folderpicker_create_exists",
            denied: "lang_edit_set1_folderpicker_create_denied"
        };

        function resetFolderPickerCreateUI() {
            var enableEl = document.getElementById("folderPickerCreateEnable");
            var nameEl = document.getElementById("folderPickerCreateName");
            if (enableEl) {
                enableEl.checked = false;
            }
            if (nameEl) {
                nameEl.value = "";
            }
            updateFolderPickerCreateControls();
        }

        function updateFolderPickerCreateControls() {
            var enableEl = document.getElementById("folderPickerCreateEnable");
            var nameEl = document.getElementById("folderPickerCreateName");
            if (!enableEl || !nameEl) return;
            var hasParent = !!currentFolderPath;
            enableEl.disabled = !hasParent;
            if (!hasParent) {
                enableEl.checked = false;
            }
            nameEl.disabled = !hasParent || !enableEl.checked;
        }

        function isValidParentForCreate(parentFullPath) {
            if (!parentFullPath) return false;
            var parentSharePath = getRelativePath(parentFullPath);
            if (parentSharePath === parentFullPath && !parentFullPath.startsWith("/volume")) {
                return false;
            }
            return true;
        }

        function mapCurrentPathToVolumePath(path) {
            var finalPath = path;
            if (!finalPath.startsWith("/volume")) {
                var parts = finalPath.split("/");
                var shareName = parts[1];
                if (shareName && sharesMap[shareName]) {
                    finalPath = sharesMap[shareName] + finalPath.substring(shareName.length + 1);
                }
            }
            return finalPath;
        }

        function validateNewFolderName(name) {
            var trimmed = (name || "").trim();
            if (!trimmed) {
                return folderPickerCreateMsg.nameEmpty;
            }
            if (trimmed.length > 255) {
                return folderPickerCreateMsg.nameInvalid;
            }
            if (/[\/\\]/.test(trimmed) || trimmed === ".." || trimmed.indexOf("..") !== -1) {
                return folderPickerCreateMsg.nameInvalid;
            }
            if (/^\.|\.$/.test(trimmed)) {
                return folderPickerCreateMsg.nameInvalid;
            }
            return null;
        }

        function mapCreateFolderError(errorCode) {
            var code = parseInt(errorCode, 10);
            if (code === 1104) {
                return folderPickerCreateMsg.exists;
            }
            if (code === 117 || code === 119) {
                return folderPickerCreateMsg.denied;
            }
            if (errorCode) {
                return folderPickerCreateMsg.failed + " (" + errorCode + ")";
            }
            return folderPickerCreateMsg.failed;
        }

        function createSubfolder(parentFullPath, folderName, callback) {
            if (!isValidParentForCreate(parentFullPath)) {
                callback(folderPickerCreateMsg.noParent);
                return;
            }
            var parentSharePath = getRelativePath(parentFullPath);
            resolveSynoTokenForFolderPicker(function(synoToken) {
                if (!synoToken) {
                    callback(folderPickerCreateMsg.failed);
                    return;
                }
                $.ajax({
                    url: "/webapi/entry.cgi",
                    type: "GET",
                    timeout: 10000,
                    data: {
                        api: "SYNO.FileStation.CreateFolder",
                        version: 2,
                        method: "create",
                        folder_path: JSON.stringify([parentSharePath]),
                        name: JSON.stringify([folderName]),
                        SynoToken: synoToken
                    },
                    success: function(response) {
                        if (response && response.success) {
                            var newFullPath = normalizeFolderPath(parentFullPath + "/" + folderName);
                            callback(null, newFullPath);
                            return;
                        }
                        var errorCode = response.error ? response.error.code : "unknown";
                        callback(mapCreateFolderError(errorCode));
                    },
                    error: function(xhr, status) {
                        callback(mapCreateFolderError(status));
                    }
                });
            });
        }

        function openFolderPicker(inputId) {
            console.log("openFolderPicker called with inputId:", inputId);
            if (typeof inputId === 'string') {
                folderPickerCurrentInput = document.getElementById(inputId);
            } else {
                folderPickerCurrentInput = inputId;
            }
            console.log("folderPickerCurrentInput set to:", folderPickerCurrentInput);
            var resolvedId = (typeof inputId === "string") ? inputId : (folderPickerCurrentInput && folderPickerCurrentInput.id);
            var title = (resolvedId && folderPickerTitles[resolvedId]) ? folderPickerTitles[resolvedId] : folderPickerDefaultTitle;
            $("#folderPickerModalLabel").text(title);
            var placeholder = (resolvedId && folderPickerCreatePlaceholders[resolvedId])
                ? folderPickerCreatePlaceholders[resolvedId]
                : folderPickerDefaultPlaceholder;
            $("#folderPickerCreateName").attr("placeholder", placeholder);
            currentFolderPath = "";
            sharesMap = {};
            resetFolderPickerCreateUI();
            $("#folderPickerModal").modal("show");
            loadShares();
        }

        function setCurrentPath(path) {
            currentFolderPath = path;
            console.log("currentFolderPath set to:", currentFolderPath);
            updateFolderPickerCreateControls();
        }

        function buildListItemClass(baseClass, itemPath) {
            var activeClass = (itemPath && currentFolderPath === itemPath) ? " active" : "";
            return "list-group-item list-group-item-action " + baseClass + activeClass;
        }

        function getRelativePath(fullPath) {
            var bestMatch = '';
            for (var realPath in sharesRealMap) {
                if (fullPath.startsWith(realPath) && realPath.length > bestMatch.length) {
                    bestMatch = realPath;
                }
            }
            if (bestMatch) {
                return sharesRealMap[bestMatch] + fullPath.substring(bestMatch.length);
            } else {
                return fullPath; // fallback
            }
        }

        /** DSM Web API Guide: SynoToken should be obtained via SYNO.API.Auth method=token in JS (not only parent URL). */
        function getSynoTokenFromUrlFallback() {
            var t = new URLSearchParams(window.location.search).get('SynoToken');
            if (t) return { token: t, source: 'self' };
            if (window.parent !== window) {
                try {
                    t = new URLSearchParams(window.parent.location.search).get('SynoToken');
                    if (t) return { token: t, source: 'parent' };
                } catch (e) {
                    return { token: null, source: 'parent_denied' };
                }
            }
            return { token: null, source: 'none' };
        }

        function resolveSynoTokenForFolderPicker(cb) {
            function tryTokenApi(ver) {
                $.ajax({
                    url: "/webapi/entry.cgi",
                    type: "GET",
                    timeout: 10000,
                    data: { api: "SYNO.API.Auth", version: ver, method: "token" },
                    success: function(resp) {
                        if (resp.success && resp.data && resp.data.synotoken) {
                            cb(resp.data.synotoken);
                            return;
                        }
                        if (ver === 7) {
                            tryTokenApi(6);
                            return;
                        }
                        var fb = getSynoTokenFromUrlFallback();
                        cb(fb.token);
                    },
                    error: function() {
                        if (ver === 7) {
                            tryTokenApi(6);
                            return;
                        }
                        var fb = getSynoTokenFromUrlFallback();
                        cb(fb.token);
                    }
                });
            }
            tryTokenApi(7);
        }

        function setPathStatusIcon(inputId, isValid) {
            var statusIcon = document.getElementById(inputId + "-status");
            if (!statusIcon) return;
            statusIcon.src = isValid ? "images/status_green@geimist.svg" : "images/status_error@geimist.svg";
        }

        function normalizeFolderPath(path) {
            if (!path) return path;
            if (path === "/") return path;
            return path.replace(/\/+$/, "");
        }

        function restoreInitialPathStatusIcon(inputId) {
            var statusIcon = document.getElementById(inputId + "-status");
            if (!statusIcon) return;
            var initialValid = statusIcon.getAttribute("data-server-valid") === "true";
            setPathStatusIcon(inputId, initialValid);
        }

        function mapRealPathToSharePath(path) {
            var bestMatch = "";
            for (var realPath in sharesRealMap) {
                if (path.startsWith(realPath) && realPath.length > bestMatch.length) {
                    bestMatch = realPath;
                }
            }
            if (bestMatch) {
                return sharesRealMap[bestMatch] + path.substring(bestMatch.length);
            }
            return path;
        }

        function validatePathWithFileStation(path, synoToken, cb) {
            var normalizedPath = normalizeFolderPath(path);
            $.ajax({
                url: "/webapi/entry.cgi",
                type: "GET",
                timeout: 10000,
                data: {
                    api: "SYNO.FileStation.List",
                    version: 2,
                    method: "list",
                    folder_path: normalizedPath,
                    limit: 1,
                    SynoToken: synoToken
                },
                success: function(response) {
                    if (response && response.success) {
                        cb(true);
                        return;
                    }

                    // Fallback: /volume*-Pfad auf Share-Pfad mappen und erneut pruefen.
                    if (!normalizedPath.startsWith("/volume")) {
                        cb(false);
                        return;
                    }

                    $.ajax({
                        url: "/webapi/entry.cgi",
                        type: "GET",
                        timeout: 10000,
                        data: {
                            api: "SYNO.FileStation.List",
                            version: 2,
                            method: "list_share",
                            additional: '["name","path","isdir","perm","real_path"]',
                            SynoToken: synoToken
                        },
                        success: function(shareResponse) {
                            if (!(shareResponse && shareResponse.success && shareResponse.data && shareResponse.data.shares)) {
                                cb(false);
                                return;
                            }

                            sharesMap = {};
                            sharesRealMap = {};
                            shareResponse.data.shares.forEach(function(share) {
                                sharesMap[share.name] = share.additional.real_path;
                                sharesRealMap[share.additional.real_path] = share.path;
                            });

                            var mappedPath = mapRealPathToSharePath(normalizedPath);
                            var normalizedMappedPath = normalizeFolderPath(mappedPath);
                            if (normalizedMappedPath === normalizedPath) {
                                cb(false);
                                return;
                            }

                            $.ajax({
                                url: "/webapi/entry.cgi",
                                type: "GET",
                                timeout: 10000,
                                data: {
                                    api: "SYNO.FileStation.List",
                                    version: 2,
                                    method: "list",
                                    folder_path: normalizedMappedPath,
                                    limit: 1,
                                    SynoToken: synoToken
                                },
                                success: function(mappedResponse) {
                                    cb(!!(mappedResponse && mappedResponse.success));
                                },
                                error: function() {
                                    cb(false);
                                }
                            });
                        },
                        error: function() {
                            cb(false);
                        }
                    });
                },
                error: function() {
                    cb(false);
                }
            });
        }

        function updatePathStatusIcon(inputId) {
            var inputElem = document.getElementById(inputId);
            if (!inputElem) return;

            var rawPath = (inputElem.value || "").trim();
            var rawInitialPath = (inputElem.getAttribute("data-initial-path") || "").trim();
            var path = normalizeFolderPath(rawPath);
            var initialPath = normalizeFolderPath(rawInitialPath);

            // Wenn der Wert wieder dem initialen Serverwert entspricht, den initialen Status explizit wiederherstellen.
            if (path === initialPath) {
                restoreInitialPathStatusIcon(inputId);
                return;
            }

            if (!path || path.charAt(0) !== "/") {
                setPathStatusIcon(inputId, false);
                return;
            }

            resolveSynoTokenForFolderPicker(function(synoToken) {
                if (!synoToken) {
                    setPathStatusIcon(inputId, false);
                    return;
                }

                validatePathWithFileStation(path, synoToken, function(isValid) {
                    setPathStatusIcon(inputId, isValid);
                });
            });
        }

        function loadShares() {
            console.log("loadShares called");
            $("#folderContent").html("<div class=\"text-center\"><img src=\"./images/status_loading.gif\" alt=\"Loading...\"></div>");

            resolveSynoTokenForFolderPicker(function(synoToken) {
            if (!synoToken) {
                $("#folderContent").html("<div class=\"alert alert-warning\"><strong>lang_edit_set1_folderpicker_not_available</strong><br><br>lang_edit_set1_folderpicker_csrf_message<br><br>lang_edit_set1_folderpicker_fix_instructions<br>lang_edit_set1_folderpicker_step1<br>lang_edit_set1_folderpicker_step2<br>lang_edit_set1_folderpicker_step3<br><br>lang_edit_set1_folderpicker_alternative</div>");
                return;
            }

            $.ajax({
                url: "/webapi/entry.cgi",
                type: "GET",
                timeout: 10000,
                data: {
                    api: "SYNO.FileStation.List",
                    version: 2,
                    method: "list_share",
                    additional: '["name","path","isdir","perm","real_path"]',
                    SynoToken: synoToken
                },
                success: function(response) {
                    console.log("API Response:", response);
                    if (response.success) {
                        sharesMap = {};
                        var html = "<ul class=\"list-group synocr-folderpicker-list\">";
                        html += "<li class=\"list-group-item synocr-folderpicker-section\">lang_edit_set1_folderpicker_available_shares:</li>";
                        // Add shares
                        if (response.data && response.data.shares) {
                            response.data.shares.forEach(function(share) {
                                sharesMap[share.name] = share.additional.real_path;
                                sharesRealMap[share.additional.real_path] = share.path;
                                html += "<li class=\"" + buildListItemClass("synocr-folderpicker-item", share.additional.real_path) + "\" onclick=\"setCurrentPath('" + share.additional.real_path + "'); loadFolders('" + share.additional.real_path + "')\"><i class=\"bi bi-folder\"></i> " + share.name + "</li>";
                            });
                        }
                        html += "</ul>";
                        $("#folderContent").html(html);
                        updateFolderPickerCreateControls();
                    } else {
                        var errorCode = response.error ? response.error.code : "unknown";
                        if (errorCode == 119) {
                            $("#folderContent").html("<div class=\"alert alert-warning\"><strong>lang_edit_set1_folderpicker_access_denied</strong><br><br>lang_edit_set1_folderpicker_csrf_message<br><br>lang_edit_set1_folderpicker_fix_instructions<br>lang_edit_set1_folderpicker_step1<br>lang_edit_set1_folderpicker_step2<br>lang_edit_set1_folderpicker_step3<br><br>lang_edit_set1_folderpicker_alternative</div>");
                        } else {
                            $("#folderContent").html("<div class=\"alert alert-danger\">lang_edit_set1_folderpicker_failed_loading_shares " + errorCode + "</div>");
                        }
                        updateFolderPickerCreateControls();
                    }
                },
                error: function(xhr, status, error) {
                    console.log("AJAX Error:", status, error);
                    $("#folderContent").html("<div class=\"alert alert-danger\">lang_edit_set1_folderpicker_failed_loading_shares " + status + "</div>");
                    updateFolderPickerCreateControls();
                }
            });
            });
        }

        function loadFolders(fullPath) {
            console.log("loadFolders called with fullPath:", fullPath);
            var folderPath = getRelativePath(fullPath);
            console.log("using folder_path:", folderPath);
            if (folderPath === fullPath) {
                // Not a valid share path, go back to shares
                loadShares();
                return;
            }
            $("#folderContent").html("<div class=\"text-center\"><img src=\"./images/status_loading.gif\" alt=\"Loading...\"></div>");

            resolveSynoTokenForFolderPicker(function(synoToken) {
            if (!synoToken) {
                $("#folderContent").html("<div class=\"alert alert-warning\"><strong>lang_edit_set1_folderpicker_not_available</strong><br><br>lang_edit_set1_folderpicker_csrf_message<br><br>lang_edit_set1_folderpicker_fix_instructions<br>lang_edit_set1_folderpicker_step1<br>lang_edit_set1_folderpicker_step2<br>lang_edit_set1_folderpicker_step3<br><br>lang_edit_set1_folderpicker_alternative</div>");
                return;
            }
            $.ajax({
                url: "/webapi/entry.cgi",
                type: "GET",
                timeout: 10000,
                data: {
                    api: "SYNO.FileStation.List",
                    version: 2,
                    method: "list",
                    folder_path: folderPath,
                    additional: '["name","path","isdir","perm"]',
                    sort_by: "name",
                    sort_direction: "asc",
                    limit: 100,
                    SynoToken: synoToken
                },
                success: function(response) {
                    console.log("API Response:", response);
                    if (response.success) {
                        var html = "<ul class=\"list-group synocr-folderpicker-list\">";
                        // Add back to shares button
                        html += "<li class=\"" + buildListItemClass("synocr-folderpicker-nav", "__shares__") + "\" onclick=\"setCurrentPath(''); loadShares()\"><i class=\"bi bi-arrow-left\"></i> lang_edit_set1_folderpicker_back_to_shares</li>";
                        // Add parent folder if not root
                        if (folderPath !== "/") {
                            var parentFullPath = fullPath.substring(0, fullPath.lastIndexOf("/")) || "/volume1";
                            html += "<li class=\"" + buildListItemClass("synocr-folderpicker-nav", parentFullPath) + "\" onclick=\"setCurrentPath('" + parentFullPath + "'); loadFolders('" + parentFullPath + "')\"><i class=\"bi bi-arrow-up\"></i> ..</li>";
                        }
                        // Add folders
                        if (response.data && response.data.files) {
                            response.data.files.forEach(function(file) {
                                if (file.isdir) {
                                    var relativeFilePath = file.path.substring(folderPath.length);
                                    var nextFullPath = fullPath + relativeFilePath;
                                    html += "<li class=\"" + buildListItemClass("synocr-folderpicker-item", nextFullPath) + "\" onclick=\"setCurrentPath('" + nextFullPath + "'); loadFolders('" + nextFullPath + "')\"><i class=\"bi bi-folder\"></i> " + file.name + "</li>";
                                }
                            });
                        }
                        html += "</ul>";
                        $("#folderContent").html(html);
                        updateFolderPickerCreateControls();
                    } else {
                        $("#folderContent").html("<div class=\"alert alert-danger\">lang_edit_set1_folderpicker_failed_loading_folders: " + (response.error ? response.error.code : "unknown") + "</div>");
                        updateFolderPickerCreateControls();
                    }
                },
                error: function(xhr, status, error) {
                    console.log("AJAX Error:", status, error);
                    $("#folderContent").html("<div class=\"alert alert-danger\">lang_edit_set1_folderpicker_failed_loading_folders: " + status + "</div>");
                    updateFolderPickerCreateControls();
                }
            });
            });
        }

        function selectFolder(path) {
            console.log("selectFolder called with path:", path, "and currentInput:", folderPickerCurrentInput);
            if (folderPickerCurrentInput) {
                folderPickerCurrentInput.value = path;
                updatePathStatusIcon(folderPickerCurrentInput.id);
                markEditPageDirty({ target: folderPickerCurrentInput });
                $("#folderPickerModal").modal("hide");
            } else {
                console.error("folderPickerCurrentInput is null");
            }
        }

        function selectCurrentFolder() {
            var createEnableEl = document.getElementById("folderPickerCreateEnable");
            var createNameEl = document.getElementById("folderPickerCreateName");
            var createEnabled = createEnableEl && createEnableEl.checked;

            if (createEnabled) {
                if (!currentFolderPath || !isValidParentForCreate(currentFolderPath)) {
                    alert(folderPickerCreateMsg.noParent);
                    return;
                }
                var folderName = createNameEl ? createNameEl.value : "";
                var nameError = validateNewFolderName(folderName);
                if (nameError) {
                    alert(nameError);
                    return;
                }
                folderName = folderName.trim();
                createSubfolder(currentFolderPath, folderName, function(err, newFullPath) {
                    if (err) {
                        alert(err);
                        return;
                    }
                    selectFolder(mapCurrentPathToVolumePath(newFullPath));
                });
                return;
            }

            if (currentFolderPath) {
                selectFolder(mapCurrentPathToVolumePath(currentFolderPath));
            } else {
                console.log("No current folder selected");
            }
        }
    </script>
    <p>&nbsp;</p><p>&nbsp;</p>
EOF
)

    # Sprachvariablen nach dem Heredoc ersetzen, um JS-Kompatibilität zu erhalten
    OUTPUT="${OUTPUT//FOLDERPICKER_TITLE_INPUTDIR/$lang_edit_set1_sourcedir_title}"
    OUTPUT="${OUTPUT//FOLDERPICKER_TITLE_OUTPUTDIR/$lang_edit_set1_targetdir_title}"
    OUTPUT="${OUTPUT//FOLDERPICKER_TITLE_BACKUPDIR/$lang_edit_set1_backupdir_title}"
    OUTPUT="${OUTPUT//FOLDERPICKER_TITLE_LOGDIR/$lang_edit_set1_logdir_title}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_titel/$lang_edit_set1_folderpicker_titel}"
    OUTPUT="${OUTPUT//lang_button_abort/$lang_button_abort}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_not_available/$lang_edit_set1_folderpicker_not_available}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_csrf_message/$lang_edit_set1_folderpicker_csrf_message}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_fix_instructions/$lang_edit_set1_folderpicker_fix_instructions}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_step1/$lang_edit_set1_folderpicker_step1}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_step2/$lang_edit_set1_folderpicker_step2}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_step3/$lang_edit_set1_folderpicker_step3}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_alternative/$lang_edit_set1_folderpicker_alternative}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_access_denied/$lang_edit_set1_folderpicker_access_denied}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_failed_loading_shares/$lang_edit_set1_folderpicker_failed_loading_shares}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_available_shares/$lang_edit_set1_folderpicker_available_shares}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_back_to_shares/$lang_edit_set1_folderpicker_back_to_shares}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_failed_loading_folders/$lang_edit_set1_folderpicker_failed_loading_folders}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_create_enable/$lang_edit_set1_folderpicker_create_enable}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_create_name_label/$lang_edit_set1_folderpicker_create_name_label}"
    OUTPUT="${OUTPUT//FOLDERPICKER_PLACEHOLDER_INPUTDIR/$lang_edit_set1_folderpicker_create_name_placeholder_inputdir}"
    OUTPUT="${OUTPUT//FOLDERPICKER_PLACEHOLDER_OUTPUTDIR/$lang_edit_set1_folderpicker_create_name_placeholder_outputdir}"
    OUTPUT="${OUTPUT//FOLDERPICKER_PLACEHOLDER_BACKUPDIR/$lang_edit_set1_folderpicker_create_name_placeholder_backupdir}"
    OUTPUT="${OUTPUT//FOLDERPICKER_PLACEHOLDER_LOGDIR/$lang_edit_set1_folderpicker_create_name_placeholder_logdir}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_create_no_parent/$lang_edit_set1_folderpicker_create_no_parent}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_create_name_empty/$lang_edit_set1_folderpicker_create_name_empty}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_create_name_invalid/$lang_edit_set1_folderpicker_create_name_invalid}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_create_failed/$lang_edit_set1_folderpicker_create_failed}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_create_exists/$lang_edit_set1_folderpicker_create_exists}"
    OUTPUT="${OUTPUT//lang_edit_set1_folderpicker_create_denied/$lang_edit_set1_folderpicker_create_denied}"
    OUTPUT="${OUTPUT//lang_edit_unsaved_changes_warning/$lang_edit_unsaved_changes_warning}"

    echo "${OUTPUT}"
fi

INFO_LANG_HELP='
    search="a*b?name[1]\stuff"   # Beispiel: kann beliebige Metazeichen enthalten
    repl="ERSETZT"

    # 1) Backslashes zuerst escapen
    safe=${search//\\/\\\\}

    # 2) dann Glob-Metazeichen escapen
    safe=${safe//\*/\\*}
    safe=${safe//\?/\\?}
    safe=${safe//\[/\\[}
    safe=${safe//\]/\\]}

    # 3) dann sichere Ersetzung
    OUTPUT="${OUTPUT//"$safe"/$repl}"'
