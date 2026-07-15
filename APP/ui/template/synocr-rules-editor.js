/**
 * synOCR — Rule editor (vanilla JS, no framework)
 *
 * Reads the ruleset JSON from #synocr-ruleset-data and localized strings from
 * #synocr-rules-lang, renders a visual rule/subrule editor with native HTML5
 * drag&drop prioritization, a Raw-JSON tab, and saves via POST to
 * index.cgi?page=rules-save-json (validated server-side by rules_validate_json).
 *
 * Phase 2 (planned): cross-ruleset rule copy/paste via sessionStorage (variant B).
 * - "Copy rule" stores JSON.stringify(cloneRule(r)) under sessionStorage key
 *   "synocr-rule-clipboard".
 * - On editor init, if that key exists, show a "Paste rule" action in the toolbar.
 * - Paste: uniqueRuleName + insert (e.g. after selection or at end); warn when
 *   requires/excludes reference rule names missing in the target ruleset.
 */
(function () {
    'use strict';

    var DATA_ID = 'synocr-ruleset-data';
    var LANG_ID = 'synocr-rules-lang';
    var ROOT_ID = 'synocr-rules-editor-root';
    var TOOLBAR_ID = 'synocr-rules-toolbar';
    var SCROLL_ID = 'synocr-rules-editor-scroll';
    var RAW_ID = 'synocr-rules-raw';
    var STATUS_ID = 'synocr-rules-status';
    var FILTER_ID = 'synocr-rules-filter';
    var FILTER_COUNT_ID = 'synocr-rules-filter-count';
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

    var state = {
        rules: [], groups: {}, rawDirty: false,
        dragIndex: null, dragCard: null, dragHeight: null, dropPlaceholder: null,
        expandedRules: {}, collapsedRules: {}
    };
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

    function applyDataTip(el, text) {
        if (window.synocrDataTips) {
            window.synocrDataTips.applyDataTip(el, text);
            return;
        }
        if (!el || !text) return;
        el.setAttribute('data-tip', text);
        el.removeAttribute('title');
    }

    function bindDataTipsOnce() {
        if (window.synocrDataTips) {
            window.synocrDataTips.bindOnce();
            return;
        }
    }

    function regexAssistantAvailable() {
        return !!window.synocrRegexAssistant && typeof window.synocrRegexAssistant.open === 'function';
    }
    function wandButton(titleKey, onClick) {
        var btn = h('button', {
            type: 'button',
            class: 'btn btn-link synocr-regex-wand synocr-has-tip',
            'data-tip': L(titleKey),
            onclick: function (e) { e.preventDefault(); onClick(e); }
        });
        btn.appendChild(h('img', { src: './images/magic.svg', alt: '', class: 'synocr-regex-wand-icon' }));
        return btn;
    }
    /** Builder gear (tag / target folder) — settings icon inside the field on the right. */
    function gearButton(titleKey, onClick) {
        var btn = h('button', {
            type: 'button',
            class: 'btn btn-link synocr-rule-targetfolder-gear synocr-has-tip',
            'data-tip': L(titleKey),
            onclick: function (e) { e.preventDefault(); onClick(e); }
        });
        btn.appendChild(h('img', { src: './images/settings.svg', alt: '', class: 'synocr-rule-targetfolder-gear-icon' }));
        return btn;
    }
    /** Wrap a text input so the wand sits inside the field on the right (like the gear on tag/targetfolder). */
    function wrapRegexWand(input, titleKey, onClick, active) {
        input.classList.add('synocr-regex-field-input');
        var wrap = h('div', { class: 'synocr-regex-field-wrap' + (active ? ' synocr-regex-active' : '') }, [input, wandButton(titleKey, onClick)]);
        return wrap;
    }

    function applyRegexDependentControls(active, multilineInput, multilineRow) {
        if (multilineInput) multilineInput.disabled = !active;
        if (multilineRow) {
            if (active) multilineRow.classList.remove('synocr-switch-disabled');
            else multilineRow.classList.add('synocr-switch-disabled');
        }
    }

    function syncModalRegexMultilineGate(multilineInput, multilineRow, regexValue) {
        var active = !!(regexValue != null && String(regexValue).trim());
        applyRegexDependentControls(active, multilineInput, multilineRow);
    }

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
        if (t) {
            attrs['data-tip'] = t;
            attrs.class += ' synocr-has-tip';
        }
        return h('label', attrs, text);
    }

    function setTip(el, tipKey) {
        if (!el || !tipKey) return;
        applyDataTip(el, tip(tipKey));
        if (el.getAttribute('data-tip')) el.classList.add('synocr-has-tip');
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

    function ruleNamesSet() {
        var set = {};
        state.rules.forEach(function (r) {
            var n = (r.name || '').trim();
            if (n) set[n] = true;
        });
        return set;
    }

    function uniqueDuplicateRuleName(original) {
        var base = (original || '').trim() || 'rule';
        var suffix = L('dup_suffix') || ' (Kopie)';
        var candidate = base + suffix;
        var names = ruleNamesSet();
        var tryName = candidate;
        var n = 2;
        while (names[tryName]) {
            tryName = candidate + ' ' + n;
            n += 1;
        }
        return tryName;
    }

    function cloneRule(rule) {
        var om = rule.on_match || {};
        return {
            name: rule.name,
            condition: rule.condition || 'any',
            priority: rule.priority,
            tagname: rule.tagname || '',
            tagname_RegEx: rule.tagname_RegEx || '',
            targetfolder: rule.targetfolder || '',
            dirname_RegEx: rule.dirname_RegEx || '',
            multilineregex: !!rule.multilineregex,
            dirname_multilineregex: !!rule.dirname_multilineregex,
            postscript: rule.postscript || '',
            apprise_call: rule.apprise_call || '',
            apprise_attachment: rule.apprise_attachment || '',
            notify_lang: rule.notify_lang || '',
            on_match: { action: om.action || '', result: om.result || '' },
            requires: (rule.requires || []).slice(),
            excludes: (rule.excludes || []).slice(),
            subrules: (rule.subrules || []).map(function (s) {
                return {
                    searchstring: s.searchstring || '',
                    searchtyp: s.searchtyp || 'contains',
                    isRegEx: !!s.isRegEx,
                    source: s.source || 'content',
                    casesensitive: !!s.casesensitive,
                    multilineregex: !!s.multilineregex
                };
            })
        };
    }

    function duplicateRuleAt(index) {
        if (index < 0 || index >= state.rules.length) return;
        var clone = cloneRule(state.rules[index]);
        clone.name = uniqueDuplicateRuleName(clone.name);
        clone.priority = '';
        var insertAt = index + 1;
        state.rules.splice(insertAt, 0, clone);
        reassignRulePrioritiesFromOrder();
        setRuleExpanded(clone, insertAt, false);
        setRuleCollapsed(clone, insertAt, false);
        render();
        var listEl = document.querySelector('.synocr-rules-list');
        if (listEl) {
            var card = listEl.querySelector('.synocr-rule-card[data-rule-index="' + insertAt + '"]');
            if (card && typeof card.scrollIntoView === 'function') {
                card.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
            }
        }
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

    function isRuleCollapsed(r, i) {
        var key = ruleKey(r, i);
        if (state.collapsedRules[key] === undefined) {
            state.collapsedRules[key] = true;
        }
        return state.collapsedRules[key];
    }

    function setRuleCollapsed(r, i, collapsed) {
        state.collapsedRules[ruleKey(r, i)] = collapsed;
    }

    function cleanupRuleDrag() {
        if (state.dragCard) {
            state.dragCard.classList.remove('synocr-rule-card-dragging');
            state.dragCard = null;
        }
        if (state.dropPlaceholder && state.dropPlaceholder.parentNode) {
            state.dropPlaceholder.parentNode.removeChild(state.dropPlaceholder);
        }
        state.dropPlaceholder = null;
        state.dragIndex = null;
        state.dragHeight = null;
    }

    function getRuleInsertIndex(listEl, clientY) {
        var cards = listEl.querySelectorAll('.synocr-rule-card:not(.synocr-rule-card-dragging):not(.synocr-rule-card--filter-hidden)');
        var c;
        for (c = 0; c < cards.length; c++) {
            var rect = cards[c].getBoundingClientRect();
            if (clientY < rect.top + rect.height / 2) {
                return parseInt(cards[c].dataset.ruleIndex, 10);
            }
        }
        return state.rules.length;
    }

    function isNoOpRuleMove(from, insertAt) {
        return insertAt === from || insertAt === from + 1;
    }

    function moveRulePlaceholder(listEl, insertAt) {
        var ph = state.dropPlaceholder;
        if (!ph || !listEl) return;
        var from = state.dragIndex;
        if (from == null || isNoOpRuleMove(from, insertAt)) {
            if (ph.parentNode) ph.parentNode.removeChild(ph);
            return;
        }
        var cards = listEl.querySelectorAll('.synocr-rule-card');
        var target = null;
        var c;
        for (c = 0; c < cards.length; c++) {
            if (parseInt(cards[c].dataset.ruleIndex, 10) === insertAt) {
                target = cards[c];
                break;
            }
        }
        if (target && !target.classList.contains('synocr-rule-card-dragging')) {
            listEl.insertBefore(ph, target);
        } else {
            listEl.appendChild(ph);
        }
    }

    function reassignRulePrioritiesFromOrder() {
        state.rules.forEach(function (r, i) {
            r.priority = String(10 * (i + 1));
        });
    }

    function applyRuleReorder(from, insertAt) {
        if (from == null || isNoOpRuleMove(from, insertAt)) return;
        var item = state.rules.splice(from, 1)[0];
        if (insertAt > from) insertAt--;
        state.rules.splice(insertAt, 0, item);
        reassignRulePrioritiesFromOrder();
    }

    function onRulesListDragOver(e) {
        if (state.dragIndex == null) return;
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        moveRulePlaceholder(e.currentTarget, getRuleInsertIndex(e.currentTarget, e.clientY));
    }

    function onRulesListDrop(e) {
        e.preventDefault();
        if (state.dragIndex == null) return;
        var from = state.dragIndex;
        var insertAt = getRuleInsertIndex(e.currentTarget, e.clientY);
        cleanupRuleDrag();
        applyRuleReorder(from, insertAt);
        render();
    }

    function bindRulesListDrag(listEl) {
        if (!listEl || listEl._synocrDragBound) return;
        listEl._synocrDragBound = true;
        // Improvement potential (mobile/touch): HTML5 drag & drop has no
        // reliable touch support, so reordering via the ⠿ handle does not work
        // on tablets/phones. A future enhancement could add ↑/↓ buttons per
        // rule card as a pointer/touch fallback (call applyRuleReorder()).
        listEl.addEventListener('dragover', onRulesListDragOver);
        listEl.addEventListener('drop', onRulesListDrop);
    }

    var APPRISE_SERVICES_URL = 'https://appriseit.com/services/';

    function appriseServicesHelpLink() {
        return h('a', {
            href: APPRISE_SERVICES_URL,
            target: '_blank',
            rel: 'noopener noreferrer',
            class: 'synocr-apprise-services-link'
        }, L('help_link'));
    }

    function fieldPrimaryCell(label, control, tipKey, withAppriseHelp) {
        var labelNode = labeled(label, tipKey);
        if (withAppriseHelp) {
            labelNode = h('div', { class: 'synocr-rule-label-row' }, [
                labelNode,
                appriseServicesHelpLink()
            ]);
        }
        return h('div', { class: 'synocr-rule-field' }, [
            labelNode,
            control
        ]);
    }

    function fieldPrimaryText(label, value, onInput, ph, tipKey, withAppriseHelp) {
        var inp = h('input', { type: 'text', class: 'form-control form-control-sm', value: value });
        if (ph) inp.setAttribute('placeholder', ph);
        inp.addEventListener('input', function () { onInput(inp.value); });
        return fieldPrimaryCell(label, inp, tipKey, withAppriseHelp);
    }

    function fieldPrimarySelect(label, sel, tipKey) {
        return fieldPrimaryCell(label, sel, tipKey, false);
    }

    function fieldPrimaryRefList(label, current, onChange, tipKey) {
        return fieldPrimaryCell(label, refChecklist(current, onChange), tipKey, false);
    }

    function detailsGridRow(cells) {
        var row = h('div', { class: 'synocr-rule-details-row' });
        cells.forEach(function (cell) {
            if (cell) row.appendChild(cell);
        });
        return row;
    }

    function toggleSwitch(checked, onChange, disabled) {
        var inp = h('input', { type: 'checkbox', class: 'form-check-input', role: 'switch' });
        if (checked) inp.checked = true;
        if (disabled) inp.disabled = true;
        inp.addEventListener('change', function () { onChange(inp.checked); });
        return inp;
    }

    function fieldSwitchRow(label, checked, onChange, tipKey) {
        return h('div', { class: 'row mb-3' }, [
            h('div', { class: 'col-sm-5' }, labeled(label, tipKey)),
            h('div', { class: 'col-sm-5' }, h('div', { class: 'form-check form-switch' }, toggleSwitch(checked, onChange)))
        ]);
    }

    function inlineSwitch(label, checked, onChange, tipKey, disabled) {
        var inp = toggleSwitch(checked, onChange, disabled);
        var labelAttrs = { class: 'form-check-label synocr-rule-tip-label' };
        var t = tipKey ? tip(tipKey) : '';
        if (t) {
            labelAttrs['data-tip'] = t;
            labelAttrs.class += ' synocr-has-tip';
        }
        return h('div', { class: 'form-check form-switch form-check-inline mb-0' + (disabled ? ' synocr-switch-disabled' : '') }, [
            inp,
            h('label', labelAttrs, label)
        ]);
    }

    function ruleNames() {
        return state.rules.map(function (r) { return (r.name || '').trim(); }).filter(function (n) { return !!n; });
    }

    function getFilterQuery() {
        var el = document.getElementById(FILTER_ID);
        return el ? el.value.trim().toLowerCase() : '';
    }

    function isFilterActive() {
        return getFilterQuery().length > 0;
    }

    function ruleHaystack(r) {
        var parts = [
            r.name, r.tagname, r.tagname_RegEx, r.targetfolder, r.dirname_RegEx,
            r.postscript, r.apprise_call, r.notify_lang, r.priority, r.condition,
            r.apprise_attachment
        ];
        if (r.on_match) {
            parts.push(r.on_match.action, r.on_match.result);
        }
        if (r.requires && r.requires.length) parts.push(r.requires.join(' '));
        if (r.excludes && r.excludes.length) parts.push(r.excludes.join(' '));
        (r.subrules || []).forEach(function (s) {
            parts.push(s.searchstring, s.searchtyp, s.source);
        });
        return parts.filter(function (p) { return p != null && String(p) !== ''; }).join('\u0001').toLowerCase();
    }

    function ruleMatchesFilter(r, query) {
        if (!query) return true;
        return ruleHaystack(r).indexOf(query) !== -1;
    }

    function fmtFilterCount(shown, total) {
        return L('filter_count').replace('%1', String(shown)).replace('%2', String(total));
    }

    function syncFilterCount(shown, total, active) {
        var el = document.getElementById(FILTER_COUNT_ID);
        if (!el) return;
        if (!active) {
            el.style.display = 'none';
            el.textContent = '';
            return;
        }
        el.style.display = '';
        el.textContent = fmtFilterCount(shown, total);
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

        var ssWrap = wrapRegexWand(ss, 'regex_wand_title', function () {
            if (!regexAssistantAvailable()) return;
            window.synocrRegexAssistant.open({
                mode: 'match', source: s.source, multiline: s.multilineregex, casesensitive: s.casesensitive,
                pattern: s.searchstring || '',
                onApply: function (res) {
                    s.searchstring = res.pattern; s.isRegEx = true; s.multilineregex = res.multiline; s.casesensitive = res.casesensitive;
                    ss.value = res.pattern; render();
                }
            });
        }, s.isRegEx);

        var del = h('button', { type: 'button', class: 'btn btn-outline-danger btn-sm synocr-subrule-delete synocr-has-tip', 'data-tip': L('btn_remove_subrule'), onclick: function () { state.rules[i].subrules.splice(j, 1); render(); } }, '×');

        var fields = h('div', { class: 'synocr-subrule-fields' }, [
            h('div', { class: 'synocr-subrule-source' }, src),
            h('div', { class: 'synocr-subrule-typ' }, st),
            h('div', { class: 'synocr-subrule-search' }, ssWrap)
        ]);
        var flags = h('div', { class: 'synocr-subrule-flags' }, [
            inlineSwitch(L('sub_casesensitive'), s.casesensitive, function (v) { s.casesensitive = v; }, 'help_sub_casesensitive'),
            inlineSwitch(L('sub_isregex'), s.isRegEx, function (v) {
                s.isRegEx = v;
                render();
            }, 'help_sub_isregex'),
            inlineSwitch(L('sub_multiline'), s.multilineregex, function (v) { s.multilineregex = v; }, 'help_sub_multiline', !s.isRegEx)
        ]);
        var body = h('div', { class: 'synocr-subrule-body' }, [fields, flags]);

        row.appendChild(body);
        row.appendChild(h('div', { class: 'synocr-subrule-delete-wrap' }, del));
        return row;
    }

    function renderRule(i, filterExpand) {
        var r = state.rules[i];
        var expanded = isRuleExpanded(r, i);
        var collapsed = filterExpand ? false : isRuleCollapsed(r, i);
        var detailsId = 'synocr-rule-details-' + i;
        var bodyId = 'synocr-rule-body-' + i;

        var nameInp = h('input', { type: 'text', class: 'form-control form-control-sm', value: r.name });
        nameInp.addEventListener('input', function () { r.name = nameInp.value; });
        nameInp.addEventListener('change', function () { render(); });

        var condSel = select(COND, r.condition, function (v) { r.condition = v; });
        condSel.classList.add('form-select-sm');
        setTip(condSel, 'help_rule_condition');

        var tagInp = h('input', { type: 'text', class: 'form-control form-control-sm synocr-rule-targetfolder-input', value: r.tagname });
        tagInp.addEventListener('input', function () { r.tagname = tagInp.value; });
        var tagGearBtn = gearButton('tn_builder', function () { openTagBuilder(i, tagInp); });
        var tagWrap = h('div', { class: 'synocr-rule-targetfolder-wrap' }, [tagInp, tagGearBtn]);

        var targetInp = h('input', { type: 'text', class: 'form-control form-control-sm synocr-rule-targetfolder-input', value: r.targetfolder, placeholder: L('placeholder_targetfolder') });
        targetInp.addEventListener('input', function () { r.targetfolder = targetInp.value; });
        var gearBtn = gearButton('tf_builder', function () { openTargetFolderBuilder(i, targetInp); });
        var targetWrap = h('div', { class: 'synocr-rule-targetfolder-wrap' }, [targetInp, gearBtn]);

        var handle = h('span', {
            class: 'synocr-rule-drag-handle synocr-has-tip',
            'data-tip': L('drag_hint'),
            draggable: 'true'
        }, '⠿');

        var removeBtn = h('button', {
            type: 'button', class: 'btn btn-outline-danger btn-sm synocr-rule-remove synocr-has-tip',
            'data-tip': L('btn_remove_rule'),
            onclick: function () { state.rules.splice(i, 1); render(); }
        }, '×');

        var duplicateBtn = h('button', {
            type: 'button', class: 'btn btn-sm synocr-btn-outline-blue synocr-rule-duplicate synocr-btn-duplicate-icon synocr-has-tip',
            'data-tip': L('btn_duplicate_rule'),
            onclick: function () { duplicateRuleAt(i); }
        }, '⧉');

        var rawJumpBtn = h('button', {
            type: 'button', class: 'btn btn-sm synocr-btn-outline-blue synocr-rule-raw-jump synocr-has-tip',
            'data-tip': L('btn_jump_raw_rule', 'Im Raw-JSON anzeigen'),
            onclick: function () { jumpToRuleRaw(i); }
        }, '{}');

        var cardActions = h('div', { class: 'synocr-rule-card-actions' }, [removeBtn, duplicateBtn, rawJumpBtn]);

        var headerRow = h('div', { class: 'synocr-rule-header' }, [
            fieldPrimaryCell(L('rule_name'), nameInp, 'help_rule_name'),
            fieldPrimaryCell(L('tagname'), tagWrap, 'help_tagname')
        ]);

        var secondaryRow = h('div', { class: 'synocr-rule-secondary' }, [
            fieldPrimaryCell(L('rule_condition'), condSel, 'help_rule_condition'),
            fieldPrimaryCell(L('targetfolder'), targetWrap, 'help_targetfolder')
        ]);

        var subWrap = h('div', { class: 'synocr-rule-subrules mb-2' }, [
            h('div', { class: 'd-flex justify-content-between align-items-center mb-2' }, [
                h('span', { class: 'synocr-text-blue' }, [
                    h('span', { class: 'synocr-rule-tip-label synocr-has-tip', 'data-tip': tip('help_sub_source') }, L('sub_source')),
                    ' / ',
                    h('span', { class: 'synocr-rule-tip-label synocr-has-tip', 'data-tip': tip('help_sub_searchtyp') }, L('sub_searchtyp')),
                    ' / ',
                    h('span', { class: 'synocr-rule-tip-label synocr-has-tip', 'data-tip': tip('help_sub_searchstring') }, L('sub_searchstring'))
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
        var detailsInner = h('div', { class: 'pt-2 synocr-rule-details-grid' });
        detailsInner.appendChild(detailsGridRow([
            fieldPrimarySelect(L('on_match_action'), actSel, 'help_on_match_action'),
            fieldPrimarySelect(L('on_match_result'), resSel, 'help_on_match_result')
        ]));
        detailsInner.appendChild(detailsGridRow([
            fieldPrimaryRefList(L('requires'), r.requires, function (v) { r.requires = v; }, 'help_requires'),
            fieldPrimaryRefList(L('excludes'), r.excludes, function (v) { r.excludes = v; }, 'help_excludes')
        ]));
        detailsInner.appendChild(detailsGridRow([
            fieldPrimaryText(L('postscript'), r.postscript, function (v) { r.postscript = v; }, undefined, 'help_postscript'),
            fieldPrimaryText(L('apprise'), r.apprise_call, function (v) { r.apprise_call = v; }, undefined, 'help_apprise', true)
        ]));
        detailsInner.appendChild(detailsGridRow([
            fieldPrimarySelect(L('apprise_att'), attSel, 'help_apprise_att'),
            fieldPrimarySelect(L('notify_lang'), langSel, 'help_notify_lang')
        ]));
        detailsBody.appendChild(detailsInner);

        var collapseBtn = h('button', {
            type: 'button',
            class: 'synocr-rule-collapse-toggle synocr-has-tip',
            'data-tip': collapsed ? L('toggle_rule_expand') : L('toggle_rule_collapse'),
            'aria-label': collapsed ? L('toggle_rule_expand') : L('toggle_rule_collapse'),
            'aria-expanded': collapsed ? 'false' : 'true',
            'aria-controls': bodyId,
            onclick: function () {
                setRuleCollapsed(r, i, !isRuleCollapsed(r, i));
                render();
            }
        });

        var ruleBody = h('div', {
            class: 'collapse synocr-rule-body synocr-rule-collapsible' + (collapsed ? '' : ' show'),
            id: bodyId
        });
        ruleBody.appendChild(secondaryRow);
        ruleBody.appendChild(subWrap);
        ruleBody.appendChild(detailsFooter);
        ruleBody.appendChild(detailsBody);

        var headerRowWrap = h('div', { class: 'synocr-rule-header-row' }, [handle, collapseBtn, headerRow]);
        var cardLayout = h('div', { class: 'synocr-rule-layout' }, [headerRowWrap, ruleBody]);

        var cardClass = 'card card-body mb-3 synocr-rule-card' + (collapsed ? ' synocr-rule-card-collapsed' : '');
        var card = h('div', { class: cardClass, dataset: { ruleIndex: String(i) } }, [
            cardActions, cardLayout
        ]);

        handle.addEventListener('dragstart', function (e) {
            if (isFilterActive()) {
                e.preventDefault();
                return;
            }
            state.dragIndex = i;
            state.dragCard = card;
            var rect = card.getBoundingClientRect();
            var mb = parseFloat(window.getComputedStyle(card).marginBottom) || 0;
            state.dragHeight = rect.height + mb;
            card.classList.add('synocr-rule-card-dragging');
            var ph = document.createElement('div');
            ph.className = 'synocr-rule-drop-placeholder';
            ph.style.height = state.dragHeight + 'px';
            ph.setAttribute('aria-hidden', 'true');
            state.dropPlaceholder = ph;
            e.dataTransfer.effectAllowed = 'move';
            try { e.dataTransfer.setData('text/plain', String(i)); } catch (err) {}
        });
        handle.addEventListener('dragend', function () {
            cleanupRuleDrag();
        });

        return card;
    }

    function render() {
        var root = document.getElementById(ROOT_ID);
        if (!root) return;
        root.textContent = '';

        var fq = getFilterQuery();
        var filterActive = fq.length > 0;
        var total = state.rules.length;

        if (!total) {
            root.appendChild(h('div', { class: 'card card-body text-secondary' }, '—'));
            syncFilterCount(0, 0, false);
            return;
        }
        var list = h('div', { class: 'synocr-rules-list' + (filterActive ? ' synocr-rules-list--filtered' : '') });
        var shown = 0;
        state.rules.forEach(function (r, i) {
            var card = renderRule(i, filterActive);
            if (filterActive && !ruleMatchesFilter(r, fq)) {
                card.classList.add('synocr-rule-card--filter-hidden');
            } else {
                shown++;
            }
            list.appendChild(card);
        });
        if (filterActive && shown === 0) {
            list.appendChild(h('div', { class: 'card card-body text-secondary synocr-rules-filter-empty' }, L('filter_empty')));
        }
        root.appendChild(list);
        bindRulesListDrag(list);
        syncFilterCount(shown, total, filterActive);
    }

    function initFilter() {
        var inp = document.getElementById(FILTER_ID);
        if (!inp || inp._synocrFilterBound) return;
        inp._synocrFilterBound = true;
        inp.addEventListener('input', function () {
            if (state.dragIndex != null) cleanupRuleDrag();
            render();
        });
    }

    function initToolbar() {
        var toolbar = document.getElementById(TOOLBAR_ID);
        if (!toolbar || toolbar._synocrInit) return;
        toolbar._synocrInit = true;
        toolbar.appendChild(h('span', { class: 'text-secondary small' }, L('drag_hint')));
        toolbar.appendChild(h('button', {
            type: 'button',
            class: 'btn btn-sm synocr-btn-add synocr-btn-add-filled',
            onclick: function () {
                var n = 1;
                var names = ruleNames();
                while (names.indexOf('rule_' + n) !== -1) n++;
                state.rules.push({ name: 'rule_' + n, condition: 'any', priority: '', tagname: '', tagname_RegEx: '', targetfolder: '', dirname_RegEx: '', multilineregex: false, dirname_multilineregex: false, postscript: '', apprise_call: '', apprise_attachment: '', notify_lang: '', on_match: { action: '', result: '' }, requires: [], excludes: [], subrules: [{ searchstring: '', searchtyp: 'contains', isRegEx: false, source: 'content', casesensitive: false, multilineregex: false }] });
                reassignRulePrioritiesFromOrder();
                render();
            }
        }, '+ ' + L('btn_add_rule')));
    }

    function setRulesEditorPageMode() {
        var page = document.querySelector('.synocr-rules-editor-page');
        if (!page) return;
        if (isRawTabActive()) {
            page.classList.add('synocr-rules-editor-page--raw');
        } else {
            page.classList.remove('synocr-rules-editor-page--raw');
        }
    }

    function initRulesEditorLayout() {
        var scrollForm = document.querySelector('.synocr-content-scroll');
        if (scrollForm && document.getElementById(ROOT_ID)) {
            scrollForm.classList.add('synocr-rules-editor-active');
        }
        setRulesEditorPageMode();
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
        if (typeof window.synocrAutoDismissModal === 'function') {
            window.synocrAutoDismissModal(document.getElementById('popup-rules-save'), 2000);
        }
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
        }).then(function (r) {
            // Reject on HTTP errors (e.g. 502/403) so a non-JSON error page
            // doesn't surface as a cryptic JSON-parse failure downstream.
            if (!r.ok) throw new Error('http_' + r.status);
            return r.json();
        }).then(function (res) {
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
        }).catch(function (e) {
            // 'http_<status>'  -> dedicated server-error message
            // anything else    -> fetch-level/network failure (e.g. offline)
            var s = String((e && e.message) || e);
            if (s.indexOf('http_') === 0) {
                setStatus(L('save_http_error').replace('%s', s.slice(5)), false);
            } else {
                setStatus(L('save_error') + ' ' + s, false);
            }
        });
    }

    function isRawTabActive() {
        var pane = document.getElementById('synocr-rules-pane-raw');
        return !!(pane && pane.classList.contains('active'));
    }

    function syncRawTextareaHeight() {
        var rawTa = document.getElementById(RAW_ID);
        if (!rawTa) return;
        if (!isRawTabActive()) {
            rawTa.style.height = '';
            return;
        }
        var scrollEl = document.querySelector('.synocr-content-scroll');
        var colEl = document.querySelector('.synocr-content-col');
        var tabArea = document.querySelector('.synocr-ruleset-tab-area');
        var containerBottom = scrollEl
            ? scrollEl.getBoundingClientRect().bottom
            : (colEl ? colEl.getBoundingClientRect().bottom : window.innerHeight);
        if (tabArea) {
            var tabRect = tabArea.getBoundingClientRect();
            if (tabRect.bottom > 0 && tabRect.bottom < containerBottom) {
                containerBottom = tabRect.bottom;
            }
        }

        var top = rawTa.getBoundingClientRect().top;
        var h = Math.floor(containerBottom - top - 8);
        rawTa.style.height = Math.max(120, h) + 'px';
    }

    function scheduleRawTextareaHeight() {
        syncRawTextareaHeight();
        window.requestAnimationFrame(syncRawTextareaHeight);
        window.setTimeout(syncRawTextareaHeight, 50);
    }

    // Find the character range of a rule's object in pretty-printed JSON text.
    // `key` is the rules-object key exactly as produced by toBlob().
    function findRuleRangeInJson(text, key) {
        if (!text || !key) return null;
        var needle = JSON.stringify(key) + ':';
        var from = 0, occurrence = 0;
        // match the nth occurrence equal to the requested key index among same-named keys
        var pos = -1, hitIdx = 0;
        while ((pos = text.indexOf(needle, from)) !== -1) {
            // ensure the match is a top-level rules key: preceded by whitespace/start
            // and the char after the colon is optional space + '{'
            var after = pos + needle.length;
            var j = after;
            while (j < text.length && (text[j] === ' ' || text[j] === '\t')) j++;
            if (text[j] === '{') {
                if (occurrence === hitIdx) { break; }
                hitIdx++;
            }
            from = pos + needle.length;
            pos = -1;
        }
        if (pos === -1) {
            // fallback: first occurrence with an opening brace
            from = 0; pos = -1;
            while ((pos = text.indexOf(needle, from)) !== -1) {
                var after2 = pos + needle.length, j2 = after2;
                while (j2 < text.length && (text[j2] === ' ' || text[j2] === '\t')) j2++;
                if (text[j2] === '{') break;
                from = pos + needle.length; pos = -1;
            }
            if (pos === -1) return null;
        }
        var bracePos = pos + needle.length;
        while (bracePos < text.length && text[bracePos] !== '{') bracePos++;
        if (bracePos >= text.length) return null;
        // brace matching, respecting strings & escapes
        var depth = 0, i = bracePos, inStr = false, esc = false;
        while (i < text.length) {
            var c = text[i];
            if (inStr) {
                if (esc) { esc = false; }
                else if (c === '\\') { esc = true; }
                else if (c === '"') { inStr = false; }
            } else {
                if (c === '"') { inStr = true; }
                else if (c === '{') { depth++; }
                else if (c === '}') { depth--; if (depth === 0) { i++; break; }
                }
            }
            i++;
        }
        if (depth !== 0) return null;
        // start a bit before the key for context (line start)
        var start = pos;
        while (start > 0 && text[start - 1] !== '\n') start--;
        return { start: start, end: i };
    }

    function jumpToRuleRaw(ruleIndex) {
        if (ruleIndex == null || ruleIndex < 0 || ruleIndex >= state.rules.length) return;
        var r = state.rules[ruleIndex];
        var key = (r.name || '').trim() || ('rule_' + (ruleIndex + 1));
        var rawTa = document.getElementById(RAW_ID);
        var tabRaw = document.getElementById('synocr-rules-tab-raw');
        if (!rawTa || !tabRaw) return;

        function doSelect() {
            var text = rawTa.value || '';
            var range = findRuleRangeInJson(text, key);
            if (!range) { rawTa.focus(); return; }
            rawTa.focus();
            try { rawTa.setSelectionRange(range.start, range.end); } catch (e) {}
            // best-effort scroll: focus + selection scrolls in most browsers;
            // fallback: estimate by line number if selection not yet in view.
            var beforeSel = text.slice(0, range.start);
            var line = beforeSel.split('\n').length - 1;
            var lh = parseFloat(window.getComputedStyle(rawTa).lineHeight) || 18;
            var target = Math.max(0, line * lh - rawTa.clientHeight / 3);
            if (Math.abs(rawTa.scrollTop - target) > rawTa.clientHeight) {
                rawTa.scrollTop = target;
            }
        }

        if (isRawTabActive()) {
            // already on raw tab: refresh from visual model, then select
            rawTa.value = JSON.stringify(toBlob(), null, 2);
            state.rawDirty = false;
            window.requestAnimationFrame(doSelect);
        } else {
            // Pre-fill the raw textarea from the current visual model so the
            // selection is correct even if the tab's shown.bs.tab handler
            // (which normally fills it) never fires. The shown handler will
            // overwrite it with the same value, which is harmless.
            rawTa.value = JSON.stringify(toBlob(), null, 2);
            state.rawDirty = false;

            var fired = false;
            function runSelect() {
                if (fired) return;
                fired = true;
                tabRaw.removeEventListener('shown.bs.tab', runSelect);
                window.requestAnimationFrame(doSelect);
            }
            tabRaw.addEventListener('shown.bs.tab', runSelect);
            if (window.bootstrap && window.bootstrap.Tab) {
                window.bootstrap.Tab.getOrCreateInstance(tabRaw).show();
            } else if (window.jQuery && window.jQuery.fn.tab) {
                window.jQuery(tabRaw).tab('show');
            } else {
                tabRaw.click();
            }
            // Fallback: if shown.bs.tab never fires (framework missing or a
            // race), still select after a short delay so the button works.
            window.setTimeout(runSelect, 200);
        }
    }

    function initTabs() {
        var rawTa = document.getElementById(RAW_ID);
        var tabVisual = document.getElementById('synocr-rules-tab-visual');
        var tabRaw = document.getElementById('synocr-rules-tab-raw');
        if (tabRaw) {
            tabRaw.addEventListener('shown.bs.tab', function () {
                if (rawTa) rawTa.value = JSON.stringify(toBlob(), null, 2);
                setRulesEditorPageMode();
                scheduleRawTextareaHeight();
            });
        }
        if (tabVisual) {
            tabVisual.addEventListener('shown.bs.tab', function () {
                if (state.rawDirty && rawTa) {
                    try { fromBlob(JSON.parse(rawTa.value)); state.rawDirty = false; render(); }
                    catch (e) { setStatus(L('raw_invalid'), false); }
                }
                if (rawTa) rawTa.style.height = '';
                setRulesEditorPageMode();
            });
        }
        if (rawTa) rawTa.addEventListener('input', function () { state.rawDirty = true; });
        window.addEventListener('resize', syncRawTextareaHeight);
        var scrollEl = document.querySelector('.synocr-content-scroll');
        if (scrollEl && typeof window.ResizeObserver === 'function') {
            new window.ResizeObserver(syncRawTextareaHeight).observe(scrollEl);
        }
        var navToggle = document.getElementById('synocr-nav-toggle');
        if (navToggle) {
            navToggle.addEventListener('click', function () {
                window.setTimeout(scheduleRawTextareaHeight, 320);
            });
        }
        scheduleRawTextareaHeight();
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

    function syncTfRegexGate() {
        if (!tfModal.dirInput) return;
        syncModalRegexMultilineGate(tfModal.multilineInput, tfModal.multilineRow, tfModal.dirInput.value);
    }

    function syncTnRegexGate() {
        if (!tnModal.regexInput) return;
        syncModalRegexMultilineGate(tnModal.multilineInput, tnModal.multilineRow, tnModal.regexInput.value);
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
                class: 'synocr-namesyntax-palette-item synocr-has-tip',
                draggable: 'true',
                'data-token': tok,
                'data-tip': tok
            }, pathTokens[tok]));
        });

        var dirInput = h('input', { type: 'text', id: TF_DIRINPUT_ID, class: 'form-control form-control-sm font-monospace', placeholder: '[0-9]{4}' });
        dirInput.addEventListener('input', function () {
            updateTargetPreview();
            syncTfRegexGate();
        });
        var hintEl = h('div', { class: 'small text-muted mt-1' });
        var previewModeEl = h('div', { id: TF_PREVIEW_MODE_ID, class: 'small text-muted mb-1' });
        var previewEl = h('div', { id: TF_PREVIEW_ID, class: 'form-control form-control-sm bg-light font-monospace small' });

        var tfMultilineInput = h('input', { type: 'checkbox', id: TF_MULTILINE_ID, class: 'form-check-input', role: 'switch' });
        var tfMultilineRow = h('div', { class: 'form-check form-switch mt-2' }, [
            tfMultilineInput,
            h('label', { class: 'form-check-label synocr-rule-tip-label synocr-has-tip', 'for': TF_MULTILINE_ID, 'data-tip': tip('help_dirname_multiline') }, L('dirname_multiline'))
        ]);

        var dirInputWrap = wrapRegexWand(dirInput, 'regex_wand_title', function () {
            if (!regexAssistantAvailable()) return;
            window.synocrRegexAssistant.open({
                mode: 'extract', extractType: 'dir',
                multiline: tfMultilineInput.checked, casesensitive: false,
                pattern: dirInput.value || '',
                onApply: function (res) {
                    dirInput.value = res.pattern;
                    tfMultilineInput.checked = res.multiline;
                    updateTargetPreview();
                    syncTfRegexGate();
                }
            });
        }, true);

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
                        h('label', { class: 'form-label small fw-bold mb-1 synocr-rule-tip-label synocr-has-tip', 'for': TF_VISUAL_ID, 'data-tip': tip('help_targetfolder') }, L('targetfolder')),
                        pathRow,
                        hidden,
                        palette,
                        h('div', { class: 'border-top pt-3 mb-3' }, [
                            h('label', { class: 'form-label small fw-bold mb-1 synocr-rule-tip-label synocr-has-tip', 'for': TF_DIRINPUT_ID, 'data-tip': tip('help_dirname_regex') }, L('dirname_regex')),
                            dirInputWrap,
                            hintEl,
                            tfMultilineRow
                        ]),
                        h('div', { class: 'border-top pt-3' }, [
                            h('label', { class: 'form-label small fw-bold mb-1 synocr-rule-tip-label synocr-has-tip', 'data-tip': tip('help_tf_preview') }, L('tf_preview')),
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
        tfModal.dirInputWrap = dirInputWrap;
        tfModal.multilineInput = tfMultilineInput;
        tfModal.multilineRow = tfMultilineRow;
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
        syncTfRegexGate();
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
                class: 'synocr-namesyntax-palette-item synocr-has-tip',
                draggable: 'true',
                'data-token': tok,
                'data-tip': tok
            }, tagTokens[tok]));
        });

        var regexInput = h('input', { type: 'text', id: TN_REGEX_INPUT_ID, class: 'form-control form-control-sm font-monospace', placeholder: '[0-9]{4}' });
        regexInput.addEventListener('input', function () {
            updateTagHint();
            syncTnRegexGate();
        });
        var hintEl = h('div', { class: 'small text-muted mt-1' });

        var multilineInput = h('input', { type: 'checkbox', id: TN_MULTILINE_ID, class: 'form-check-input', role: 'switch' });
        var multilineRow = h('div', { class: 'form-check form-switch' }, [
            multilineInput,
            h('label', { class: 'form-check-label synocr-rule-tip-label synocr-has-tip', 'for': TN_MULTILINE_ID, 'data-tip': tip('help_multiline') }, L('multiline'))
        ]);

        var regexInputWrap = wrapRegexWand(regexInput, 'regex_wand_title', function () {
            if (!regexAssistantAvailable()) return;
            window.synocrRegexAssistant.open({
                mode: 'extract', extractType: 'tag',
                multiline: multilineInput.checked, casesensitive: false,
                pattern: regexInput.value || '',
                onApply: function (res) {
                    regexInput.value = res.pattern;
                    multilineInput.checked = res.multiline;
                    updateTagHint();
                    syncTnRegexGate();
                }
            });
        }, true);

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
                        h('label', { class: 'form-label small fw-bold mb-1 synocr-rule-tip-label synocr-has-tip', 'for': TN_VISUAL_ID, 'data-tip': tip('help_tagname') }, L('tagname')),
                        editorWrap,
                        hidden,
                        palette,
                        h('div', { class: 'border-top pt-3 mb-3' }, [
                            h('label', { class: 'form-label small fw-bold mb-1 synocr-rule-tip-label synocr-has-tip', 'for': TN_REGEX_INPUT_ID, 'data-tip': tip('help_tagname_regex') }, L('tagname_regex')),
                            regexInputWrap,
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
        tnModal.regexInputWrap = regexInputWrap;
        tnModal.multilineInput = multilineInput;
        tnModal.multilineRow = multilineRow;
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
        syncTnRegexGate();
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
        var l = readJson(LANG_ID);
        if (l) {
            lang = l;
            if (window.synocrDataTips) {
                window.synocrDataTips.setLang(l);
            }
        }
        bindDataTipsOnce();
        var root = document.getElementById(ROOT_ID);
        if (!root) return;
        var pt = readJson(PATH_TOKENS_ID);
        if (pt && typeof pt === 'object') pathTokens = pt;
        var tt = readJson(TAG_TOKENS_ID);
        if (tt && typeof tt === 'object') tagTokens = tt;
        var nl = readJson(NOTIFY_LANGS_ID);
        if (nl && typeof nl === 'object') notifyLangs = nl;
        var data = readJson(DATA_ID);
        fromBlob(data || { rules: {}, groups: {} });
        initRulesEditorLayout();
        initFilter();
        initToolbar();
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
