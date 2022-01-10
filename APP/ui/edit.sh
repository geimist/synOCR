#!/bin/bash
# /usr/syno/synoman/webman/3rdparty/synOCR/edit.sh

OLDIFS=$IFS
APPDIR=$(cd $(dirname $0);pwd)
cd ${APPDIR}
#PATH=$PATH:/usr/local/bin:/opt/usr/bin

new_profile ()
{
# In this function a new profile record is written to the DB
# Call: new_profile "profile name"
# --------------------------------------------------------------
    sqliteinfo=$(sqlite3 ./etc/synOCR.sqlite "INSERT INTO config ( profile ) VALUES ( '$1' )")
}


# Check DB (create if necessary / upgrade):
    DBupgradelog=$(./upgradeconfig.sh)

convert2YAML ()
{
# In this function the existing tag list is written to a YAML file
# --------------------------------------------------------------

if [ -f ${SAMPLECONFIGFILE} ]; then
    echo "${SAMPLECONFIGFILE} already exists"
    return 1
fi

if [ -f "$taglist" ]; then
    taglist=$( cat "$taglist" )
else
    # BackUp of the database entry
    echo "➜ BackUp the database entry of the tag list"
    BackUp_taglist="${INPUTDIR%/}/_BackUp_taglist_[profile_$(echo "$profile" | tr -dc "[a-z][A-Z][0-9] .-_")]_$(date +%s).txt"
    echo "$taglist" > "${BackUp_taglist}"
    chmod 755 "${BackUp_taglist}"
fi

taglist2=$( echo "$taglist" | sed -e "s/ /%20/g" | sed -e "s/;/ /g" )    # encode spaces in tags and convert semicolons to spaces (for array)
tagarray=( $taglist2 )   # Transfer tags to array

count=1

samplefilecontent="    ##############################################################################################################
    #
    #                        ${lang_edit_yamlsample_02}
    #
    #   - $lang_edit_yamlsample_03
    #       - $lang_edit_yamlsample_04
    #       - $lang_edit_yamlsample_05
    #   - $lang_edit_yamlsample_06
    #   - $lang_edit_yamlsample_07
    #   - $lang_edit_yamlsample_08 >synOCR_YAMLRULEFILE<
    #
    #   - $lang_edit_yamlsample_09
    #       > \"sampletagrulename\"
    #           - \"sampletagrulename\" $lang_edit_yamlsample_10
    #           - $lang_edit_yamlsample_11
    #           - $lang_edit_yamlsample_12
    #           - $lang_edit_yamlsample_13
    #           - $lang_edit_yamlsample_14
    #       > \"tagname:\"
    #           - $lang_edit_yamlsample_15 >tagname: VALUE< (${lang_edit_yamlsample_16})
    #           - $lang_edit_yamlsample_17
    #           - $lang_edit_yamlsample_17a
    #           - $lang_edit_yamlsample_18 (>tagname:<)
    #       > \"tagname_RegEx:\"
    #           - $lang_edit_yamlsample_15 >tagname_RegEx: RegEx< (${lang_edit_yamlsample_16})
    #           - $lang_edit_yamlsample_17
    #           - $lang_edit_yamlsample_17b
    #           - $lang_edit_yamlsample_18 (>tagname_RegEx:<)
    #       > \"targetfolder:\"
    #           - $lang_edit_yamlsample_19
    #           - $lang_edit_yamlsample_15 >targetfolder: VALUE< (${lang_edit_yamlsample_16})
    #           - $lang_edit_yamlsample_20
    #           - $lang_edit_yamlsample_21 (/volume1/...)
    #           - $lang_edit_yamlsample_22a
    #             $lang_edit_yamlsample_22b
    #           - ${lang_edit_yamlsample_18} (>targetfolder:<)
    #       > \"condition:\"
    #           - $lang_edit_yamlsample_24
    #           - $lang_edit_yamlsample_15 >condition: VALUE<  (${lang_edit_yamlsample_16})
    #           - $lang_edit_yamlsample_25 \"all\" / \"any\" / \"none\"
    #               - \"condition: all\"  > $lang_edit_yamlsample_26
    #               - \"condition: any\"  > $lang_edit_yamlsample_27
    #               - \"condition: none\" > $lang_edit_yamlsample_28
    #           - ${lang_edit_yamlsample_18} (>condition:<)
    #       > \"subrules:\"
    #           - $lang_edit_yamlsample_29 ($lang_edit_yamlsample_30 \"subrules:\")
    #           - $lang_edit_yamlsample_31
    #           - $lang_edit_yamlsample_32
    #       > \"- searchstring:\"
    #           - $lang_edit_yamlsample_15 >- searchstring: VALUE<
    #             $lang_edit_yamlsample_33
    #             ${lang_edit_yamlsample_16}
    #           - $lang_edit_yamlsample_34
    #           - $lang_edit_yamlsample_35
    #       > \"searchtyp:\"
    #           - $lang_edit_yamlsample_15 >searchtyp: VALUE<  (${lang_edit_yamlsample_16})
    #           - $lang_edit_yamlsample_36 \"contains\", \"does not contain\",             (${lang_edit_yamlsample_37})
    #                           \"is\", \"is not\"                              (${lang_edit_yamlsample_38})
    #                           \"starts with\", \"does not starts with\",
    #                           \"ends with\", \"does not ends with\",
    #             $lang_edit_yamlsample_39, (\"contains\")
    #       > \"isRegEx:\"
    #           - $lang_edit_yamlsample_40
    #           - $lang_edit_yamlsample_15 >isRegEx: VALUE<  (${lang_edit_yamlsample_16})
    #           - $lang_edit_yamlsample_36 \"true\" / \"false\"
    #             $lang_edit_yamlsample_39 (\"false\")
    #       > \"source:\"
    #           - $lang_edit_yamlsample_15 >source: VALUE<  (${lang_edit_yamlsample_16})
    #           - $lang_edit_yamlsample_36 \"content\" / \"filename\"
    #             $lang_edit_yamlsample_39 (\"content\")
    #       > \"casesensitive:\"
    #           - $lang_edit_yamlsample_15 >casesensitive: VALUE<  (${lang_edit_yamlsample_16})
    #           - $lang_edit_yamlsample_36 \"true\" / \"false\"
    #             $lang_edit_yamlsample_39 (\"false\")
    #
    #   - ${lang_edit_yamlsample_41}:
    #       https://codebeautify.org/yaml-validator
    #
    ##############################################################################################################"

writesamplefile() {

echo "# synOCR_YAMLRULEFILE   # keep this line!
# ${lang_edit_yamlsample_01}:
# $SAMPLECONFIGFILE

" > ${SAMPLECONFIGFILE}

# Help text with fixed width and closing #:
    echo "➜ write description"
    echo "$samplefilecontent" | while read data
    do
        # Correct counting:
        # ToDo: funktioniert noch nicht zuverlässig …
        lenRAW=${#data}
        stringCLEAN=${data//[ööüßÄÜÖ]/}           # ToDo: keine Ausschlusssuche, sondern nach gültigen ASCII-Zeichen suchen und rest addieren / würde auch Sonderzeichen abdecken
        lenCLEAN=${#stringCLEAN}

    #    lenRAW=$( echo "$data" | wc -c)
    #    lenCLEAN=$( echo "$data" | LC_ALL=C tr -dc '\0-\177' | wc -c)   # lenASCII

        DIFF=$((lenRAW - lenCLEAN))
        DIFF=$((DIFF / 2))
        len=$((110 + DIFF))
        printf "    %-${len}s#\n" "$data" >> "${SAMPLECONFIGFILE}"
    done

    sed -i 's/ > / ➜ /g;s/ - / • /g' "${SAMPLECONFIGFILE}"  # printf kommt mit diesen Zeichen nicht klar (Zählung stimmt nicht)

echo "➜ write sample entry"
echo "

#sample:

#sampletagrulename1:
#    tagname: target_tag
#    targetfolder: \"/<path>/\"
#    tagname_RegEx: \"HUK[[:digit:]]{2}\"
#    condition: all
#    subrules:
#    - searchstring: foundme
#      searchtyp: contains
#      isRegEx: false
#      source: content
#      casesensitive: true
#    - searchstring: dontfoundme
#      searchtyp: is not
#      isRegEx: false
#      source: content
#      casesensitive: false

#-----------------------------------------------------------
# $lang_edit_yamlsample_42
#-----------------------------------------------------------
" >> "${SAMPLECONFIGFILE}"

}
writesamplefile

# convert / write the user config:
echo "➜ convert / write the userconfig"
for i in ${tagarray[@]}; do

    if echo "$i" | grep -q "=" ;then
    # for combination of tag and category
        if echo $(echo "$i" | awk -F'=' '{print $1}') | grep -q  "^§" ;then
            searchtyp=is
        else
            searchtyp=contains
        fi
        i=$(echo $i | sed -e "s/^§//g")
        tagname=$(echo "$i" | awk -F'=' '{print $1}' | sed -e "s/%20/ /g")
        targetfolder=$(echo "$i" | awk -F'=' '{print $2}' | sed -e "s/%20/ /g")
     else
        if echo $(echo "$i" | awk -F'=' '{print $1}') | grep -q  "^§" ;then
            searchtyp=is
        else
            searchtyp=contains
        fi
        i=$(echo $i | sed -e "s/^§//g")
        tagname=$(echo "$i" | sed -e "s/%20/ /g")
    fi

# write YAML:
    echo "$(echo "${tagname}" | sed 's/[^0-9a-zA-Z#!§%&\._-]*//g')_${count}:" >> "${SAMPLECONFIGFILE}"
    echo "    tagname: ${tagname}" >> "${SAMPLECONFIGFILE}"
    echo "    targetfolder: ${targetfolder}" >> "${SAMPLECONFIGFILE}"
    echo "    condition: any" >> "${SAMPLECONFIGFILE}"
    echo "    subrules:" >> "${SAMPLECONFIGFILE}"
    echo "    - searchstring: ${tagname}" >> "${SAMPLECONFIGFILE}"
    echo "      searchtyp: ${searchtyp}" >> "${SAMPLECONFIGFILE}"
    echo "      isRegEx: false" >> "${SAMPLECONFIGFILE}"
    echo "      source: content" >> "${SAMPLECONFIGFILE}"
    echo "      casesensitive: false" >> "${SAMPLECONFIGFILE}"

    count=$((count + 1))
    echo "    - rule No. $count"
done
chmod 755 "${SAMPLECONFIGFILE}"

# Write path to new configfile in DB:
    echo "➜ Write path to the new configfile in DB"
    sSQLupdate="UPDATE config SET taglist='${SAMPLECONFIGFILE}' WHERE profile_ID='$profile_ID' "
    sqlite3 ./etc/synOCR.sqlite "$sSQLupdate"

    return 0
}

# --------------------------------------------------------------
# -> convert existing tag list to YAML file:
# --------------------------------------------------------------
if [[ "$page" == "edit-convert2YAML" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'$lang_popup_note'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>
                <div class="modal-body text-center">'

                    SAMPLECONFIGFILE="${INPUTDIR%/}/_TagConfig_[profile_$(echo "$profile" | tr -dc "[a-z][A-Z][0-9] .-_")].txt"
                    SAMPLECONFIGLOGFILE="${SAMPLECONFIGFILE}_$(date +%s)_convert.log"

                    if [ $loglevel = "2" ] ; then
                        convert2YAML > "${SAMPLECONFIGLOGFILE}"
                        chmod 755 "${SAMPLECONFIGLOGFILE}"
                    else
                        convert2YAML > /dev/null  2>&1
                    fi

                    if [ $? -eq 1 ]; then
                        echo '
                        <p class="text-danger">
                            '$lang_edit_yamlsample_gui_01'<br />
                            '$lang_edit_yamlsample_gui_02'<br /><br />
                            ('$SAMPLECONFIGFILE')
                        </p>'
                    else
                        echo '
                        <p>
                            '$lang_edit_yamlsample_gui_03'<br /><br />
                            ('$SAMPLECONFIGFILE')
                        </p>'
                    fi

                    echo '
                </div>
                <div class="modal-footer bg-light">
                    <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_buttonnext'...</button>
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
if [[ "$page" == "edit-del_profile-query" ]] || [[ "$page" == "edit-del_profile" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'$lang_popup_note'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>'

                if [[ "$page" == "edit-del_profile-query" ]]; then
                    echo '
                    <div class="modal-body text-center">
                        <p>'$lang_edit_delques_1' (<strong>'$profile'</strong>) '$lang_edit_delques_2'</p>
                    </div>
                    <div class="modal-footer bg-light">
                        <a href="index.cgi?page=edit-del_profile" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_yes'</a>&nbsp;&nbsp;&nbsp;
                        <a href="index.cgi?page=edit&value=" class="btn btn-secondary btn-sm">'$lang_button_abort'</a>
                    </div>'

                elif [[ "$page" == "edit-del_profile" ]]; then
                    sqlite3 ./etc/synOCR.sqlite "DELETE FROM config WHERE profile_ID='$profile_ID';"

                    # make the first profile of the DB active next (otherwise a profile name with empty data would be displayed)
                    getprofile=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT profile_ID FROM config ORDER BY profile_ID ASC LIMIT 1" | awk -F'\t' '{print $1}')
                    # getprofile (write to $var without GUI):
                    encode_value=$getprofile
                    decode_value=$(urldecode "$encode_value")
                    "$set_var" "./usersettings/var.txt" "getprofile" "$decode_value"
                    "$set_var" "./usersettings/var.txt" "encode_getprofile" "$encode_value"
                    sleep 1

                    echo '
                    <div class="modal-body text-center">'
                        if [ $(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT count(profile_ID) FROM config WHERE profile_ID='$profile_ID' ") = "0" ] ; then
                            echo '
                            <p>
                                '$lang_edit_profname' <strong>'$profile'</strong> '$lang_edit_delfin2'
                            </p>'
                        else
                            echo '
                            <p class="text-danger">
                                '$lang_edit_deler' (<strong>'$profile'</strong>)!
                            </p>'
                        fi
                        echo '
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_buttonnext'...</button>
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
if [[ "$page" == "edit-dup-profile-query" ]] || [[ "$page" == "edit-dup-profile" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'$lang_popup_note'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>'

                if [[ "$page" == "edit-dup-profile-query" ]]; then
                    echo '
                    <div class="modal-body">
                        <p>'$lang_edit_dup1'</p>
                        <div class="row mb-3">
                            <div class="col">
                                <label for="new_profile_value">'$lang_edit_profname'</label>
                            </div>
                            <div class="col">'
                                if [ -n "$new_profile_value" ]; then
                                    echo '<input type="text" name="new_profile_value" id="new_profile_value" class="form-control form-control-sm" value="'$new_profile_value'" />'
                                else
                                    echo '<input type="text" name="new_profile_value" id="new_profile_value" class="form-control form-control-sm" value="" />'
                                fi
                                echo '
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit-dup-profile" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_edit_create'...</button>&nbsp;&nbsp;&nbsp;
                        <a href="index.cgi?page=edit&value=" class="btn btn-secondary btn-sm">'$lang_button_abort'</a>
                    </div>'

                elif [[ "$page" == "edit-dup-profile" ]]; then
                    echo '
                    <div class="modal-body text-center">'
                        if [ ! -z "$new_profile_value" ] ; then
                            sSQL="SELECT count(profile_ID) FROM config WHERE profile='$new_profile_value' "
                            if [ $(sqlite3 ./etc/synOCR.sqlite "$sSQL") = "0" ] ; then
                                sSQL="INSERT INTO config ( profile, active, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix, documentSplitPattern, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN, dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, filedate, tagsymbol, ignoredDate, backup_max, backup_max_type ) VALUES ( '$new_profile_value', '$active', '$INPUTDIR', '$OUTPUTDIR', '$BACKUPDIR', '$LOGDIR', '$LOGmax', '$SearchPraefix', '$delSearchPraefix', '$documentSplitPattern', '$taglist', '$searchAll', '$moveTaggedFiles', '$NameSyntax', '$(sed -e "s/'/''/g" <<<"$ocropt")', '$dockercontainer', '$PBTOKEN', '$dsmtextnotify', '$MessageTo', '$dsmbeepnotify', '$loglevel', '$filedate', '$tagsymbol', '$ignoredDate', '$backup_max', '$backup_max_type' )"
                                sqlite3 ./etc/synOCR.sqlite "$sSQL"

                                sSQL2="SELECT count(profile_ID) FROM config WHERE profile='$new_profile_value' "

                                if [ $(sqlite3 ./etc/synOCR.sqlite "$sSQL2") = "1" ] ; then
                                    echo '
                                    <p>
                                        '$lang_edit_profname' <strong>'$profile'</strong> '$lang_edit_dup2' <strong>'$new_profile_value'</strong> '$lang_edit_dup3'.
                                    </p>'
                                else
                                    echo '
                                    <p class="text-danger">
                                        '$lang_edit_dup4'
                                    </p>'
                                fi
                            else
                                echo '
                                <p class="text-danger">
                                    '$lang_edit_dup4'<br />
                                    '$lang_edit_dup5' <strong>'$new_profile_value'</strong> '$lang_edit_dup6'
                                </p>'
                            fi
                        else
                            echo '
                            <p class="text-warning">
                                '$lang_edit_dup4'<br />
                                '$lang_edit_dup7'
                            </p>'
                        fi
                        echo '
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_buttonnext'...</button>
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
if [[ "$page" == "edit-new_profile-query" ]] || [[ "$page" == "edit-new_profile" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'$lang_popup_note'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>'

                if [[ "$page" == "edit-new_profile-query" ]]; then
                    echo '
                    <div class="modal-body">
                        <p>'$lang_edit_new1'</p>
                        <div class="row mb-3">
                            <div class="col">
                                <label for="new_profile_value">'$lang_edit_profname'</label>
                            </div>
                            <div class="col">'

                                if [ -n "$new_profile_value" ]; then
                                    echo '<input type="text" name="new_profile_value" id="new_profile_value" class="form-control form-control-sm" value="'$new_profile_value'" />'
                                else
                                    echo '<input type="text" name="new_profile_value" id="new_profile_value" class="form-control form-control-sm" value="" />'
                                fi
                                echo '
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit-new_profile" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_edit_create'...</button>&nbsp;&nbsp;&nbsp;
                        <a href="index.cgi?page=edit&value=" class="btn btn-secondary btn-sm">'$lang_button_abort'</a>
                    </div>'
                elif [[ "$page" == "edit-new_profile" ]]; then
                    echo '
                    <div class="modal-body text-center">'
                        if [ ! -z "$new_profile_value" ] ; then
                            sSQL="SELECT count(profile_ID) FROM config WHERE profile='$new_profile_value' "
                            if [ $(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL") = "0" ] ; then
                                new_profile "$new_profile_value"
                                if [ $(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL") = "1" ] ; then
                                    echo '
                                    <p>
                                        '$lang_edit_new2' <strong>'$new_profile_value'</strong> '$lang_edit_new3'.
                                    </p>'
                                else
                                    echo '
                                    <p class="text-danger">
                                        '$lang_edit_new4'
                                    </p>'
                                fi
                            else
                                echo '
                                <p class="text-danger">
                                    '$lang_edit_new4'<br />
                                    '$lang_edit_dup5' <strong>'$new_profile_value'</strong> '$lang_edit_dup6'
                                </p>'
                            fi
                        else
                            echo '
                            <p class="text-danger">
                                '$lang_edit_new4'<br />
                                '$lang_edit_dup7'
                            </p>'
                        fi
                        echo '
                    </div>
                    <div class="modal-footer bg-light">
                        <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_buttonnext'...</button>
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
if [[ "$page" == "edit-save" ]]; then
    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-validation" tabindex="-1" aria-labelledby="label-validation" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'$lang_popup_note'</h5>
                    <a href="index.cgi" onclick="history.go(-1); event.preventDefault();" class="btn-close" aria-label="Close"></a>
                </div>
                <div class="modal-body text-center">'

                    sSQLupdate="UPDATE config SET profile='$profile', active='$active', INPUTDIR='$INPUTDIR', OUTPUTDIR='$OUTPUTDIR', BACKUPDIR='$BACKUPDIR',
                        LOGDIR='$LOGDIR', LOGmax='$LOGmax', SearchPraefix='$SearchPraefix', delSearchPraefix='$delSearchPraefix', taglist='$taglist', searchAll='$searchAll',
                        moveTaggedFiles='$moveTaggedFiles', NameSyntax='$NameSyntax', ocropt='$(sed -e "s/'/''/g" <<<"$ocropt")', dockercontainer='$dockercontainer', PBTOKEN='$PBTOKEN',
                        dsmtextnotify='$dsmtextnotify', MessageTo='$MessageTo', dsmbeepnotify='$dsmbeepnotify', loglevel='$loglevel', filedate='$filedate', tagsymbol='$tagsymbol',
                        documentSplitPattern='$documentSplitPattern', ignoredDate='$ignoredDate', backup_max='$backup_max', backup_max_type='$backup_max_type' WHERE profile_ID='$profile_ID' "

                    sqlite3 ./etc/synOCR.sqlite "$sSQLupdate"

                    # write global change to table system:
                    sqlite3 ./etc/synOCR.sqlite "UPDATE system SET value_1='$dockerimageupdate' WHERE key='dockerimageupdate' "

                    echo '
                    <p>
                        '$lang_edit_savefin'
                    </p>
                </div>
                <div class="modal-footer bg-light">
                    <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_buttonnext'...</button>
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


if [[ "$page" == "edit" ]]; then
    # Read file contents for variable utilization
    if [ -z "$getprofile" ] ; then
        sSQL="SELECT profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix,
            delSearchPraefix, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN,
            dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, active, filedate, tagsymbol, documentSplitPattern, ignoredDate, backup_max, backup_max_type FROM config WHERE profile_ID='1' "
    else
        sSQL="SELECT profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix,
            delSearchPraefix, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN,
            dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, active, filedate, tagsymbol, documentSplitPattern, ignoredDate, backup_max, backup_max_type FROM config WHERE profile_ID='$getprofile' "
    fi
    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL")

    # Separate record fields:
        profile_ID=$(echo "$sqlerg" | awk -F'\t' '{print $1}')
        timestamp=$(echo "$sqlerg" | awk -F'\t' '{print $2}')
        profile=$(echo "$sqlerg" | awk -F'\t' '{print $3}')
        INPUTDIR=$(echo "$sqlerg" | awk -F'\t' '{print $4}')
        OUTPUTDIR=$(echo "$sqlerg" | awk -F'\t' '{print $5}')
        BACKUPDIR=$(echo "$sqlerg" | awk -F'\t' '{print $6}')
        LOGDIR=$(echo "$sqlerg" | awk -F'\t' '{print $7}')
        LOGmax=$(echo "$sqlerg" | awk -F'\t' '{print $8}')
        SearchPraefix=$(echo "$sqlerg" | awk -F'\t' '{print $9}')
        delSearchPraefix=$(echo "$sqlerg" | awk -F'\t' '{print $10}')
        taglist=$(echo "$sqlerg" | awk -F'\t' '{print $11}')
        searchAll=$(echo "$sqlerg" | awk -F'\t' '{print $12}')
        moveTaggedFiles=$(echo "$sqlerg" | awk -F'\t' '{print $13}')
        NameSyntax=$(echo "$sqlerg" | awk -F'\t' '{print $14}')
        ocropt=$(echo "$sqlerg" | awk -F'\t' '{print $15}')
        dockercontainer=$(echo "$sqlerg" | awk -F'\t' '{print $16}')
        PBTOKEN=$(echo "$sqlerg" | awk -F'\t' '{print $17}')
        dsmtextnotify=$(echo "$sqlerg" | awk -F'\t' '{print $18}')
        MessageTo=$(echo "$sqlerg" | awk -F'\t' '{print $19}')
        dsmbeepnotify=$(echo "$sqlerg" | awk -F'\t' '{print $20}')
        loglevel=$(echo "$sqlerg" | awk -F'\t' '{print $21}')
        active=$(echo "$sqlerg" | awk -F'\t' '{print $22}')
        filedate=$(echo "$sqlerg" | awk -F'\t' '{print $23}')
        tagsymbol=$(echo "$sqlerg" | awk -F'\t' '{print $24}')
        documentSplitPattern=$(echo "$sqlerg" | awk -F'\t' '{print $25}')
        ignoredDate=$(echo "$sqlerg" | awk -F'\t' '{print $26}')
        backup_max=$(echo "$sqlerg" | awk -F'\t' '{print $27}')
        backup_max_type=$(echo "$sqlerg" | awk -F'\t' '{print $28}')

    # read global values:
        dockerimageupdate=$(sqlite3 ./etc/synOCR.sqlite "SELECT value_1 FROM system WHERE key='dockerimageupdate' ")


    # -> Headline
    echo '
    <h2 class="synocr-text-blue mt-3">synOCR '$lang_page2'</h2>
    <p>&nbsp;</p>
    <p>'$lang_edit_summary1'</p>
    <p>'$lang_edit_summary2'</p>
    <p>'$lang_edit_summary3'</p>
    <p>'$lang_edit_summary4'</p>'

        if [ ! -z "$DBupgradelog" ] ; then
            DBupgradelog=$(echo "$DBupgradelog" | sed ':a;N;$!ba;s/\n/<br />/g')
            if echo "$DBupgradelog" | grep -q ERROR ; then
                message_color="color: #BD0010;"
            else
                message_color="color: green;"
            fi
            echo '<p style="'$message_color';">'$lang_edit_dbupdate': '$DBupgradelog' </p>'
        fi

    # Profile selection:
    sSQL="SELECT profile_ID, profile FROM config "
    sqlerg=$(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL")

    echo '
    <p>&nbsp;</p>
    <div class="row mb-3">
        <div class="col-sm-5">
            <label for="getprofile" class="ms-4">'$lang_edit_change_profile'</label>
        </div>
        <div class="col-sm-5">
            <select name="getprofile" id="getprofile" class="form-select form-select-sm">'

                IFS=$'\012'
                for entry in $sqlerg; do
                    IFS=$OLDIFS

                    profile_ID_DB=$(echo "$entry" | awk -F'\t' '{print $1}')
                    profile_DB=$(echo "$entry" | awk -F'\t' '{print $2}')

                    if [[ "$profile_ID" == $profile_ID_DB ]]; then
                        echo '<option value='$profile_ID_DB' selected>'$profile_DB'</option>'
                    else
                        echo '<option value='$profile_ID_DB'>'$profile_DB'</option>'
                    fi
                done
                echo '
            </select>
        </div>
        <div class="col-sm-2">
            <button name="page" value="edit" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_buttonchange'</button>
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
                    <span class="synocr-text-blue">'$lang_edit_set1_title'</span>
                </button>
            </h2>
            <div id="Collapse-01" class="accordion-collapse collapse border-white" aria-labelledby="Heading-01" data-bs-parent="#Accordion-01">
                <div class="accordion-body">'

                    # Profil name
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="profile">'$lang_edit_profname'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "$profile" ]; then
                                echo '<input type="text" name="profile" id="profile" class="form-control form-control-sm" value="'$profile'" />'
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
                                        '$lang_edit_set1_profilename_help'
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
                            <label for="active">'$lang_edit_set1_profile_activ_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="active" id="active" class="form-select form-select-sm">'
                                if [[ "$active" == "1" ]]; then
                                    echo '<option value="1" selected>'$lang_edit_set1_profile_activ'</option>'
                                else
                                    echo '<option value="1">'$lang_edit_set1_profile_activ'</option>'
                                fi
                                if [[ "$active" == "0" ]]; then
                                    echo '<option value="0" selected>'$lang_edit_set1_profile_inactiv'</option>'
                                else
                                    echo '<option value="0">'$lang_edit_set1_profile_inactiv'</option>'
                                fi
                                echo '
                            </select>
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
                                        '$lang_edit_set1_profile_activ_help1'<br />
                                        '$lang_edit_set1_profile_activ_help2'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'
                    # profile ID (write to $var without GUI)
                    "$set_var" "$var" "profile_ID" "$(urldecode "$profile_ID")"
                    "$set_var" "$var" "encode_profile_ID" "$profile_ID"

                    # SOURCEDIR
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="INPUTDIR">'$lang_edit_set1_sourcedir_title'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "$INPUTDIR" ]; then
                                echo '<input type="text" name="INPUTDIR" id="INPUTDIR" class="form-control form-control-sm" value="'$INPUTDIR'" />'
                            else
                                echo '<input type="text" name="INPUTDIR" id="INPUTDIR" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "$INPUTDIR" ]; then
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
                                        '$lang_edit_set1_sourcedir_help1'<br />
                                        '$lang_edit_set1_sourcedir_help2'
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
                            <label for="OUTPUTDIR">'$lang_edit_set1_targetdir_title'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "$OUTPUTDIR" ]; then
                                echo '<input type="text" name="OUTPUTDIR" id="OUTPUTDIR" class="form-control form-control-sm" value="'$OUTPUTDIR'" />'
                            else
                                echo '<input type="text" name="OUTPUTDIR" id="OUTPUTDIR" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "$OUTPUTDIR" ]; then
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
                                        '$lang_edit_set1_targetdir_help1'<br />
                                        '$lang_edit_set1_targetdir_help2'
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
                            <label for="BACKUPDIR">'$lang_edit_set1_backupdir_title'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "$BACKUPDIR" ]; then
                                echo '<input type="text" name="BACKUPDIR" id="BACKUPDIR" class="form-control form-control-sm" value="'$BACKUPDIR'" />'
                            else
                                echo '<input type="text" name="BACKUPDIR" id="BACKUPDIR" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "$BACKUPDIR" ]; then
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
                                        '$lang_edit_set1_backupdir_help1'<br />
                                        '$lang_edit_set1_backupdir_help2'<br />
                                        '$lang_edit_set1_backupdir_help3'
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
                            <label for="LOGDIR">'$lang_edit_set1_logdir_title'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "$LOGDIR" ]; then
                                echo '<input type="text" name="LOGDIR" id="LOGDIR" class="form-control form-control-sm" value="'$LOGDIR'" />'
                            else
                                echo '<input type="text" name="LOGDIR" id="LOGDIR" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">'

                                # folder status:
                                if [ -d "$LOGDIR" ]; then
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
                                        '$lang_edit_set1_logdir_help1'<br />
                                        '$lang_edit_set1_logdir_help2'
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
                    <span class="synocr-text-blue">'$lang_edit_set2_title'</span>
                </button>
            </h2>
            <div id="Collapse-02" class="accordion-collapse collapse border-white" aria-labelledby="Heading-02" data-bs-parent="#Accordion-02">
                <div class="accordion-body">'

                    # ocropt
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="ocropt">'$lang_edit_set2_ocropt_title'</label>
                        </div>
                        <div class="col-sm-5">'
                            if [ -n "$ocropt" ]; then
                                echo '<input type="text" name="ocropt" id="ocropt" class="form-control form-control-sm" value="'$ocropt'" />'
                            else
                                echo '<input type="text" name="ocropt" id="ocropt" class="form-control form-control-sm" value="" />'
                            fi
                            echo '
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
                                        '$lang_edit_set2_ocropt_help1'<br /><br />
                                        <code><span style="background-color:#cccccc;font-hight:1.1em;">-l&nbsp;</span></code>&nbsp;'$lang_edit_set2_ocropt_help5' (deu, eng, deu+eng, ...)<br />
                                        <code><span style="background-color:#cccccc;font-hight:1.1em;">-s&nbsp;</span></code>&nbsp;'$lang_edit_set2_ocropt_help2'<br />
                                        <code><span style="background-color:#cccccc;font-hight:1.1em;">-f&nbsp;</span></code>&nbsp;'$lang_edit_set2_ocropt_help3'<br />
                                        <code><span style="background-color:#cccccc;font-hight:1.1em;">-r&nbsp;</span></code>&nbsp;'$lang_edit_set2_ocropt_help4'<br />
                                        <code><span style="background-color:#cccccc;font-hight:1.1em;">-d&nbsp;</span></code>&nbsp;'$lang_edit_set2_ocropt_help6'<br />
                                        <br /><a href="https://ocrmypdf.readthedocs.io/en/latest/cookbook.html" style="color: #BD0010;">'$lang_edit_set2_ocropt_help7'</a><br />
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
                            <label for="dockercontainer">'$lang_edit_set2_dockerimage_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="dockercontainer" id="dockercontainer" class="form-select form-select-sm">'

                                # local ocrmypdf images:
                                imagelist=($(docker images | sort | awk '/ocrmypdf/ && !/<none>/ {print $1 ":" $2}'))

                                # check for default images and add if necessary:
                                if ! $(echo "${imagelist[@]}" | grep -q "jbarlow83/ocrmypdf:latest" ) ; then
                                    imagelist+=("jbarlow83/ocrmypdf:latest")
                                fi
                                if ! $(echo "${imagelist[@]}" | grep -q "geimist/ocrmypdf-polyglot:latest" ) ; then
                                    imagelist+=("geimist/ocrmypdf-polyglot:latest")
                                fi

                                IFS=$'\012'
                                for entry in ${imagelist[@]}; do
                                    IFS=$OLDIFS
                                    if [[ "$dockercontainer" == "${entry}" ]]; then
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
                                        '$lang_edit_set2_dockerimage_help1'<br />
                                        jbarlow83/ocrmypdf '$lang_edit_set2_dockerimage_help2'<br />
                                        '$lang_edit_set2_dockerimage_help3'<br />
                                        '$lang_edit_set2_dockerimage_help4'
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
                            <label for="dockerimageupdate">'$lang_edit_set2_dockerimageupdate_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="dockerimageupdate" id="dockerimageupdate" class="form-select form-select-sm">'

                                if [[ "$dockerimageupdate" == "0" ]]; then
                                    echo '<option value="0" selected>'$lang_edit_set2_dockerimageupdate_no'</option>'
                                else
                                    echo '<option value="0">'$lang_edit_set2_dockerimageupdate_no'</option>'
                                fi
                                if [[ "$dockerimageupdate" == "1" ]]; then
                                    echo '<option value="1" selected>'$lang_edit_set2_dockerimageupdate_yes'</option>'
                                else
                                    echo '<option value="1">'$lang_edit_set2_dockerimageupdate_yes'</option>'
                                fi

                                echo '
                            </select>
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
                                        '$lang_edit_set2_dockerimageupdate_help1'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # SearchPraefix
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="SearchPraefix">'$lang_edit_set2_searchpref_title'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "$SearchPraefix" ]; then
                                echo '<input type="text" name="SearchPraefix" id="SearchPraefix" class="form-control form-control-sm" value="'$SearchPraefix'" />'
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
                                        '$lang_edit_set2_searchpref_help1'<br />
                                        '$lang_edit_set2_searchpref_help2'<br />
                                        <strong>!</strong> '$lang_edit_set2_searchpref_help3' ( !value )<br />
                                        <strong>$</strong> '$lang_edit_set2_searchpref_help4' ( value$ )
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
                            <label for="delSearchPraefix">.'$lang_edit_set2_delsearchpref_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="delSearchPraefix" id="delSearchPraefix" class="form-select form-select-sm">'

                                if [[ "$delSearchPraefix" == "no" ]]; then
                                    echo '<option value="no" selected>'$lang_edit_set2_delsearchpref_keep'</option>'
                                else
                                    echo '<option value="no">'$lang_edit_set2_delsearchpref_keep'</option>'
                                fi
                                if [[ "$delSearchPraefix" == "yes" ]]; then
                                    echo '<option value="yes" selected>'$lang_edit_set2_delsearchpref_delete'</option>'
                                else
                                    echo '<option value="yes">'$lang_edit_set2_delsearchpref_delete'</option>'
                                fi

                                echo '
                            </select>
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
                                        '$lang_edit_set2_delsearchpref_help1'<br />
                                        '$lang_edit_set2_delsearchpref_help2'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # Document split pattern
                    # echo '
                    # <div class="row mb-3">
                        # <div class="col-sm-5">
                            # <label for="documentSplitPattern">'$lang_edit_set2_documentSplitPattern_title'</label>
                        # </div>
                        # <div class="col-sm-5">'

                             # if [ -n "$documentSplitPattern" ]; then
                                # echo '<input type="text" name="documentSplitPattern" id="documentSplitPattern" class="form-control form-control-sm" value="'$documentSplitPattern'" />'
                            # else
                                # echo '<input type="text" name="documentSplitPattern" id="documentSplitPattern" class="form-control form-control-sm" value="" />'
                            # fi

                            # echo '
                        # </div>
                        # <div class="col-sm-2">
                            # <div class="float-end">
                                # <a data-bs-toggle="collapse" href="#documentSplitPattern-info" role="button" aria-expanded="false" aria-controls="documentSplitPattern-info">
                                    # <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            # </div>
                        # </div>
                    # </div>
                    # <div class="row">
                        # <div class="col-sm-10">
                            # <div class="collapse" id="documentSplitPattern-info">
                                # <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    # <span>
                                    #     '$lang_edit_set2_documentSplitPattern_help1'
                                    # </span>
                                # </div>
                            # </div>
                        # </div>
                        # <div class="col-sm-2"></div>
                    # </div>'

                    # Taglist
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="taglist">'$lang_edit_set2_taglist_title''
                                # ("taglist" does not refer to an external file OR refers to an external file and has max. one line) AND input directory is a valid path
                                if ( [[ ! -f "$taglist" ]] || $([[ -f "$taglist" ]] && [[ $( cat "$taglist" | wc -l ) -le 1 ]]) ) && [ -d "$INPUTDIR" ] ; then
                                    echo '
                                        <br /><br />
                                        <button name="page" value="edit-convert2YAML" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_edit_yamlsample_button'</button>&nbsp;&nbsp;
                                    <a data-bs-toggle="collapse" href="#convert2YAML" role="button" aria-expanded="false" aria-controls="convert2YAML">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>'
                                fi

                                echo '
                            </label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "$taglist" ]; then
                            #    echo '<input type="text" name="taglist" value="'$taglist'" />'
                                echo '<textarea name="taglist" id="taglist" class="form-control" cols="35" rows="4">'$taglist'</textarea>'
                            else
                            #    echo '<input type="text" name="taglist" value="" />'
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
                                        <strong>'$lang_edit_yamlsample_button_help_headline'</strong><br /><br />
                                        '$lang_edit_yamlsample_button_help_01'<br />
                                        '$lang_edit_yamlsample_button_help_02'<br />
                                        '$lang_edit_yamlsample_button_help_03'<br />
                                    </span>
                                </div>
                            </div>

                            <div class="collapse" id="taglist-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '$lang_edit_set2_taglist_help1'<br />
                                        '$lang_edit_set2_taglist_help2'<br />
                                        '$lang_edit_set2_taglist_help2_1'<br />
                                        <strong>'$lang_edit_set2_taglist_help3'</strong><br />
                                        '$lang_edit_set2_taglist_help4'<br />
                                        '$lang_edit_set2_taglist_help5'<br /><br />
                                        '$lang_edit_set2_taglist_help6'<br />
                                        <br />
                                        '$lang_edit_set2_taglist_help7'<br /><br />
                                        '$lang_edit_set2_taglist_help8'<br /><br />
                                        '$lang_edit_set2_taglist_help9'<br />
                                        '$lang_edit_set2_taglist_help10'<br />
                                        '$lang_edit_set2_taglist_help11'<br /><br />
                                        <strong>'$lang_edit_yamlsample_button_help_headline'</strong>
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
                            <label for="searchAll">'$lang_edit_set2_searchall_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="searchAll" id="searchAll" class="form-select form-select-sm">'

                                if [[ "$searchAll" == "no" ]]; then
                                    echo '<option value="no" selected>'$lang_edit_set2_searchall_1page'</option>'
                                else
                                    echo '<option value="no">'$lang_edit_set2_searchall_1page'</option>'
                                fi
                                if [[ "$searchAll" == "searchAll" ]]; then
                                    echo '<option value="searchAll" selected>'$lang_edit_set2_searchall_all'</option>'
                                else
                                    echo '<option value="searchAll">'$lang_edit_set2_searchall_all'</option>'
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
                                        '$lang_edit_set2_searchall_help1'<br />
                                        '$lang_edit_set2_searchall_help2'
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
                            <label for="moveTaggedFiles" class="text-white">'$lang_edit_set2_moveTaggedFiles_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="moveTaggedFiles" id="moveTaggedFiles" class="form-select form-select-sm">'

                                if [[ "$moveTaggedFiles" == "no" ]]; then
                                    echo '<option value="no" selected>'$lang_edit_set2_moveTaggedFiles_targetdir'</option>'
                                else
                                    echo '<option value="no">'$lang_edit_set2_moveTaggedFiles_targetdir'</option>'
                                fi
                                if [[ "$moveTaggedFiles" == "useCatDir" ]]; then
                                    echo '<option value="useCatDir" selected>'$lang_edit_set2_moveTaggedFiles_useCatDir'</option>'
                                else
                                    echo '<option value="useCatDir">'$lang_edit_set2_moveTaggedFiles_useCatDir'</option>'
                                fi
                                if [[ "$moveTaggedFiles" == "useTagDir" ]]; then
                                    echo '<option value="useTagDir" selected>'$lang_edit_set2_moveTaggedFiles_useTagDir'</option>'
                                else
                                    echo '<option value="useTagDir">'$lang_edit_set2_moveTaggedFiles_useTagDir'</option>'
                                fi
                                if [[ "$moveTaggedFiles" == "useYearDir" ]]; then
                                    echo '<option value="useYearDir" selected>'$lang_edit_set2_moveTaggedFiles_useYearDir'</option>'
                                else
                                    echo '<option value="useYearDir">'$lang_edit_set2_moveTaggedFiles_useYearDir'</option>'
                                fi
                                if [[ "$moveTaggedFiles" == "useYearMonthDir" ]]; then
                                    echo '<option value="useYearMonthDir" selected>'$lang_edit_set2_moveTaggedFiles_useYearMonthDir'</option>'
                                else
                                    echo '<option value="useYearMonthDir">'$lang_edit_set2_moveTaggedFiles_useYearMonthDir'</option>'
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
                                        '$lang_edit_set2_moveTaggedFiles_help1'
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
                            <label for="NameSyntax">'$lang_edit_set2_renamesyntax_title'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "$NameSyntax" ]; then
                                echo '<input type="text" name="NameSyntax" id="NameSyntax" class="form-control form-control-sm" value="'$NameSyntax'" />'
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
                                        '$lang_edit_set2_renamesyntax_help1'<br /><br />
                                        '$lang_edit_set2_renamesyntax_help2'<br />
                                        '$lang_edit_set2_renamesyntax_help3':<br />
                                        <strong>§docr</strong> ('$lang_edit_set2_renamesyntax_help4')<br />
                                        <strong>§mocr</strong> ('$lang_edit_set2_renamesyntax_help5')<br />
                                        <strong>§yocr2</strong> ('$lang_edit_set2_renamesyntax_help6a')<br />
                                        <strong>§yocr4</strong> ('$lang_edit_set2_renamesyntax_help6b')<br />
                                        <strong>§ssnow</strong> ('$lang_edit_set2_renamesyntax_help22')<br />
                                        <strong>§mmnow</strong> ('$lang_edit_set2_renamesyntax_help23')<br />
                                        <strong>§hhnow</strong> ('$lang_edit_set2_renamesyntax_help24')<br />
                                        <strong>§dnow</strong> ('$lang_edit_set2_renamesyntax_help7')<br />
                                        <strong>§mnow</strong> ('$lang_edit_set2_renamesyntax_help8')<br />
                                        <strong>§ynow2</strong> ('$lang_edit_set2_renamesyntax_help9a')<br />
                                        <strong>§ynow4</strong> ('$lang_edit_set2_renamesyntax_help9b')<br />
                                        <strong>§sssource</strong> ('$lang_edit_set2_renamesyntax_help25')<br />
                                        <strong>§mmsource</strong> ('$lang_edit_set2_renamesyntax_help26')<br />
                                        <strong>§hhsource</strong> ('$lang_edit_set2_renamesyntax_help27')<br />
                                        <strong>§dsource</strong> ('$lang_edit_set2_renamesyntax_help10')<br />
                                        <strong>§msource</strong> ('$lang_edit_set2_renamesyntax_help11')<br />
                                        <strong>§ysource2</strong> ('$lang_edit_set2_renamesyntax_help12a')<br />
                                        <strong>§ysource4</strong> ('$lang_edit_set2_renamesyntax_help12b')<br />
                                        <strong>§tag</strong> ('$lang_edit_set2_renamesyntax_help13')<br />
                                        <strong>§tit</strong> ('$lang_edit_set2_renamesyntax_help14')<br />
                                        <strong>§pagecount</strong> ('$lang_edit_set2_renamesyntax_help18a')<br />
                                        <strong>§pagecounttotal</strong> ('$lang_edit_set2_renamesyntax_help18')<br />
                                        <strong>§filecounttotal</strong> ('$lang_edit_set2_renamesyntax_help19')<br />
                                        <strong>§pagecountprofile</strong> ('$lang_edit_set2_renamesyntax_help20')<br />
                                        <strong>§filecountprofile</strong> ('$lang_edit_set2_renamesyntax_help21')<br /><br />
                                        >><strong>§yocr4-§mocr-§docr_§tag_§tit</strong><< '$lang_edit_set2_renamesyntax_help15'<br />
                                        '$lang_edit_set2_renamesyntax_help16' >><strong>2018-12-09_#Rechnung_00376.pdf</strong><<<br />
                                        <br />'$lang_edit_set2_renamesyntax_help17'
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
                            <label for="tagsymbol">'$lang_edit_set2_tagsymbol_title'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "$tagsymbol" ]; then
                                echo '<input type="text" name="tagsymbol" id="tagsymbol" class="form-control form-control-sm" value="'$tagsymbol'" />'
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
                                        '$lang_edit_set2_tagsymbol_help1'<br />
                                        '$lang_edit_set2_tagsymbol_help2'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # Filedate
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="filedate">'$lang_edit_set2_filedate_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="filedate" id="filedate" class="form-select form-select-sm">'

                               if [[ "$filedate" == "now" ]]; then
                                    echo '<option value="now" selected>'$lang_edit_set2_filedate_now'</option>'
                                else
                                    echo '<option value="now">'$lang_edit_set2_filedate_now'</option>'
                                fi
                                if [[ "$filedate" == "ocr" ]]; then
                                    echo '<option value="ocr" selected>'$lang_edit_set2_filedate_ocr'</option>'
                                else
                                    echo '<option value="ocr">'$lang_edit_set2_filedate_ocr'</option>'
                                fi
                                if [[ "$filedate" == "source" ]]; then
                                    echo '<option value="source" selected>'$lang_edit_set2_filedate_source'</option>'
                                else
                                    echo '<option value="source">'$lang_edit_set2_filedate_source'</option>'
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
                                        '$lang_edit_set2_filedate_help1'<br />
                                        '$lang_edit_set2_filedate_help2'
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
                            <label for="tagsymbol">'$lang_edit_set2_ignoredDate_title'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "$ignoredDate" ]; then
                                echo '<input type="text" name="ignoredDate" id="ignoredDate" class="form-control form-control-sm" value="'$ignoredDate'" />'
                            else
                                echo '<input type="text" name="ignoredDate" id="ignoredDate" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#fignoredDate-info" role="button" aria-expanded="false" aria-controls="fignoredDate-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="fignoredDate-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '$lang_edit_set2_ignoredDate_help1'<br /><br />
                                        <strong>'$lang_edit_set2_ignoredDate_help2'</strong>
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
                    <span class="synocr-text-blue">'$lang_edit_set3_title'</span>
                </button>
            </h2>
            <div id="Collapse-03" class="accordion-collapse collapse border-white" aria-labelledby="Heading-03" data-bs-parent="#Accordion-03">
                <div class="accordion-body">'

                    # BACKUP ROTATION
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="backup_max">'$lang_edit_set3_backuprotate_title'</label>
                        </div>
                        <div class="col-sm-2">'

                            if [ -n "$backup_max" ]; then
                                echo '<input type="text" name="backup_max" id="ignoredDate" class="form-control form-control-sm" value="'$backup_max'" />'
                            else
                                echo '<input type="text" name="backup_max" id="ignoredDate" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>'

                        # Ausgeblendeter Label-Tag: $lang_edit_set3_backuprotatetype_title
                        echo '
                        <div class="col-sm-3">
                            <select name="backup_max_type" id="backup_max_type" class="form-select form-select-sm">'

                                if [[ "$backup_max_type" == "files" ]]; then
                                    echo '<option value="files" selected>'$lang_edit_set3_backuprotatetype_files'</option>'
                                else
                                    echo '<option value="files">'$lang_edit_set3_backuprotatetype_files'</option>'
                                fi
                                if [[ "$backup_max_type" == "days" ]]; then
                                    echo '<option value="days" selected>'$lang_edit_set3_backuprotatetype_days'</option>'
                                else
                                    echo '<option value="days">'$lang_edit_set3_backuprotatetype_days'</option>'
                                fi

                                echo '
                            </select>
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
                                        '$lang_edit_set3_backuprotate_help1'<br /><br />
                                        '$lang_edit_set3_backuprotate_help2'<br />
                                        '$lang_edit_set3_backuprotate_help3'
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
                            <label for="LOGmax">'$lang_edit_set3_logmax_title'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "$LOGmax" ]; then
                                echo '<input type="text" name="LOGmax" id="LOGmax" class="form-control form-control-sm" value="'$LOGmax'" />'
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
                                        '$lang_edit_set3_logmax_help'
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
                            <label for="dsmtextnotify">'$lang_edit_set3_dsmtextnotify_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="dsmtextnotify" id="dsmtextnotify" class="form-select form-select-sm">'

                                if [[ "$dsmtextnotify" == "off" ]]; then
                                    echo '<option value="off" selected>'$lang_edit_set3_dsmtextnotify_off'</option>'
                                else
                                    echo '<option value="off">'$lang_edit_set3_dsmtextnotify_off'</option>'
                                fi
                                if [[ "$dsmtextnotify" == "on" ]]; then
                                    echo '<option value="on" selected>'$lang_edit_set3_dsmtextnotify_on'</option>'
                                else
                                    echo '<option value="on">'$lang_edit_set3_dsmtextnotify_on'</option>'
                                fi

                                echo '
                            </select>
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
                                        '$lang_edit_set3_dsmtextnotify_help1'<br />
                                        '$lang_edit_set3_dsmtextnotify_help2'
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
                    IFS=$'\012'

                    for user in $user_list ; do
                        IFS=$oldIFS
                        user_name=$(echo $user | awk -F: '{print $1}')
                        user_id=$( id -u $user_name )
                        # sort out system user:
                        if [ $user_id -ge 1000 ] && [ $user_id -le 100000 ] ; then
                            user_list_array+=( "$user_name" )
                        fi
                    done

                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="MessageTo">'$lang_edit_set3_MessageTo_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="MessageTo" id="MessageTo" class="form-select form-select-sm">'

                                for entry in ${user_list_array[@]}; do
                                    IFS=$OLDIFS
                                    if [[ "$MessageTo" == "${entry}" ]]; then
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
                                        '$lang_edit_set3_MessageTo_help1'<br />
                                        '$lang_edit_set3_MessageTo_help2'<br />
                                        '$lang_edit_set3_MessageTo_help3'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # PushBullet token
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="PBTOKEN">'$lang_edit_set3_PBTOKEN_title'</label>
                        </div>
                        <div class="col-sm-5">'

                            if [ -n "$PBTOKEN" ]; then
                                echo '<input type="text" name="PBTOKEN" id="PBTOKEN" class="form-control form-control-sm" value="'$PBTOKEN'" />'
                            else
                                echo '<input type="text" name="PBTOKEN" id="PBTOKEN" class="form-control form-control-sm" value="" />'
                            fi

                            echo '
                        </div>
                        <div class="col-sm-2">
                            <div class="float-end">
                                <a data-bs-toggle="collapse" href="#PBTOKEN-info" role="button" aria-expanded="false" aria-controls="PBTOKEN-info">
                                    <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/></a>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-10">
                            <div class="collapse" id="PBTOKEN-info">
                                <div class="card card-body mb-3" style="background-color: #F2FAFF;">
                                    <span>
                                        '$lang_edit_set3_PBTOKEN_help1'<br />
                                        '$lang_edit_set3_PBTOKEN_help2'<br />
                                        '$lang_edit_set3_PBTOKEN_help3'
                                    </span>
                                </div>
                            </div>
                        </div>
                        <div class="col-sm-2"></div>
                    </div>'

                    # dsmbeepnotify
                    echo '
                    <div class="row mb-3">
                        <div class="col-sm-5">
                            <label for="dsmbeepnotify">'$lang_edit_set3_dsmbeepnotify_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="dsmbeepnotify" id="dsmbeepnotify" class="form-select form-select-sm">'

                                if [[ "$dsmbeepnotify" == "off" ]]; then
                                    echo '<option value="off" selected>'$lang_edit_set3_dsmbeepnotify_off'</option>'
                                else
                                    echo '<option value="off">'$lang_edit_set3_dsmbeepnotify_off'</option>'
                                fi
                                if [[ "$dsmbeepnotify" == "on" ]]; then
                                    echo '<option value="on" selected>'$lang_edit_set3_dsmbeepnotify_on'</option>'
                                else
                                    echo '<option value="on">'$lang_edit_set3_dsmbeepnotify_on'</option>'
                                fi

                                echo '
                            </select>
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
                                        '$lang_edit_set3_dsmbeepnotify_help1'
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
                            <label for="loglevel">'$lang_edit_set3_loglevel_title'</label>
                        </div>
                        <div class="col-sm-5">
                            <select name="loglevel" id="loglevel" class="form-select form-select-sm">'

                                if [[ "$loglevel" == "0" ]]; then
                                    echo '<option value="0" selected>'$lang_edit_set3_loglevel_off'</option>'
                                else
                                    echo '<option value="0">'$lang_edit_set3_loglevel_off'</option>'
                                fi
                                if [[ "$loglevel" == "1" ]]; then
                                    echo '<option value="1" selected>'$lang_edit_set3_loglevel_1'</option>'
                                else
                                    echo '<option value="1">'$lang_edit_set3_loglevel_1'</option>'
                                fi
                                if [[ "$loglevel" == "2" ]]; then
                                    echo '<option value="2" selected>'$lang_edit_set3_loglevel_2'</option>'
                                else
                                    echo '<option value="2">'$lang_edit_set3_loglevel_2'</option>'
                                fi

                                echo '
                            </select>
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
                                        '$lang_edit_set3_loglevel_help1'<br />
                                        '$lang_edit_set3_loglevel_help2'<br />
                                        '$lang_edit_set3_loglevel_help3'
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
    </div>
    <p>&nbsp;</p><p>&nbsp;</p>'

fi
