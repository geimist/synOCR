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
