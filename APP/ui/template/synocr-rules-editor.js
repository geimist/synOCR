/**
 * synOCR — Rule editor (vanilla JS, no framework)
 *
 * Reads the ruleset JSON from #synocr-ruleset-data and localized strings from
 * #synocr-rules-lang, renders a visual rule/subrule editor with native HTML5
 * drag&drop prioritization, a Raw-JSON tab, and saves via POST to
 * index.cgi?page=rules-save-json (validated server-side by rules_validate_json).
 */
(function () {
    'use strict';

    var DATA_ID = 'synocr-ruleset-data';
    var LANG_ID = 'synocr-rules-lang';
    var ROOT_ID = 'synocr-rules-editor-root';
    var RAW_ID = 'synocr-rules-raw';
    var STATUS_ID = 'synocr-rules-status';
    var ID_INPUT = 'synocr-ruleset-id';
    var NAME_INPUT = 'ruleset-name';
    var DESC_INPUT = 'ruleset-description';

    var PATH_TOKENS_ID = 'synocr-rules-path-tokens';
    var TAG_TOKENS_ID = 'synocr-rules-tag-tokens';
    var NOTIFY_LANGS_ID = 'synocr-rules-notify-langs';
    var TF_MODAL_ID = 'synocr-targetfolder-modal';
    var TF_VISUAL_ID = 'synocr-tf-visual';
    var TF_HIDDEN_ID = 'synocr-tf-hidden';
    var TF_PALETTE_ID = 'synocr-tf-palette';
    var TF_DIRINPUT_ID = 'synocr-tf-dirregex';
    var TF_PREVIEW_ID = 'synocr-tf-preview';
    var TF_PREVIEW_MODE_ID = 'synocr-tf-preview-mode';
    var TF_PICKER_BTN_ID = 'synocr-tf-picker';
    var TF_APPLY_BTN_ID = 'synocr-tf-apply';
    var TF_MULTILINE_ID = 'synocr-tf-multiline';

    var TN_MODAL_ID = 'synocr-tag-modal';
    var TN_VISUAL_ID = 'synocr-tn-visual';
    var TN_HIDDEN_ID = 'synocr-tn-hidden';
    var TN_PALETTE_ID = 'synocr-tn-palette';
    var TN_REGEX_INPUT_ID = 'synocr-tn-tagregex';
    var TN_MULTILINE_ID = 'synocr-tn-multiline';
    var TN_APPLY_BTN_ID = 'synocr-tn-apply';

    var state = { rules: [], groups: {}, rawDirty: false, dragIndex: null, expandedRules: {} };
    var lang = {};
    var savedSnapshot = '';
    var pathTokens = {};
    var tagTokens = {};
    var notifyLangs = {};
    var tfModal = { el: null, editor: null, ruleIndex: null, targetInput: null, dirInput: null, multilineInput: null, hintEl: null, previewEl: null, previewModeEl: null };
    var tnModal = { el: null, editor: null, ruleIndex: null, tagInput: null, regexInput: null, multilineInput: null, hintEl: null };

    var SEARCHTYP = [
        { v: 'contains', l: 'st_contains' },
        { v: 'does not contain', l: 'st_not_contains' },
        { v: 'is', l: 'st_is' },
        { v: 'is not', l: 'st_is_not' },
        { v: 'starts with', l: 'st_starts' },
        { v: 'does not starts with', l: 'st_not_starts' },
        { v: 'ends with', l: 'st_ends' },
        { v: 'does not ends with', l: 'st_not_ends' },
        { v: 'matches', l: 'st_matches' },
        { v: 'does not match', l: 'st_not_matches' }
    ];
    var SOURCE = [
        { v: 'content', l: 'src_content' },
        { v: 'filename', l: 'src_filename' }
    ];
    var COND = [
        { v: 'any', l: 'cond_any' },
        { v: 'all', l: 'cond_all' },
        { v: 'none', l: 'cond_none' }
    ];
    var ON_MATCH_ACTION = [
        { v: '', l: 'omatch_unset' },
        { v: 'continue', l: 'omatch_continue' },
        { v: 'break', l: 'omatch_break' }
    ];
    var ON_MATCH_RESULT = [
        { v: '', l: 'omatch_unset' },
        { v: 'merge', l: 'omatch_merge' },
        { v: 'replace', l: 'omatch_replace' },
        { v: 'exclusive', l: 'omatch_exclusive' }
    ];
    var APPRISE_ATTACHMENT = [
        { v: '', l: 'omatch_unset' },
        { v: 'true', l: 'apprise_att_true' },
        { v: 'false', l: 'apprise_att_false' }
    ];

    function readJson(id) {
        var el = document.getElementById(id);
        if (!el) return null;
        try {
            var raw = el.textContent.trim();
            return raw ? JSON.parse(raw) : null;
        } catch (e) {
            return null;
        }
    }

    function h(tag, attrs, kids) {
        var el = document.createElement(tag);
        if (attrs) {
            for (var k in attrs) {
                if (!Object.prototype.hasOwnProperty.call(attrs, k)) continue;
                if (k === 'class') el.className = attrs[k];
                else if (k === 'text') el.textContent = attrs[k];
                else if (k === 'dataset') { for (var d in attrs[k]) el.dataset[d] = attrs[k][d]; }
                else if (k.indexOf('on') === 0 && typeof attrs[k] === 'function') el.addEventListener(k.slice(2), attrs[k]);
                else el.setAttribute(k, attrs[k]);
            }
        }
        if (kids != null) {
            if (!Array.isArray(kids)) kids = [kids];
            kids.forEach(function (k) {
                if (k == null) return;
                el.appendChild(typeof k === 'string' ? document.createTextNode(k) : k);
            });
        }
        return el;
    }

    function L(key) { return lang[key] != null ? lang[key] : key; }

    function parseAppriseAttachment(val) {
        if (val === true || val === 'true') return 'true';
        if (val === false || val === 'false') return 'false';
        return '';
    }

    function notifyLangSelectOptions(current) {
        var opts = [{ v: '', l: 'omatch_unset' }];
        var seen = { '': true };
        Object.keys(notifyLangs).sort().forEach(function (code) {
            opts.push({ v: code, text: notifyLangs[code] || code });
            seen[code] = true;
        });
        if (current && !seen[current]) {
            opts.push({ v: current, text: current });
        }
        return opts;
    }

    function tip(key) {
        var t = L(key);
        return (t && t !== key) ? t : '';
    }

    function labeled(text, tipKey) {
        var attrs = { class: 'synocr-rule-tip-label' };
        var t = tipKey ? tip(tipKey) : '';
        if (t) attrs.title = t;
        return h('label', attrs, text);
    }

    function setTip(el, tipKey) {
        if (!el || !tipKey) return;
        var t = tip(tipKey);
        if (t) el.setAttribute('title', t);
    }

    function fromBlob(blob) {
        var rulesObj = (blob && blob.rules && typeof blob.rules === 'object') ? blob.rules : {};
        var arr = Object.keys(rulesObj).map(function (k) {
            var r = rulesObj[k] || {};
            var om = r.on_match || {};
            return {
                name: k,
                condition: r.condition || 'any',
                priority: (r.priority != null && r.priority !== '') ? r.priority : '',
                tagname: r.tagname || '',
                tagname_RegEx: r.tagname_RegEx || '',
                targetfolder: r.targetfolder || '',
                dirname_RegEx: r.dirname_RegEx || '',
                multilineregex: r.multilineregex === true || r.multilineregex === 'true',
                dirname_multilineregex: r.dirname_multilineregex === true || r.dirname_multilineregex === 'true',
                postscript: r.postscript || '',
                apprise_call: r.apprise_call || '',
                apprise_attachment: parseAppriseAttachment(r.apprise_attachment),
                notify_lang: r.notify_lang || '',
                on_match: { action: om.action || '', result: om.result || '' },
                requires: Array.isArray(r.requires) ? r.requires.slice() : (typeof r.requires === 'string' ? [r.requires] : []),
                excludes: Array.isArray(r.excludes) ? r.excludes.slice() : (typeof r.excludes === 'string' ? [r.excludes] : []),
                subrules: (r.subrules || []).map(function (s) {
                    s = s || {};
                    return {
                        searchstring: s.searchstring || '',
                        searchtyp: s.searchtyp || s.searchtype || 'contains',
                        isRegEx: s.isRegEx === true || s.isRegEx === 'true',
                        source: s.source || 'content',
                        casesensitive: s.casesensitive === true || s.casesensitive === 'true',
                        multilineregex: s.multilineregex === true || s.multilineregex === 'true'
                    };
                })
            };
        });
        arr.sort(function (a, b) { return (Number(a.priority) || 100) - (Number(b.priority) || 100); });
        state.rules = arr;
        state.groups = (blob && blob.groups && typeof blob.groups === 'object') ? blob.groups : {};
    }

    function toBlob() {
        var rules = {};
        state.rules.forEach(function (r, i) {
            var key = (r.name || '').trim() || ('rule_' + (i + 1));
            var prio = r.priority;
            if (prio === '' || prio == null || isNaN(Number(prio))) prio = 10 * (i + 1);
            var obj = { priority: Number(prio), subrules: [] };
            if (r.condition) obj.condition = r.condition;
            if (r.tagname) obj.tagname = r.tagname;
            if (r.tagname_RegEx) obj.tagname_RegEx = r.tagname_RegEx;
            if (r.targetfolder) obj.targetfolder = r.targetfolder;
            if (r.dirname_RegEx) obj.dirname_RegEx = r.dirname_RegEx;
            if (r.multilineregex) obj.multilineregex = true;
            if (r.dirname_multilineregex) obj.dirname_multilineregex = true;
            if (r.postscript) obj.postscript = r.postscript;
            if (r.apprise_call) obj.apprise_call = r.apprise_call;
            if (r.apprise_attachment === 'true') obj.apprise_attachment = true;
            else if (r.apprise_attachment === 'false') obj.apprise_attachment = false;
            if (r.notify_lang) obj.notify_lang = r.notify_lang;
            if (r.on_match && (r.on_match.action || r.on_match.result)) {
                obj.on_match = {};
                if (r.on_match.action) obj.on_match.action = r.on_match.action;
                if (r.on_match.result) obj.on_match.result = r.on_match.result;
            }
            if (r.requires && r.requires.length) obj.requires = r.requires.slice();
            if (r.excludes && r.excludes.length) obj.excludes = r.excludes.slice();
            obj.subrules = (r.subrules || []).map(function (s) {
                var o = { searchstring: s.searchstring || '' };
                if (s.searchtyp) o.searchtyp = s.searchtyp;
                if (s.isRegEx) o.isRegEx = true;
                if (s.source) o.source = s.source;
                if (s.casesensitive) o.casesensitive = true;
                if (s.multilineregex) o.multilineregex = true;
                return o;
            });
            rules[key] = obj;
        });
        return { rules: rules, groups: state.groups || {} };
    }

    function optionLabel(o) {
        if (o.text != null) return o.text;
        if (!o.l) return '';
        return L(o.l);
    }

    function select(options, current, onChange) {
        var sel = h('select', { class: 'form-select form-select-sm' });
        options.forEach(function (o) {
            var opt = h('option', { value: o.v }, optionLabel(o));
            if (o.v === current) opt.selected = true;
            sel.appendChild(opt);
        });
        sel.addEventListener('change', function () { onChange(sel.value); });
        return sel;
    }

    function ruleKey(r, i) {
        return (r.name || '').trim() || ('rule_' + i);
    }

    function isRuleExpanded(r, i) {
        var key = ruleKey(r, i);
        if (state.expandedRules[key] === undefined) {
            state.expandedRules[key] = false;
        }
        return state.expandedRules[key];
    }

    function setRuleExpanded(r, i, expanded) {
        state.expandedRules[ruleKey(r, i)] = expanded;
    }

    function fieldText(label, value, onInput, ph, tipKey) {
        var inp = h('input', { type: 'text', class: 'form-control form-control-sm', value: value });
        if (ph) inp.setAttribute('placeholder', ph);
        inp.addEventListener('input', function () { onInput(inp.value); });
        return h('div', { class: 'row mb-3' }, [
            h('div', { class: 'col-sm-5' }, labeled(label, tipKey)),
            h('div', { class: 'col-sm-5' }, inp)
        ]);
    }

    function fieldSelect(label, sel, tipKey) {
        return h('div', { class: 'row mb-3' }, [
            h('div', { class: 'col-sm-5' }, labeled(label, tipKey)),
            h('div', { class: 'col-sm-5' }, sel)
        ]);
    }

    function toggleSwitch(checked, onChange) {
        var inp = h('input', { type: 'checkbox', class: 'form-check-input', role: 'switch' });
        if (checked) inp.checked = true;
        inp.addEventListener('change', function () { onChange(inp.checked); });
        return inp;
    }

    function fieldSwitchRow(label, checked, onChange, tipKey) {
        return h('div', { class: 'row mb-3' }, [
            h('div', { class: 'col-sm-5' }, labeled(label, tipKey)),
            h('div', { class: 'col-sm-5' }, h('div', { class: 'form-check form-switch' }, toggleSwitch(checked, onChange)))
        ]);
    }

    function inlineSwitch(label, checked, onChange, tipKey) {
        var inp = toggleSwitch(checked, onChange);
        var labelAttrs = { class: 'form-check-label synocr-rule-tip-label' };
        var t = tipKey ? tip(tipKey) : '';
        if (t) labelAttrs.title = t;
        return h('div', { class: 'form-check form-switch form-check-inline mb-0' }, [
            inp,
            h('label', labelAttrs, label)
        ]);
    }

    function fieldRefList(label, current, onChange, tipKey) {
        return h('div', { class: 'row mb-3' }, [
            h('div', { class: 'col-sm-5' }, labeled(label, tipKey)),
            h('div', { class: 'col-sm-5' }, refChecklist(current, onChange))
        ]);
    }

    function ruleNames() {
        return state.rules.map(function (r) { return (r.name || '').trim(); }).filter(function (n) { return !!n; });
    }

    function refChecklist(current, onChange) {
        var names = ruleNames();
        var wrap = h('div', { class: 'synocr-rule-reflist' });
        if (!names.length) {
            wrap.appendChild(h('span', { class: 'small' }, '—'));
            return wrap;
        }
        names.forEach(function (n) {
            var checked = current.indexOf(n) !== -1;
            var inp = h('input', { type: 'checkbox', class: 'form-check-input me-2' });
            if (checked) inp.checked = true;
            inp.addEventListener('change', function () {
                if (inp.checked && current.indexOf(n) === -1) current.push(n);
                if (!inp.checked) { var idx = current.indexOf(n); if (idx !== -1) current.splice(idx, 1); }
                onChange(current);
            });
            wrap.appendChild(h('div', { class: 'form-check small' }, h('label', { class: 'form-check-label' }, [inp, n])));
        });
        return wrap;
    }

    function renderSubrule(i, j) {
        var s = state.rules[i].subrules[j];
        var row = h('div', { class: 'synocr-subrule-row' });

        var ss = h('input', { type: 'text', class: 'form-control form-control-sm', value: s.searchstring });
        ss.addEventListener('input', function () { s.searchstring = ss.value; });

        var st = select(SEARCHTYP, s.searchtyp, function (v) { s.searchtyp = v; });
        st.classList.add('form-select-sm');
        setTip(st, 'help_sub_searchtyp');

        var src = select(SOURCE, s.source, function (v) { s.source = v; });
        setTip(src, 'help_sub_source');
        setTip(ss, 'help_sub_searchstring');

        var del = h('button', { type: 'button', class: 'btn btn-outline-danger btn-sm synocr-subrule-delete', title: L('btn_remove_subrule'), onclick: function () { state.rules[i].subrules.splice(j, 1); render(); } }, '×');

        var fields = h('div', { class: 'synocr-subrule-fields' }, [
            h('div', { class: 'synocr-subrule-source' }, src),
            h('div', { class: 'synocr-subrule-typ' }, st),
            h('div', { class: 'synocr-subrule-search' }, ss)
        ]);
        var flags = h('div', { class: 'synocr-subrule-flags' }, [
            inlineSwitch(L('sub_isregex'), s.isRegEx, function (v) { s.isRegEx = v; }, 'help_sub_isregex'),
            inlineSwitch(L('sub_casesensitive'), s.casesensitive, function (v) { s.casesensitive = v; }, 'help_sub_casesensitive'),
            inlineSwitch(L('sub_multiline'), s.multilineregex, function (v) { s.multilineregex = v; }, 'help_sub_multiline')
        ]);
        var body = h('div', { class: 'synocr-subrule-body' }, [fields, flags]);

        row.appendChild(body);
        row.appendChild(h('div', { class: 'synocr-subrule-delete-wrap' }, del));
        return row;
    }

    function fieldPrimaryCell(label, control, tipKey) {
        return h('div', { class: 'synocr-rule-field' }, [
            labeled(label, tipKey),
            control
        ]);
    }

    function renderRule(i) {
        var r = state.rules[i];
        var expanded = isRuleExpanded(r, i);
        var detailsId = 'synocr-rule-details-' + i;

        var nameInp = h('input', { type: 'text', class: 'form-control form-control-sm', value: r.name });
        nameInp.addEventListener('input', function () { r.name = nameInp.value; });
        nameInp.addEventListener('change', function () { render(); });

        var condSel = select(COND, r.condition, function (v) { r.condition = v; });
        condSel.classList.add('form-select-sm');
        setTip(condSel, 'help_rule_condition');

        var tagInp = h('input', { type: 'text', class: 'form-control form-control-sm synocr-rule-targetfolder-input', value: r.tagname });
        tagInp.addEventListener('input', function () { r.tagname = tagInp.value; });
        var tagGearBtn = h('button', {
            type: 'button', class: 'btn btn-link synocr-rule-targetfolder-gear',
            title: L('tn_builder'),
            onclick: function (e) { e.preventDefault(); openTagBuilder(i, tagInp); }
        }, '\u2699');
        var tagWrap = h('div', { class: 'synocr-rule-targetfolder-wrap' }, [tagInp, tagGearBtn]);

        var targetInp = h('input', { type: 'text', class: 'form-control form-control-sm synocr-rule-targetfolder-input', value: r.targetfolder, placeholder: L('placeholder_targetfolder') });
        targetInp.addEventListener('input', function () { r.targetfolder = targetInp.value; });
        var gearBtn = h('button', {
            type: 'button', class: 'btn btn-link synocr-rule-targetfolder-gear',
            title: L('tf_builder'),
            onclick: function (e) { e.preventDefault(); openTargetFolderBuilder(i, targetInp); }
        }, '\u2699');
        var targetWrap = h('div', { class: 'synocr-rule-targetfolder-wrap' }, [targetInp, gearBtn]);

        var handle = h('span', {
            class: 'synocr-rule-drag-handle',
            title: L('drag_hint'),
            draggable: 'true',
            ondragstart: function (e) {
                state.dragIndex = i;
                e.dataTransfer.effectAllowed = 'move';
                try { e.dataTransfer.setData('text/plain', String(i)); } catch (err) {}
            }
        }, '⠿');

        var removeBtn = h('button', {
            type: 'button', class: 'btn btn-outline-danger btn-sm synocr-rule-remove',
            title: L('btn_remove_rule'),
            onclick: function () { state.rules.splice(i, 1); render(); }
        }, '×');

        var primaryBody = h('div', { class: 'synocr-rule-primary' }, [
            fieldPrimaryCell(L('rule_name'), nameInp, 'help_rule_name'),
            fieldPrimaryCell(L('rule_condition'), condSel, 'help_rule_condition'),
            fieldPrimaryCell(L('tagname'), tagWrap, 'help_tagname'),
            fieldPrimaryCell(L('targetfolder'), targetWrap, 'help_targetfolder')
        ]);

        var ruleBody = h('div', { class: 'synocr-rule-body' });

        var subWrap = h('div', { class: 'synocr-rule-subrules mb-2' }, [
            h('div', { class: 'd-flex justify-content-between align-items-center mb-2' }, [
                h('span', { class: 'synocr-text-blue' }, [
                    h('span', { class: 'synocr-rule-tip-label', title: tip('help_sub_source') }, L('sub_source')),
                    ' / ',
                    h('span', { class: 'synocr-rule-tip-label', title: tip('help_sub_searchtyp') }, L('sub_searchtyp')),
                    ' / ',
                    h('span', { class: 'synocr-rule-tip-label', title: tip('help_sub_searchstring') }, L('sub_searchstring'))
                ]),
                h('button', { type: 'button', class: 'btn btn-sm synocr-btn-add', onclick: function () { r.subrules.push({ searchstring: '', searchtyp: 'contains', isRegEx: false, source: 'content', casesensitive: false, multilineregex: false }); render(); } }, '+ ' + L('btn_add_subrule'))
            ])
        ]);
        r.subrules.forEach(function (s, j) { subWrap.appendChild(renderSubrule(i, j)); });

        var toggleBtn = h('button', {
            type: 'button',
            class: 'btn btn-link btn-sm synocr-rule-details-toggle text-decoration-none p-0',
            'aria-expanded': expanded ? 'true' : 'false',
            'aria-controls': detailsId,
            onclick: function () {
                setRuleExpanded(r, i, !isRuleExpanded(r, i));
                render();
            }
        }, (expanded ? '▼ ' : '▶ ') + (expanded ? L('toggle_details_hide') : L('toggle_details_show')));

        var detailsFooter = h('div', { class: 'synocr-rule-details-footer border-top pt-2 mt-2' }, [toggleBtn]);

        var actSel = select(ON_MATCH_ACTION, r.on_match.action, function (v) { r.on_match.action = v; });
        var resSel = select(ON_MATCH_RESULT, r.on_match.result, function (v) { r.on_match.result = v; });
        var attSel = select(APPRISE_ATTACHMENT, r.apprise_attachment, function (v) { r.apprise_attachment = v; });
        var langSel = select(notifyLangSelectOptions(r.notify_lang), r.notify_lang, function (v) { r.notify_lang = v; });

        var detailsBody = h('div', {
            class: 'collapse synocr-rule-details' + (expanded ? ' show' : ''),
            id: detailsId
        });
        var detailsInner = h('div', { class: 'pt-2' });
        detailsInner.appendChild(fieldText(L('rule_priority'), r.priority, function (v) { r.priority = v; }, 'auto', 'help_rule_priority'));
        detailsInner.appendChild(fieldSelect(L('on_match_action'), actSel, 'help_on_match_action'));
        detailsInner.appendChild(fieldSelect(L('on_match_result'), resSel, 'help_on_match_result'));
        detailsInner.appendChild(fieldRefList(L('requires'), r.requires, function (v) { r.requires = v; }, 'help_requires'));
        detailsInner.appendChild(fieldRefList(L('excludes'), r.excludes, function (v) { r.excludes = v; }, 'help_excludes'));
        detailsInner.appendChild(fieldText(L('postscript'), r.postscript, function (v) { r.postscript = v; }, undefined, 'help_postscript'));
        detailsInner.appendChild(fieldText(L('apprise'), r.apprise_call, function (v) { r.apprise_call = v; }, undefined, 'help_apprise'));
        detailsInner.appendChild(fieldSelect(L('apprise_att'), attSel, 'help_apprise_att'));
        detailsInner.appendChild(fieldSelect(L('notify_lang'), langSel, 'help_notify_lang'));
        detailsBody.appendChild(detailsInner);

        ruleBody.appendChild(primaryBody);
        ruleBody.appendChild(subWrap);
        ruleBody.appendChild(detailsFooter);
        ruleBody.appendChild(detailsBody);

        var cardLayout = h('div', { class: 'synocr-rule-layout' }, [handle, ruleBody]);

        var card = h('div', { class: 'card card-body mb-3 synocr-rule-card', dataset: { ruleIndex: String(i) } }, [
            removeBtn, cardLayout
        ]);
        card.addEventListener('dragover', function (e) { e.preventDefault(); });
        card.addEventListener('drop', function (e) {
            e.preventDefault();
            var from = state.dragIndex;
            var to = i;
            if (from == null || from === to) return;
            var moved = state.rules.splice(from, 1)[0];
            state.rules.splice(to, 0, moved);
            state.dragIndex = null;
            render();
        });
        return card;
    }

    function render() {
        var root = document.getElementById(ROOT_ID);
        if (!root) return;
        root.textContent = '';

        var toolbar = h('div', { class: 'd-flex justify-content-between align-items-center mb-2' }, [
            h('span', { class: 'text-secondary small' }, L('drag_hint')),
            h('button', { type: 'button', class: 'btn btn-sm synocr-btn-add synocr-btn-add-filled', onclick: function () {
                var n = 1;
                var names = ruleNames();
                while (names.indexOf('rule_' + n) !== -1) n++;
                state.rules.push({ name: 'rule_' + n, condition: 'any', priority: '', tagname: '', tagname_RegEx: '', targetfolder: '', dirname_RegEx: '', multilineregex: false, dirname_multilineregex: false, postscript: '', apprise_call: '', apprise_attachment: '', notify_lang: '', on_match: { action: '', result: '' }, requires: [], excludes: [], subrules: [{ searchstring: '', searchtyp: 'contains', isRegEx: false, source: 'content', casesensitive: false, multilineregex: false }] });
                render();
            } }, '+ ' + L('btn_add_rule'))
        ]);
        root.appendChild(toolbar);

        if (!state.rules.length) {
            root.appendChild(h('div', { class: 'card card-body text-secondary' }, '—'));
            return;
        }
        state.rules.forEach(function (r, i) { root.appendChild(renderRule(i)); });
    }

    function showRulesModal(modalId) {
        var modalEl = document.getElementById(modalId);
        if (!modalEl) return;
        if (modalEl.parentElement !== document.body) {
            document.body.appendChild(modalEl);
        }
        var $ = window.jQuery;
        if ($ && $.fn.modal) {
            $(modalEl).modal('show');
            return;
        }
        if (window.bootstrap && bootstrap.Modal) {
            bootstrap.Modal.getOrCreateInstance(modalEl).show();
        }
    }

    function setStatus(msg, ok) {
        var el = document.getElementById(STATUS_ID);
        if (el) {
            el.textContent = msg || '';
            el.style.color = ok ? '#1a7f37' : '#BD0010';
        }
        if (msg && !ok) showSaveErrorModal(msg);
    }

    function buildComparableState() {
        var nameEl = document.getElementById(NAME_INPUT);
        var descEl = document.getElementById(DESC_INPUT);
        var rawTa = document.getElementById(RAW_ID);
        var base = {
            name: nameEl ? nameEl.value : '',
            description: descEl ? descEl.value : ''
        };
        if (state.rawDirty && rawTa) {
            return Object.assign(base, { _raw: rawTa.value });
        }
        var blob = toBlob();
        return Object.assign(base, { rules: blob.rules, groups: blob.groups });
    }

    function snapshotString() {
        return JSON.stringify(buildComparableState());
    }

    function updateSavedSnapshot() {
        savedSnapshot = snapshotString();
    }

    function isPageDirty() {
        return snapshotString() !== savedSnapshot;
    }

    function showSaveSuccessModal() {
        var msgEl = document.getElementById('popup-rules-save-msg');
        if (msgEl) {
            msgEl.textContent = L('save_success');
        }
        showRulesModal('popup-rules-save');
    }

    function showSaveErrorModal(msg) {
        var msgEl = document.getElementById('popup-rules-error-msg');
        if (msgEl) msgEl.textContent = msg || '';
        showRulesModal('popup-rules-save-error');
    }

    function initSaveModal() {
        ['popup-rules-save', 'popup-rules-save-error'].forEach(function (id) {
            var modalEl = document.getElementById(id);
            if (modalEl && modalEl.parentElement !== document.body) {
                document.body.appendChild(modalEl);
            }
        });
    }

    function initDirtyTracking() {
        var warning = L('unsaved_warning');

        window.addEventListener('beforeunload', function (event) {
            if (!isPageDirty()) return;
            event.preventDefault();
            event.returnValue = warning;
            return warning;
        });

        document.querySelectorAll('.synocr-rules-leave-link').forEach(function (link) {
            link.addEventListener('click', function (event) {
                if (!isPageDirty()) return;
                if (!window.confirm(warning)) {
                    event.preventDefault();
                }
            });
        });
    }

    function syncFromRawIfDirty() {
        if (!state.rawDirty) return;
        var ta = document.getElementById(RAW_ID);
        if (!ta) return;
        try {
            var blob = JSON.parse(ta.value);
            fromBlob(blob);
            state.rawDirty = false;
        } catch (e) {
            setStatus(L('raw_invalid'), false);
            throw e;
        }
    }

    function fmtVal(key, a) {
        var s = L(key);
        return s.indexOf('%1') !== -1 ? s.replace('%1', a != null ? a : '') : s;
    }

    function duplicateRuleNames() {
        var seen = {}, dups = [];
        state.rules.forEach(function (r) {
            var n = (r.name || '').trim();
            if (!n) return;
            if (seen[n]) { if (dups.indexOf(n) < 0) dups.push(n); }
            else seen[n] = true;
        });
        return dups;
    }

    function save() {
        try { syncFromRawIfDirty(); } catch (e) { return; }
        var blob = toBlob();
        var editorCount = state.rules.length;
        var keyCount = Object.keys(blob.rules).length;
        var dupNames = duplicateRuleNames();
        if (dupNames.length || editorCount !== keyCount) {
            var msgs = dupNames.map(function (n) { return fmtVal('val_rule_dup_name', n); });
            if (!msgs.length) msgs = [L('save_dup_blocked')];
            setStatus(msgs.join('\n'), false);
            return;
        }
        var body = {
            ruleset_id: document.getElementById(ID_INPUT).value,
            name: document.getElementById(NAME_INPUT).value,
            description: document.getElementById(DESC_INPUT).value,
            rules: blob.rules,
            groups: blob.groups,
            editor_rule_count: editorCount
        };
        setStatus('', true);
        fetch('index.cgi?page=rules-save-json', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        }).then(function (r) { return r.json(); }).then(function (res) {
            if (res && res.ok) {
                var dataEl = document.getElementById(DATA_ID);
                if (dataEl) dataEl.textContent = JSON.stringify(blob);
                var ta = document.getElementById(RAW_ID);
                if (ta) { ta.value = JSON.stringify(blob, null, 2); state.rawDirty = false; }
                updateSavedSnapshot();
                showSaveSuccessModal();
            } else {
                var errs = (res && res.errors && res.errors.length) ? res.errors.join('\n') : L('save_error');
                setStatus(L('save_error') + '\n' + errs, false);
            }
        }).catch(function (e) { setStatus(L('save_error') + ' ' + e, false); });
    }

    function initTabs() {
        var rawTa = document.getElementById(RAW_ID);
        var tabVisual = document.getElementById('synocr-rules-tab-visual');
        var tabRaw = document.getElementById('synocr-rules-tab-raw');
        if (tabRaw) {
            tabRaw.addEventListener('shown.bs.tab', function () {
                if (rawTa) rawTa.value = JSON.stringify(toBlob(), null, 2);
            });
        }
        if (tabVisual) {
            tabVisual.addEventListener('shown.bs.tab', function () {
                if (state.rawDirty && rawTa) {
                    try { fromBlob(JSON.parse(rawTa.value)); state.rawDirty = false; render(); }
                    catch (e) { setStatus(L('raw_invalid'), false); }
                }
            });
        }
        if (rawTa) rawTa.addEventListener('input', function () { state.rawDirty = true; });
    }

    // --- target-folder builder modal ---------------------------------------

    function showModal(el) {
        if (!el) return;
        if (el.parentElement !== document.body) document.body.appendChild(el);
        var $ = window.jQuery;
        if ($ && $.fn.modal) { $(el).modal('show'); return; }
        if (window.bootstrap && bootstrap.Modal) bootstrap.Modal.getOrCreateInstance(el).show();
    }

    function hideModal(el) {
        if (!el) return;
        var $ = window.jQuery;
        if ($ && $.fn.modal) { $(el).modal('hide'); return; }
        if (window.bootstrap && bootstrap.Modal) bootstrap.Modal.getOrCreateInstance(el).hide();
    }

    // Mirrors the backend detection in synOCR.sh: a path starting with "/volume*"
    // (grep "^/volume*") is treated as absolute; everything else becomes a
    // subfolder of the profile output dir. Date/count tokens get today's values
    // for a concrete preview; §dirname_RegEx becomes a <RegEx> placeholder.
    function previewPath(value) {
        var v = value || '';
        var now = new Date();
        var yy = String(now.getFullYear());
        var yy2 = yy.slice(2);
        var mm = String(now.getMonth() + 1).padStart(2, '0');
        var dd = String(now.getDate()).padStart(2, '0');
        var hh = String(now.getHours()).padStart(2, '0');
        var mi = String(now.getMinutes()).padStart(2, '0');
        var ss = String(now.getSeconds()).padStart(2, '0');
        var sample = v
            .replace(/§yocr4/g, yy).replace(/§yocr2/g, yy2)
            .replace(/§mocr/g, mm).replace(/§docr/g, dd)
            .replace(/§ynow4/g, yy).replace(/§ynow2/g, yy2)
            .replace(/§mnow/g, mm).replace(/§dnow/g, dd)
            .replace(/§hhnow/g, hh).replace(/§mmnow/g, mi).replace(/§ssnow/g, ss)
            .replace(/§ysource4/g, yy).replace(/§ysource2/g, yy2)
            .replace(/§msource/g, mm).replace(/§dsource/g, dd)
            .replace(/§hhsource/g, hh).replace(/§mmsource/g, mi).replace(/§sssource/g, ss)
            .replace(/§pagecount/g, '1')
            .replace(/§pagecounttotal/g, '1')
            .replace(/§filecounttotal/g, '1')
            .replace(/§pagecountprofile/g, '1')
            .replace(/§filecountprofile/g, '1')
            .replace(/§dirname_RegEx/g, '<RegEx>');
        return { text: sample, abs: /^\/volume*/.test(sample) };
    }

    function updateTargetPreview() {
        if (!tfModal.editor) return;
        var v = tfModal.editor.getValue();
        var p = previewPath(v);
        var modeLabel = p.abs ? L('tf_mode_abs') : L('tf_mode_rel');
        if (tfModal.previewModeEl) {
            tfModal.previewModeEl.textContent = '[' + modeLabel + ']';
        }
        if (tfModal.previewEl) {
            tfModal.previewEl.textContent = p.text || '—';
        }
        if (tfModal.hintEl) {
            var hasChip = v.indexOf('§dirname_RegEx') !== -1;
            if (hasChip) {
                tfModal.hintEl.textContent = L('tf_dirregex_help');
            } else {
                var chipLabel = L('tf_chip_dirname') || pathTokens['§dirname_RegEx'] || '§dirname_RegEx';
                tfModal.hintEl.textContent = L('tf_dirhint').replace('%s', chipLabel);
            }
        }
    }

    function ensureTargetModal() {
        if (tfModal.el) return tfModal.el;

        var visual = h('div', {
            id: TF_VISUAL_ID,
            class: 'form-control form-control-sm synocr-namesyntax-editor',
            contenteditable: 'true',
            spellcheck: 'false',
            tabindex: '0'
        });
        var hidden = h('input', { type: 'hidden', id: TF_HIDDEN_ID });
        var palette = h('div', { id: TF_PALETTE_ID, class: 'synocr-namesyntax-palette d-flex flex-wrap gap-1 mb-3' });
        Object.keys(pathTokens).forEach(function (tok) {
            palette.appendChild(h('span', {
                class: 'synocr-namesyntax-palette-item',
                draggable: 'true',
                'data-token': tok,
                title: tok
            }, pathTokens[tok]));
        });

        var dirInput = h('input', { type: 'text', id: TF_DIRINPUT_ID, class: 'form-control form-control-sm font-monospace', placeholder: '[0-9]{4}' });
        dirInput.addEventListener('input', updateTargetPreview);
        var hintEl = h('div', { class: 'small text-muted mt-1' });
        var previewModeEl = h('div', { id: TF_PREVIEW_MODE_ID, class: 'small text-muted mb-1' });
        var previewEl = h('div', { id: TF_PREVIEW_ID, class: 'form-control form-control-sm bg-light font-monospace small' });

        var tfMultilineInput = h('input', { type: 'checkbox', id: TF_MULTILINE_ID, class: 'form-check-input', role: 'switch' });
        var tfMultilineRow = h('div', { class: 'form-check form-switch mt-2' }, [
            tfMultilineInput,
            h('label', { class: 'form-check-label synocr-rule-tip-label', 'for': TF_MULTILINE_ID, title: tip('help_dirname_multiline') }, L('dirname_multiline'))
        ]);

        var pickerBtn = h('button', { type: 'button', id: TF_PICKER_BTN_ID, class: 'btn btn-outline-secondary' }, L('tf_pick'));
        pickerBtn.addEventListener('click', function () {
            if (typeof window.synocr_openPicker !== 'function') return;
            window.synocr_openPicker(null, 'folder', {
                title: L('tf_pick_title'),
                confirmLabel: L('tf_pick_confirm'),
                onSelect: function (path) {
                    if (tfModal.editor) tfModal.editor.insertText(path);
                }
            });
        });

        var applyBtn = h('button', { type: 'button', id: TF_APPLY_BTN_ID, class: 'btn btn-primary btn-sm', style: 'background-color:#0086E5;' }, L('tf_apply'));
        applyBtn.addEventListener('click', targetModalSave);
        var cancelBtn = h('button', { type: 'button', class: 'btn btn-secondary btn-sm', 'data-bs-dismiss': 'modal' }, L('btn_cancel'));

        var editorWrap = h('div', { class: 'synocr-namesyntax-editor-wrap flex-grow-1' }, visual);
        var pathRow = h('div', { class: 'input-group input-group-sm mb-2' }, [editorWrap, pickerBtn]);

        var modalEl = h('div', { id: TF_MODAL_ID, class: 'modal fade', tabindex: '-1', 'aria-hidden': 'true' }, [
            h('div', { class: 'modal-dialog modal-lg' }, [
                h('div', { class: 'modal-content' }, [
                    h('div', { class: 'modal-header bg-light' }, [
                        h('h5', { class: 'modal-title' }, L('tf_builder')),
                        h('button', { type: 'button', class: 'btn-close', 'data-bs-dismiss': 'modal', 'aria-label': 'Close' })
                    ]),
                    h('div', { class: 'modal-body' }, [
                        h('label', { class: 'form-label small fw-bold mb-1 synocr-rule-tip-label', 'for': TF_VISUAL_ID, title: tip('help_targetfolder') }, L('targetfolder')),
                        pathRow,
                        hidden,
                        palette,
                        h('div', { class: 'border-top pt-3 mb-3' }, [
                            h('label', { class: 'form-label small fw-bold mb-1 synocr-rule-tip-label', 'for': TF_DIRINPUT_ID, title: tip('help_dirname_regex') }, L('dirname_regex')),
                            dirInput,
                            hintEl,
                            tfMultilineRow
                        ]),
                        h('div', { class: 'border-top pt-3' }, [
                            h('label', { class: 'form-label small fw-bold mb-1 synocr-rule-tip-label', title: tip('help_tf_preview') }, L('tf_preview')),
                            previewModeEl,
                            previewEl
                        ])
                    ]),
                    h('div', { class: 'modal-footer bg-light' }, [cancelBtn, applyBtn])
                ])
            ])
        ]);

        document.body.appendChild(modalEl);
        tfModal.el = modalEl;
        tfModal.dirInput = dirInput;
        tfModal.multilineInput = tfMultilineInput;
        tfModal.hintEl = hintEl;
        tfModal.previewEl = previewEl;
        tfModal.previewModeEl = previewModeEl;

        if (window.synocrChipEditor && typeof window.synocrChipEditor.create === 'function') {
            tfModal.editor = window.synocrChipEditor.create({
                visual: visual,
                hidden: hidden,
                palette: palette,
                tokenMap: pathTokens,
                onChange: updateTargetPreview
            });
        }
        return modalEl;
    }

    function openTargetFolderBuilder(ruleIndex, targetInput) {
        var r = state.rules[ruleIndex];
        if (!r) return;
        ensureTargetModal();
        tfModal.ruleIndex = ruleIndex;
        tfModal.targetInput = targetInput || null;
        if (tfModal.dirInput) tfModal.dirInput.value = r.dirname_RegEx || '';
        if (tfModal.editor) tfModal.editor.setValue(r.targetfolder || '');
        if (tfModal.multilineInput) tfModal.multilineInput.checked = r.dirname_multilineregex === true;
        updateTargetPreview();
        showModal(tfModal.el);
    }

    function targetModalSave() {
        var r = state.rules[tfModal.ruleIndex];
        if (!r) return;
        if (tfModal.editor) r.targetfolder = tfModal.editor.getValue();
        if (tfModal.dirInput) r.dirname_RegEx = tfModal.dirInput.value;
        if (tfModal.multilineInput) r.dirname_multilineregex = tfModal.multilineInput.checked;
        if (tfModal.targetInput) tfModal.targetInput.value = r.targetfolder;
        hideModal(tfModal.el);
    }

    // --- tag-name builder modal --------------------------------------------

    function updateTagHint() {
        if (!tnModal.editor || !tnModal.hintEl) return;
        var v = tnModal.editor.getValue();
        var hasChip = v.indexOf('§tagname_RegEx') !== -1;
        if (hasChip) {
            tnModal.hintEl.textContent = L('tn_regex_help');
        } else {
            var chipLabel = L('tn_chip_tagname') || tagTokens['§tagname_RegEx'] || '§tagname_RegEx';
            tnModal.hintEl.textContent = L('tn_dirhint').replace('%s', chipLabel);
        }
    }

    function ensureTagModal() {
        if (tnModal.el) return tnModal.el;

        var visual = h('div', {
            id: TN_VISUAL_ID,
            class: 'form-control form-control-sm synocr-namesyntax-editor',
            contenteditable: 'true',
            spellcheck: 'false',
            tabindex: '0'
        });
        var hidden = h('input', { type: 'hidden', id: TN_HIDDEN_ID });
        var palette = h('div', { id: TN_PALETTE_ID, class: 'synocr-namesyntax-palette d-flex flex-wrap gap-1 mb-3' });
        Object.keys(tagTokens).forEach(function (tok) {
            palette.appendChild(h('span', {
                class: 'synocr-namesyntax-palette-item',
                draggable: 'true',
                'data-token': tok,
                title: tok
            }, tagTokens[tok]));
        });

        var regexInput = h('input', { type: 'text', id: TN_REGEX_INPUT_ID, class: 'form-control form-control-sm font-monospace', placeholder: '[0-9]{4}' });
        regexInput.addEventListener('input', updateTagHint);
        var hintEl = h('div', { class: 'small text-muted mt-1' });

        var multilineInput = h('input', { type: 'checkbox', id: TN_MULTILINE_ID, class: 'form-check-input', role: 'switch' });
        var multilineRow = h('div', { class: 'form-check form-switch' }, [
            multilineInput,
            h('label', { class: 'form-check-label synocr-rule-tip-label', 'for': TN_MULTILINE_ID, title: tip('help_multiline') }, L('multiline'))
        ]);

        var applyBtn = h('button', { type: 'button', id: TN_APPLY_BTN_ID, class: 'btn btn-primary btn-sm', style: 'background-color:#0086E5;' }, L('tf_apply'));
        applyBtn.addEventListener('click', tagModalSave);
        var cancelBtn = h('button', { type: 'button', class: 'btn btn-secondary btn-sm', 'data-bs-dismiss': 'modal' }, L('btn_cancel'));

        var editorWrap = h('div', { class: 'synocr-namesyntax-editor-wrap' }, visual);

        var modalEl = h('div', { id: TN_MODAL_ID, class: 'modal fade', tabindex: '-1', 'aria-hidden': 'true' }, [
            h('div', { class: 'modal-dialog modal-lg' }, [
                h('div', { class: 'modal-content' }, [
                    h('div', { class: 'modal-header bg-light' }, [
                        h('h5', { class: 'modal-title' }, L('tn_builder')),
                        h('button', { type: 'button', class: 'btn-close', 'data-bs-dismiss': 'modal', 'aria-label': 'Close' })
                    ]),
                    h('div', { class: 'modal-body' }, [
                        h('label', { class: 'form-label small fw-bold mb-1 synocr-rule-tip-label', 'for': TN_VISUAL_ID, title: tip('help_tagname') }, L('tagname')),
                        editorWrap,
                        hidden,
                        palette,
                        h('div', { class: 'border-top pt-3 mb-3' }, [
                            h('label', { class: 'form-label small fw-bold mb-1 synocr-rule-tip-label', 'for': TN_REGEX_INPUT_ID, title: tip('help_tagname_regex') }, L('tagname_regex')),
                            regexInput,
                            hintEl
                        ]),
                        h('div', { class: 'border-top pt-3' }, multilineRow)
                    ]),
                    h('div', { class: 'modal-footer bg-light' }, [cancelBtn, applyBtn])
                ])
            ])
        ]);

        document.body.appendChild(modalEl);
        tnModal.el = modalEl;
        tnModal.regexInput = regexInput;
        tnModal.multilineInput = multilineInput;
        tnModal.hintEl = hintEl;

        if (window.synocrChipEditor && typeof window.synocrChipEditor.create === 'function') {
            tnModal.editor = window.synocrChipEditor.create({
                visual: visual,
                hidden: hidden,
                palette: palette,
                tokenMap: tagTokens,
                onChange: updateTagHint
            });
        }
        return modalEl;
    }

    function openTagBuilder(ruleIndex, tagInput) {
        var r = state.rules[ruleIndex];
        if (!r) return;
        ensureTagModal();
        tnModal.ruleIndex = ruleIndex;
        tnModal.tagInput = tagInput || null;
        if (tnModal.regexInput) tnModal.regexInput.value = r.tagname_RegEx || '';
        if (tnModal.multilineInput) tnModal.multilineInput.checked = r.multilineregex === true;
        if (tnModal.editor) tnModal.editor.setValue(r.tagname || '');
        updateTagHint();
        showModal(tnModal.el);
    }

    function tagModalSave() {
        var r = state.rules[tnModal.ruleIndex];
        if (!r) return;
        if (tnModal.editor) r.tagname = tnModal.editor.getValue();
        if (tnModal.regexInput) r.tagname_RegEx = tnModal.regexInput.value;
        if (tnModal.multilineInput) r.multilineregex = tnModal.multilineInput.checked;
        if (tnModal.tagInput) tnModal.tagInput.value = r.tagname;
        hideModal(tnModal.el);
    }

    function init() {
        var root = document.getElementById(ROOT_ID);
        if (!root) return;
        var l = readJson(LANG_ID);
        if (l) lang = l;
        var pt = readJson(PATH_TOKENS_ID);
        if (pt && typeof pt === 'object') pathTokens = pt;
        var tt = readJson(TAG_TOKENS_ID);
        if (tt && typeof tt === 'object') tagTokens = tt;
        var nl = readJson(NOTIFY_LANGS_ID);
        if (nl && typeof nl === 'object') notifyLangs = nl;
        var data = readJson(DATA_ID);
        fromBlob(data || { rules: {}, groups: {} });
        render();
        initTabs();
        updateSavedSnapshot();
        initDirtyTracking();
        initSaveModal();
        document.querySelectorAll('.synocr-rules-save-btn').forEach(function (btn) {
            btn.addEventListener('click', save);
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
