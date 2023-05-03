#!/bin/bash

#################################################################################
#   description:    - generates the foote for all pages in the GUI              #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/footer.sh          #
#   © 2023 by geimist                                                           #
#################################################################################

if [[ "$mainpage" == "timer" ]]; then
    echo '
        <footer>
        <p class="center">'

    if [[ "$page" != "timer" ]] && [[ "$page" != "timer-set-6" ]] && [[ "$page" != "timer-delete-query" ]] && [[ "$page" != "timer-delete" ]]; then
        if [[ "$page" == timer-* ]]; then
            if [[ "$page" == "timer-set-1" ]]; then
                echo '
                <button name="page" value="timer" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_buttonback'</button>&nbsp;&nbsp;&nbsp;'
            elif [[ "$page" == "timer-set-5" ]] && [[ "$timer_times" == "one" ]]; then
                echo '
                <button name="page" value="timer-set-2" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_buttonback'</button>&nbsp;&nbsp;&nbsp;'
            else
                echo '
                <button name="page" value="timer-set-'$siteless'" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_buttonback'</button>&nbsp;&nbsp;&nbsp;'
            fi
            if [[ "$page" == "timer-set-5" ]]; then
                echo '
                <button name="page" value="timer-set-6" class="blue_button" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_foot_buttonsavetimer'</button>'
            else
                echo '
                <button name="page" value="timer-set-'$sitemore'" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'$lang_buttonnext'</button>'
            fi
        fi
    fi

    echo '
        </p>
        </footer>
        <div class="clear"></div>'

elif [[ "$mainpage" == "edit" ]]; then
    echo '
        <footer>
            <div class="fixed-bottom bg-white p-4 border-top border-light border-5">
                <div style="text-align: right;">
                    <button name="page" value="edit-save" class="btn btn-white btn-sm" style="color: #FFFFFF; background-color: #0086E5;">'$lang_buttonsave'</button>&nbsp;
                    <button name="page" value="edit-new_profile-query" class="btn btn-warning btn-sm">'$lang_foot_buttonnewprofile'</button>&nbsp;
                    <button name="page" value="edit-dup-profile-query" title="'$lang_foot_buttoncloneprof_tit'" class="btn btn-warning btn-sm">'$lang_foot_buttoncloneprof'</button>&nbsp;
                    <button name="page" value="edit-del_profile-query" title="'$lang_foot_buttondelprof_tit'" class="btn btn-white btn-sm" style="color: #FFFFFF; background-color: #BD0010;">'$lang_foot_buttondelprof'</button>&nbsp;
                    <a href="etc/synOCR.sqlite" download="synOCR.sqlite" title="'$lang_foot_buttondownDB_tit'" class="btn btn-secondary btn-sm" style="color: #FFFFFF;">'$lang_foot_buttondownDB'</a>
                </div>
            </div>
        </footer>'
fi
