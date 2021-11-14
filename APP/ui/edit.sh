#!/bin/bash
# /usr/syno/synoman/webman/3rdparty/synOCR/edit.sh

OLDIFS=$IFS
APPDIR=$(cd $(dirname $0);pwd)
cd ${APPDIR}
PATH=$PATH:/usr/local/bin:/opt/usr/bin

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


# convert existing tag list to YAML file:
if [[ "$page" == "edit-convert2YAML" ]]; then
        echo '<div class="Content_1Col_full">'

        SAMPLECONFIGFILE="${INPUTDIR%/}/_TagConfig_[profile_$(echo "$profile" | tr -dc "[a-z][A-Z][0-9] .-_")].txt"
        SAMPLECONFIGLOGFILE="${SAMPLECONFIGFILE}_$(date +%s)_convert.log"

        if [ $loglevel = "2" ] ; then
            convert2YAML > "${SAMPLECONFIGLOGFILE}"
            chmod 755 "${SAMPLECONFIGLOGFILE}"
        else
            convert2YAML > /dev/null  2>&1 
        fi

        if [ $? -eq 1 ]; then
            echo '<br /><div class="warning"><br /><p class="center">'$lang_edit_yamlsample_gui_01'
            <br>'$lang_edit_yamlsample_gui_02'
            <br><br>('$SAMPLECONFIGFILE')</p><br /></div>'
        else
            echo '<br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">'$lang_edit_yamlsample_gui_03'
            <br><br>('$SAMPLECONFIGFILE')<br /></div>'
        fi
        echo '<br /><p class="center"><button name="page" value="edit" class="blue_button">'$lang_buttonnext'...</button></p><br />'
        echo '</div><div class="clear"></div>'
fi


# Delete current profile:
if [[ "$page" == "edit-del_profile-query" ]] || [[ "$page" == "edit-del_profile" ]]; then
    if [[ "$page" == "edit-del_profile-query" ]]; then
        echo '<p class="center" style="'$synotrred';">
            '$lang_edit_delques_1' (<b>'$profile'</b>) '$lang_edit_delques_2'<br /><br /><br />
            <a href="index.cgi?page=edit-del_profile" class="red_button">'$lang_yes'</a>&nbsp;&nbsp;&nbsp;<a href="index.cgi?page=edit" class="button">'$lang_no'</a></p>'  >> "$stop"
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
        if [ $(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "SELECT count(profile_ID) FROM config WHERE profile_ID='$profile_ID' ") = "0" ] ; then
            echo '<p class="center" style="'$green';"><b>'$lang_edit_profname' <b>'$profile'</b> '$lang_edit_delfin2'.</b></p>
                <br /><p class="center"><button name="page" value="edit" class="blue_button">'$lang_buttonnext'...</button></p><br />' >> "$stop"
        else
            echo '<p class="center" style="'$green';">'$lang_edit_deler' (<b>'$profile'</b>)!</p>
                <br /><p class="center"><button name="page" value="edit" class="blue_button">'$lang_buttonnext'...</button></p><br />' >> "$stop"
        fi
    fi
fi


# Duplicate profile:
if [[ "$page" == "edit-dup-profile-query" ]] || [[ "$page" == "edit-dup-profile" ]]; then
    if [[ "$page" == "edit-dup-profile-query" ]]; then
        echo '<div class="Content_1Col_full">'
        echo '<p><br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">'$lang_edit_dup1':</p><br />
        <label style="width: auto;padding: 0.5em 0.5em 0.25em 0.25em;"><b>'$lang_edit_profname': </b></label>' #style="vertical-align: bottom;" style="width: 200px;"
        if [ -n "$new_profile_value" ]; then
            echo '<input type="text" style="width: 200px;" name="new_profile_value" value="'$new_profile_value'" />'
        else
            echo '<input type="text" style="width: 200px;" name="new_profile_value" value="" />'
        fi
        echo '</p></div><br /><p class="center"><button name="page" value="edit-dup-profile" class="blue_button">'$lang_edit_create'...</button></p><br />
            </div><div class="clear"></div>'
    elif [[ "$page" == "edit-dup-profile" ]]; then
        echo '<div class="Content_1Col_full">'
        if [ ! -z "$new_profile_value" ] ; then
            sSQL="SELECT count(profile_ID) FROM config WHERE profile='$new_profile_value' "
            if [ $(sqlite3 ./etc/synOCR.sqlite "$sSQL") = "0" ] ; then
                sSQL="INSERT INTO config ( profile, active, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix, delSearchPraefix, documentSplitPattern, taglist, searchAll,
                                    moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN, dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, filedate, tagsymbol, ignoredDate
                                    ) VALUES (
                                    '$new_profile_value', '$active', '$INPUTDIR', '$OUTPUTDIR', '$BACKUPDIR', '$LOGDIR', '$LOGmax', '$SearchPraefix', '$delSearchPraefix',
                                    '$documentSplitPattern', '$taglist', '$searchAll', '$moveTaggedFiles', '$NameSyntax', '$ocropt', '$dockercontainer', '$PBTOKEN', '$dsmtextnotify',
                                    '$MessageTo', '$dsmbeepnotify', '$loglevel', '$filedate', '$tagsymbol', '$ignoredDate' )"
                sqlite3 ./etc/synOCR.sqlite "$sSQL"

                sSQL2="SELECT count(profile_ID) FROM config WHERE profile='$new_profile_value' "
                if [ $(sqlite3 ./etc/synOCR.sqlite "$sSQL2") = "1" ] ; then
                    echo '<br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">'$lang_edit_profname' <b>'$profile'</b> '$lang_edit_dup2' <b>'$new_profile_value'</b> '$lang_edit_dup3'.</p><br /></div>'
                else
                    echo '<br /><div class="warning"><br /><p class="center">'$lang_edit_dup4'</p><br /></div>'
                fi
            else
                echo '<br /><div class="warning"><br /><p class="center">'$lang_edit_dup4'
                <br>'$lang_edit_dup5' <b>'$new_profile_value'</b> '$lang_edit_dup6'</p><br /></div>'
            fi
        else
            echo '<br /><div class="warning"><br /><p class="center">'$lang_edit_dup4'
            <br>'$lang_edit_dup7'</p><br /></div>'
        fi
        echo '<br /><p class="center"><button name="page" value="edit" class="blue_button">'$lang_buttonnext'...</button></p><br />'
        echo '</div><div class="clear"></div>'
    fi
fi


# create new profile:
if [[ "$page" == "edit-new_profile-query" ]] || [[ "$page" == "edit-new_profile" ]]; then
    if [[ "$page" == "edit-new_profile-query" ]]; then
        echo '<div class="Content_1Col_full">'
        echo '<p><br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">'$lang_edit_new1':</p><br />
        <label style="width: auto;padding: 0.5em 0.5em 0.25em 0.25em;"><b>'$lang_edit_profname': </b></label>' #style="vertical-align: bottom;" style="width: 200px;"
        if [ -n "$new_profile_value" ]; then
            echo '<input type="text" style="width: 200px;" name="new_profile_value" value="'$new_profile_value'" />'
        else
            echo '<input type="text" style="width: 200px;" name="new_profile_value" value="" />'
        fi
        echo '</p></div><br /><p class="center"><button name="page" value="edit-new_profile" class="blue_button">'$lang_edit_create'...</button></p><br />
            </div><div class="clear"></div>'
    elif [[ "$page" == "edit-new_profile" ]]; then
        echo '<div class="Content_1Col_full">'
        if [ ! -z "$new_profile_value" ] ; then
            sSQL="SELECT count(profile_ID) FROM config WHERE profile='$new_profile_value' "
            if [ $(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL") = "0" ] ; then
                new_profile "$new_profile_value"
                if [ $(sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL") = "1" ] ; then
                    echo '<br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">'$lang_edit_new2' <b>'$new_profile_value'</b> '$lang_edit_new3'.</p><br /></div>'
                else
                    echo '<br /><div class="warning"><br /><p class="center">'$lang_edit_new4'</p><br /></div>'
                fi
            else
                echo '<br /><div class="warning"><br /><p class="center">'$lang_edit_new4'
                <br>'$lang_edit_dup5' <b>'$new_profile_value'</b> '$lang_edit_dup6'</p><br /></div>'
            fi
        else
            echo '<br /><div class="warning"><br /><p class="center">'$lang_edit_new4'
            <br>'$lang_edit_dup7'</p><br /></div>'
        fi
        echo '<br /><p class="center"><button name="page" value="edit" class="blue_button">'$lang_buttonnext'...</button></p><br />'
        echo '</div><div class="clear"></div>'
    fi
fi


# Write record to DB:
if [[ "$page" == "edit-save" ]]; then
    sSQLupdate="UPDATE config SET profile='$profile', active='$active', INPUTDIR='$INPUTDIR', OUTPUTDIR='$OUTPUTDIR', BACKUPDIR='$BACKUPDIR',
        LOGDIR='$LOGDIR', LOGmax='$LOGmax', SearchPraefix='$SearchPraefix', delSearchPraefix='$delSearchPraefix', taglist='$taglist', searchAll='$searchAll',
        moveTaggedFiles='$moveTaggedFiles', NameSyntax='$NameSyntax', ocropt='$ocropt', dockercontainer='$dockercontainer', PBTOKEN='$PBTOKEN',
        dsmtextnotify='$dsmtextnotify', MessageTo='$MessageTo', dsmbeepnotify='$dsmbeepnotify', loglevel='$loglevel', filedate='$filedate', tagsymbol='$tagsymbol', documentSplitPattern='$documentSplitPattern', ignoredDate='$ignoredDate' WHERE profile_ID='$profile_ID' "
    sqlite3 ./etc/synOCR.sqlite "$sSQLupdate"

    # write global change to table system:
    sqlite3 ./etc/synOCR.sqlite "UPDATE system SET dockerimageupdate='$dockerimageupdate' WHERE rowid=1 "

    echo '<div class="Content_1Col_full">'
    echo '<br /><div class="info"><br /><p class="center" style="color:#0086E5;font-weight:normal; ">'$lang_edit_savefin'</p><br /></div>'
    echo '<br /><p class="center"><button name="page" value="edit" class="blue_button">'$lang_buttonnext'...</button></p><br />'
    echo '</div><div class="clear"></div>'
fi


if [[ "$page" == "edit" ]]; then
    # Read file contents for variable utilization
    if [ -z "$getprofile" ] ; then
        sSQL="SELECT profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix,
            delSearchPraefix, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN,
            dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, active, filedate, tagsymbol, documentSplitPattern, ignoredDate FROM config WHERE profile_ID='1' "
    else
        sSQL="SELECT profile_ID, timestamp, profile, INPUTDIR, OUTPUTDIR, BACKUPDIR, LOGDIR, LOGmax, SearchPraefix,
            delSearchPraefix, taglist, searchAll, moveTaggedFiles, NameSyntax, ocropt, dockercontainer, PBTOKEN,
            dsmtextnotify, MessageTo, dsmbeepnotify, loglevel, active, filedate, tagsymbol, documentSplitPattern, ignoredDate FROM config WHERE profile_ID='$getprofile' "
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


    # read global values:
        dockerimageupdate=$(sqlite3 ./etc/synOCR.sqlite "SELECT dockerimageupdate FROM system WHERE rowid=1 ")

    echo '
    <div id="Content_1Col">
    <div class="Content_1Col_full">
        <div class="title">
            synOCR '$lang_page2'
        </div>'$lang_edit_summary1'<br>
        '$lang_edit_summary2'<br><br>
        '$lang_edit_summary3'<br><br>
        '$lang_edit_summary4'<br><br>'

        if [ ! -z "$DBupgradelog" ] ; then
            echo "<p>'$lang_edit_dbupdate': $DBupgradelog </p>"
        fi

# Profile selection:
    sSQL="SELECT profile_ID, profile FROM config "
    sqlerg=`sqlite3 -separator $'\t' ./etc/synOCR.sqlite "$sSQL"`
    echo '<p>
        <label style="width: 200px;padding: 0.5em 0.5em 0.25em 0.25em;"><b>'$lang_edit_change_profile'</b></label>
        <select name="getprofile" style="width: 200px;">'

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

    echo '</select><button name="page" value="edit" class="blue_button" style="float:right;">'$lang_buttonchange'</button>&nbsp;'

    # -> General section

# Expandable:
    echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;">
    <br />
    <details><p>
    <summary>
        <span class="detailsitem">'$lang_edit_set1_title'</span>
    </summary></p>
    <p>' # from here is the text to be expanded and collapsed.

    # Profil name
    echo '
        <p>
        <label>'$lang_edit_profname'</label>'
        if [ -n "$profile" ]; then
            echo '<input type="text" name="profile" value="'$profile'" />'
        else
            echo '<input type="text" name="profile" value="" />'
        fi
        echo '<a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set1_profilename_help'</span></a></p>'

    # Profile activated?
    echo '
        <p>
        <label>'$lang_edit_set1_profile_activ_title'</label>
        <select name="active">'
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
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set1_profile_activ_help1'<br>
            '$lang_edit_set1_profile_activ_help2'</span></a>
        </p>'

    # profile ID (write to $var without GUI)
        encode_value=$profile_ID
        decode_value=$(urldecode "$encode_value")
        "$set_var" "./usersettings/var.txt" "profile_ID" "$decode_value"
        "$set_var" "./usersettings/var.txt" "encode_profile_ID" "$encode_value"
    
    # SOURCEDIR
    echo '
        <p>
        <label>'$lang_edit_set1_sourcedir_title'</label>'
        if [ -n "$INPUTDIR" ]; then
            echo '<input type="text" name="INPUTDIR" value="'$INPUTDIR'" />'
        else
            echo '<input type="text" name="INPUTDIR" value="" />'
        fi
        echo '
            <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set1_sourcedir_help1'<br>
            '$lang_edit_set1_sourcedir_help2'</span></a>
            </p>'

    # OUTPUTDIR
    echo '
        <p>
        <label>'$lang_edit_set1_targetdir_title'</label>'
        if [ -n "$OUTPUTDIR" ]; then
            echo '<input type="text" name="OUTPUTDIR" value="'$OUTPUTDIR'" />'
        else
            echo '<input type="text" name="OUTPUTDIR" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set1_targetdir_help1'<br>
            '$lang_edit_set1_targetdir_help2'</span></a>
        </p>'

    # BACKUPDIR
    echo '
        <p>
        <label>'$lang_edit_set1_backupdir_title'</label>'
        if [ -n "$BACKUPDIR" ]; then
            echo '<input type="text" name="BACKUPDIR" value="'$BACKUPDIR'" />'
        else
            echo '<input type="text" name="BACKUPDIR" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set1_backupdir_help1'<br>
            '$lang_edit_set1_backupdir_help2'<br>
            '$lang_edit_set1_backupdir_help3'</span></a>
        </p>'

    # LOGDIR
    echo '
        <p>
        <label>'$lang_edit_set1_logdir_title'</label>'
        if [ -n "$LOGDIR" ]; then
            echo '<input type="text" name="LOGDIR" value="'$LOGDIR'" />'
        else
            echo '<input type="text" name="LOGDIR" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set1_logdir_help1'<br>
            '$lang_edit_set1_logdir_help2'</span></a>
        </p>'


    echo '
    </details>
        </fieldset>
    </p>'


    # -> OCR section:
    echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;">
    <br />
    <details><p>
    <summary>
        <span class="detailsitem">'$lang_edit_set2_title'</span>
    </summary></p>
    <p>'

    # ocropt
    echo '
        <p>
        <label>'$lang_edit_set2_ocropt_title'</label>'
        if [ -n "$ocropt" ]; then
            echo '<input type="text" name="ocropt" value="'$ocropt'" />'
        else
            echo '<input type="text" name="ocropt" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_ocropt_help1'<br><br>
            -l&nbsp;&nbsp;'$lang_edit_set2_ocropt_help5' (deu,enu,...)<br>
            -s&nbsp;&nbsp;'$lang_edit_set2_ocropt_help2'<br>
            -f&nbsp;&nbsp;'$lang_edit_set2_ocropt_help3'<br>
            -r&nbsp;&nbsp;'$lang_edit_set2_ocropt_help4'<br>
            -d&nbsp;&nbsp;'$lang_edit_set2_ocropt_help6'<br></span></a>
        </p>'

    # docker container
    echo '
        <p>
        <label>'$lang_edit_set2_dockerimage_title'</label>
        <select name="dockercontainer">'

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
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_dockerimage_help1'<br>
            jbarlow83/ocrmypdf '$lang_edit_set2_dockerimage_help2'<br>
            '$lang_edit_set2_dockerimage_help3'<br>
            '$lang_edit_set2_dockerimage_help4'</span></a>
        </p>'

    # docker-image-update
    echo '
        <p>
        <label>'$lang_edit_set2_dockerimageupdate_title'</label>
        <select name="dockerimageupdate">'
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
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_dockerimageupdate_help1'<br></span></a>
        </p>'

    # SearchPraefix
    echo '
        <p>
        <label>'$lang_edit_set2_searchpref_title'</label>'
        if [ -n "$SearchPraefix" ]; then
            echo '<input type="text" name="SearchPraefix" value="'$SearchPraefix'" />'
        else
            echo '<input type="text" name="SearchPraefix" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_searchpref_help1'<br>
            '$lang_edit_set2_searchpref_help2'<br>
            <strong>!</strong> '$lang_edit_set2_searchpref_help3' ( !value )<br>
            <strong>$</strong> '$lang_edit_set2_searchpref_help4' ( value$ )</span></a>
        </p>'

    # delSearchPraefix
    echo '
        <p>
        <label><span style="color: #FFFFFF;">.'$lang_edit_set2_delsearchpref_title'</span></label>
        <select name="delSearchPraefix">'
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
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_delsearchpref_help1'<br>
            '$lang_edit_set2_delsearchpref_help2'</span></a>
        </p>'

    # Document split pattern
 #   echo '
 #       <p>
 #       <label>'$lang_edit_set2_documentSplitPattern_title'</label>'
 #       if [ -n "$documentSplitPattern" ]; then
 #           echo '<input type="text" name="documentSplitPattern" value="'$documentSplitPattern'" />'
 #       else
 #           echo '<input type="text" name="documentSplitPattern" value="" />'
 #       fi
 #   echo '
 #       <a class="helpbox" href="#HELP">
 #           <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
 #           <span>'$lang_edit_set2_documentSplitPattern_help1'</span></a>
 #       </p>'
    
    # Taglist
    echo '
        <p>
        <label>'$lang_edit_set2_taglist_title
    # YAML convert button:
        # ("taglist" does not refer to an external file OR refers to an external file and has max. one line) AND input directory is a valid path
        if ( [[ ! -f "$taglist" ]] || $([[ -f "$taglist" ]] && [[ $( cat "$taglist" | wc -l ) -le 1 ]]) ) && [ -d "$INPUTDIR" ] ; then
            echo '<a class="helpbox" >
            <br><br><label><button name="page" value="edit-convert2YAML" class="blue_button">'$lang_edit_yamlsample_button'</button></label>&nbsp;<span>
            <strong>'$lang_edit_yamlsample_button_help_headline'</strong><br><br>
            '$lang_edit_yamlsample_button_help_01'<br>
            '$lang_edit_yamlsample_button_help_02'<br>
            '$lang_edit_yamlsample_button_help_03'<br></span></a>'
        fi
        echo '</label>'
        if [ -n "$taglist" ]; then
        #    echo '<input type="text" name="taglist" value="'$taglist'" />'
            echo '<textarea id="text" name="taglist" cols="35" rows="4">'$taglist'</textarea>'
        else
        #    echo '<input type="text" name="taglist" value="" />'
            echo '<textarea id="text" name="taglist" cols="35" rows="4"></textarea>'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_taglist_help1'<br>
            '$lang_edit_set2_taglist_help2'<br>
            '$lang_edit_set2_taglist_help2_1'<br>
            <strong>'$lang_edit_set2_taglist_help3'</strong><br>
            '$lang_edit_set2_taglist_help4'<br>
            '$lang_edit_set2_taglist_help5'<br><br>
            '$lang_edit_set2_taglist_help6'<br>
            <br>
            '$lang_edit_set2_taglist_help7'<br><br>
            '$lang_edit_set2_taglist_help8'<br><br>
            '$lang_edit_set2_taglist_help9'<br>
            '$lang_edit_set2_taglist_help10'<br>
            '$lang_edit_set2_taglist_help11'<br><br>
            <strong>'$lang_edit_yamlsample_button_help_headline'</strong><br><br></span></a>
        </p>'

    # searchArea
    echo '
        <p>
        <label>'$lang_edit_set2_searchall_title'</label>
        <select name="searchAll">'
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
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_searchall_help1'<br>
            '$lang_edit_set2_searchall_help2'</span></a>
        </p>'

    # moveTaggedFiles
    echo '
        <p>
        <label><span style="color: #FFFFFF;">'$lang_edit_set2_moveTaggedFiles_title'</span></label>
        <select name="moveTaggedFiles">'
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
    echo '
        </select>
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_moveTaggedFiles_help1'</span></a>
        </p>'

    # OCR Rename-Syntax
    echo '
        <p>
        <label>'$lang_edit_set2_renamesyntax_title'</label>'
        if [ -n "$NameSyntax" ]; then
            echo '<input type="text" name="NameSyntax" value="'$NameSyntax'" />'
        else
            echo '<input type="text" name="NameSyntax" value="" />'
        fi

    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_renamesyntax_help1'<br><br>
            '$lang_edit_set2_renamesyntax_help2'<br>
            '$lang_edit_set2_renamesyntax_help3':<br>
            <b>§docr</b> ('$lang_edit_set2_renamesyntax_help4')<br>
            <b>§mocr</b> ('$lang_edit_set2_renamesyntax_help5')<br>
            <b>§yocr2</b> ('$lang_edit_set2_renamesyntax_help6a')<br>
            <b>§yocr4</b> ('$lang_edit_set2_renamesyntax_help6b')<br>
            <b>§ssnow</b> ('$lang_edit_set2_renamesyntax_help22')<br>
            <b>§mmnow</b> ('$lang_edit_set2_renamesyntax_help23')<br>
            <b>§hhnow</b> ('$lang_edit_set2_renamesyntax_help24')<br>
            <b>§dnow</b> ('$lang_edit_set2_renamesyntax_help7')<br>
            <b>§mnow</b> ('$lang_edit_set2_renamesyntax_help8')<br>
            <b>§ynow2</b> ('$lang_edit_set2_renamesyntax_help9a')<br>
            <b>§ynow4</b> ('$lang_edit_set2_renamesyntax_help9b')<br>
            <b>§sssource</b> ('$lang_edit_set2_renamesyntax_help25')<br>
            <b>§mmsource</b> ('$lang_edit_set2_renamesyntax_help26')<br>
            <b>§hhsource</b> ('$lang_edit_set2_renamesyntax_help27')<br>
            <b>§dsource</b> ('$lang_edit_set2_renamesyntax_help10')<br>
            <b>§msource</b> ('$lang_edit_set2_renamesyntax_help11')<br>
            <b>§ysource2</b> ('$lang_edit_set2_renamesyntax_help12a')<br>
            <b>§ysource4</b> ('$lang_edit_set2_renamesyntax_help12b')<br>
            <b>§tag</b> ('$lang_edit_set2_renamesyntax_help13')<br>
            <b>§tit</b> ('$lang_edit_set2_renamesyntax_help14')<br>
            <b>§pagecounttotal</b> ('$lang_edit_set2_renamesyntax_help18')<br>
            <b>§filecounttotal</b> ('$lang_edit_set2_renamesyntax_help19')<br>
            <b>§pagecountprofile</b> ('$lang_edit_set2_renamesyntax_help20')<br>
            <b>§filecountprofile</b> ('$lang_edit_set2_renamesyntax_help21')<br><br>
            >><b>§yocr4-§mocr-§docr_§tag_§tit</b><< '$lang_edit_set2_renamesyntax_help15'<br>
            '$lang_edit_set2_renamesyntax_help16' >><b>2018-12-09_#Rechnung_00376.pdf</b><<<br>
            <br>'$lang_edit_set2_renamesyntax_help17'<br><br><br><br><br></span></a>
        </p>'

    # Tagkennzeichnung
    echo '
        <p>
        <label>'$lang_edit_set2_tagsymbol_title'</label>'
        if [ -n "$tagsymbol" ]; then
            echo '<input type="text" name="tagsymbol" value="'$tagsymbol'" />'
        else
            echo '<input type="text" name="tagsymbol" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_tagsymbol_help1'<br>
            '$lang_edit_set2_tagsymbol_help2'<br></span></a>
        </p>'

    # Filedate
    echo '
        <p>
        <label>'$lang_edit_set2_filedate_title'</label>
        <select name="filedate">'
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
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_filedate_help1'<br>
            '$lang_edit_set2_filedate_help2'</span></a>
        </p>'

    # ignoredDate:
    echo '
        <p>
        <label>'$lang_edit_set2_ignoredDate_title'</label>'
        if [ -n "$ignoredDate" ]; then
            echo '<input type="text" name="ignoredDate" value="'$ignoredDate'" />'
        else
            echo '<input type="text" name="ignoredDate" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set2_ignoredDate_help1'<br><br>
            <b>'$lang_edit_set2_ignoredDate_help2'</b><br></span></a>
        </p>'

    echo '
    </details>
        </fieldset>
    </p>'

    # -> Section DSM notification and other settings
    echo '<fieldset>
    <hr style="border-style: dashed; size: 1px;">
    <br />
    <details><p>
    <summary>
        <span class="detailsitem">'$lang_edit_set3_title'</span>
    </summary></p>
    <p>'

    # LOGmax
    echo '
        <p>
        <label>'$lang_edit_set3_logmax_title'</label>'
        if [ -n "$LOGmax" ]; then
            echo '<input type="text" name="LOGmax" value="'$LOGmax'" />'
        else
            echo '<input type="text" name="LOGmax" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set3_logmax_help'</span></a>
        </p>'

    # dsmtextnotify
    echo '
        <p>
        <label>'$lang_edit_set3_dsmtextnotify_title'</label>
        <select name="dsmtextnotify">'
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
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set3_dsmtextnotify_help1'
            <br>'$lang_edit_set3_dsmtextnotify_help2'</span></a>
        </p>'

    # MessageTo
    echo '
        <p>
        <label>'$lang_edit_set3_MessageTo_title'</label>'
        if [ -n "$MessageTo" ]; then
            echo '<input type="text" name="MessageTo" value="'$MessageTo'" />'
        else
            echo '<input type="text" name="MessageTo" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set3_MessageTo_help1'
            <br>'$lang_edit_set3_MessageTo_help2'
            <br>'$lang_edit_set3_MessageTo_help3'
        </span></a></p>'

    # PushBullet token
    echo '
        <p>
        <label>'$lang_edit_set3_PBTOKEN_title'</label>'
        if [ -n "$PBTOKEN" ]; then
            echo '<input type="text" name="PBTOKEN" value="'$PBTOKEN'" />'
        else
            echo '<input type="text" name="PBTOKEN" value="" />'
        fi
    echo '
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set3_PBTOKEN_help1'<br>
            '$lang_edit_set3_PBTOKEN_help2'<br>
            '$lang_edit_set3_PBTOKEN_help3'</span></a>
        </p>'

    # dsmbeepnotify
    echo '
        <p>
        <label>'$lang_edit_set3_dsmbeepnotify_title'</label>
        <select name="dsmbeepnotify">'
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
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set3_dsmbeepnotify_help1'</span></a>
        </p>'

    # LOGlevel
    echo '
        <p>
        <label>'$lang_edit_set3_loglevel_title'</label>
        <select name="loglevel">'
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
        <a class="helpbox" href="#HELP">
            <img src="images/icon_information_mini@geimist.svg" height="25" width="25"/>
            <span>'$lang_edit_set3_loglevel_help1'<br>
            '$lang_edit_set3_loglevel_help2'<br>
            '$lang_edit_set3_loglevel_help3'</span><br><br><br></a>
        </p>'

    echo '
        </p>
        </details>
        <br><hr style="border-style: dashed; size: 1px;">
    </fieldset>'

    echo '
    </div>
    </div><div class="clear"></div>
    <div id="minheight"></div>
'
fi
