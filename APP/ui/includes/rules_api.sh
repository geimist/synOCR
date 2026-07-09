#!/bin/bash
# shellcheck disable=SC2154,SC2016
#################################################################################
#   description:    - JSON API endpoints for the rule editor (POST save/import)  #
#   path:            /usr/syno/synoman/webman/3rdparty/synOCR/includes/rules_api.sh
#   © 2026 by geimist                                                           #
#################################################################################
#
# Sourced by index.cgi BEFORE the HTML shell so it can emit a clean
# application/json response and exit. Requires functions.sh + language() to be
# loaded already (synocr_sqlite, sql_escape, rules_validate_json, lang_rules_*).

# Emit {"ok":false,"errors":[...]}. With $1: error message(s), newline-separated.
# Without $1: read error lines from stdin (one per line).
rules_api_json_err() {
    local _first=1 _line
    printf '{"ok":false,"errors":['
    if [ -n "${1-}" ]; then
        while IFS= read -r _line; do
            [ -z "${_line}" ] && continue
            [ ${_first} -eq 0 ] && printf ','
            printf '%s' "$(printf '%s' "${_line}" | jq -Rs .)"
            _first=0
        done <<< "$1"
    else
        while IFS= read -r _line; do
            [ -z "${_line}" ] && continue
            [ ${_first} -eq 0 ] && printf ','
            printf '%s' "$(printf '%s' "${_line}" | jq -Rs .)"
            _first=0
        done
    fi
    printf ']}'
}

# POST body (JSON): { ruleset_id, name, description, rules, groups }
# Persists the ruleset; validates with rules_validate_json (hard, non-zero aborts).
rules_api_save_json() {
    local _body _id _name _desc _rules _groups _blob _errs _rc _count _dup
    # Read exactly CONTENT_LENGTH bytes so we never block waiting for stdin EOF.
    if [ -n "${CONTENT_LENGTH:-}" ] && [ "${CONTENT_LENGTH}" -gt 0 ] 2>/dev/null; then
        _body=$(head -c "${CONTENT_LENGTH}")
    else
        _body=$(cat)
    fi
    if ! printf '%s' "${_body}" | jq -e . >/dev/null 2>&1; then
        rules_api_json_err "${lang_rules_val_json_parse}"
        return
    fi
    _id=$(printf '%s' "${_body}" | jq -r '.ruleset_id // empty')
    _name=$(printf '%s' "${_body}" | jq -r '.name // empty')
    _desc=$(printf '%s' "${_body}" | jq -r '.description // empty')
    _rules=$(printf '%s' "${_body}" | jq -c '.rules // {}')
    _groups=$(printf '%s' "${_body}" | jq -c '.groups // {}')

    if [ -z "${_id}" ]; then
        rules_api_json_err "${lang_rules_val_missing_id}"
        return
    fi
    if [ -z "${_name}" ]; then
        rules_api_json_err "${lang_rules_val_no_name}"
        return
    fi
    # duplicate name check (excluding the current ruleset)
    _dup=$(synocr_sqlite "SELECT count(*) FROM ruleset WHERE name='$(sql_escape "${_name}")' AND id!='${_id}'")
    if [ "${_dup}" -gt 0 ]; then
        rules_api_json_err "${lang_rules_val_dup_name}"
        return
    fi

    # hard structural validation (storage-agnostic)
    _blob=$(printf '{"rules":%s,"groups":%s}' "${_rules}" "${_groups}")
    _errs=$(rules_validate_json "${_blob}")
    _rc=$?
    if [ ${_rc} -ne 0 ]; then
        rules_api_json_err "${_errs}"
        return
    fi

    _count=$(printf '%s' "${_rules}" | jq 'keys | length' 2>/dev/null)
    [ -z "${_count}" ] && _count=0
    _editor_count=$(printf '%s' "${_body}" | jq -r '.editor_rule_count // empty')
    if [ -n "${_editor_count}" ] && [ "${_editor_count}" -eq "${_editor_count}" ] 2>/dev/null && [ "${_editor_count}" -ne "${_count}" ]; then
        rules_api_json_err "${lang_rules_save_dup_blocked}"
        return
    fi

    synocr_sqlite "UPDATE ruleset
                       SET name='$(sql_escape "${_name}")',
                           description='$(sql_escape "${_desc}")',
                           rules_json='$(sql_escape "${_rules}")',
                           groups_json='$(sql_escape "${_groups}")',
                           rule_count='${_count}',
                           updated_at=datetime('now','localtime')
                     WHERE id='${_id}';" >/dev/null

    printf '{"ok":true,"rule_count":%s,"updated":"%s"}' "${_count}" "$(date '+%Y-%m-%d %H:%M')"
}

# POST body (JSON), three operations via `op`:
#   load:    { op, path, searchAll, clean_up_spaces, source }
#            -> { ok, text, token, notes? }
#   preview: { op, token, pattern, mode, multiline, casesensitive, extractType }
#            -> { ok, matches:[text,...], count, extracted?, error?, notes? }
#   release: { op, token } -> { ok }
#
# Text extraction mirrors synOCR.sh (pdftotext -layout + sed clean_up); match
# runs the same grep -oP/-oPz flags as the rule engine; extract post-processing
# mirrors the tagname_RegEx / dirname_RegEx pipelines so preview == production.
rules_api_regex_preview() {
    local _body _op _tmpdir
    _tmpdir="${TMPDIR:-/tmp}"
    [ -d "${_tmpdir}" ] || _tmpdir=/tmp

    if [ -n "${CONTENT_LENGTH:-}" ] && [ "${CONTENT_LENGTH}" -gt 0 ] 2>/dev/null; then
        _body=$(head -c "${CONTENT_LENGTH}")
    else
        _body=$(cat)
    fi
    if ! printf '%s' "${_body}" | jq -e . >/dev/null 2>&1; then
        rules_api_json_err "${lang_rules_val_json_parse}"
        return
    fi
    _op=$(printf '%s' "${_body}" | jq -r '.op // empty')

    case "${_op}" in
        load)
            local _path _searchAll _clean _source _tmpfile _ptmp _token _text _notes
            _path=$(printf '%s' "${_body}" | jq -r '.path // empty')
            _searchAll=$(printf '%s' "${_body}" | jq -r '.searchAll // "first"')
            _clean=$(printf '%s' "${_body}" | jq -r '.clean_up_spaces // "true"')
            _source=$(printf '%s' "${_body}" | jq -r '.source // "content"')

            if [ -z "${_path}" ] || ! printf '%s' "${_path}" | grep -qiE '\.pdf$'; then
                printf '{"ok":false,"error":%s}' "$(printf '%s' "${lang_rules_regex_err_path}" | jq -Rs .)"
                return
            fi
            [ -f "${_path}" ] || { printf '{"ok":false,"error":%s}' "$(printf '%s' "${lang_rules_regex_err_notfound}" | jq -Rs .)"; return; }

            _tmpfile=$(mktemp "${_tmpdir}/synocr_regex_XXXXXX") || { printf '{"ok":false,"error":%s}' "$(printf '%s' "${lang_rules_regex_err_tmp}" | jq -Rs .)"; return; }
            _token=$(basename "${_tmpfile}" | sed 's/^synocr_regex_//')

            if [ "${_source}" = "filename" ]; then
                basename "${_path}" > "${_tmpfile}"
            else
                _ptmp=$(mktemp "${_tmpdir}/synocr_regexpdf_XXXXXX") || { rm -f "${_tmpfile}"; printf '{"ok":false,"error":%s}' "$(printf '%s' "${lang_rules_regex_err_tmp}" | jq -Rs .)"; return; }
                if [ "${_searchAll}" = "all" ]; then
                    /bin/pdftotext -layout "${_path}" "${_ptmp}" 2>/dev/null
                else
                    /bin/pdftotext -layout -l 1 "${_path}" "${_ptmp}" 2>/dev/null
                fi
                sed -i 's/^ *//' "${_ptmp}"
                if [ "${_clean}" = "true" ]; then
                    sed -i 's/ \+/ /g' "${_ptmp}"
                fi
                [ -s "${_ptmp}" ] || _notes="no_text_layer"
                # cap extracted text ~500 KB so grep stays fast
                head -c 512000 "${_ptmp}" > "${_tmpfile}"
                rm -f "${_ptmp}"
            fi

            _text=$(cat "${_tmpfile}"; printf 'X'); _text=${_text%X}
            if [ -n "${_notes:-}" ]; then
                printf '{"ok":true,"token":%s,"text":%s,"notes":%s}' \
                    "$(printf '%s' "${_token}" | jq -Rs .)" \
                    "$(printf '%s' "${_text}" | jq -Rs .)" \
                    "$(printf '%s' "${_notes}" | jq -Rs .)"
            else
                printf '{"ok":true,"token":%s,"text":%s}' \
                    "$(printf '%s' "${_token}" | jq -Rs .)" \
                    "$(printf '%s' "${_text}" | jq -Rs .)"
            fi
            ;;
        preview)
            local _token _pattern _mode _ml _cs _extractType _tmpfile _grep_opt _matches _count _extracted _sanitize1 _result
            _token=$(printf '%s' "${_body}" | jq -r '.token // empty')
            _pattern=$(printf '%s' "${_body}" | jq -r '.pattern // empty')
            _mode=$(printf '%s' "${_body}" | jq -r '.mode // "match"')
            _ml=$(printf '%s' "${_body}" | jq -r '.multiline // "false"')
            _cs=$(printf '%s' "${_body}" | jq -r '.casesensitive // "false"')
            _extractType=$(printf '%s' "${_body}" | jq -r '.extractType // "tag"')

            if ! printf '%s' "${_token}" | grep -qE '^[A-Za-z0-9_-]+$'; then
                printf '{"ok":false,"error":%s}' "$(printf '%s' "${lang_rules_regex_err_token}" | jq -Rs .)"
                return
            fi
            _tmpfile="${_tmpdir}/synocr_regex_${_token}"
            [ -f "${_tmpfile}" ] || { printf '{"ok":false,"error":%s}' "$(printf '%s' "${lang_rules_regex_err_token}" | jq -Rs .)"; return; }

            [ -n "${_pattern}" ] || { printf '{"ok":true,"matches":[],"count":0}'; return; }

            _grep_opt=""
            [ "${_cs}" = "true" ] || _grep_opt="i"
            [ "${_ml}" = "true" ] && _grep_opt="${_grep_opt}z"

            # PCRE compile check (exit 2 == syntax error)
            printf 'x\n' | grep -qP${_grep_opt} -- "${_pattern}" >/dev/null 2>&1
            if [ $? -eq 2 ]; then
                printf '{"ok":false,"error":%s}' "$(printf '%s' "${lang_rules_regex_err_syntax}" | jq -Rs .)"
                return
            fi

            if [ "${_ml}" = "true" ]; then
                _matches=$(grep -oP${_grep_opt} -- "${_pattern}" "${_tmpfile}" 2>/dev/null | tr '\000' '\001' | jq -Rs 'split("\u0001") | map(select(length>0))')
            else
                _matches=$(grep -oP${_grep_opt} -- "${_pattern}" "${_tmpfile}" 2>/dev/null | jq -Rs 'split("\n") | map(select(length>0))')
            fi
            [ -z "${_matches}" ] && _matches='[]'
            _count=$(printf '%s' "${_matches}" | jq 'length' 2>/dev/null)
            [ -z "${_count}" ] && _count=0

            if [ "${_mode}" = "extract" ]; then
                # first sed = tagname_RegEx sanitizing (/ \ : ? -> _), always applied;
                # dir adds the alnum-class pass + leading/trailing . or - strip.
                _sanitize1='s%[/\\:?]%_%g'
                if [ "${_ml}" = "true" ]; then
                    _result=$(grep -oP${_grep_opt} -- "${_pattern}" "${_tmpfile}" 2>/dev/null | tr '\n\0' ' \n' | head -n1 | sed "${_sanitize1}")
                else
                    _result=$(grep -oP${_grep_opt} -- "${_pattern}" "${_tmpfile}" 2>/dev/null | tr -d '\0' | head -n1 | sed "${_sanitize1}")
                fi
                if [ "${_extractType}" = "dir" ] && [ -n "${_result}" ]; then
                    _result=$(printf '%s' "${_result}" | sed 's/[^A-Za-z0-9_. -]/_/g')
                    _result=${_result%%[.-]}
                    _result=${_result##[.-]}
                fi
                printf '{"ok":true,"matches":%s,"count":%s,"extracted":%s}' \
                    "${_matches}" "${_count}" "$(printf '%s' "${_result}" | jq -Rs .)"
            else
                printf '{"ok":true,"matches":%s,"count":%s}' "${_matches}" "${_count}"
            fi
            ;;
        release)
            local _token _tmpfile
            _token=$(printf '%s' "${_body}" | jq -r '.token // empty')
            if printf '%s' "${_token}" | grep -qE '^[A-Za-z0-9_-]+$'; then
                _tmpfile="${_tmpdir}/synocr_regex_${_token}"
                rm -f "${_tmpfile}" 2>/dev/null
            fi
            printf '{"ok":true}'
            ;;
        *)
            printf '{"ok":false,"error":%s}' "$(printf '%s' "${lang_rules_regex_err_op}" | jq -Rs .)"
            ;;
    esac
}
