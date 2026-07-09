/**
 * synOCR — RegEx-Assistent („Zauberstab“)
 *
 * Visual PCRE builder for the rule editor. Opened from synocr-rules-editor.js
 * at the searchstring / tagname_RegEx / dirname_RegEx fields via
 *   synocrRegexAssistant.open({ mode, extractType, multiline, casesensitive,
 *                              source, pattern, onApply })
 *   → onApply({ pattern, multiline, casesensitive })
 *
 * Flow: pick a sample PDF (+ page range / clean-up-spaces options) → server
 * extracts the text exactly like synOCR.sh (pdftotext -layout + sed) and
 * returns a token; the user marks text and assigns types (fest/variabel/klasse);
 * segments are translated to a PCRE pattern; live preview runs server-side
 * (grep -P, same flags as the rule engine) and highlights matches. Extract mode
 * uses \K + lookahead so the consumed match == the extracted value (matches the
 * tagname_RegEx / dirname_RegEx backend exactly).
 *
 * Endpoint: POST index.cgi?page=rules-regex-preview  (op=load|preview|release)
 */
(function () {
    'use strict';

    var LANG_ID = 'synocr-rules-lang';
    var MODAL_ID = 'synocr-regex-assistant-modal';
    var ENDPOINT = 'index.cgi?page=rules-regex-preview';
    var LAST_PDF_KEY = 'synocr_regex_last_pdf';

    var lang = {};
    var st = null;  // active session state

    function getLastPdf() {
        try { return localStorage.getItem(LAST_PDF_KEY) || ''; } catch (e) { return ''; }
    }
    function saveLastPdf(path) {
        if (!path) return;
        try { localStorage.setItem(LAST_PDF_KEY, path); } catch (e) {}
    }
    function pdfBasename(path) {
        if (!path) return '';
        var i = path.lastIndexOf('/');
        return i >= 0 ? path.slice(i + 1) : path;
    }
    function setPath(path) {
        if (!st) return;
        st.path = path || '';
        if (st.pathLabelEl) {
            st.pathLabelEl.textContent = st.path ? pdfBasename(st.path) : '';
            st.pathLabelEl.title = st.path || '';
        }
    }
    function syncLastDocBtn() {
        if (!st || !st.lastDocBtn) return;
        st.lastDocBtn.style.display = getLastPdf() ? '' : 'none';
    }

    function readLang() {
        var el = document.getElementById(LANG_ID);
        if (!el) return;
        try { lang = JSON.parse(el.textContent.trim()) || {}; } catch (e) { lang = {}; }
    }
    function L(key, fb) { return lang[key] != null ? lang[key] : (fb != null ? fb : key); }

    var SEG_HELP_KEYS = {
        fixed: 'regex_help_tool_fixed',
        variable: 'regex_help_tool_variable',
        class: 'regex_help_tool_class',
        alt: 'regex_help_tool_alt',
        anchor: 'regex_help_tool_anchor',
        context: 'regex_help_tool_context'
    };

    function toolButton(toolClass, labelKey, helpKey) {
        return h('button', {
            type: 'button',
            class: 'btn btn-sm synocr-regex-tool ' + toolClass + ' synocr-has-tip',
            'data-tip-key': helpKey
        }, L(labelKey));
    }

    function h(tag, attrs, kids) {
        var el = document.createElement(tag);
        if (attrs) for (var k in attrs) {
            if (!Object.prototype.hasOwnProperty.call(attrs, k)) continue;
            if (k === 'class') el.className = attrs[k];
            else if (k === 'text') el.textContent = attrs[k];
            else if (k === 'dataset') for (var d in attrs[k]) el.dataset[d] = attrs[k][d];
            else if (k.indexOf('on') === 0 && typeof attrs[k] === 'function') el.addEventListener(k.slice(2), attrs[k]);
            else el.setAttribute(k, attrs[k]);
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

    function escHtml(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
    function escPcre(s) { return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

    // ---- pattern assembly --------------------------------------------------
    function fixedFrag(seg) {
        var s = escPcre(seg.text);
        if (seg.wsFlex) s = s.replace(/ +/g, '\\s+');
        return s;
    }
    function varFrag(seg) {
        if (seg.varKind === 'greedy') return '.*';
        if (seg.varKind === 'ws') return '\\s+';
        return '.*?';
    }
    function classFrag(seg) {
        var base = ({ digits: '\\d', letters: '[A-Za-z]', alnum: '[A-Za-z0-9]', special: '[^A-Za-z0-9]' })[seg.classKind] || '\\d';
        if (seg.classQuant === 'fixed') return base + '{' + (parseInt(seg.n, 10) || 1) + '}';
        if (seg.classQuant === 'range') return base + '{' + (parseInt(seg.n, 10) || 0) + ',' + (seg.m != null && seg.m !== '' ? parseInt(seg.m, 10) : '') + '}';
        return base + '+';
    }
    function altFrag(seg) {
        var texts = (seg.texts || []).filter(function (t) { return t !== ''; });
        if (!texts.length) return '(?:)';
        return '(?:' + texts.map(escPcre).join('|') + ')';
    }
    function anchorFrag(seg) {
        return ({ word: '\\b', start: '^', end: '$' })[seg.anchorKind] || '\\b';
    }
    function contextFrag(seg) {
        var t = escPcre(seg.text || '');
        if (seg.lookKind === 'before') return '(?<=' + t + ')';
        if (seg.lookKind === 'notBefore') return '(?<!' + t + ')';
        if (seg.lookKind === 'notAfter') return '(?!' + t + ')';
        return '(?=' + t + ')';
    }
    function segFrag(seg) {
        if (seg.type === 'fixed') return fixedFrag(seg);
        if (seg.type === 'variable') return varFrag(seg);
        if (seg.type === 'alt') return altFrag(seg);
        if (seg.type === 'anchor') return anchorFrag(seg);
        if (seg.type === 'context') return contextFrag(seg);
        return classFrag(seg);
    }
    function optionalWrap(frag, seg) {
        if (seg.type === 'anchor' || seg.type === 'context') return frag;
        return seg.optional ? '(?:' + frag + ')?' : frag;
    }
    // In extract mode the prefix/suffix become zero-width lookarounds. Eligible
    // segments: anchor (always zero-width) and fixed/alt that the user flagged
    // as extract-anchor. Their fragments are emitted without the optional-wrap.
    function isLook(seg) {
        if (seg.type === 'anchor') return true;
        if ((seg.type === 'fixed' || seg.type === 'alt') && seg.anchor) return true;
        return false;
    }
    function lookFrag(seg) {
        if (seg.type === 'fixed') return fixedFrag(seg);
        if (seg.type === 'alt') return altFrag(seg);
        if (seg.type === 'anchor') return anchorFrag(seg);
        return segFrag(seg);
    }

    function assemble() {
        if (st.expertDirty) return st.expertPattern;
        var segs = st.segments;
        if (!segs.length) return '';
        if (st.mode === 'extract') {
            var i = 0, n = segs.length, prefix = [], suffix = [];
            while (i < n && isLook(segs[i])) { prefix.push(segs[i]); i++; }
            var j = n - 1;
            while (j >= i && isLook(segs[j])) { suffix.unshift(segs[j]); j--; }
            var core = segs.slice(i, j + 1);
            var p = '';
            if (prefix.length) p += prefix.map(lookFrag).join('') + '\\K';
            p += core.map(function (s) { return optionalWrap(segFrag(s), s); }).join('');
            if (suffix.length) p += '(?=' + suffix.map(lookFrag).join('') + ')';
            return p;
        }
        return segs.map(function (s) { return optionalWrap(segFrag(s), s); }).join('');
    }

    // ---- rendering ---------------------------------------------------------
    function spanSpaces(s) { return s.replace(/ /g, '<span class="synocr-sp"> </span>'); }

    function renderText(matches) {
        var raw = st.text || '';
        var out = '', pos = 0;
        if (matches && matches.length) {
            for (var k = 0; k < matches.length; k++) {
                var m = matches[k];
                if (m === '') continue;
                var idx = raw.indexOf(m, pos);
                if (idx < 0) continue;
                out += spanSpaces(escHtml(raw.slice(pos, idx)));
                out += '<mark class="synocr-regex-match">' + spanSpaces(escHtml(m)) + '</mark>';
                pos = idx + m.length;
            }
        }
        out += spanSpaces(escHtml(raw.slice(pos)));
        st.viewerEl.innerHTML = out;
    }

    function renderMatchPreview(matches, extracted) {
        if (!st || !st.matchPreviewEl) return;
        var el = st.matchPreviewEl;
        var text = '';
        if (st.mode === 'extract') {
            if (extracted != null && extracted !== '') text = extracted;
            else if (matches && matches.length) text = matches[0];
        } else if (matches && matches.length) {
            text = matches[0];
        }
        if (!text) {
            el.style.display = 'none';
            el.textContent = '';
            el.title = '';
            return;
        }
        el.style.display = '';
        el.textContent = text;
        el.title = (matches && matches.length > 1)
            ? matches.map(function (m, i) { return (i + 1) + '. ' + m; }).join('\n')
            : text;
    }

    function lastEnd() {
        return st.segments.reduce(function (m, s) { return Math.max(m, s.end); }, 0);
    }

    function addSegment(type) {
        var seg;
        if (type === 'alt') {
            seg = { type: 'alt', texts: [''], start: lastEnd(), end: lastEnd(),
                    optional: false, anchor: false };
        } else if (type === 'anchor') {
            seg = { type: 'anchor', anchorKind: 'word', start: lastEnd(), end: lastEnd(),
                    optional: false, anchor: false };
        } else {
            var txt = st.selText || '';
            if (!txt) return;
            var start = st.text.indexOf(txt, lastEnd());
            if (start < 0) start = st.text.indexOf(txt);
            if (start < 0) return;
            seg = { type: type, text: txt, start: start, end: start + txt.length,
                    wsFlex: false, anchor: false, optional: false,
                    varKind: 'any', classKind: 'digits', classQuant: 'plus', n: '', m: '',
                    lookKind: 'after' };
            st.selText = '';
            if (window.getSelection) { try { window.getSelection().removeAllRanges(); } catch (e) {} }
        }
        st.segments.push(seg);
        st.expertDirty = false;
        renderSegments();
        syncExpert();
        schedulePreview();
    }

    function makeOptCheckbox(seg, prop, labelKey, helpKey) {
        var cb = h('input', { type: 'checkbox', class: 'form-check-input' });
        cb.checked = !!seg[prop];
        cb.addEventListener('change', function () {
            seg[prop] = cb.checked;
            st.expertDirty = false;
            if (prop === 'anchor') renderSegments(); // lookaround eligibility may shift
            syncExpert();
            schedulePreview();
        });
        var labelAttrs = { class: 'synocr-regex-seg-opt' };
        if (helpKey) {
            labelAttrs.class += ' synocr-has-tip';
            labelAttrs['data-tip-key'] = helpKey;
        }
        return h('label', labelAttrs, [cb, h('span', { text: L(labelKey) })]);
    }

    function renderSegments() {
        var bar = st.segBarEl;
        bar.innerHTML = '';
        if (!st.segments.length) {
            bar.appendChild(h('span', { class: 'small text-muted' }, L('regex_seg_empty', '—')));
            return;
        }
        st.segments.forEach(function (seg, idx) {
            var chip = h('div', { class: 'synocr-regex-seg' });
            var typeClass = { fixed: 'seg_fixed', variable: 'seg_var', class: 'seg_class', alt: 'seg_alt', anchor: 'seg_anchor', context: 'seg_context' }[seg.type];
            var label = L('regex_' + typeClass, seg.type);
            var helpKey = SEG_HELP_KEYS[seg.type];
            var badgeAttrs = { class: 'synocr-regex-seg-type ' + typeClass, text: label };
            if (helpKey) {
                badgeAttrs.class += ' synocr-has-tip';
                badgeAttrs['data-tip-key'] = helpKey;
            }
            chip.appendChild(h('span', badgeAttrs));

            if (seg.type === 'fixed') {
                chip.appendChild(makeOptCheckbox(seg, 'wsFlex', 'regex_seg_wsflex', 'regex_help_seg_wsflex'));
                if (st.mode === 'extract') {
                    chip.appendChild(makeOptCheckbox(seg, 'anchor', 'regex_seg_anchor', 'regex_help_seg_extract_anchor'));
                }
            } else if (seg.type === 'alt') {
                if (st.mode === 'extract') {
                    chip.appendChild(makeOptCheckbox(seg, 'anchor', 'regex_seg_anchor', 'regex_help_seg_extract_anchor'));
                }
                var inputs = h('div', { class: 'synocr-regex-seg-alt-inputs d-flex flex-wrap gap-1 align-items-center' });
                (seg.texts || ['']).forEach(function (t, ti) {
                    (function (ti) {
                        var inp = h('input', { type: 'text', class: 'form-control form-control-sm synocr-regex-seg-alt-inp', placeholder: L('regex_alt_placeholder', 'Text'), value: t });
                        inp.addEventListener('input', function () { seg.texts[ti] = inp.value; st.expertDirty = false; syncExpert(); schedulePreview(); });
                        inputs.appendChild(inp);
                        if (seg.texts.length > 1) {
                            var rmAlt = h('button', { type: 'button', class: 'btn btn-sm synocr-regex-seg-alt-rm', title: L('regex_btn_remove_seg', '×'), onclick: function () {
                                seg.texts.splice(ti, 1);
                                if (!seg.texts.length) seg.texts.push('');
                                st.expertDirty = false; renderSegments(); syncExpert(); schedulePreview();
                            } }, '×');
                            inputs.appendChild(rmAlt);
                        }
                    })(ti);
                });
                var addAlt = h('button', { type: 'button', class: 'btn btn-sm synocr-regex-seg-alt-add', title: L('regex_alt_add'), onclick: function () {
                    seg.texts.push(''); st.expertDirty = false; renderSegments(); syncExpert(); schedulePreview();
                } }, '+');
                inputs.appendChild(addAlt);
                chip.appendChild(inputs);
            } else if (seg.type === 'anchor') {
                var aSel = h('select', { class: 'form-select form-select-sm synocr-regex-seg-select synocr-regex-seg-select-anchor' }, [
                    h('option', { value: 'word', text: L('regex_anchor_word') }),
                    h('option', { value: 'start', text: L('regex_anchor_start') }),
                    h('option', { value: 'end', text: L('regex_anchor_end') })
                ]);
                aSel.value = seg.anchorKind;
                aSel.addEventListener('change', function () { seg.anchorKind = aSel.value; st.expertDirty = false; syncExpert(); schedulePreview(); });
                chip.appendChild(aSel);
            } else if (seg.type === 'context') {
                var cSel = h('select', { class: 'form-select form-select-sm synocr-regex-seg-select synocr-regex-seg-select-context' }, [
                    h('option', { value: 'before', text: L('regex_context_before') }),
                    h('option', { value: 'after', text: L('regex_context_after') }),
                    h('option', { value: 'notBefore', text: L('regex_context_not_before') }),
                    h('option', { value: 'notAfter', text: L('regex_context_not_after') })
                ]);
                cSel.value = seg.lookKind || 'after';
                cSel.addEventListener('change', function () { seg.lookKind = cSel.value; st.expertDirty = false; syncExpert(); schedulePreview(); });
                chip.appendChild(cSel);
            } else if (seg.type === 'variable') {
                var sel = h('select', { class: 'form-select form-select-sm synocr-regex-seg-select synocr-regex-seg-select-var' }, [
                    h('option', { value: 'any', text: L('regex_var_any') }),
                    h('option', { value: 'greedy', text: L('regex_var_until_anchor') }),
                    h('option', { value: 'ws', text: L('regex_var_whitespace') })
                ]);
                sel.value = seg.varKind;
                sel.addEventListener('change', function () { seg.varKind = sel.value; st.expertDirty = false; syncExpert(); schedulePreview(); });
                chip.appendChild(sel);
            } else {
                var kind = h('select', { class: 'form-select form-select-sm synocr-regex-seg-select synocr-regex-seg-select-kind' }, [
                    h('option', { value: 'digits', text: L('regex_class_digits') }),
                    h('option', { value: 'letters', text: L('regex_class_letters') }),
                    h('option', { value: 'alnum', text: L('regex_class_alnum') }),
                    h('option', { value: 'special', text: L('regex_class_special') })
                ]);
                kind.value = seg.classKind;
                var quant = h('select', { class: 'form-select form-select-sm synocr-regex-seg-select synocr-regex-seg-select-quant' }, [
                    h('option', { value: 'plus', text: '+' }),
                    h('option', { value: 'fixed', text: L('regex_class_length_fixed') }),
                    h('option', { value: 'range', text: L('regex_class_length_range') })
                ]);
                quant.value = seg.classQuant;
                var nInp = h('input', { type: 'number', class: 'form-control form-control-sm synocr-regex-seg-num', placeholder: 'n' });
                nInp.value = seg.n;
                var mInp = h('input', { type: 'number', class: 'form-control form-control-sm synocr-regex-seg-num', placeholder: 'm' });
                mInp.value = seg.m;
                function applyQuant() {
                    seg.classKind = kind.value; seg.classQuant = quant.value; seg.n = nInp.value; seg.m = mInp.value;
                    nInp.style.display = (quant.value === 'fixed' || quant.value === 'range') ? '' : 'none';
                    mInp.style.display = (quant.value === 'range') ? '' : 'none';
                    st.expertDirty = false; syncExpert(); schedulePreview();
                }
                kind.addEventListener('change', applyQuant);
                quant.addEventListener('change', applyQuant);
                nInp.addEventListener('input', applyQuant);
                mInp.addEventListener('input', applyQuant);
                applyQuant();
                chip.appendChild(kind); chip.appendChild(quant); chip.appendChild(nInp); chip.appendChild(mInp);
            }

            // optional flag — available for every consuming type (not for anchor/context)
            if (seg.type !== 'anchor' && seg.type !== 'context') {
                chip.appendChild(makeOptCheckbox(seg, 'optional', 'regex_seg_optional', 'regex_help_seg_optional'));
            }

            // text preview for fixed/variable/class/context (alt & anchor show controls instead)
            if (seg.type === 'fixed' || seg.type === 'variable' || seg.type === 'class' || seg.type === 'context') {
                chip.appendChild(h('span', { class: 'synocr-regex-seg-text font-monospace', title: seg.text, text: '\u201e' + seg.text + '\u201c' }));
            }

            var rm = h('button', { type: 'button', class: 'btn btn-sm synocr-regex-seg-rm', title: L('regex_btn_remove_seg', '×'), onclick: function () {
                st.segments.splice(idx, 1); st.expertDirty = false; renderSegments(); syncExpert(); schedulePreview();
            } }, '×');
            chip.appendChild(rm);
            bar.appendChild(chip);
        });
    }

    // ---- plain-text explanation -------------------------------------------
    function explainSeg(seg) {
        var s = '';
        if (seg.type === 'fixed') {
            s = L('regex_explain_fixed').replace('%t', seg.text || '');
            if (seg.wsFlex) s += ' ' + L('regex_explain_fixed_wsflex');
        } else if (seg.type === 'variable') {
            if (seg.varKind === 'greedy') s = L('regex_explain_var_greedy');
            else if (seg.varKind === 'ws') s = L('regex_explain_var_ws');
            else s = L('regex_explain_var_any');
        } else if (seg.type === 'class') {
            var kindLabel = ({
                digits: L('regex_explain_class_digits'),
                letters: L('regex_explain_class_letters'),
                alnum: L('regex_explain_class_alnum'),
                special: L('regex_explain_class_special')
            })[seg.classKind] || L('regex_explain_class_digits');
            var quantLabel;
            if (seg.classQuant === 'fixed') quantLabel = ' ' + L('regex_explain_class_fixed').replace('%n', String(seg.n || '1'));
            else if (seg.classQuant === 'range') quantLabel = ' ' + L('regex_explain_class_range').replace('%n', String(seg.n || '0')).replace('%m', String(seg.m || ''));
            else quantLabel = ' ' + L('regex_explain_class_plus');
            s = kindLabel + quantLabel;
        } else if (seg.type === 'alt') {
            var texts = (seg.texts || []).filter(function (t) { return t !== ''; });
            s = L('regex_explain_alt').replace('%t', texts.join(', '));
        } else if (seg.type === 'anchor') {
            if (seg.anchorKind === 'start') s = L('regex_explain_anchor_start');
            else if (seg.anchorKind === 'end') s = L('regex_explain_anchor_end');
            else s = L('regex_explain_anchor_word');
        } else if (seg.type === 'context') {
            var lk = seg.lookKind || 'after';
            var ctxTpl = ({
                before: L('regex_explain_context_before'),
                after: L('regex_explain_context_after'),
                notBefore: L('regex_explain_context_not_before'),
                notAfter: L('regex_explain_context_not_after')
            })[lk] || L('regex_explain_context_after');
            s = ctxTpl.replace('%t', seg.text || '');
        }
        if (seg.optional) s += ' ' + L('regex_explain_optional_suffix');
        return s;
    }

    function renderExplain() {
        if (!st || !st.explainEl) return;
        var el = st.explainEl;
        el.innerHTML = '';
        el.appendChild(h('div', { class: 'synocr-regex-explain-title small fw-bold mb-1' }, L('regex_explain_title')));
        if (st.expertDirty) {
            el.appendChild(h('div', { class: 'small text-muted' }, L('regex_explain_expert_only')));
            return;
        }
        if (!st.segments.length) {
            el.appendChild(h('div', { class: 'small text-muted' }, L('regex_explain_empty')));
            return;
        }
        var ol = h('ol', { class: 'synocr-regex-explain-list mb-0' });
        st.segments.forEach(function (seg) {
            ol.appendChild(h('li', { class: 'synocr-regex-explain-item' }, explainSeg(seg)));
        });
        el.appendChild(ol);
    }

    function syncExpert() {
        if (!st.expertEl) return;
        if (!st.expertDirty) st.expertEl.value = assemble();
        syncExpertTextareaHeight(st.expertEl);
        renderExplain();
    }

    function syncExpertTextareaHeight(el) {
        if (!el) return;
        var minH = 34;
        var max = Math.max(minH, Math.floor(window.innerHeight * 0.5));
        el.style.height = 'auto';
        var next = el.scrollHeight;
        if (!next || next < minH) next = minH;
        if (next > max) {
            el.style.height = max + 'px';
            el.style.overflowY = 'auto';
        } else {
            el.style.height = next + 'px';
            el.style.overflowY = 'hidden';
        }
    }

    // ---- server calls ------------------------------------------------------
    function post(body, cb) {
        var xhr = new XMLHttpRequest();
        xhr.open('POST', ENDPOINT, true);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4) return;
            try { cb(JSON.parse(xhr.responseText)); } catch (e) { cb({ ok: false, error: 'response' }); }
        };
        xhr.send(JSON.stringify(body));
    }

    function doLoad() {
        if (!st.path) return;
        setStatus(L('regex_sample_loading'));
        post({ op: 'load', path: st.path, searchAll: st.searchAll, clean_up_spaces: st.clean, source: st.source }, function (r) {
            if (!r || !r.ok) { setStatus((r && r.error) || 'error'); return; }
            saveLastPdf(st.path);
            syncLastDocBtn();
            st.token = r.token;
            st.text = r.text || '';
            renderText(null);
            st.viewerWrapEl.style.display = '';
            st.bodyEl.style.display = '';
            if (r.notes === 'no_text_layer') setStatus(L('regex_hint_no_text_layer'));
            else setStatus(L('regex_sample_loaded').replace('%n', st.text.length));
            schedulePreview();
        });
    }

    var previewTimer = null;
    function schedulePreview() {
        if (!st || !st.token) return;
        if (previewTimer) clearTimeout(previewTimer);
        previewTimer = setTimeout(runPreview, 300);
    }

    function runPreview() {
        if (!st || !st.token) return;
        var pattern = st.expertDirty ? st.expertPattern : assemble();
        post({ op: 'preview', token: st.token, pattern: pattern, mode: st.mode,
               multiline: st.multiline, casesensitive: st.casesensitive, extractType: st.extractType }, function (r) {
            if (!r) return;
            if (r.ok === false) {
                st.countEl.textContent = '';
                renderMatchPreview([], null);
                setStatus(r.error === 'syntax' ? L('regex_preview_error') : (r.error || 'error'));
                renderText(null);
                return;
            }
            renderText(r.matches || []);
            var n = r.count || 0;
            st.countEl.textContent = n > 0 ? L('regex_preview_matches').replace('%n', n) : L('regex_preview_no_match');
            renderMatchPreview(r.matches || [], r.extracted);
            setStatus(n > 0 ? '' : L('regex_hint_tested_one_sample'));
        });
    }

    function releaseToken() {
        if (st && st.token) {
            try { post({ op: 'release', token: st.token }, function () {}); } catch (e) {}
            st.token = null;
        }
    }

    function setStatus(t) { if (st && st.statusEl) st.statusEl.textContent = t || ''; }

    // ---- modal construction ------------------------------------------------
    function buildModal() {
        if (document.getElementById(MODAL_ID)) return document.getElementById(MODAL_ID);

        var viewerEl = h('pre', { class: 'form-control synocr-regex-viewer small' });
        var viewerWrap = h('div', { class: 'mb-2 synocr-regex-viewer-wrap', style: 'display:none;' }, [viewerEl]);

        // toolbar (capture selection on mousedown before focus shifts)
        var toolFixed = toolButton('synocr-regex-tool-fixed', 'regex_tool_fixed', 'regex_help_tool_fixed');
        var toolVar = toolButton('synocr-regex-tool-var', 'regex_tool_variable', 'regex_help_tool_variable');
        var toolClass = toolButton('synocr-regex-tool-class', 'regex_tool_class', 'regex_help_tool_class');
        var toolAlt = toolButton('synocr-regex-tool-alt', 'regex_tool_alt', 'regex_help_tool_alt');
        var toolAnchor = toolButton('synocr-regex-tool-anchor', 'regex_tool_anchor', 'regex_help_tool_anchor');
        var toolContext = toolButton('synocr-regex-tool-context', 'regex_tool_context', 'regex_help_tool_context');
        function capSel() { try { st.selText = window.getSelection().toString(); } catch (e) {} }
        toolFixed.addEventListener('mousedown', capSel);
        toolVar.addEventListener('mousedown', capSel);
        toolClass.addEventListener('mousedown', capSel);
        toolContext.addEventListener('mousedown', capSel);
        toolFixed.addEventListener('click', function () { addSegment('fixed'); });
        toolVar.addEventListener('click', function () { addSegment('variable'); });
        toolClass.addEventListener('click', function () { addSegment('class'); });
        toolAlt.addEventListener('click', function () { addSegment('alt'); });
        toolAnchor.addEventListener('click', function () { addSegment('anchor'); });
        toolContext.addEventListener('click', function () { addSegment('context'); });

        var segBar = h('div', { class: 'synocr-regex-segbar mb-2' });
        var expertEl = h('textarea', { class: 'form-control form-control-sm font-monospace synocr-regex-expert', rows: '1', spellcheck: 'false' });
        expertEl.addEventListener('input', function () {
            st.expertDirty = true;
            st.expertPattern = expertEl.value;
            syncExpertTextareaHeight(expertEl);
            renderExplain();
            schedulePreview();
        });

        var explainEl = h('div', { class: 'synocr-regex-explain mt-2 mb-2' });

        var countEl = h('span', { class: 'small fw-bold synocr-regex-count flex-shrink-0' });
        var matchPreviewEl = h('span', { class: 'synocr-regex-match-preview font-monospace', style: 'display:none;' });
        var previewRow = h('div', { class: 'synocr-regex-preview-row d-flex align-items-center gap-2' }, [countEl, matchPreviewEl]);

        // load section — single compact row
        var lastDocBtn = h('button', { type: 'button', class: 'btn btn-outline-primary btn-sm', style: 'display:none;' }, L('regex_btn_last_doc'));
        lastDocBtn.addEventListener('click', function () {
            var last = getLastPdf();
            if (!last) return;
            setPath(last);
            doLoad();
        });
        var pickBtn = h('button', { type: 'button', class: 'btn btn-outline-secondary btn-sm' }, L('regex_btn_pick_doc'));
        var pathLabel = h('span', { class: 'small text-muted synocr-regex-path text-truncate' });
        pickBtn.addEventListener('click', function () {
            if (typeof window.synocr_openPicker !== 'function') return;
            window.synocr_openPicker(null, 'file', {
                extensions: ['pdf'], title: L('regex_btn_pick_doc'), confirmLabel: L('regex_btn_pick_confirm', 'OK'),
                onSelect: function (path) { setPath(path); doLoad(); }
            });
        });
        var optFirst = h('input', { type: 'radio', name: 'synocr-regex-pages', value: 'first', class: 'form-check-input', id: 'synocr-regex-pages-first' }); optFirst.checked = true;
        var optAll = h('input', { type: 'radio', name: 'synocr-regex-pages', value: 'all', class: 'form-check-input', id: 'synocr-regex-pages-all' });
        function pageVal() { return optAll.checked ? 'all' : 'first'; }
        optFirst.addEventListener('change', function () { st.searchAll = pageVal(); });
        optAll.addEventListener('change', function () { st.searchAll = pageVal(); });
        var cleanInp = h('input', { type: 'checkbox', class: 'form-check-input', id: 'synocr-regex-clean' }); cleanInp.checked = true;
        cleanInp.addEventListener('change', function () { st.clean = cleanInp.checked ? 'true' : 'false'; });
        var srcSel = h('select', { class: 'form-select form-select-sm synocr-regex-src-select' }, [
            h('option', { value: 'content', text: L('regex_opt_source_content') }),
            h('option', { value: 'filename', text: L('regex_opt_source_filename') })
        ]);
        srcSel.addEventListener('change', function () { if (st) st.source = srcSel.value; });
        var srcWrap = h('span', { class: 'd-inline-flex align-items-center gap-1 synocr-regex-src-wrap' }, [
            h('span', { class: 'text-muted', text: L('regex_source_label', 'Quelle:') }), srcSel
        ]);
        var loadBtn = h('button', { type: 'button', class: 'btn btn-primary btn-sm', style: 'background-color:#0086E5;', title: L('regex_hint_options_change_requires_reload') }, L('regex_btn_load'));
        loadBtn.addEventListener('click', doLoad);

        var loadSection = h('div', { class: 'synocr-regex-load-section border-bottom pb-3 mb-3' }, [
            h('div', { class: 'synocr-regex-load-row d-flex flex-wrap align-items-center gap-2 small' }, [
                h('span', { class: 'synocr-regex-load-title fw-bold' }, L('regex_load_section_title')),
                lastDocBtn,
                pickBtn,
                pathLabel
            ]),
            h('div', { class: 'synocr-regex-load-opts d-flex flex-wrap align-items-center gap-3 small mt-2' }, [
                h('div', { class: 'form-check mb-0' }, [optFirst, h('label', { class: 'form-check-label', 'for': 'synocr-regex-pages-first', text: L('regex_opt_first_page') })]),
                h('div', { class: 'form-check mb-0' }, [optAll, h('label', { class: 'form-check-label', 'for': 'synocr-regex-pages-all', text: L('regex_opt_all_pages') })]),
                h('div', { class: 'form-check mb-0' }, [cleanInp, h('label', { class: 'form-check-label', 'for': 'synocr-regex-clean', text: L('regex_opt_clean_spaces') })]),
                srcWrap,
                loadBtn
            ])
        ]);

        // flags
        var mlInp = h('input', { type: 'checkbox', class: 'form-check-input', role: 'switch' });
        mlInp.addEventListener('change', function () { st.multiline = mlInp.checked ? 'true' : 'false'; schedulePreview(); });
        var csInp = h('input', { type: 'checkbox', class: 'form-check-input', role: 'switch' });
        csInp.addEventListener('change', function () { st.casesensitive = csInp.checked ? 'true' : 'false'; schedulePreview(); });

        var statusEl = h('div', { class: 'small text-muted mt-1' });

        var applyBtn = h('button', { type: 'button', class: 'btn btn-primary btn-sm', style: 'background-color:#0086E5;' }, L('regex_btn_apply'));
        applyBtn.addEventListener('click', function () {
            var pattern = st.expertDirty ? st.expertPattern : assemble();
            var cb = st.onApply;
            hideModal();
            if (typeof cb === 'function') cb({ pattern: pattern, multiline: st.multiline === 'true', casesensitive: st.casesensitive === 'true' });
        });
        var cancelBtn = h('button', { type: 'button', class: 'btn btn-secondary btn-sm', 'data-bs-dismiss': 'modal' }, L('regex_btn_cancel'));

        var bodyEl = h('div', { class: 'synocr-regex-body', style: 'display:none;' }, [
            h('div', { class: 'd-flex flex-wrap gap-1 mb-2' }, [toolFixed, toolVar, toolClass, toolAlt, toolAnchor, toolContext]),
            segBar,
            h('label', { class: 'form-label small fw-bold mb-1' }, L('regex_expert_pattern')),
            expertEl,
            explainEl,
            h('div', { class: 'd-flex flex-wrap align-items-center gap-3 mt-2 mb-2' }, [
                h('div', { class: 'form-check form-switch' }, [mlInp, h('label', { class: 'form-check-label', 'for': mlInp.id, text: L('regex_multiline', 'Multi-Line') })]),
                h('div', { class: 'form-check form-switch' }, [csInp, h('label', { class: 'form-check-label', 'for': csInp.id, text: L('regex_casesensitive', 'Groß-/Kleinschreibung') })])
            ]),
            viewerWrap,
            previewRow,
            statusEl
        ]);

        var modalEl = h('div', { id: MODAL_ID, class: 'modal fade', tabindex: '-1', 'aria-hidden': 'true' }, [
            h('div', { class: 'modal-dialog modal-dialog-centered synocr-regex-assistant-modal' }, [
                h('div', { class: 'modal-content' }, [
                    h('div', { class: 'modal-header bg-light' }, [
                        h('h5', { class: 'modal-title' }, L('regex_assistant_title')),
                        h('button', { type: 'button', class: 'btn-close', 'data-bs-dismiss': 'modal', 'aria-label': 'Close' })
                    ]),
                    h('div', { class: 'modal-body' }, [
                        loadSection,
                        bodyEl
                    ]),
                    h('div', { class: 'modal-footer bg-light' }, [cancelBtn, applyBtn])
                ])
            ])
        ]);
        document.body.appendChild(modalEl);

        // stash refs
        var M = {};
        M.el = modalEl; M.viewerEl = viewerEl; M.viewerWrapEl = viewerWrap; M.matchPreviewEl = matchPreviewEl; M.bodyEl = bodyEl;
        M.segBarEl = segBar; M.expertEl = expertEl; M.explainEl = explainEl; M.countEl = countEl; M.statusEl = statusEl;
        M.srcSel = srcSel; M.srcWrapEl = srcWrap; M.mlInp = mlInp; M.csInp = csInp;
        M.optFirst = optFirst; M.optAll = optAll; M.cleanInp = cleanInp; M.pathLabelEl = pathLabel;
        M.lastDocBtn = lastDocBtn; M.pickBtn = pickBtn; M.loadBtn = loadBtn;
        modalEl._refs = M;

        modalEl.addEventListener('hidden.bs.modal', releaseToken);
        modalEl.addEventListener('shown.bs.modal', function () {
            // Raise above any already-open modal (tag/target-folder builder) —
            // BS5 does not always stack backdrops correctly for nested modals.
            var open = document.querySelectorAll('.modal.show');
            var baseZ = 1055;
            open.forEach(function (m) { if (m !== modalEl) { var z = parseInt(getComputedStyle(m).zIndex, 10) || baseZ; if (z >= baseZ) baseZ = z + 10; } });
            modalEl.style.zIndex = String(baseZ + 10);
            var backdrops = document.querySelectorAll('.modal-backdrop');
            if (backdrops.length) backdrops[backdrops.length - 1].style.zIndex = String(baseZ);
        });
        return modalEl;
    }

    function showModal(el) {
        if (window.jQuery && window.jQuery.fn.modal) { window.jQuery(el).modal('show'); return; }
        if (window.bootstrap && window.bootstrap.Modal) window.bootstrap.Modal.getOrCreateInstance(el).show();
    }
    function hideModal(el) {
        el = el || (st && st.el);
        if (!el) return;
        if (window.jQuery && window.jQuery.fn.modal) { window.jQuery(el).modal('hide'); return; }
        if (window.bootstrap && window.bootstrap.Modal) window.bootstrap.Modal.getOrCreateInstance(el).hide();
    }

    // ---- public API --------------------------------------------------------
    function open(opts) {
        opts = opts || {};
        readLang();
        var el = buildModal();
        var M = el._refs;

        st = {
            el: el, viewerEl: M.viewerEl, viewerWrapEl: M.viewerWrapEl, matchPreviewEl: M.matchPreviewEl, bodyEl: M.bodyEl,
            segBarEl: M.segBarEl, expertEl: M.expertEl, explainEl: M.explainEl, countEl: M.countEl, statusEl: M.statusEl,
            pathLabelEl: M.pathLabelEl, lastDocBtn: M.lastDocBtn, pickBtn: M.pickBtn, loadBtn: M.loadBtn,
            mode: opts.mode === 'extract' ? 'extract' : 'match',
            extractType: opts.extractType === 'dir' ? 'dir' : 'tag',
            multiline: opts.multiline ? 'true' : 'false',
            casesensitive: opts.casesensitive ? 'true' : 'false',
            source: opts.source === 'filename' ? 'filename' : 'content',
            searchAll: 'first', clean: 'true',
            path: '', token: null, text: '', segments: [], selText: '',
            expertDirty: false, expertPattern: '', onApply: opts.onApply || null
        };

        var initialPattern = opts.pattern != null ? String(opts.pattern) : '';
        if (initialPattern) {
            st.expertDirty = true;
            st.expertPattern = initialPattern;
        }

        // reset UI
        setPath(getLastPdf());
        syncLastDocBtn();
        M.viewerWrapEl.style.display = 'none';
        M.bodyEl.style.display = 'none';
        M.mlInp.checked = st.multiline === 'true';
        M.csInp.checked = st.casesensitive === 'true';
        M.optFirst.checked = true; M.optAll.checked = false; M.cleanInp.checked = true;
        M.srcSel.value = st.source;
        M.srcWrapEl.style.display = (st.mode === 'extract') ? 'none' : '';
        M.countEl.textContent = '';
        M.statusEl.textContent = '';
        M.expertEl.value = initialPattern;
        renderMatchPreview([], null);
        renderSegments();
        renderExplain();
        renderText(null);

        showModal(el);
        syncExpertTextareaHeight(M.expertEl);
        window.requestAnimationFrame(function () { syncExpertTextareaHeight(M.expertEl); });
    }

    window.synocrRegexAssistant = { open: open };
})();
