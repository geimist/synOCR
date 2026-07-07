#!/bin/bash
# shellcheck disable=SC2154,SC2016,SC2034
#################################################################################
#   description:    - shared folder/file picker modal for the synOCR GUI         #
#   path:            /usr/syno/synoman/webman/3rdparty/synOCR/includes/folderpicker.sh
#   © 2026 by geimist                                                           #
#################################################################################
#
# Emit once on any page that uses the picker:
#     synocr_folderpicker_emit
# Open from JS (template/synocr-folderpicker.js):
#     synocr_openPicker(inputId, 'folder'|'file', { extensions:['yml','yaml'], title:'...', confirmLabel:'...', onSelect:function(path){} })

synocr_folderpicker_emit() {
    _fp_lang=$(jq -c -n \
        --arg title          "${lang_folderpicker_title}" \
        --arg select         "${lang_folderpicker_select}" \
        --arg abort          "${lang_button_abort}" \
        --arg shares         "${lang_folderpicker_available_shares}" \
        --arg back           "${lang_folderpicker_back}" \
        --arg loading        "${lang_folderpicker_loading}" \
        --arg failed_shares  "${lang_folderpicker_failed_shares}" \
        --arg failed_folders "${lang_folderpicker_failed_folders}" \
        --arg no_token       "${lang_folderpicker_no_token}" \
        '{title:$title,select:$select,abort:$abort,shares:$shares,back:$back,loading:$loading,failed_shares:$failed_shares,failed_folders:$failed_folders,no_token:$no_token}')

    echo '
    <!-- Shared Folder/File Picker Modal -->
    <div class="modal fade" id="synocrFolderPickerModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-lg synocr-folderpicker-modal">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="synocrFolderPickerModalLabel">'"${lang_folderpicker_title}"'</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div id="synocrFolderPickerContent" class="border p-3 synocr-folderpicker-content" style="height:320px;overflow-y:auto;"></div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal" id="synocrFolderPickerAbort">'"${lang_button_abort}"'</button>
                    <button type="button" class="btn btn-primary" id="synocrFolderPickerConfirm" style="background-color:#0086E5;">'"${lang_folderpicker_select}"'</button>
                </div>
            </div>
        </div>
    </div>
    <script type="application/json" id="synocr-folderpicker-lang">'"${_fp_lang}"'</script>'
}
