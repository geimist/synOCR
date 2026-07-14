#!/bin/bash
# shellcheck disable=SC2154,SC2016,SC2034

#################################################################################
#   description:    - generates the rule editor page (ruleset management)        #
#   path:            /usr/syno/synoman/webman/3rdparty/synOCR/GUI_rules.sh      #
#   © 2026 by geimist                                                           #
#################################################################################

APPDIR=$(cd "$(dirname "$0")" || exit 1;pwd)
cd "${APPDIR}" || exit 1
IFSsaved=IFS

# Check DB (create if necessary / upgrade):
    DBupgradelog=$(./upgradeconfig.sh)

# Shared folder/file picker (modal + lang JSON emitted on demand).
    [ -f "${APPDIR}/includes/folderpicker.sh" ] && . "${APPDIR}/includes/folderpicker.sh"


# --- helpers ----------------------------------------------------------------

# HTML-escape a value for safe embedding into HTML text/attributes.
rules_html_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# Pick a unique ruleset name starting from $1 (appends " 2", " 3", ... if needed).
rules_unique_name() {
    local base="$1" try="${1}" n=2
    while [ "$(synocr_sqlite "SELECT count(*) FROM ruleset WHERE name='$(sql_escape "${try}")'")" -gt 0 ]; do
        try="${base} ${n}"
        n=$((n + 1))
    done
    printf '%s' "${try}"
}

# Emit a tiny client-side redirect (headers are already sent when GUI_rules.sh is sourced).
rules_redirect() {
    local url="$1"
    echo '
    <script type="text/javascript">
        window.location.replace("'"${url}"'");
    </script>'
}


# Convert a YAML file at $1 to a wrapped JSON blob {"rules":{...},"groups":{...}}.
# Returns 0 on success, non-zero on failure (rc=2 means no converter available).
# Prefers synOCR's python3 venv (has the yaml module), then system python3, then yq_bin.
rules_yaml_to_json() {
    local _f="$1" _content _rc _py _errf _jq_out _jq_rc
    [ -f "${_f}" ] || return 1
    _py=""
    [ -x "${APPDIR}/python3_env/bin/python3" ] && _py="${APPDIR}/python3_env/bin/python3"
    [ -z "${_py}" ] && [ -x "${APPDIR%/ui}/python3_env/bin/python3" ] && _py="${APPDIR%/ui}/python3_env/bin/python3"
    [ -z "${_py}" ] && command -v python3 >/dev/null 2>&1 && _py="python3"
    if [ -n "${_py}" ]; then
        _errf=$(mktemp /tmp/synocr_ymlerr.XXXXXX)
        _content=$("${_py}" -c 'import sys, yaml, json
try:
    d = yaml.safe_load(sys.stdin.read())
    print(json.dumps(d, indent=2, sort_keys=False))
except Exception as e:
    sys.stderr.write(str(e)); sys.exit(1)' < "${_f}" 2>"${_errf}")
        _rc=$?
        rm -f "${_errf}"
        if [ ${_rc} -eq 0 ] && [ -n "${_content}" ]; then
            _jq_out=$(printf '%s' "${_content}" | jq -c 'if has("rules") and (.rules|type=="object") then {rules:.rules,groups:(.groups//{})} else {rules:.,groups:{}} end' 2>/dev/null)
            _jq_rc=$?
            if [ ${_jq_rc} -eq 0 ] && [ -n "${_jq_out}" ]; then
                printf '%s' "${_jq_out}"
                return 0
            fi
            return ${_jq_rc:-1}
        fi
    fi
    if command -v yq_bin >/dev/null 2>&1; then
        _content=$(yq_bin read "${_f}" -jP 2>/dev/null) || return 1
        [ -z "${_content}" ] && return 1
        printf '%s' "${_content}" | jq -c 'if has("rules") and (.rules|type=="object") then {rules:.rules,groups:(.groups//{})} else {rules:.,groups:{}} end' 2>/dev/null
        return $?
    fi
    return 2
}

# Resolve synOCR venv interpreter (not system python3).
rules_synocr_resolve_venv_python() {
    local _p=""
    for _p in \
        "${APPDIR}/python3_env/bin/python3" \
        "${APPDIR}/python3_env/bin/python" \
        "${APPDIR%/ui}/python3_env/bin/python3" \
        "${APPDIR%/ui}/python3_env/bin/python"
    do
        [ -x "${_p}" ] && { printf '%s' "${_p}"; return 0; }
    done
    return 1
}

# True when synOCR venv exists and PyYAML is importable (required for YAML import).
rules_synocr_yaml_import_ready() {
    local _py=""
    _py=$(rules_synocr_resolve_venv_python) || return 1
    "${_py}" -c "import yaml" 2>/dev/null
}

# True when synOCR's python3_env is not ready yet (e.g. fresh install before first OCR run).
rules_synocr_venv_missing() {
    rules_synocr_yaml_import_ready && return 1
    return 0
}

# YAML import view: legacy URL → editor with import modal open.
rules_import_view() {
    local _id="$1"
    _rj=$(synocr_sqlite "SELECT rules_json FROM ruleset WHERE id='${_id}';")
    [ -z "${_rj}" ] && { rules_redirect "index.cgi?page=rules"; return; }
    rules_redirect "index.cgi?page=rules-edit-${_id}&yaml=1"
}

# YAML import run: convert + hard-validate + store into the (empty) ruleset, then
# redirect to the editor. Renders an inline error card on any failure.
rules_import_run() {
    local _id="$1" _path="${import_path:-}" _rj _blob _errs _rules _groups _count _yrc _vrc
    if [ -z "${_path}" ]; then
        echo '<div class="card card-body mb-3">'"${lang_rules_import_no_file}"'</div>'
        echo '<a href="index.cgi?page=rules-edit-'"${_id}"'&yaml=1" class="btn btn-secondary btn-sm">'"${lang_rules_back}"'</a>'
        return
    fi
    if [ ! -f "${_path}" ]; then
        echo '<div class="card card-body mb-3">'"${lang_rules_import_invalid}"' ('"$(rules_html_escape "${_path}")"')</div>'
        echo '<a href="index.cgi?page=rules-edit-'"${_id}"'&yaml=1" class="btn btn-secondary btn-sm">'"${lang_rules_back}"'</a>'
        return
    fi
    _rj=$(synocr_sqlite "SELECT rules_json FROM ruleset WHERE id='${_id}';")
    [ -z "${_rj}" ] && { rules_redirect "index.cgi?page=rules"; return; }
    if [ "${_rj}" != "{}" ] && [ -n "${_rj}" ]; then
        rules_redirect "index.cgi?page=rules-edit-${_id}"
        return
    fi
    if rules_synocr_venv_missing; then
        rules_redirect "index.cgi?page=rules-edit-${_id}&yaml=1&yaml_noven=1"
        return
    fi
    _blob=$(rules_yaml_to_json "${_path}")
    _yrc=$?
    if [ ${_yrc} -ne 0 ] || [ -z "${_blob}" ]; then
        if rules_synocr_venv_missing; then
            rules_redirect "index.cgi?page=rules-edit-${_id}&yaml=1&yaml_noven=1"
            return
        fi
        echo '<div class="card card-body mb-3">'"${lang_rules_import_invalid}"'</div>'
        echo '<a href="index.cgi?page=rules-edit-'"${_id}"'&yaml=1" class="btn btn-secondary btn-sm">'"${lang_rules_back}"'</a>'
        return
    fi
    _errs=$(rules_validate_json "${_blob}")
    _vrc=$?
    if [ ${_vrc} -ne 0 ]; then
        echo '<div class="card card-body mb-3"><span class="text-danger">'"${lang_rules_import_error}"'</span><pre class="small mt-2">'"$(rules_html_escape "${_errs}")"'</pre>'
        echo '</div>'
        echo '<a href="index.cgi?page=rules-edit-'"${_id}"'&yaml=1" class="btn btn-secondary btn-sm">'"${lang_rules_back}"'</a>'
        return
    fi
    _rules=$(printf '%s' "${_blob}" | jq -c '.rules')
    _groups=$(printf '%s' "${_blob}" | jq -c '.groups // {}')
    _count=$(printf '%s' "${_rules}" | jq 'keys|length' 2>/dev/null)
    [ -z "${_count}" ] && _count=0
    synocr_sqlite "UPDATE ruleset SET rules_json='$(sql_escape "${_rules}")', groups_json='$(sql_escape "${_groups}")', rule_count='${_count}', updated_at=datetime('now','localtime') WHERE id='${_id}';" >/dev/null
    rules_redirect "index.cgi?page=rules-edit-${_id}"
}


# --- list view ---------------------------------------------------------------

rules_list_view() {
    echo '
    <div class="d-flex justify-content-between align-items-center mt-3 flex-wrap gap-2 synocr-rules-list-head">
        <h2 class="synocr-text-blue mb-0">'"${lang_rules_title}"'</h2>
        <a href="index.cgi?page=rules-new" class="btn btn-primary btn-sm flex-shrink-0" style="background-color: #0086E5;">'"${lang_rules_btn_new}"'</a>
    </div>
    <hr class="mt-2 mb-3">'

    _rows=$(synocr_sqlite -json "SELECT id, name, description, rules_json, updated_at FROM ruleset ORDER BY name COLLATE NOCASE")

    if [ -z "${_rows}" ] || [ "${_rows}" = "[]" ]; then
        echo '
        <div class="card card-body mb-3 synocr-hint-card">'"${lang_rules_empty}"'</div>'
        return
    fi

    echo '
    <div class="table-responsive synocr-rulesets-table-wrap">
        <table class="table table-hover align-middle synocr-rulesets-table">
            <colgroup>
                <col class="synocr-rulesets-col-name">
                <col class="synocr-rulesets-col-desc">
                <col class="synocr-rulesets-col-count">
                <col class="synocr-rulesets-col-updated">
                <col class="synocr-rulesets-col-actions">
            </colgroup>
            <thead class="synocr-text-blue">
                <tr>
                    <th class="synocr-rulesets-col-name">'"${lang_rules_col_name}"'</th>
                    <th class="synocr-rulesets-col-desc">'"${lang_rules_col_description}"'</th>
                    <th class="text-center synocr-rulesets-col-count">'"${lang_rules_col_rules}"'</th>
                    <th class="text-center synocr-rulesets-col-updated">'"${lang_rules_col_updated}"'</th>
                    <th class="text-center synocr-rulesets-col-actions">'"${lang_rules_col_actions}"'</th>
                </tr>
            </thead>
            <tbody>'

    while IFS= read -r _row; do
        [ -z "${_row}" ] && continue
        _id=$(synocr_jq_row_field "${_row}" id)
        _name=$(synocr_jq_row_field "${_row}" name)
        _desc=$(synocr_jq_row_field "${_row}" description)
        _rj=$(synocr_jq_row_field "${_row}" rules_json)
        _updated=$(synocr_jq_row_field "${_row}" updated_at)
        _count=$(printf '%s' "${_rj}" | jq 'keys | length' 2>/dev/null)
        [ -z "${_count}" ] && _count=0
        _assigned=$(synocr_sqlite "SELECT count(*) FROM config WHERE ruleset_id='${_id}'")
        _name_h=$(rules_html_escape "${_name}")
        _desc_h=$(rules_html_escape "${_desc}")
        [ -z "${_desc_h}" ] && _desc_h="${lang_rules_no_description}"

        echo '
                <tr>
                    <td class="synocr-rulesets-col-name">
                        <strong>'"${_name_h}"'</strong><br>
                        <span class="text-secondary small">'"${_assigned}"' '"${lang_rules_assigned_profiles}"'</span>
                    </td>
                    <td class="synocr-rulesets-col-desc">'"${_desc_h}"'</td>
                    <td class="text-center synocr-rulesets-col-count">'"${_count}"'</td>
                    <td class="text-center small synocr-rulesets-col-updated">'"${_updated}"'</td>
                    <td class="text-center synocr-rulesets-col-actions">
                        <span class="synocr-rulesets-actions">
                            <a href="index.cgi?page=rules-edit-'"${_id}"'" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_rules_btn_edit}"'</a>
                            <a href="index.cgi?page=rules-dup-'"${_id}"'" class="btn btn-sm synocr-btn-outline-blue synocr-btn-duplicate-icon synocr-rulesets-btn-duplicate" title="'"${lang_rules_btn_duplicate}"'" aria-label="'"${lang_rules_btn_duplicate}"'">⧉</a>
                            <a href="index.cgi?page=rules-del-'"${_id}"'" class="btn btn-outline-danger btn-sm">'"${lang_rules_btn_delete}"'</a>
                        </span>
                    </td>
                </tr>'
    done < <(synocr_jq_rows "${_rows}")

    echo '
            </tbody>
        </table>
    </div>'
}


# --- actions: new / duplicate / delete ---------------------------------------

rules_action_new() {
    _name=$(rules_unique_name "${lang_rules_new_default_name}")
    _new_id=$(synocr_sqlite "INSERT INTO ruleset (name, description, rules_json, groups_json, rule_count) VALUES ('$(sql_escape "${_name}")', '', '{}', '{}', 0); SELECT last_insert_rowid();")
    rules_redirect "index.cgi?page=rules-edit-${_new_id}"
}

rules_action_dup() {
    _src_id="$1"
    _name=$(synocr_sqlite_json_field "SELECT name AS v FROM ruleset WHERE id='${_src_id}'" v)
    if [ -z "${_name}" ]; then
        rules_redirect "index.cgi?page=rules"
        return
    fi
    _desc=$(synocr_sqlite_json_field "SELECT description AS v FROM ruleset WHERE id='${_src_id}'" v)
    _rj=$(synocr_sqlite_json_field "SELECT rules_json AS v FROM ruleset WHERE id='${_src_id}'" v)
    _gj=$(synocr_sqlite_json_field "SELECT groups_json AS v FROM ruleset WHERE id='${_src_id}'" v)
    _rc=$(synocr_sqlite_json_field "SELECT rule_count AS v FROM ruleset WHERE id='${_src_id}'" v)
    [ -z "${_rj}" ] && _rj='{}'
    [ -z "${_gj}" ] && _gj='{}'
    [ -z "${_rc}" ] && _rc=0
    _new_name=$(rules_unique_name "${_name}${lang_rules_dup_suffix}")
    _new_id=$(synocr_sqlite "INSERT INTO ruleset (name, description, rules_json, groups_json, rule_count) VALUES ('$(sql_escape "${_new_name}")', '$(sql_escape "${_desc}")', '$(sql_escape "${_rj}")', '$(sql_escape "${_gj}")', '${_rc}'); SELECT last_insert_rowid();")
    rules_redirect "index.cgi?page=rules-edit-${_new_id}"
}

rules_action_del_query() {
    _id="$1"
    _name=$(synocr_sqlite_json_field "SELECT name AS v FROM ruleset WHERE id='${_id}'" v)
    if [ -z "${_name}" ]; then
        rules_redirect "index.cgi?page=rules"
        return
    fi
    _name_h=$(rules_html_escape "${_name}")
    _assigned=$(synocr_sqlite "SELECT count(*) FROM config WHERE ruleset_id='${_id}'")
    if [ "${_assigned}" -gt 0 ]; then
        _msg="${lang_rules_confirm_delete_used}"
    else
        _msg="${lang_rules_confirm_delete}"
    fi

    echo '
    <!-- Modal -->
    <div class="modal fade" id="popup-rules-del" tabindex="-1" aria-labelledby="label-rules-del" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline">'"${lang_popup_note}"'</h5>
                    <a href="index.cgi?page=rules" class="btn-close" aria-label="Close"></a>
                </div>
                <div class="modal-body text-center">
                    <p>'"${_msg}"'</p>
                    <p><strong>'"${_name_h}"'</strong></p>
                </div>
                <div class="modal-footer bg-light">
                    <a href="index.cgi?page=rules-del-confirm-'"${_id}"'" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_yes}"'</a>&nbsp;&nbsp;&nbsp;
                    <a href="index.cgi?page=rules" class="btn btn-secondary btn-sm">'"${lang_button_abort}"'</a>
                </div>
            </div>
        </div>
    </div>
    <script type="text/javascript">
        $(window).on("load", function() {
            $("#popup-rules-del").modal("show");
        });
    </script>'
}

rules_action_del_confirm() {
    _id="$1"
    synocr_sqlite "DELETE FROM ruleset WHERE id='${_id}';" >/dev/null
    # null dangling profile references so the loader falls back to taglist instead of erroring:
    synocr_sqlite "UPDATE config SET ruleset_id=NULL WHERE ruleset_id='${_id}';" >/dev/null
    rules_redirect "index.cgi?page=rules"
}


# --- editor view (shell; visual editor + save are wired in Phase 4) ----------

rules_edit_view() {
    _id="$1"
    _json=$(synocr_sqlite -json "SELECT id, name, description, rules_json, groups_json FROM ruleset WHERE id='${_id}'")
    if [ -z "${_json}" ] || [ "${_json}" = "[]" ]; then
        echo '
        <div class="card card-body mb-3 synocr-hint-card">'"${lang_rules_empty}"'</div>'
        echo '
        <a href="index.cgi?page=rules" class="btn btn-primary btn-sm" style="background-color: #0086E5;">'"${lang_rules_back}"'</a>'
        return
    fi

    _name=$(synocr_jq_field "${_json}" name)
    _desc=$(synocr_jq_field "${_json}" description)
    _rj=$(synocr_jq_field "${_json}" rules_json)
    _gj=$(synocr_jq_field "${_json}" groups_json)
    [ -z "${_rj}" ] && _rj='{}'
    [ -z "${_gj}" ] && _gj='{}'

    # wrapped, embedded JSON for the editor JS; escape < > so a RegEx containing
    # "</script>" cannot break out of the script tag.
    _data_json=$(jq -c -n --argjson r "${_rj}" --argjson g "${_gj}" '{rules:$r, groups:$g}' 2>/dev/null)
    if [ -z "${_data_json}" ]; then
        _data_json='{"rules":{},"groups":{}}'
    fi
    _data_json=$(printf '%s' "${_data_json}" | sed -e 's/</\\u003c/g' -e 's/>/\\u003e/g')

    # localized strings for the editor JS (single source of truth: lang_ger.txt)
    _lang_json=$(jq -c -n \
        --arg btn_add_rule        "${lang_rules_btn_add_rule}" \
        --arg btn_add_subrule     "${lang_rules_btn_add_subrule}" \
        --arg btn_remove_rule     "${lang_rules_btn_remove_rule}" \
        --arg btn_duplicate_rule  "${lang_rules_btn_duplicate_rule}" \
        --arg btn_jump_raw_rule   "${lang_rules_btn_jump_raw_rule}" \
        --arg btn_remove_subrule  "${lang_rules_btn_remove_subrule}" \
        --arg btn_save            "${lang_rules_btn_save}" \
        --arg btn_cancel          "${lang_rules_btn_cancel}" \
        --arg rule_name           "${lang_rules_rule_name}" \
        --arg rule_condition      "${lang_rules_rule_condition}" \
        --arg cond_any            "${lang_rules_rule_condition_any}" \
        --arg cond_all            "${lang_rules_rule_condition_all}" \
        --arg cond_none           "${lang_rules_rule_condition_none}" \
        --arg tagname             "${lang_rules_rule_tagname}" \
        --arg tagname_regex       "${lang_rules_rule_tagname_regex}" \
        --arg targetfolder        "${lang_rules_rule_targetfolder}" \
        --arg placeholder_targetfolder "${lang_rules_placeholder_targetfolder}" \
        --arg dirname_regex       "${lang_rules_rule_dirname_regex}" \
        --arg multiline           "${lang_rules_rule_multilineregex}" \
        --arg dirname_multiline   "${lang_rules_rule_dirname_multilineregex}" \
        --arg postscript          "${lang_rules_rule_postscript}" \
        --arg apprise             "${lang_rules_rule_apprise}" \
        --arg apprise_att         "${lang_rules_rule_apprise_attachment}" \
        --arg apprise_att_true    "${lang_edit_set3_apprise_attachment_true}" \
        --arg apprise_att_false   "${lang_edit_set3_apprise_attachment_false}" \
        --arg notify_lang         "${lang_rules_rule_notify_lang}" \
        --arg on_match_action     "${lang_rules_rule_on_match_action}" \
        --arg on_match_result     "${lang_rules_rule_on_match_result}" \
        --arg omatch_unset        "${lang_rules_on_match_unset}" \
        --arg omatch_continue     "${lang_rules_on_match_continue}" \
        --arg omatch_break        "${lang_rules_on_match_break}" \
        --arg omatch_merge        "${lang_rules_on_match_merge}" \
        --arg omatch_replace      "${lang_rules_on_match_replace}" \
        --arg omatch_exclusive    "${lang_rules_on_match_exclusive}" \
        --arg requires            "${lang_rules_rule_requires}" \
        --arg excludes            "${lang_rules_rule_excludes}" \
        --arg sub_searchstring    "${lang_rules_subrule_searchstring}" \
        --arg sub_searchtyp       "${lang_rules_subrule_searchtyp}" \
        --arg sub_isregex         "${lang_rules_subrule_isregex}" \
        --arg sub_source          "${lang_rules_subrule_source}" \
        --arg sub_casesensitive   "${lang_rules_subrule_casesensitive}" \
        --arg sub_multiline       "${lang_rules_subrule_multilineregex}" \
        --arg src_filename        "${lang_rules_subrule_source_filename}" \
        --arg src_content         "${lang_rules_subrule_source_content}" \
        --arg st_contains         "${lang_rules_searchtyp_contains}" \
        --arg st_not_contains     "${lang_rules_searchtyp_not_contains}" \
        --arg st_is               "${lang_rules_searchtyp_exact}" \
        --arg st_is_not           "${lang_rules_searchtyp_is_not}" \
        --arg st_starts           "${lang_rules_searchtyp_starts}" \
        --arg st_not_starts       "${lang_rules_searchtyp_not_starts}" \
        --arg st_ends             "${lang_rules_searchtyp_ends}" \
        --arg st_not_ends         "${lang_rules_searchtyp_not_ends}" \
        --arg st_matches          "${lang_rules_searchtyp_matches}" \
        --arg st_not_matches      "${lang_rules_searchtyp_not_matches}" \
        --arg tab_visual          "${lang_rules_tab_visual}" \
        --arg tab_raw             "${lang_rules_tab_raw}" \
        --arg drag_hint           "${lang_rules_drag_hint}" \
        --arg dup_suffix          "${lang_rules_dup_suffix}" \
        --arg filter_placeholder  "${lang_rules_filter_placeholder}" \
        --arg filter_count        "${lang_rules_filter_count}" \
        --arg filter_empty        "${lang_rules_filter_empty}" \
        --arg section_details     "${lang_rules_section_details}" \
        --arg toggle_details_show "${lang_rules_toggle_details_show}" \
        --arg toggle_details_hide "${lang_rules_toggle_details_hide}" \
        --arg toggle_rule_expand "${lang_rules_toggle_rule_expand}" \
        --arg toggle_rule_collapse "${lang_rules_toggle_rule_collapse}" \
        --arg save_success        "${lang_rules_save_success}" \
        --arg save_error          "${lang_rules_save_error}" \
        --arg save_error_title    "${lang_rules_save_error_title}" \
        --arg save_http_error     "${lang_rules_save_http_error}" \
        --arg save_dup_blocked    "${lang_rules_save_dup_blocked}" \
        --arg val_rule_dup_name   "${lang_rules_val_rule_dup_name}" \
        --arg raw_invalid         "${lang_rules_raw_invalid}" \
        --arg unsaved_warning     "${lang_edit_unsaved_changes_warning}" \
        --arg tf_builder          "${lang_rules_targetfolder_builder}" \
        --arg tf_pick             "${lang_rules_targetfolder_pick}" \
        --arg tf_pick_title       "${lang_rules_targetfolder_pick_title}" \
        --arg tf_pick_confirm     "${lang_rules_targetfolder_pick_confirm}" \
        --arg tf_preview          "${lang_rules_targetfolder_preview}" \
        --arg tf_mode_abs         "${lang_rules_targetfolder_mode_abs}" \
        --arg tf_mode_rel         "${lang_rules_targetfolder_mode_rel}" \
        --arg tf_dirhint          "${lang_rules_targetfolder_dirhint}" \
        --arg tf_dirregex_help    "${lang_rules_targetfolder_dirregex_help}" \
        --arg tf_chip_dirname     "${lang_rules_path_chip_dirname_regex}" \
        --arg tf_apply            "${lang_rules_targetfolder_apply}" \
        --arg tn_builder          "${lang_rules_tag_builder}" \
        --arg tn_chip_tagname     "${lang_rules_tag_chip_tagname_regex}" \
        --arg tn_dirhint          "${lang_rules_tag_dirhint}" \
        --arg tn_regex_help       "${lang_rules_tag_regex_help}" \
        --arg help_rule_name      "${lang_rules_help_rule_name}" \
        --arg help_rule_condition "${lang_rules_help_rule_condition}" \
        --arg help_tagname        "${lang_rules_help_tagname}" \
        --arg help_targetfolder   "${lang_rules_help_targetfolder}" \
        --arg help_sub_source     "${lang_rules_help_sub_source}" \
        --arg help_sub_searchtyp  "${lang_rules_help_sub_searchtyp}" \
        --arg help_sub_searchstring "${lang_rules_help_sub_searchstring}" \
        --arg help_sub_isregex    "${lang_rules_help_sub_isregex}" \
        --arg help_sub_casesensitive "${lang_rules_help_sub_casesensitive}" \
        --arg help_sub_multiline  "${lang_rules_help_sub_multiline}" \
        --arg help_tagname_regex  "${lang_rules_help_tagname_regex}" \
        --arg help_multiline      "${lang_rules_help_multiline}" \
        --arg help_dirname_multiline "${lang_rules_help_dirname_multiline}" \
        --arg help_on_match_action "${lang_rules_help_on_match_action}" \
        --arg help_on_match_result "${lang_rules_help_on_match_result}" \
        --arg help_requires       "${lang_rules_help_requires}" \
        --arg help_excludes       "${lang_rules_help_excludes}" \
        --arg help_postscript     "${lang_rules_help_postscript}" \
        --arg help_apprise        "${lang_rules_help_apprise}" \
        --arg help_link           "${lang_page4}" \
        --arg help_apprise_att    "${lang_rules_help_apprise_att}" \
        --arg help_notify_lang    "${lang_rules_help_notify_lang}" \
        --arg help_dirname_regex  "${lang_rules_help_dirname_regex}" \
        --arg help_tf_preview     "${lang_rules_help_tf_preview}" \
        --arg regex_alt_add "${lang_rules_regex_alt_add}" \
        --arg regex_alt_placeholder "${lang_rules_regex_alt_placeholder}" \
        --arg regex_anchor_end "${lang_rules_regex_anchor_end}" \
        --arg regex_anchor_start "${lang_rules_regex_anchor_start}" \
        --arg regex_anchor_word "${lang_rules_regex_anchor_word}" \
        --arg regex_context_after "${lang_rules_regex_context_after}" \
        --arg regex_context_before "${lang_rules_regex_context_before}" \
        --arg regex_context_not_after "${lang_rules_regex_context_not_after}" \
        --arg regex_context_not_before "${lang_rules_regex_context_not_before}" \
        --arg regex_explain_branch_reset "${lang_rules_regex_explain_branch_reset}" \
        --arg regex_explain_class_star "${lang_rules_regex_explain_class_star}" \
        --arg regex_explain_escape_cr "${lang_rules_regex_explain_escape_cr}" \
        --arg regex_explain_escape_line_break "${lang_rules_regex_explain_escape_line_break}" \
        --arg regex_explain_escape_newline "${lang_rules_regex_explain_escape_newline}" \
        --arg regex_explain_escape_non_digit "${lang_rules_regex_explain_escape_non_digit}" \
        --arg regex_explain_escape_non_space "${lang_rules_regex_explain_escape_non_space}" \
        --arg regex_explain_escape_non_word "${lang_rules_regex_explain_escape_non_word}" \
        --arg regex_explain_escape_not_newline "${lang_rules_regex_explain_escape_not_newline}" \
        --arg regex_explain_escape_tab "${lang_rules_regex_explain_escape_tab}" \
        --arg regex_explain_escape_word "${lang_rules_regex_explain_escape_word}" \
        --arg regex_explain_char_any "${lang_rules_regex_explain_char_any}" \
        --arg regex_explain_char_optional "${lang_rules_regex_explain_char_optional}" \
        --arg regex_explain_keep "${lang_rules_regex_explain_keep}" \
        --arg regex_explain_unknown "${lang_rules_regex_explain_unknown}" \
        --arg regex_explain_context_after "${lang_rules_regex_explain_context_after}" \
        --arg regex_explain_context_before "${lang_rules_regex_explain_context_before}" \
        --arg regex_explain_context_not_after "${lang_rules_regex_explain_context_not_after}" \
        --arg regex_explain_context_not_before "${lang_rules_regex_explain_context_not_before}" \
        --arg regex_hint_context "${lang_rules_regex_hint_context}" \
        --arg regex_help_seg_extract_anchor_1 "${lang_rules_regex_help_seg_extract_anchor_1}" \
        --arg regex_help_seg_extract_anchor_2 "${lang_rules_regex_help_seg_extract_anchor_2}" \
        --arg regex_help_seg_extract_anchor_3 "${lang_rules_regex_help_seg_extract_anchor_3}" \
        --arg regex_help_seg_extract_anchor_t "${lang_rules_regex_help_seg_extract_anchor_t}" \
        --arg regex_help_seg_optional_1 "${lang_rules_regex_help_seg_optional_1}" \
        --arg regex_help_seg_optional_2 "${lang_rules_regex_help_seg_optional_2}" \
        --arg regex_help_seg_optional_3 "${lang_rules_regex_help_seg_optional_3}" \
        --arg regex_help_seg_optional_t "${lang_rules_regex_help_seg_optional_t}" \
        --arg regex_help_seg_wsflex_1 "${lang_rules_regex_help_seg_wsflex_1}" \
        --arg regex_help_seg_wsflex_2 "${lang_rules_regex_help_seg_wsflex_2}" \
        --arg regex_help_seg_wsflex_t "${lang_rules_regex_help_seg_wsflex_t}" \
        --arg regex_help_tool_alt_1 "${lang_rules_regex_help_tool_alt_1}" \
        --arg regex_help_tool_alt_2 "${lang_rules_regex_help_tool_alt_2}" \
        --arg regex_help_tool_alt_3 "${lang_rules_regex_help_tool_alt_3}" \
        --arg regex_help_tool_alt_4 "${lang_rules_regex_help_tool_alt_4}" \
        --arg regex_help_tool_alt_t "${lang_rules_regex_help_tool_alt_t}" \
        --arg regex_help_tool_anchor_1 "${lang_rules_regex_help_tool_anchor_1}" \
        --arg regex_help_tool_anchor_2 "${lang_rules_regex_help_tool_anchor_2}" \
        --arg regex_help_tool_anchor_3 "${lang_rules_regex_help_tool_anchor_3}" \
        --arg regex_help_tool_anchor_4 "${lang_rules_regex_help_tool_anchor_4}" \
        --arg regex_help_tool_anchor_t "${lang_rules_regex_help_tool_anchor_t}" \
        --arg regex_help_tool_class_1 "${lang_rules_regex_help_tool_class_1}" \
        --arg regex_help_tool_class_2 "${lang_rules_regex_help_tool_class_2}" \
        --arg regex_help_tool_class_3 "${lang_rules_regex_help_tool_class_3}" \
        --arg regex_help_tool_class_t "${lang_rules_regex_help_tool_class_t}" \
        --arg regex_help_tool_context_1 "${lang_rules_regex_help_tool_context_1}" \
        --arg regex_help_tool_context_2 "${lang_rules_regex_help_tool_context_2}" \
        --arg regex_help_tool_context_3 "${lang_rules_regex_help_tool_context_3}" \
        --arg regex_help_tool_context_4 "${lang_rules_regex_help_tool_context_4}" \
        --arg regex_help_tool_context_t "${lang_rules_regex_help_tool_context_t}" \
        --arg regex_help_tool_fixed_1 "${lang_rules_regex_help_tool_fixed_1}" \
        --arg regex_help_tool_fixed_2 "${lang_rules_regex_help_tool_fixed_2}" \
        --arg regex_help_tool_fixed_3 "${lang_rules_regex_help_tool_fixed_3}" \
        --arg regex_help_tool_fixed_4 "${lang_rules_regex_help_tool_fixed_4}" \
        --arg regex_help_tool_fixed_t "${lang_rules_regex_help_tool_fixed_t}" \
        --arg regex_help_tool_variable_1 "${lang_rules_regex_help_tool_variable_1}" \
        --arg regex_help_tool_variable_2 "${lang_rules_regex_help_tool_variable_2}" \
        --arg regex_help_tool_variable_3 "${lang_rules_regex_help_tool_variable_3}" \
        --arg regex_help_tool_variable_4 "${lang_rules_regex_help_tool_variable_4}" \
        --arg regex_help_tool_variable_5 "${lang_rules_regex_help_tool_variable_5}" \
        --arg regex_help_tool_variable_t "${lang_rules_regex_help_tool_variable_t}" \
        --arg regex_seg_context "${lang_rules_regex_seg_context}" \
        --arg regex_tool_context "${lang_rules_regex_tool_context}" \
        --arg regex_assistant_title "${lang_rules_regex_assistant_title}" \
        --arg regex_toggle_seg_show "${lang_rules_regex_toggle_seg_show}" \
        --arg regex_toggle_seg_hide "${lang_rules_regex_toggle_seg_hide}" \
        --arg regex_btn_expert_mode "${lang_rules_regex_btn_expert_mode}" \
        --arg regex_btn_visual_mode "${lang_rules_regex_btn_visual_mode}" \
        --arg regex_parse_failed "${lang_rules_regex_parse_failed}" \
        --arg regex_btn_apply "${lang_rules_regex_btn_apply}" \
        --arg regex_btn_cancel "${lang_rules_regex_btn_cancel}" \
        --arg regex_btn_last_doc "${lang_rules_regex_btn_last_doc}" \
        --arg regex_btn_load "${lang_rules_regex_btn_load}" \
        --arg regex_btn_pick_doc "${lang_rules_regex_btn_pick_doc}" \
        --arg regex_btn_pick_confirm "${lang_rules_regex_btn_pick_confirm}" \
        --arg regex_btn_reload "${lang_rules_regex_btn_reload}" \
        --arg regex_btn_remove_seg "${lang_rules_regex_btn_remove_seg}" \
        --arg regex_seg_drag_hint "${lang_rules_regex_seg_drag_hint}" \
        --arg regex_casesensitive "${lang_rules_regex_casesensitive}" \
        --arg regex_class_alnum "${lang_rules_regex_class_alnum}" \
        --arg regex_class_digits "${lang_rules_regex_class_digits}" \
        --arg regex_class_length_fixed "${lang_rules_regex_class_length_fixed}" \
        --arg regex_class_length_range "${lang_rules_regex_class_length_range}" \
        --arg regex_class_letters "${lang_rules_regex_class_letters}" \
        --arg regex_class_special "${lang_rules_regex_class_special}" \
        --arg regex_expert_pattern "${lang_rules_regex_expert_pattern}" \
        --arg regex_explain_alt "${lang_rules_regex_explain_alt}" \
        --arg regex_explain_atomic "${lang_rules_regex_explain_atomic}" \
        --arg regex_explain_backref "${lang_rules_regex_explain_backref}" \
        --arg regex_explain_anchor_end "${lang_rules_regex_explain_anchor_end}" \
        --arg regex_explain_anchor_start "${lang_rules_regex_explain_anchor_start}" \
        --arg regex_explain_anchor_word "${lang_rules_regex_explain_anchor_word}" \
        --arg regex_explain_class_alnum "${lang_rules_regex_explain_class_alnum}" \
        --arg regex_explain_class_digits "${lang_rules_regex_explain_class_digits}" \
        --arg regex_explain_class_generic "${lang_rules_regex_explain_class_generic}" \
        --arg regex_explain_class_generic_negated "${lang_rules_regex_explain_class_generic_negated}" \
        --arg regex_explain_class_word_dot_dash "${lang_rules_regex_explain_class_word_dot_dash}" \
        --arg regex_explain_cp_char "${lang_rules_regex_explain_cp_char}" \
        --arg regex_explain_cp_digit "${lang_rules_regex_explain_cp_digit}" \
        --arg regex_explain_cp_h_space "${lang_rules_regex_explain_cp_h_space}" \
        --arg regex_explain_cp_non_digit "${lang_rules_regex_explain_cp_non_digit}" \
        --arg regex_explain_cp_non_space "${lang_rules_regex_explain_cp_non_space}" \
        --arg regex_explain_cp_non_word "${lang_rules_regex_explain_cp_non_word}" \
        --arg regex_explain_cp_range "${lang_rules_regex_explain_cp_range}" \
        --arg regex_explain_cp_space "${lang_rules_regex_explain_cp_space}" \
        --arg regex_explain_cp_v_space "${lang_rules_regex_explain_cp_v_space}" \
        --arg regex_explain_cp_word "${lang_rules_regex_explain_cp_word}" \
        --arg regex_explain_class_fixed "${lang_rules_regex_explain_class_fixed}" \
        --arg regex_explain_class_letters "${lang_rules_regex_explain_class_letters}" \
        --arg regex_explain_class_plus "${lang_rules_regex_explain_class_plus}" \
        --arg regex_explain_class_range "${lang_rules_regex_explain_class_range}" \
        --arg regex_explain_class_special "${lang_rules_regex_explain_class_special}" \
        --arg regex_explain_empty "${lang_rules_regex_explain_empty}" \
        --arg regex_explain_expert_only "${lang_rules_regex_explain_expert_only}" \
        --arg regex_explain_extract_anchor "${lang_rules_regex_explain_extract_anchor}" \
        --arg regex_explain_extract_value "${lang_rules_regex_explain_extract_value}" \
        --arg regex_explain_fixed "${lang_rules_regex_explain_fixed}" \
        --arg regex_explain_fixed_wsflex "${lang_rules_regex_explain_fixed_wsflex}" \
        --arg regex_explain_flags_case "${lang_rules_regex_explain_flags_case}" \
        --arg regex_explain_flags_dotall "${lang_rules_regex_explain_flags_dotall}" \
        --arg regex_explain_flags_extended "${lang_rules_regex_explain_flags_extended}" \
        --arg regex_explain_flags_group "${lang_rules_regex_explain_flags_group}" \
        --arg regex_explain_flags_multiline "${lang_rules_regex_explain_flags_multiline}" \
        --arg regex_explain_flags_off "${lang_rules_regex_explain_flags_off}" \
        --arg regex_explain_flags_scope_rest "${lang_rules_regex_explain_flags_scope_rest}" \
        --arg regex_explain_group_captured "${lang_rules_regex_explain_group_captured}" \
        --arg regex_explain_optional_suffix "${lang_rules_regex_explain_optional_suffix}" \
        --arg regex_explain_redos "${lang_rules_regex_explain_redos}" \
        --arg regex_explain_title "${lang_rules_regex_explain_title}" \
        --arg regex_explain_var_any "${lang_rules_regex_explain_var_any}" \
        --arg regex_explain_var_greedy "${lang_rules_regex_explain_var_greedy}" \
        --arg regex_explain_var_ws "${lang_rules_regex_explain_var_ws}" \
        --arg regex_explain_var_ws_single "${lang_rules_regex_explain_var_ws_single}" \
        --arg regex_extract_value_label "${lang_rules_regex_extract_value_label}" \
        --arg regex_hint_extract_lookaround "${lang_rules_regex_hint_extract_lookaround}" \
        --arg regex_hint_no_text_layer "${lang_rules_regex_hint_no_text_layer}" \
        --arg regex_hint_options_change_requires_reload "${lang_rules_regex_hint_options_change_requires_reload}" \
        --arg regex_hint_tested_one_sample "${lang_rules_regex_hint_tested_one_sample}" \
        --arg regex_load_section_title "${lang_rules_regex_load_section_title}" \
        --arg regex_multiline "${lang_rules_regex_multiline}" \
        --arg regex_opt_all_pages "${lang_rules_regex_opt_all_pages}" \
        --arg regex_opt_clean_spaces "${lang_rules_regex_opt_clean_spaces}" \
        --arg regex_opt_first_page "${lang_rules_regex_opt_first_page}" \
        --arg regex_opt_source_content "${lang_rules_regex_opt_source_content}" \
        --arg regex_opt_source_filename "${lang_rules_regex_opt_source_filename}" \
        --arg regex_preview_error "${lang_rules_regex_preview_error}" \
        --arg regex_network_error "${lang_rules_regex_network_error}" \
        --arg regex_preview_matches "${lang_rules_regex_preview_matches}" \
        --arg regex_preview_no_match "${lang_rules_regex_preview_no_match}" \
        --arg regex_sample_loaded "${lang_rules_regex_sample_loaded}" \
        --arg regex_sample_loading "${lang_rules_regex_sample_loading}" \
        --arg regex_sample_pick "${lang_rules_regex_sample_pick}" \
        --arg regex_seg_alt "${lang_rules_regex_seg_alt}" \
        --arg regex_seg_anchor "${lang_rules_regex_seg_anchor}" \
        --arg regex_seg_class "${lang_rules_regex_seg_class}" \
        --arg regex_seg_empty "${lang_rules_regex_seg_empty}" \
        --arg regex_seg_fixed "${lang_rules_regex_seg_fixed}" \
        --arg regex_seg_optional "${lang_rules_regex_seg_optional}" \
        --arg regex_seg_var "${lang_rules_regex_seg_var}" \
        --arg regex_seg_wsflex "${lang_rules_regex_seg_wsflex}" \
        --arg regex_source_label "${lang_rules_regex_source_label}" \
        --arg regex_tool_alt "${lang_rules_regex_tool_alt}" \
        --arg regex_tool_anchor "${lang_rules_regex_tool_anchor}" \
        --arg regex_tool_class "${lang_rules_regex_tool_class}" \
        --arg regex_tool_fixed "${lang_rules_regex_tool_fixed}" \
        --arg regex_tool_variable "${lang_rules_regex_tool_variable}" \
        --arg regex_var_any "${lang_rules_regex_var_any}" \
        --arg regex_var_until_anchor "${lang_rules_regex_var_until_anchor}" \
        --arg regex_var_whitespace "${lang_rules_regex_var_whitespace}" \
        --arg regex_wand_title "${lang_rules_regex_wand_title}" \
        '{regex_alt_add:$regex_alt_add,regex_alt_placeholder:$regex_alt_placeholder,regex_anchor_end:$regex_anchor_end,regex_anchor_start:$regex_anchor_start,regex_anchor_word:$regex_anchor_word,regex_context_after:$regex_context_after,regex_context_before:$regex_context_before,regex_context_not_after:$regex_context_not_after,regex_context_not_before:$regex_context_not_before,regex_assistant_title:$regex_assistant_title,regex_btn_expert_mode:$regex_btn_expert_mode,regex_btn_visual_mode:$regex_btn_visual_mode,regex_parse_failed:$regex_parse_failed,regex_toggle_seg_show:$regex_toggle_seg_show,regex_toggle_seg_hide:$regex_toggle_seg_hide,regex_btn_apply:$regex_btn_apply,regex_btn_cancel:$regex_btn_cancel,regex_btn_last_doc:$regex_btn_last_doc,regex_btn_load:$regex_btn_load,regex_btn_pick_doc:$regex_btn_pick_doc,regex_btn_pick_confirm:$regex_btn_pick_confirm,regex_btn_reload:$regex_btn_reload,regex_btn_remove_seg:$regex_btn_remove_seg,regex_seg_drag_hint:$regex_seg_drag_hint,regex_casesensitive:$regex_casesensitive,regex_class_alnum:$regex_class_alnum,regex_class_digits:$regex_class_digits,regex_class_length_fixed:$regex_class_length_fixed,regex_class_length_range:$regex_class_length_range,regex_class_letters:$regex_class_letters,regex_class_special:$regex_class_special,regex_expert_pattern:$regex_expert_pattern,regex_explain_alt:$regex_explain_alt,regex_explain_atomic:$regex_explain_atomic,regex_explain_backref:$regex_explain_backref,regex_explain_anchor_end:$regex_explain_anchor_end,regex_explain_anchor_start:$regex_explain_anchor_start,regex_explain_anchor_word:$regex_explain_anchor_word,regex_explain_context_after:$regex_explain_context_after,regex_explain_context_before:$regex_explain_context_before,regex_explain_context_not_after:$regex_explain_context_not_after,regex_explain_context_not_before:$regex_explain_context_not_before,regex_explain_class_alnum:$regex_explain_class_alnum,regex_explain_char_any:$regex_explain_char_any,regex_explain_char_optional:$regex_explain_char_optional,regex_explain_keep:$regex_explain_keep,regex_explain_unknown:$regex_explain_unknown,regex_explain_branch_reset:$regex_explain_branch_reset,regex_explain_class_star:$regex_explain_class_star,regex_explain_escape_cr:$regex_explain_escape_cr,regex_explain_escape_line_break:$regex_explain_escape_line_break,regex_explain_escape_newline:$regex_explain_escape_newline,regex_explain_escape_non_digit:$regex_explain_escape_non_digit,regex_explain_escape_non_space:$regex_explain_escape_non_space,regex_explain_escape_non_word:$regex_explain_escape_non_word,regex_explain_escape_not_newline:$regex_explain_escape_not_newline,regex_explain_escape_tab:$regex_explain_escape_tab,regex_explain_escape_word:$regex_explain_escape_word,regex_explain_class_digits:$regex_explain_class_digits,regex_explain_class_generic:$regex_explain_class_generic,regex_explain_class_generic_negated:$regex_explain_class_generic_negated,regex_explain_class_word_dot_dash:$regex_explain_class_word_dot_dash,regex_explain_cp_char:$regex_explain_cp_char,regex_explain_cp_digit:$regex_explain_cp_digit,regex_explain_cp_h_space:$regex_explain_cp_h_space,regex_explain_cp_non_digit:$regex_explain_cp_non_digit,regex_explain_cp_non_space:$regex_explain_cp_non_space,regex_explain_cp_non_word:$regex_explain_cp_non_word,regex_explain_cp_range:$regex_explain_cp_range,regex_explain_cp_space:$regex_explain_cp_space,regex_explain_cp_v_space:$regex_explain_cp_v_space,regex_explain_cp_word:$regex_explain_cp_word,regex_explain_class_fixed:$regex_explain_class_fixed,regex_explain_class_letters:$regex_explain_class_letters,regex_explain_class_plus:$regex_explain_class_plus,regex_explain_class_range:$regex_explain_class_range,regex_explain_class_special:$regex_explain_class_special,regex_explain_empty:$regex_explain_empty,regex_explain_expert_only:$regex_explain_expert_only,regex_explain_extract_anchor:$regex_explain_extract_anchor,regex_explain_extract_value:$regex_explain_extract_value,regex_explain_fixed:$regex_explain_fixed,regex_explain_fixed_wsflex:$regex_explain_fixed_wsflex,regex_explain_flags_case:$regex_explain_flags_case,regex_explain_flags_dotall:$regex_explain_flags_dotall,regex_explain_flags_extended:$regex_explain_flags_extended,regex_explain_flags_group:$regex_explain_flags_group,regex_explain_flags_multiline:$regex_explain_flags_multiline,regex_explain_flags_off:$regex_explain_flags_off,regex_explain_flags_scope_rest:$regex_explain_flags_scope_rest,regex_explain_group_captured:$regex_explain_group_captured,regex_explain_optional_suffix:$regex_explain_optional_suffix,regex_explain_redos:$regex_explain_redos,regex_explain_title:$regex_explain_title,regex_explain_var_any:$regex_explain_var_any,regex_explain_var_greedy:$regex_explain_var_greedy,regex_explain_var_ws:$regex_explain_var_ws,regex_explain_var_ws_single:$regex_explain_var_ws_single,regex_extract_value_label:$regex_extract_value_label,regex_hint_context:$regex_hint_context,regex_help_seg_extract_anchor_1:$regex_help_seg_extract_anchor_1,regex_help_seg_extract_anchor_2:$regex_help_seg_extract_anchor_2,regex_help_seg_extract_anchor_3:$regex_help_seg_extract_anchor_3,regex_help_seg_extract_anchor_t:$regex_help_seg_extract_anchor_t,regex_help_seg_optional_1:$regex_help_seg_optional_1,regex_help_seg_optional_2:$regex_help_seg_optional_2,regex_help_seg_optional_3:$regex_help_seg_optional_3,regex_help_seg_optional_t:$regex_help_seg_optional_t,regex_help_seg_wsflex_1:$regex_help_seg_wsflex_1,regex_help_seg_wsflex_2:$regex_help_seg_wsflex_2,regex_help_seg_wsflex_t:$regex_help_seg_wsflex_t,regex_help_tool_alt_1:$regex_help_tool_alt_1,regex_help_tool_alt_2:$regex_help_tool_alt_2,regex_help_tool_alt_3:$regex_help_tool_alt_3,regex_help_tool_alt_4:$regex_help_tool_alt_4,regex_help_tool_alt_t:$regex_help_tool_alt_t,regex_help_tool_anchor_1:$regex_help_tool_anchor_1,regex_help_tool_anchor_2:$regex_help_tool_anchor_2,regex_help_tool_anchor_3:$regex_help_tool_anchor_3,regex_help_tool_anchor_4:$regex_help_tool_anchor_4,regex_help_tool_anchor_t:$regex_help_tool_anchor_t,regex_help_tool_class_1:$regex_help_tool_class_1,regex_help_tool_class_2:$regex_help_tool_class_2,regex_help_tool_class_3:$regex_help_tool_class_3,regex_help_tool_class_t:$regex_help_tool_class_t,regex_help_tool_context_1:$regex_help_tool_context_1,regex_help_tool_context_2:$regex_help_tool_context_2,regex_help_tool_context_3:$regex_help_tool_context_3,regex_help_tool_context_4:$regex_help_tool_context_4,regex_help_tool_context_t:$regex_help_tool_context_t,regex_help_tool_fixed_1:$regex_help_tool_fixed_1,regex_help_tool_fixed_2:$regex_help_tool_fixed_2,regex_help_tool_fixed_3:$regex_help_tool_fixed_3,regex_help_tool_fixed_4:$regex_help_tool_fixed_4,regex_help_tool_fixed_t:$regex_help_tool_fixed_t,regex_help_tool_variable_1:$regex_help_tool_variable_1,regex_help_tool_variable_2:$regex_help_tool_variable_2,regex_help_tool_variable_3:$regex_help_tool_variable_3,regex_help_tool_variable_4:$regex_help_tool_variable_4,regex_help_tool_variable_5:$regex_help_tool_variable_5,regex_help_tool_variable_t:$regex_help_tool_variable_t,regex_hint_extract_lookaround:$regex_hint_extract_lookaround,regex_hint_no_text_layer:$regex_hint_no_text_layer,regex_hint_options_change_requires_reload:$regex_hint_options_change_requires_reload,regex_hint_tested_one_sample:$regex_hint_tested_one_sample,regex_load_section_title:$regex_load_section_title,regex_multiline:$regex_multiline,regex_opt_all_pages:$regex_opt_all_pages,regex_opt_clean_spaces:$regex_opt_clean_spaces,regex_opt_first_page:$regex_opt_first_page,regex_opt_source_content:$regex_opt_source_content,regex_opt_source_filename:$regex_opt_source_filename,regex_preview_error:$regex_preview_error,regex_network_error:$regex_network_error,regex_preview_matches:$regex_preview_matches,regex_preview_no_match:$regex_preview_no_match,regex_sample_loaded:$regex_sample_loaded,regex_sample_loading:$regex_sample_loading,regex_sample_pick:$regex_sample_pick,regex_seg_alt:$regex_seg_alt,regex_seg_anchor:$regex_seg_anchor,regex_seg_context:$regex_seg_context,regex_seg_class:$regex_seg_class,regex_seg_empty:$regex_seg_empty,regex_seg_fixed:$regex_seg_fixed,regex_seg_optional:$regex_seg_optional,regex_seg_var:$regex_seg_var,regex_seg_wsflex:$regex_seg_wsflex,regex_source_label:$regex_source_label,regex_tool_alt:$regex_tool_alt,regex_tool_anchor:$regex_tool_anchor,regex_tool_context:$regex_tool_context,regex_tool_class:$regex_tool_class,regex_tool_fixed:$regex_tool_fixed,regex_tool_variable:$regex_tool_variable,regex_var_any:$regex_var_any,regex_var_until_anchor:$regex_var_until_anchor,regex_var_whitespace:$regex_var_whitespace,regex_wand_title:$regex_wand_title,btn_add_rule:$btn_add_rule,btn_add_subrule:$btn_add_subrule,btn_remove_rule:$btn_remove_rule,btn_duplicate_rule:$btn_duplicate_rule,btn_jump_raw_rule:$btn_jump_raw_rule,btn_remove_subrule:$btn_remove_subrule,btn_save:$btn_save,btn_cancel:$btn_cancel,rule_name:$rule_name,rule_condition:$rule_condition,cond_any:$cond_any,cond_all:$cond_all,cond_none:$cond_none,tagname:$tagname,tagname_regex:$tagname_regex,targetfolder:$targetfolder,placeholder_targetfolder:$placeholder_targetfolder,dirname_regex:$dirname_regex,multiline:$multiline,dirname_multiline:$dirname_multiline,postscript:$postscript,apprise:$apprise,apprise_att:$apprise_att,apprise_att_true:$apprise_att_true,apprise_att_false:$apprise_att_false,notify_lang:$notify_lang,on_match_action:$on_match_action,on_match_result:$on_match_result,omatch_unset:$omatch_unset,omatch_continue:$omatch_continue,omatch_break:$omatch_break,omatch_merge:$omatch_merge,omatch_replace:$omatch_replace,omatch_exclusive:$omatch_exclusive,requires:$requires,excludes:$excludes,sub_searchstring:$sub_searchstring,sub_searchtyp:$sub_searchtyp,sub_isregex:$sub_isregex,sub_source:$sub_source,sub_casesensitive:$sub_casesensitive,sub_multiline:$sub_multiline,src_filename:$src_filename,src_content:$src_content,st_contains:$st_contains,st_not_contains:$st_not_contains,st_is:$st_is,st_is_not:$st_is_not,st_starts:$st_starts,st_not_starts:$st_not_starts,st_ends:$st_ends,st_not_ends:$st_not_ends,st_matches:$st_matches,st_not_matches:$st_not_matches,tab_visual:$tab_visual,tab_raw:$tab_raw,filter_placeholder:$filter_placeholder,filter_count:$filter_count,filter_empty:$filter_empty,drag_hint:$drag_hint,dup_suffix:$dup_suffix,section_details:$section_details,toggle_details_show:$toggle_details_show,toggle_details_hide:$toggle_details_hide,toggle_rule_expand:$toggle_rule_expand,toggle_rule_collapse:$toggle_rule_collapse,save_success:$save_success,save_error:$save_error,save_error_title:$save_error_title,save_http_error:$save_http_error,save_dup_blocked:$save_dup_blocked,val_rule_dup_name:$val_rule_dup_name,raw_invalid:$raw_invalid,unsaved_warning:$unsaved_warning,tf_builder:$tf_builder,tf_pick:$tf_pick,tf_pick_title:$tf_pick_title,tf_pick_confirm:$tf_pick_confirm,tf_preview:$tf_preview,tf_mode_abs:$tf_mode_abs,tf_mode_rel:$tf_mode_rel,tf_dirhint:$tf_dirhint,tf_dirregex_help:$tf_dirregex_help,tf_chip_dirname:$tf_chip_dirname,tf_apply:$tf_apply,tn_builder:$tn_builder,tn_chip_tagname:$tn_chip_tagname,tn_dirhint:$tn_dirhint,tn_regex_help:$tn_regex_help,help_rule_name:$help_rule_name,help_rule_condition:$help_rule_condition,help_tagname:$help_tagname,help_targetfolder:$help_targetfolder,help_sub_source:$help_sub_source,help_sub_searchtyp:$help_sub_searchtyp,help_sub_searchstring:$help_sub_searchstring,help_sub_isregex:$help_sub_isregex,help_sub_casesensitive:$help_sub_casesensitive,help_sub_multiline:$help_sub_multiline,help_tagname_regex:$help_tagname_regex,help_multiline:$help_multiline,help_dirname_multiline:$help_dirname_multiline,help_on_match_action:$help_on_match_action,help_on_match_result:$help_on_match_result,help_requires:$help_requires,help_excludes:$help_excludes,help_postscript:$help_postscript,help_apprise:$help_apprise,help_link:$help_link,help_apprise_att:$help_apprise_att,help_notify_lang:$help_notify_lang,help_dirname_regex:$help_dirname_regex,help_tf_preview:$help_tf_preview}')

    _name_val=$(rules_html_escape "${_name}")
    _desc_val=$(rules_html_escape "${_desc}")

    # Shared folder picker (modal + lang JSON) so the target-folder builder can
    # browse absolute destination paths on the editor page.
    synocr_folderpicker_emit

    # Path-token labels for the chip editor inside the target-folder builder.
    # Restricted to tokens the backend actually expands inside targetfolder
    # (replace_variables); §tag/§tit are filename-only and intentionally excluded.
    _path_tokens_json=$(jq -c -n \
        --arg docr             "${lang_edit_set2_renamesyntax_chip_docr}" \
        --arg mocr             "${lang_edit_set2_renamesyntax_chip_mocr}" \
        --arg yocr2            "${lang_edit_set2_renamesyntax_chip_yocr2}" \
        --arg yocr4            "${lang_edit_set2_renamesyntax_chip_yocr4}" \
        --arg ssnow            "${lang_edit_set2_renamesyntax_chip_ssnow}" \
        --arg mmnow            "${lang_edit_set2_renamesyntax_chip_mmnow}" \
        --arg hhnow            "${lang_edit_set2_renamesyntax_chip_hhnow}" \
        --arg dnow             "${lang_edit_set2_renamesyntax_chip_dnow}" \
        --arg mnow             "${lang_edit_set2_renamesyntax_chip_mnow}" \
        --arg ynow2            "${lang_edit_set2_renamesyntax_chip_ynow2}" \
        --arg ynow4            "${lang_edit_set2_renamesyntax_chip_ynow4}" \
        --arg sssource         "${lang_edit_set2_renamesyntax_chip_sssource}" \
        --arg mmsource         "${lang_edit_set2_renamesyntax_chip_mmsource}" \
        --arg hhsource         "${lang_edit_set2_renamesyntax_chip_hhsource}" \
        --arg dsource          "${lang_edit_set2_renamesyntax_chip_dsource}" \
        --arg msource          "${lang_edit_set2_renamesyntax_chip_msource}" \
        --arg ysource2         "${lang_edit_set2_renamesyntax_chip_ysource2}" \
        --arg ysource4         "${lang_edit_set2_renamesyntax_chip_ysource4}" \
        --arg pagecount        "${lang_edit_set2_renamesyntax_chip_pagecount}" \
        --arg pagecounttotal   "${lang_edit_set2_renamesyntax_chip_pagecounttotal}" \
        --arg filecounttotal   "${lang_edit_set2_renamesyntax_chip_filecounttotal}" \
        --arg pagecountprofile "${lang_edit_set2_renamesyntax_chip_pagecountprofile}" \
        --arg filecountprofile "${lang_edit_set2_renamesyntax_chip_filecountprofile}" \
        --arg dirname_regex    "${lang_rules_path_chip_dirname_regex}" \
        '{"§docr":$docr,"§mocr":$mocr,"§yocr2":$yocr2,"§yocr4":$yocr4,"§ssnow":$ssnow,"§mmnow":$mmnow,"§hhnow":$hhnow,"§dnow":$dnow,"§mnow":$mnow,"§ynow2":$ynow2,"§ynow4":$ynow4,"§sssource":$sssource,"§mmsource":$mmsource,"§hhsource":$hhsource,"§dsource":$dsource,"§msource":$msource,"§ysource2":$ysource2,"§ysource4":$ysource4,"§pagecount":$pagecount,"§pagecounttotal":$pagecounttotal,"§filecounttotal":$filecounttotal,"§pagecountprofile":$pagecountprofile,"§filecountprofile":$filecountprofile,"§dirname_RegEx":$dirname_regex}')

    _tag_tokens_json=$(jq -c -n \
        --arg tagname_regex "${lang_rules_tag_chip_tagname_regex}" \
        '{"§tagname_RegEx":$tagname_regex}')

    # Notification languages for the rule editor (same discovery as GUI_edit.sh).
    _notify_langs_json='{}'
    _notify_lang_codes=()
    while read -r _nl_code; do
        [ -n "${_nl_code}" ] && _notify_lang_codes+=("${_nl_code}")
    done <<< "$(find "./lang/" -maxdepth 1 -type f -printf "%f\n" 2>/dev/null | grep -vE '/$' | cut -f 1 -d '.' | cut -f 2 -d '_' | grep -vE '^$' | sort)"
    for _nl_code in "${_notify_lang_codes[@]}"; do
        eval "_nl_label=\$lang_langname_${_nl_code}"
        _notify_langs_json=$(jq -c --arg k "${_nl_code}" --arg v "${_nl_label}" '. + {($k): $v}' <<< "${_notify_langs_json}")
    done

    _count=$(printf '%s' "${_rj}" | jq 'keys | length' 2>/dev/null)
    [ -z "${_count}" ] && _count=0
    if rules_synocr_venv_missing; then
        _yaml_venv_missing=true
    else
        _yaml_venv_missing=false
    fi
    if [ "${_count}" -gt 0 ]; then
        _import_btn='<span class="synocr-has-tip" data-tip="'"${lang_rules_import_disabled_tooltip}"'"><button type="button" class="btn btn-outline-secondary btn-sm" disabled>'"${lang_rules_btn_import}"'</button></span>'
    else
        _import_btn='<button type="button" class="btn btn-outline-secondary btn-sm" data-bs-toggle="modal" data-bs-target="#popup-rules-import" id="synocr-rules-import-open">'"${lang_rules_btn_import}"'</button>'
    fi

    echo '
    <div class="synocr-rules-editor-page synocr-form-page">
    <div class="d-flex justify-content-between align-items-center mt-3 flex-wrap gap-2 synocr-rules-editor-head">
        <h2 class="synocr-text-blue mb-0">'"${lang_rules_editor_title}"'</h2>
        <div class="synocr-rules-actionbar d-flex gap-2 flex-shrink-0 align-items-center flex-wrap justify-content-end">
            '"${_import_btn}"'
            <button type="button" class="btn btn-primary btn-sm synocr-rules-save-btn" style="background-color: #0086E5;" id="synocr-rules-save">'"${lang_rules_btn_save}"'</button>
            <a href="index.cgi?page=rules" class="btn btn-secondary btn-sm synocr-rules-leave-link">'"${lang_rules_back}"'</a>
            <span id="synocr-rules-status" class="small synocr-rules-status"></span>
        </div>
    </div>
    <hr class="mt-2 mb-3 synocr-rules-editor-hr">

    <form id="synocr-ruleset-form" class="synocr-ruleset-form" autocomplete="off" onsubmit="return false;">
        <input type="hidden" name="ruleset_id" id="synocr-ruleset-id" value="'"${_id}"'">

        <div class="synocr-ruleset-meta mb-3">
            <label for="ruleset-name">'"${lang_rules_field_name}"'</label>
            <input type="text" class="form-control synocr-ruleset-name-input" id="ruleset-name" name="name" value="'"${_name_val}"'" required>
            <label for="ruleset-description">'"${lang_rules_field_description}"'</label>
            <input type="text" class="form-control synocr-ruleset-desc-input" id="ruleset-description" name="description" value="'"${_desc_val}"'">
        </div>

        <script type="application/json" id="synocr-ruleset-data">'"${_data_json}"'</script>
        <script type="application/json" id="synocr-rules-lang">'"${_lang_json}"'</script>
        <script type="application/json" id="synocr-rules-path-tokens">'"${_path_tokens_json}"'</script>
        <script type="application/json" id="synocr-rules-tag-tokens">'"${_tag_tokens_json}"'</script>
        <script type="application/json" id="synocr-rules-notify-langs">'"${_notify_langs_json}"'</script>

        <div class="synocr-rules-tabs-row d-flex flex-wrap align-items-center gap-3 mb-3">
            <ul class="nav nav-tabs mb-0 synocr-ruleset-tabs-nav" id="synocr-rules-tabs" role="tablist">
                <li class="nav-item"><a class="nav-link active" id="synocr-rules-tab-visual" data-bs-toggle="tab" href="#synocr-rules-pane-visual" role="tab">'"${lang_rules_tab_visual}"'</a></li>
                <li class="nav-item"><a class="nav-link" id="synocr-rules-tab-raw" data-bs-toggle="tab" href="#synocr-rules-pane-raw" role="tab">'"${lang_rules_tab_raw}"'</a></li>
            </ul>
            <div class="synocr-rules-filter-wrap ms-auto" id="synocr-rules-filter-wrap">
                <div class="d-flex align-items-center gap-2 flex-wrap justify-content-end">
                    <input type="search" class="form-control form-control-sm synocr-rules-filter-input" id="synocr-rules-filter" autocomplete="off" placeholder="'"${lang_rules_filter_placeholder}"'">
                    <span class="small text-muted synocr-rules-filter-count" id="synocr-rules-filter-count" style="display:none;" aria-live="polite"></span>
                </div>
            </div>
        </div>
        <div class="synocr-ruleset-tab-area">
            <div class="tab-content synocr-ruleset-tab-content">
                <div class="tab-pane fade show active" id="synocr-rules-pane-visual" role="tabpanel">
                    <div class="synocr-rules-editor-toolbar d-flex justify-content-between align-items-center mb-2" id="synocr-rules-toolbar"></div>
                    <div class="synocr-rules-editor-scroll" id="synocr-rules-editor-scroll">
                        <div id="synocr-rules-editor" data-ruleset-id="'"${_id}"'">
                            <div id="synocr-rules-editor-root"></div>
                        </div>
                    </div>
                </div>
                <div class="tab-pane fade" id="synocr-rules-pane-raw" role="tabpanel">
                    <textarea class="form-control font-monospace synocr-rules-raw-input" id="synocr-rules-raw" spellcheck="false"></textarea>
                </div>
            </div>
        </div>
    </form>
    </div>

    <!-- YAML import modal (GET navigation — index.cgi routes via QUERY_STRING only) -->
    <div class="modal fade" id="popup-rules-import" tabindex="-1" aria-labelledby="label-rules-import" aria-hidden="true">
        <div class="modal-dialog modal-lg">
            <div class="modal-content" id="synocr-rules-import-panel">
                <div class="modal-header bg-light">
                    <h5 class="modal-title" id="label-rules-import">'"${lang_rules_import_title}"'</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="card card-body mb-3 synocr-hint-card">'"${lang_rules_import_hint}"'</div>
                    <label class="form-label" for="synocr-import-path">'"${lang_rules_import_path}"'</label>
                    <div class="input-group">
                        <input type="text" class="form-control" id="synocr-import-path" readonly placeholder="*.yml / *.yaml">
                        <button class="btn btn-outline-secondary" type="button" id="synocr-import-browse">'"${lang_rules_import_pick}"'</button>
                    </div>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">'"${lang_rules_btn_cancel}"'</button>
                    <button type="button" class="btn btn-primary btn-sm" style="background-color:#0086E5;" id="synocr-import-submit">'"${lang_rules_import_btn}"'</button>
                </div>
            </div>
        </div>
    </div>

    <!-- YAML import blocked: python3_env not ready yet -->
    <div class="modal fade" id="popup-rules-import-no-venv" tabindex="-1" aria-labelledby="label-rules-import-no-venv" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline text-danger" id="label-rules-import-no-venv">'"${lang_rules_import_no_venv_title}"'</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body text-center">
                    <p class="mb-0">'"${lang_rules_import_no_venv}"'</p>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-primary btn-sm" style="background-color: #0086E5;" data-bs-dismiss="modal">'"${lang_buttonnext}"'...</button>
                </div>
            </div>
        </div>
    </div>
    <script type="text/javascript">
        (function(){
            var rulesetId = "'"${_id}"'";
            window.synocrRulesYamlVenvMissing = '"${_yaml_venv_missing}"' === "true";
            function synocrShowRulesModal(el) {
                if (!el) return false;
                if (el.parentElement !== document.body) document.body.appendChild(el);
                var $ = window.jQuery;
                if ($ && $.fn.modal) { $(el).modal("show"); return true; }
                if (window.bootstrap && bootstrap.Modal) { bootstrap.Modal.getOrCreateInstance(el).show(); return true; }
                return false;
            }
            function synocrHideRulesModal(el) {
                if (!el) return;
                var $ = window.jQuery;
                if ($ && $.fn.modal) { $(el).modal("hide"); return; }
                if (window.bootstrap && bootstrap.Modal) {
                    var inst = bootstrap.Modal.getInstance(el);
                    if (inst) inst.hide();
                }
            }
            function synocrShowRulesImportNoVenvModal() {
                var importModal = document.getElementById("popup-rules-import");
                var noVenvModal = document.getElementById("popup-rules-import-no-venv");
                if (!noVenvModal) return;
                synocrHideRulesModal(importModal);
                synocrShowRulesModal(noVenvModal);
            }
            function synocrInitRulesImportUi() {
                var browse = document.getElementById("synocr-import-browse");
                if (browse) browse.addEventListener("click", function(){
                    if (typeof synocr_openPicker !== "function") return;
                    synocr_openPicker("synocr-import-path", "file", {
                        extensions: ["yml","yaml"],
                        title: "'"${lang_rules_import_title}"'",
                        confirmLabel: "'"${lang_rules_import_btn}"'"
                    });
                });
                var importBtn = document.getElementById("synocr-import-submit");
                if (importBtn) importBtn.addEventListener("click", function(){
                    var pathInp = document.getElementById("synocr-import-path");
                    var path = pathInp ? pathInp.value : "";
                    if (!path) return;
                    if (window.synocrRulesYamlVenvMissing) {
                        synocrShowRulesImportNoVenvModal();
                        return;
                    }
                    var target = "index.cgi?page=rules-import-run-" + rulesetId + "&import_path=" + encodeURIComponent(path);
                    window.location.href = target;
                });
                var params = new URLSearchParams(window.location.search);
                if (params.get("yaml_noven") === "1") {
                    synocrShowRulesImportNoVenvModal();
                } else if (params.get("yaml") === "1" && '"${_count}"' === "0") {
                    synocrShowRulesModal(document.getElementById("popup-rules-import"));
                }
            }
            if (document.readyState === "complete") {
                synocrInitRulesImportUi();
            } else {
                window.addEventListener("load", synocrInitRulesImportUi);
            }
        })();
    </script>

    <!-- Save success modal (like GUI_edit) -->
    <div class="modal fade" id="popup-rules-save" tabindex="-1" aria-labelledby="label-rules-save" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline" id="label-rules-save">'"${lang_popup_note}"'</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body text-center">
                    <p id="popup-rules-save-msg">'"${lang_rules_save_success}"'</p>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-primary btn-sm" style="background-color: #0086E5;" data-bs-dismiss="modal">'"${lang_buttonnext}"'...</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Save error modal -->
    <div class="modal fade" id="popup-rules-save-error" tabindex="-1" aria-labelledby="label-rules-save-error" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title align-baseline text-danger" id="label-rules-save-error">'"${lang_rules_save_error_title}"'</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p id="popup-rules-error-msg" class="synocr-rules-error-msg mb-0"></p>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-primary btn-sm" style="background-color: #0086E5;" data-bs-dismiss="modal">'"${lang_buttonnext}"'...</button>
                </div>
            </div>
        </div>
    </div>'
}


# --- dispatch ---------------------------------------------------------------

case "${synocr_request_page}" in
    rules-new)
        rules_action_new
        ;;
    rules-dup-*)
        rules_action_dup "${synocr_request_page#rules-dup-}"
        ;;
    rules-del-confirm-*)
        rules_action_del_confirm "${synocr_request_page#rules-del-confirm-}"
        ;;
    rules-del-*)
        rules_action_del_query "${synocr_request_page#rules-del-}"
        ;;
    rules-import-run-*)
        rules_import_run "${synocr_request_page#rules-import-run-}"
        ;;
    rules-import-*)
        rules_import_view "${synocr_request_page#rules-import-}"
        ;;
    rules-edit-*)
        rules_edit_view "${synocr_request_page#rules-edit-}"
        ;;
    *)
        rules_list_view
        ;;
esac
