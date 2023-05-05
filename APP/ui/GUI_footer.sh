#!/bin/bash
# shellcheck disable=SC2154

#################################################################################
#   description:    - generates the foote for all pages in the GUI              #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/footer.sh          #
#   © 2023 by geimist                                                           #
#################################################################################

if [[ "${mainpage}" == edit ]]; then
    echo '
        <footer>
            <div class="fixed-bottom bg-white p-4 border-top border-light border-5">
                <div style="text-align: right;">
                    <button name="page" value="edit-save" class="btn btn-white btn-sm" style="color: #FFFFFF; background-color: #0086E5;">'"${lang_buttonsave}"'</button>&nbsp;
                    <button name="page" value="edit-new_profile-query" class="btn btn-warning btn-sm">'"${lang_foot_buttonnewprofile}"'</button>&nbsp;
                    <button name="page" value="edit-dup-profile-query" title="'"${lang_foot_buttoncloneprof_tit}"'" class="btn btn-warning btn-sm">'"${lang_foot_buttoncloneprof}"'</button>&nbsp;
                    <button name="page" value="edit-del_profile-query" title="'"${lang_foot_buttondelprof_tit}"'" class="btn btn-white btn-sm" style="color: #FFFFFF; background-color: #BD0010;">'"${lang_foot_buttondelprof}"'</button>&nbsp;
                    <a href="etc/synOCR.sqlite" download="synOCR.sqlite" title="'"${lang_foot_buttondownDB_tit}"'" class="btn btn-secondary btn-sm" style="color: #FFFFFF;">'"${lang_foot_buttondownDB}"'</a>
                </div>
            </div>
        </footer>'
fi
