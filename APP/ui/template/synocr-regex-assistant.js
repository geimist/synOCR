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

    function assembleSegments(segments, mode) {
        if (!segments || !segments.length) return '';
        if (mode === 'extract') {
            var i = 0, n = segments.length, prefix = [], suffix = [];
            while (i < n && isLook(segments[i])) { prefix.push(segments[i]); i++; }
            var j = n - 1;
            while (j >= i && isLook(segments[j])) { suffix.unshift(segments[j]); j--; }
            var core = segments.slice(i, j + 1);
            var p = '';
            if (prefix.length) p += prefix.map(lookFrag).join('') + '\\K';
            p += core.map(function (s) { return optionalWrap(segFrag(s), s); }).join('');
            if (suffix.length) p += '(?=' + suffix.map(lookFrag).join('') + ')';
            return p;
        }
        return segments.map(function (s) { return optionalWrap(segFrag(s), s); }).join('');
    }

    function assemble() {
        if (st.expertDirty) return st.expertPattern;
        return assembleSegments(st.segments, st.mode);
    }

    // ---- pattern decompiler (editor-produced PCRE only) ------------------
    function unescPcre(s) {
        return String(s).replace(/\\(.)/g, function (_, c) { return c; });
    }

    function splitTopLevelAlt(s) {
        var parts = [], cur = '', depth = 0, i = 0;
        while (i < s.length) {
            if (s[i] === '\\') {
                cur += s.slice(i, i + 2);
                i += 2;
                continue;
            }
            if (s.slice(i, i + 3) === '(?:') {
                depth++;
                cur += '(?:';
                i += 3;
                continue;
            }
            if (s[i] === '(') {
                depth++;
                cur += '(';
                i++;
                continue;
            }
            if (s[i] === ')') {
                depth--;
                cur += ')';
                i++;
                continue;
            }
            if (s[i] === '|' && depth === 0) {
                parts.push(cur);
                cur = '';
                i++;
                continue;
            }
            cur += s[i];
            i++;
        }
        parts.push(cur);
        return parts;
    }

    function hasTopLevelPipe(s) {
        var depth = 0, i = 0;
        while (i < s.length) {
            if (s[i] === '\\') { i += 2; continue; }
            if (s.slice(i, i + 3) === '(?:') { depth++; i += 3; continue; }
            if (s[i] === '(') { depth++; i++; continue; }
            if (s[i] === ')') { depth--; i++; continue; }
            if (s[i] === '|' && depth === 0) return true;
            i++;
        }
        return false;
    }

    function findBalancedClose(s, openPos) {
        var depth = 1, i = openPos + 1;
        while (i < s.length) {
            if (s[i] === '\\') { i += 2; continue; }
            if (s.slice(i, i + 3) === '(?:') {
                var c2 = findBalancedClose(s, i);
                if (c2 < 0) return -1;
                i = c2 + 1;
                continue;
            }
            if (s.slice(i, i + 2) === '(?') {
                var close = findBalancedClose(s, i);
                if (close < 0) return -1;
                i = close + 1;
                continue;
            }
            if (s[i] === '(') {
                var c3 = findBalancedClose(s, i);
                if (c3 < 0) return -1;
                i = c3 + 1;
                continue;
            }
            if (s[i] === ')') {
                depth--;
                if (depth === 0) return i;
            }
            i++;
        }
        return -1;
    }

    function defaultSeg(type) {
        return {
            type: type,
            text: '',
            start: 0,
            end: 0,
            wsFlex: false,
            anchor: false,
            optional: false,
            varKind: 'any',
            classKind: 'digits',
            classQuant: 'plus',
            n: '',
            m: '',
            lookKind: 'after',
            anchorKind: 'word',
            texts: ['']
        };
    }

    // Patterns with constructs the visual editor cannot represent faithfully
    // (generic classes, bare \\s, inline flags, …) stay in expert mode so the
    // server-side explain tokenizer is used instead of explainSeg().
    function patternNeedsExpertMode(pattern) {
        if (!pattern) return false;
        if (/\(\?[imsxU\-]+[):]/.test(pattern)) return true;
        if (/\(\?>/i.test(pattern)) return true;
        if (/\\(?:[1-9]\d*|g<|k<)/.test(pattern)) return true;
        if (/\\[wWDSRNnrt]/.test(pattern)) return true;
        if (/\\s(?![+*?{])/.test(pattern)) return true;
        var knownClasses = ['[A-Za-z0-9]', '[A-Za-z]', '[^A-Za-z0-9]'];
        var idx = 0;
        while ((idx = pattern.indexOf('[', idx)) >= 0) {
            var known = false;
            for (var k = 0; k < knownClasses.length; k++) {
                if (pattern.slice(idx).indexOf(knownClasses[k]) === 0) { known = true; break; }
            }
            if (!known) return true;
            idx++;
        }
        return false;
    }

    function parsePatternToSegments(pattern, mode) {
        if (!pattern) return { ok: true, segments: [] };
        var tries = [];
        tries.push(function () { return parsePatternBody(pattern, 'match'); });
        if (mode === 'extract') tries.push(function () { return parsePatternBody(pattern, 'extract'); });
        for (var t = 0; t < tries.length; t++) {
            var parsed = tries[t]();
            if (!parsed || !parsed.ok) continue;
            if (assembleSegments(parsed.segments, mode) === pattern) return parsed;
        }
        return { ok: false };
    }

    function parsePatternBody(pattern, parseMode) {
        try {
            if (parseMode === 'extract') {
                var kPos = pattern.indexOf('\\K');
                if (kPos >= 0) {
                    var prefix = pattern.slice(0, kPos);
                    var rest = pattern.slice(kPos + 2);
                    var peeled = peelExtractSuffix(rest);
                    var coreStr = peeled ? peeled.core : rest;
                    var suffixInner = peeled ? peeled.suffixInner : '';
                    var pfx = new PatternParser(prefix, 'look');
                    var prefixSegs = pfx.parseList();
                    if (!pfx.atEnd()) return { ok: false };
                    var core = new PatternParser(coreStr, 'match');
                    var coreSegs = core.parseList();
                    if (!core.atEnd()) return { ok: false };
                    var suffixSegs = [];
                    if (suffixInner) {
                        var sfx = new PatternParser(suffixInner, 'look');
                        suffixSegs = sfx.parseList();
                        if (!sfx.atEnd()) return { ok: false };
                    }
                    return { ok: true, segments: prefixSegs.concat(coreSegs, suffixSegs) };
                }
            }
            var p = new PatternParser(pattern, 'match');
            var segs = p.parseList();
            if (!p.atEnd()) return { ok: false };
            return { ok: true, segments: segs };
        } catch (e) {
            return { ok: false };
        }
    }

    function peelExtractSuffix(s) {
        var idx = s.length;
        while (idx > 0) {
            var open = s.lastIndexOf('(?=', idx - 1);
            if (open < 0) return null;
            if (s[s.length - 1] !== ')') return null;
            var close = findBalancedClose(s, open);
            if (close !== s.length - 1) {
                idx = open;
                continue;
            }
            return {
                core: s.slice(0, open),
                suffixInner: s.slice(open + 3, close)
            };
        }
        return null;
    }

    function PatternParser(pattern, listMode) {
        this.pattern = pattern;
        this.pos = 0;
        this.listMode = listMode || 'match';
    }
    PatternParser.prototype.atEnd = function () { return this.pos >= this.pattern.length; };
    PatternParser.prototype.slice = function (a, b) { return this.pattern.slice(a, b == null ? this.pos : b); };
    PatternParser.prototype.tryTake = function (lit) {
        if (this.pattern.slice(this.pos, this.pos + lit.length) !== lit) return false;
        this.pos += lit.length;
        return true;
    };
    PatternParser.prototype.parseList = function () {
        var out = [];
        while (!this.atEnd()) {
            var seg = this.parseOne();
            if (!seg) throw new Error('parse');
            out.push(seg);
        }
        return out;
    };
    PatternParser.prototype.parseOne = function () {
        var start = this.pos;
        if (this.tryTake('(?:')) {
            var innerStart = this.pos;
            var close = findBalancedClose(this.pattern, innerStart - 3);
            if (close < 0) throw new Error('parse');
            var inner = this.pattern.slice(innerStart, close);
            this.pos = close + 1;
            var optional = this.tryTake('?');
            var seg;
            if (hasTopLevelPipe(inner)) {
                seg = defaultSeg('alt');
                seg.texts = splitTopLevelAlt(inner).map(unescPcre);
                if (!seg.texts.length) seg.texts = [''];
            } else {
                var sub = new PatternParser(inner, this.listMode);
                var subs = sub.parseList();
                if (!sub.atEnd() || subs.length !== 1) throw new Error('parse');
                seg = subs[0];
            }
            if (optional) seg.optional = true;
            if (this.listMode === 'look' && (seg.type === 'fixed' || seg.type === 'alt')) seg.anchor = true;
            return seg;
        }
        var seg2 = this.parseAtom();
        if (!seg2) throw new Error('parse');
        return seg2;
    };
    PatternParser.prototype.parseAtom = function () {
        if (this.tryTake('\\b')) {
            var a = defaultSeg('anchor');
            a.anchorKind = 'word';
            return a;
        }
        if (this.tryTake('^')) {
            var a2 = defaultSeg('anchor');
            a2.anchorKind = 'start';
            return a2;
        }
        if (this.tryTake('$')) {
            var a3 = defaultSeg('anchor');
            a3.anchorKind = 'end';
            return a3;
        }
        if (this.tryTake('.*?')) {
            var v = defaultSeg('variable');
            v.varKind = 'any';
            return v;
        }
        if (this.tryTake('.*')) {
            var v2 = defaultSeg('variable');
            v2.varKind = 'greedy';
            return v2;
        }
        if (this.tryTake('\\s*')) {
            var v3s = defaultSeg('variable');
            v3s.varKind = 'ws';
            v3s.varQuant = 'star';
            return v3s;
        }
        if (this.tryTake('\\s+')) {
            var v3 = defaultSeg('variable');
            v3.varKind = 'ws';
            return v3;
        }
        if (this.tryTake('\\s?')) {
            var v3q = defaultSeg('variable');
            v3q.varKind = 'ws';
            v3q.optional = true;
            return v3q;
        }
        if (this.tryTake('\\s')) {
            var v3b = defaultSeg('variable');
            v3b.varKind = 'ws';
            return v3b;
        }
        var look = this.tryLookaround();
        if (look) return look;
        var cls = this.tryClass();
        if (cls) return cls;
        var lit = this.tryLiteral();
        if (lit) {
            if (this.listMode === 'look') lit.anchor = true;
            return lit;
        }
        return null;
    };
    PatternParser.prototype.tryLookaround = function () {
        var rest = this.pattern.slice(this.pos);
        var m = rest.match(/^\(\?(<=|<!|!|=)/);
        if (!m) return null;
        var kindMap = { '<=': 'before', '<!': 'notBefore', '!': 'notAfter', '=': 'after' };
        var openLen = 3 + (m[1].length - 1);
        var close = findBalancedClose(this.pattern, this.pos);
        if (close < 0) return null;
        var inner = this.pattern.slice(this.pos + openLen, close);
        this.pos = close + 1;
        var seg = defaultSeg('context');
        seg.lookKind = kindMap[m[1]] || 'after';
        seg.text = unescPcre(inner);
        return seg;
    };
    PatternParser.prototype.tryClass = function () {
        var base = null, kind = '';
        if (this.tryTake('\\d')) { base = '\\d'; kind = 'digits'; }
        else if (this.tryTake('[A-Za-z0-9]')) { base = '[A-Za-z0-9]'; kind = 'alnum'; }
        else if (this.tryTake('[A-Za-z]')) { base = '[A-Za-z]'; kind = 'letters'; }
        else if (this.tryTake('[^A-Za-z0-9]')) { base = '[^A-Za-z0-9]'; kind = 'special'; }
        if (!base) return null;
        var seg = defaultSeg('class');
        seg.classKind = kind;
        if (this.tryTake('{')) {
            var body = '';
            while (!this.atEnd() && this.pattern[this.pos] !== '}') {
                body += this.pattern[this.pos];
                this.pos++;
            }
            if (!this.tryTake('}')) throw new Error('parse');
            var parts = body.split(',');
            seg.classQuant = parts.length > 1 ? 'range' : 'fixed';
            seg.n = parts[0] || '0';
            seg.m = parts.length > 1 ? (parts[1] || '') : '';
            return seg;
        }
        if (!this.tryTake('+')) throw new Error('parse');
        seg.classQuant = 'plus';
        return seg;
    };
    PatternParser.prototype.tryLiteral = function () {
        var start = this.pos;
        while (!this.atEnd()) {
            if (this.pattern[this.pos] === '\\') {
                var nx = this.pattern[this.pos + 1];
                if (nx && /[swdDSWnrtRNK]/.test(nx)) break;
                this.pos += 2;
                continue;
            }
            if (this.isAtomStart()) break;
            this.pos++;
        }
        if (this.pos === start) return null;
        var raw = this.pattern.slice(start, this.pos);
        var seg = defaultSeg('fixed');
        seg.text = unescPcre(raw.replace(/\\s\+/g, ' '));
        seg.wsFlex = /\\s\+/.test(raw);
        return seg;
    };
    PatternParser.prototype.isAtomStart = function () {
        var s = this.pattern.slice(this.pos);
        if (s.indexOf('(?:') === 0) return true;
        if (/^\(\?(<=|<!|!|=)/.test(s)) return true;
        if (s.indexOf('\\b') === 0 || s.indexOf('\\s*') === 0 || s.indexOf('\\s+') === 0 ||
            s.indexOf('\\s?') === 0 || s.indexOf('\\s') === 0 || s.indexOf('\\d') === 0) return true;
        if (s.indexOf('.*?') === 0 || s.indexOf('.*') === 0) return true;
        if (s.indexOf('[A-Za-z0-9]') === 0 || s.indexOf('[A-Za-z]') === 0 || s.indexOf('[^A-Za-z0-9]') === 0) return true;
        if (s[0] === '^' || s[0] === '$') return true;
        return false;
    };

    function segTypeClass(seg) {
        return { fixed: 'seg_fixed', variable: 'seg_var', class: 'seg_class', alt: 'seg_alt', anchor: 'seg_anchor', context: 'seg_context' }[seg.type] || 'seg_fixed';
    }

    function itemTypeClass(item) {
        if (!item) return 'seg_fixed';
        var kind = item.kind || item.type;
        if (kind === 'variable' || kind === 'escape' || kind === 'keep') return 'seg_var';
        if (kind === 'class' || kind === 'class_generic') return 'seg_class';
        if (kind === 'alt' || kind === 'branch_reset' || kind === 'atomic') return 'seg_alt';
        if (kind === 'anchor') return 'seg_anchor';
        if (kind === 'context' || kind === 'flags' || kind === 'flags_group') return 'seg_context';
        if (kind === 'group') return item.captured ? 'seg_var' : 'seg_fixed';
        if (kind === 'backref') return 'seg_var';
        return segTypeClass({ type: kind });
    }

    function explainFragmentText(item, isSeg) {
        if (isSeg) return optionalWrap(segFrag(item), item);
        return item.span || item.raw || '';
    }

    function explainLineText(item, isSeg) {
        var frag = explainFragmentText(item, isSeg);
        var text = isSeg ? explainSeg(item) : explainItem(item);
        return frag ? (frag + ' — ' + text) : text;
    }

    var explainHighlightIdx = null;

    function clearExplainHighlight() {
        if (!st) return;
        explainHighlightIdx = null;
        if (st.patternPreviewEl) {
            st.patternPreviewEl.querySelectorAll('.synocr-regex-explain-highlight').forEach(function (el) {
                el.classList.remove('synocr-regex-explain-highlight');
            });
        }
    }

    function setExplainHighlight(idx) {
        if (!st || idx === explainHighlightIdx) return;
        clearExplainHighlight();
        if (idx === null || idx === undefined || idx < 0) return;
        explainHighlightIdx = idx;
        var sel = '[data-explain-idx="' + idx + '"]';
        if (st.patternPreviewEl) {
            var frag = st.patternPreviewEl.querySelector('.synocr-regex-pattern-frag' + sel);
            if (frag) frag.classList.add('synocr-regex-explain-highlight');
        }
    }

    function bindExplainHover(root) {
        if (!root || root._explainHoverBound) return;
        root._explainHoverBound = true;
        root.addEventListener('mouseover', function (e) {
            var host = e.target.closest('[data-explain-idx]');
            if (!host || !root.contains(host)) return;
            var idx = parseInt(host.getAttribute('data-explain-idx'), 10);
            if (!isNaN(idx)) setExplainHighlight(idx);
        });
        root.addEventListener('mouseleave', function (e) {
            if (!e.relatedTarget || !root.contains(e.relatedTarget)) clearExplainHighlight();
        });
    }

    function buildExplainSummary() {
        if (!st) return '';
        if (st.expertDirty) {
            if (st.expertExplainItems && st.expertExplainItems.length) {
                var title = L('regex_explain_title');
                var lines = st.expertExplainItems.map(function (item, i) {
                    return (i + 1) + '. ' + explainLineText(item, false);
                });
                var out = title + '\n' + lines.join('\n');
                if (st.expertExplainWarnings && st.expertExplainWarnings.length) {
                    var notes = [];
                    st.expertExplainWarnings.forEach(function (w) {
                        if (w === 'redos_nested_quant' || w === 'redos_overlapping_wildcard') {
                            notes.push(L('regex_explain_redos'));
                        }
                    });
                    if (notes.length) out += '\n\n' + notes.filter(function (n, i, a) { return a.indexOf(n) === i; }).join('\n');
                }
                return out;
            }
            return L('regex_explain_expert_only');
        }
        if (!st.segments.length) return L('regex_explain_empty');
        var title = L('regex_explain_title');
        var lines = st.segments.map(function (seg, i) {
            return (i + 1) + '. ' + explainLineText(seg, true);
        });
        return title + '\n' + lines.join('\n');
    }

    function syncPatternExplainTip() {
        if (!st) return;
        var tip = buildExplainSummary();
        var expert = st.expertDirty;
        if (st.patternLabelEl) {
            if (tip) {
                st.patternLabelEl.setAttribute('data-tip', tip);
                st.patternLabelEl.classList.add('synocr-has-tip');
            } else {
                st.patternLabelEl.removeAttribute('data-tip');
                st.patternLabelEl.classList.remove('synocr-has-tip');
            }
        }
        if (st.patternPreviewEl) {
            st.patternPreviewEl.tabIndex = expert ? -1 : 0;
            if (!expert && st.segments.length && tip) {
                st.patternPreviewEl.setAttribute('data-tip', tip);
                st.patternPreviewEl.classList.add('synocr-has-tip');
            } else {
                st.patternPreviewEl.removeAttribute('data-tip');
                st.patternPreviewEl.classList.remove('synocr-has-tip');
            }
        }
        if (st.expertEl) {
            if (st.expertDirty && tip) {
                st.expertEl.setAttribute('data-tip', tip);
                st.expertEl.classList.add('synocr-has-tip');
            } else {
                st.expertEl.removeAttribute('data-tip');
                st.expertEl.classList.remove('synocr-has-tip');
            }
        }
    }

    function segToggleLabel() {
        if (!st) return '';
        var open = !!st.segExpanded;
        var label = open ? L('regex_toggle_seg_hide', 'Bausteine ausblenden') : L('regex_toggle_seg_show', 'Bausteine anzeigen');
        var n = st.segments ? st.segments.length : 0;
        if (n > 0) label += ' (' + n + ')';
        return (open ? '\u25BC ' : '\u25B6 ') + label;
    }

    function syncSegCollapse() {
        if (!st || !st.segCollapseEl || !st.segToggleBtn) return;
        st.segCollapseEl.style.display = st.segExpanded ? '' : 'none';
        st.segToggleBtn.textContent = segToggleLabel();
        st.segToggleBtn.setAttribute('aria-expanded', st.segExpanded ? 'true' : 'false');
    }

    function renderPatternFromSpans(container, pattern, items, isSeg) {
        if (isSeg) {
            items.forEach(function (item, idx) {
                var frag = explainFragmentText(item, true);
                if (!frag) return;
                container.appendChild(h('span', {
                    class: 'synocr-regex-pattern-frag ' + segTypeClass(item) + ' synocr-has-tip',
                    'data-explain-idx': String(idx),
                    'data-tip': explainLineText(item, true)
                }, frag));
            });
            return;
        }
        var pos = 0;
        items.forEach(function (item, idx) {
            var start = item.start != null ? item.start : pos;
            var len = item.length != null ? item.length : ((item.span && item.span.length) || 0);
            if (start > pos) container.appendChild(document.createTextNode(pattern.slice(pos, start)));
            var fragText = pattern.slice(start, start + len);
            if (!fragText) return;
            container.appendChild(h('span', {
                class: 'synocr-regex-pattern-frag ' + itemTypeClass(item) + ' synocr-has-tip',
                'data-explain-idx': String(idx),
                'data-tip': explainLineText(item, false)
            }, fragText));
            pos = start + len;
        });
        if (pos < pattern.length) container.appendChild(document.createTextNode(pattern.slice(pos)));
    }

    function syncPatternLineLayout() {
        if (!st) return;
        var el = st.expertEl;
        var preview = st.patternPreviewEl;
        var wrap = st.patternLineWrapEl;
        var minH = 34;
        var max = Math.max(minH, Math.floor(window.innerHeight * 0.5));
        if (st.expertDirty && el && wrap && preview) {
            el.style.height = 'auto';
            preview.style.height = 'auto';
            var next = Math.max(minH, el.scrollHeight, preview.scrollHeight);
            if (next > max) {
                wrap.style.height = max + 'px';
                el.style.height = max + 'px';
                preview.style.height = max + 'px';
                el.style.overflowY = 'auto';
                preview.style.overflowY = 'auto';
            } else {
                wrap.style.height = next + 'px';
                el.style.height = next + 'px';
                preview.style.height = next + 'px';
                el.style.overflowY = 'hidden';
                preview.style.overflowY = 'hidden';
            }
            preview.style.maxHeight = max + 'px';
            el.style.maxHeight = max + 'px';
            return;
        }
        if (preview) syncPatternPreviewHeight(preview);
        if (wrap) wrap.style.height = '';
    }

    function syncPatternLineScroll() {
        if (!st || !st.expertDirty || !st.expertEl || !st.patternPreviewEl) return;
        st.patternPreviewEl.scrollTop = st.expertEl.scrollTop;
        st.patternPreviewEl.scrollLeft = st.expertEl.scrollLeft;
    }

    function renderPatternPreview() {
        if (!st || !st.patternPreviewEl) return;
        var el = st.patternPreviewEl;
        el.innerHTML = '';
        clearExplainHighlight();
        if (st.expertDirty) {
            var pattern = st.expertPattern || (st.expertEl ? st.expertEl.value : '') || '';
            if (!pattern) {
                el.style.display = 'none';
                syncPatternExplainTip();
                syncPatternLineLayout();
                return;
            }
            el.style.display = '';
            if (st.expertExplainItems && st.expertExplainItems.length && st.expertExplainPattern === pattern) {
                renderPatternFromSpans(el, pattern, st.expertExplainItems, false);
            } else {
                el.appendChild(document.createTextNode(pattern));
            }
            syncPatternLineLayout();
            syncPatternExplainTip();
            return;
        }
        if (!st.segments.length) {
            el.style.display = 'none';
            syncPatternExplainTip();
            syncPatternLineLayout();
            return;
        }
        el.style.display = '';
        renderPatternFromSpans(el, '', st.segments, true);
        syncPatternLineLayout();
        bindExplainHover(el);
        syncPatternExplainTip();
    }

    function syncPatternPreviewHeight(el) {
        if (!el) return;
        var minH = 34;
        var max = Math.max(minH, Math.floor(window.innerHeight * 0.5));
        el.style.minHeight = minH + 'px';
        el.style.maxHeight = max + 'px';
    }

    function syncPatternView() {
        if (!st) return;
        var expert = st.expertDirty;
        if (st.patternLineWrapEl) {
            st.patternLineWrapEl.classList.toggle('synocr-regex-pattern-line--expert', expert);
        }
        if (st.expertEl) {
            st.expertEl.tabIndex = expert ? 0 : -1;
            st.expertEl.setAttribute('aria-hidden', expert ? 'false' : 'true');
        }
        if (st.patternPreviewEl) {
            st.patternPreviewEl.setAttribute('aria-hidden', expert ? 'true' : 'false');
        }
        if (st.patternPreviewEl) renderPatternPreview();
        if (st.modeToggleBtn) {
            st.modeToggleBtn.textContent = expert ? L('regex_btn_visual_mode', 'Visuelle Ansicht') : L('regex_btn_expert_mode', 'Experten-RegEx bearbeiten');
        }
        syncPatternExplainTip();
        syncSegCollapse();
    }

    function setExpertMode(on, opts) {
        opts = opts || {};
        if (!st) return;
        if (on) {
            var pattern = assembleSegments(st.segments, st.mode);
            if (!pattern && st.expertEl && st.expertEl.value) pattern = st.expertEl.value;
            st.expertDirty = true;
            st.expertExplainItems = null;
            st.expertExplainPattern = '';
            st.expertPattern = pattern;
            if (st.expertEl) st.expertEl.value = pattern;
            syncPatternExplainTip();
            scheduleExpertExplain();
        } else {
            st.expertExplainItems = null;
            st.expertExplainPattern = '';
            var pattern = st.expertEl ? st.expertEl.value : st.expertPattern;
            if (patternNeedsExpertMode(pattern)) {
                if (!opts.silent) setStatus(L('regex_explain_expert_only'));
                return false;
            }
            var parsed = parsePatternToSegments(pattern, st.mode);
            if (!parsed.ok) {
                if (!opts.silent) setStatus(L('regex_parse_failed', 'Muster konnte nicht in Segmente umgewandelt werden.'));
                return false;
            }
            st.segments = parsed.segments;
            st.expertDirty = false;
            st.expertPattern = '';
            renderSegments();
        }
        syncPatternView();
        syncExpert();
        schedulePreview();
        return true;
    }

    function spanSpaces(s) { return s.replace(/ /g, '<span class="synocr-sp"> </span>'); }

    // grep -ob reports byte offsets; JS strings use character indices (UTF-8 multibyte safe).
    function charIndexFromByteOffset(raw, byteOff) {
        if (!raw || byteOff <= 0) return 0;
        var enc = typeof TextEncoder !== 'undefined' ? new TextEncoder() : null;
        if (!enc) return byteOff;
        var lo = 0, hi = raw.length;
        while (lo < hi) {
            var mid = (lo + hi) >> 1;
            if (enc.encode(raw.slice(0, mid)).length < byteOff) lo = mid + 1;
            else hi = mid;
        }
        return lo;
    }

    function renderText(matches, offsets) {
        var raw = st.text || '';
        var out = '', pos = 0;
        if (matches && matches.length) {
            for (var k = 0; k < matches.length; k++) {
                var m = matches[k];
                if (m === '') continue;
                var idx = raw.indexOf(m, pos);
                if (offsets && offsets[k] != null && offsets[k] >= 0) {
                    var byteOff = offsets[k];
                    var charFromByte = charIndexFromByteOffset(raw, byteOff);
                    if (raw.slice(charFromByte, charFromByte + m.length) === m) {
                        idx = charFromByte;
                    } else if (raw.slice(byteOff, byteOff + m.length) === m) {
                        idx = byteOff;
                    }
                }
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
            // fixed & context: their text feeds the pattern, so a marked selection is
            // required. variable & class are inserted directly per click; an optional
            // selection is kept only as orientation (it is not part of the pattern).
            var needSel = (type === 'fixed' || type === 'context');
            var txt = st.selText || '';
            if (needSel && !txt) return;
            var start = lastEnd();
            if (txt) {
                start = st.text.indexOf(txt, lastEnd());
                if (start < 0) start = st.text.indexOf(txt);
                if (start < 0) {
                    if (needSel) return;       // selection no longer present -> abort
                    start = lastEnd();         // variable/class: drop orientation, insert anyway
                    txt = '';
                }
            }
            seg = { type: type, text: txt, start: start, end: start + txt.length,
                    wsFlex: false, anchor: false, optional: false,
                    varKind: 'any', classKind: 'digits', classQuant: 'plus', n: '', m: '',
                    lookKind: 'after' };
            st.selText = '';
            if (window.getSelection) { try { window.getSelection().removeAllRanges(); } catch (e) {} }
        }
        st.segments.push(seg);
        st.expertDirty = false;
        st.segExpanded = true;
        renderSegments();
        syncExpert();
        syncPatternView();
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

    // ---- segment drag & drop reorder --------------------------------------
    function cleanupSegDrag() {
        if (st.dragChip) {
            st.dragChip.classList.remove('synocr-regex-seg-dragging');
            st.dragChip = null;
        }
        if (st.dropPlaceholder && st.dropPlaceholder.parentNode) {
            st.dropPlaceholder.parentNode.removeChild(st.dropPlaceholder);
        }
        st.dropPlaceholder = null;
        st.dragIndex = null;
        st.dragHeight = null;
    }

    function getSegInsertIndex(bar, clientY) {
        var chips = bar.querySelectorAll('.synocr-regex-seg:not(.synocr-regex-seg-dragging)');
        for (var c = 0; c < chips.length; c++) {
            var rect = chips[c].getBoundingClientRect();
            if (clientY < rect.top + rect.height / 2) {
                return parseInt(chips[c].dataset.segIndex, 10);
            }
        }
        return st.segments.length;
    }

    function isNoOpSegMove(from, insertAt) {
        return insertAt === from || insertAt === from + 1;
    }

    function moveSegPlaceholder(bar, insertAt) {
        var ph = st.dropPlaceholder;
        if (!ph || !bar) return;
        var from = st.dragIndex;
        if (from == null || isNoOpSegMove(from, insertAt)) {
            if (ph.parentNode) ph.parentNode.removeChild(ph);
            return;
        }
        var chips = bar.querySelectorAll('.synocr-regex-seg');
        var target = null;
        for (var c = 0; c < chips.length; c++) {
            if (parseInt(chips[c].dataset.segIndex, 10) === insertAt) {
                target = chips[c];
                break;
            }
        }
        if (target && !target.classList.contains('synocr-regex-seg-dragging')) {
            bar.insertBefore(ph, target);
        } else {
            bar.appendChild(ph);
        }
    }

    function applySegReorder(from, insertAt) {
        if (from == null || isNoOpSegMove(from, insertAt)) return;
        var item = st.segments.splice(from, 1)[0];
        if (insertAt > from) insertAt--;
        st.segments.splice(insertAt, 0, item);
        st.expertDirty = false;
    }

    function onSegBarDragOver(e) {
        if (st.dragIndex == null) return;
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        moveSegPlaceholder(e.currentTarget, getSegInsertIndex(e.currentTarget, e.clientY));
    }

    function onSegBarDrop(e) {
        e.preventDefault();
        if (st.dragIndex == null) return;
        var from = st.dragIndex;
        var insertAt = getSegInsertIndex(e.currentTarget, e.clientY);
        cleanupSegDrag();
        applySegReorder(from, insertAt);
        renderSegments();
        syncExpert();
        syncPatternView();
        schedulePreview();
    }

    function renderSegments() {
        var bar = st.segBarEl;
        bar.innerHTML = '';
        if (!st.segments.length) {
            bar.appendChild(h('span', { class: 'small text-muted' }, L('regex_seg_empty', '—')));
            return;
        }
        st.segments.forEach(function (seg, idx) {
            var chip = h('div', { class: 'synocr-regex-seg', dataset: { segIndex: String(idx) } });
            var typeClass = { fixed: 'seg_fixed', variable: 'seg_var', class: 'seg_class', alt: 'seg_alt', anchor: 'seg_anchor', context: 'seg_context' }[seg.type];
            var label = L('regex_' + typeClass, seg.type);
            var helpKey = SEG_HELP_KEYS[seg.type];
            var badgeAttrs = { class: 'synocr-regex-seg-type ' + typeClass, text: label };
            if (helpKey) {
                badgeAttrs.class += ' synocr-has-tip';
                badgeAttrs['data-tip-key'] = helpKey;
            }
            var dragHint = L('regex_seg_drag_hint', 'Baustein durch Ziehen verschieben');
            var handle = h('span', {
                class: 'synocr-regex-seg-drag-handle synocr-has-tip',
                'data-tip': dragHint,
                title: dragHint,
                draggable: 'true'
            }, '\u283F');
            handle.addEventListener('dragstart', function (e) {
                if (st.expertDirty) { e.preventDefault(); return; }
                st.dragIndex = idx;
                st.dragChip = chip;
                st.dragHeight = chip.getBoundingClientRect().height;
                chip.classList.add('synocr-regex-seg-dragging');
                var ph = document.createElement('div');
                ph.className = 'synocr-regex-seg-drop-placeholder';
                ph.style.height = st.dragHeight + 'px';
                ph.setAttribute('aria-hidden', 'true');
                st.dropPlaceholder = ph;
                e.dataTransfer.effectAllowed = 'move';
                try { e.dataTransfer.setData('text/plain', String(idx)); } catch (err) {}
            });
            handle.addEventListener('dragend', cleanupSegDrag);
            chip.appendChild(handle);
            chip.appendChild(h('span', badgeAttrs));

            var body = h('div', { class: 'synocr-regex-seg-body' });

            if (seg.type === 'fixed') {
                body.appendChild(makeOptCheckbox(seg, 'wsFlex', 'regex_seg_wsflex', 'regex_help_seg_wsflex'));
                if (st.mode === 'extract') {
                    body.appendChild(makeOptCheckbox(seg, 'anchor', 'regex_seg_anchor', 'regex_help_seg_extract_anchor'));
                }
            } else if (seg.type === 'alt') {
                if (st.mode === 'extract') {
                    body.appendChild(makeOptCheckbox(seg, 'anchor', 'regex_seg_anchor', 'regex_help_seg_extract_anchor'));
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
                body.appendChild(inputs);
            } else if (seg.type === 'anchor') {
                var aSel = h('select', { class: 'form-select form-select-sm synocr-regex-seg-select synocr-regex-seg-select-anchor' }, [
                    h('option', { value: 'word', text: L('regex_anchor_word') }),
                    h('option', { value: 'start', text: L('regex_anchor_start') }),
                    h('option', { value: 'end', text: L('regex_anchor_end') })
                ]);
                aSel.value = seg.anchorKind;
                aSel.addEventListener('change', function () { seg.anchorKind = aSel.value; st.expertDirty = false; syncExpert(); schedulePreview(); });
                body.appendChild(aSel);
            } else if (seg.type === 'context') {
                var cSel = h('select', { class: 'form-select form-select-sm synocr-regex-seg-select synocr-regex-seg-select-context' }, [
                    h('option', { value: 'before', text: L('regex_context_before') }),
                    h('option', { value: 'after', text: L('regex_context_after') }),
                    h('option', { value: 'notBefore', text: L('regex_context_not_before') }),
                    h('option', { value: 'notAfter', text: L('regex_context_not_after') })
                ]);
                cSel.value = seg.lookKind || 'after';
                cSel.addEventListener('change', function () { seg.lookKind = cSel.value; st.expertDirty = false; syncExpert(); schedulePreview(); });
                body.appendChild(cSel);
            } else if (seg.type === 'variable') {
                var sel = h('select', { class: 'form-select form-select-sm synocr-regex-seg-select synocr-regex-seg-select-var' }, [
                    h('option', { value: 'any', text: L('regex_var_any') }),
                    h('option', { value: 'greedy', text: L('regex_var_until_anchor') }),
                    h('option', { value: 'ws', text: L('regex_var_whitespace') })
                ]);
                sel.value = seg.varKind;
                sel.addEventListener('change', function () { seg.varKind = sel.value; st.expertDirty = false; syncExpert(); schedulePreview(); });
                body.appendChild(sel);
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
                body.appendChild(kind); body.appendChild(quant); body.appendChild(nInp); body.appendChild(mInp);
            }

            // optional flag — available for every consuming type (not for anchor/context)
            if (seg.type !== 'anchor' && seg.type !== 'context') {
                body.appendChild(makeOptCheckbox(seg, 'optional', 'regex_seg_optional', 'regex_help_seg_optional'));
            }

            // text field — editable for fixed/context (their text feeds the pattern);
            // read-only preview for variable/class (text is only the marked sample)
            if (seg.type === 'fixed' || seg.type === 'context') {
                var txtInp = h('input', {
                    type: 'text',
                    class: 'form-control form-control-sm synocr-regex-seg-text-inp font-monospace',
                    value: seg.text,
                    placeholder: L('regex_seg_text_placeholder', 'Text'),
                    draggable: 'false'
                });
                txtInp.addEventListener('input', function () {
                    seg.text = txtInp.value;
                    st.expertDirty = false;
                    syncExpert();
                    schedulePreview();
                });
                body.appendChild(txtInp);
            } else if ((seg.type === 'variable' || seg.type === 'class') && seg.text) {
                body.appendChild(h('span', { class: 'synocr-regex-seg-text font-monospace', title: seg.text, text: '\u201e' + seg.text + '\u201c' }));
            }

            chip.appendChild(body);
            var rm = h('button', { type: 'button', class: 'btn btn-sm synocr-regex-seg-rm', title: L('regex_btn_remove_seg', '×'), onclick: function () {
                st.segments.splice(idx, 1); st.expertDirty = false; renderSegments(); syncExpert(); schedulePreview();
            } }, '×');
            chip.appendChild(rm);
            bar.appendChild(chip);
        });
        syncSegCollapse();
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
            if (seg.classQuant === 'fixed') quantLabel = L('regex_explain_class_fixed').replace('%n', String(seg.n || '1'));
            else if (seg.classQuant === 'range') quantLabel = L('regex_explain_class_range').replace('%n', String(seg.n || '0')).replace('%m', String(seg.m || ''));
            else if (seg.classQuant === 'star') quantLabel = L('regex_explain_class_star');
            else if (seg.classQuant === 'plus') quantLabel = L('regex_explain_class_plus');
            else quantLabel = '';
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

    function explainQuantSuffix(item) {
        var q = item.repeat || item.classQuant;
        var s = '';
        if (q === 'fixed') s = L('regex_explain_class_fixed').replace('%n', String(item.n || '1'));
        else if (q === 'range') s = L('regex_explain_class_range').replace('%n', String(item.n || '0')).replace('%m', String(item.m || ''));
        else if (q === 'star') s = L('regex_explain_class_star');
        else if (q === 'plus') s = L('regex_explain_class_plus');
        if (item.optional) s += ' ' + L('regex_explain_optional_suffix');
        return s;
    }

    function explainFlagLetters(flags) {
        var parts = [];
        var s = String(flags || '');
        var negate = false;
        var flagKeys = {
            i: 'regex_explain_flags_case',
            m: 'regex_explain_flags_multiline',
            s: 'regex_explain_flags_dotall',
            x: 'regex_explain_flags_extended'
        };
        for (var i = 0; i < s.length; i++) {
            if (s[i] === '-') { negate = true; continue; }
            var key = flagKeys[s[i]];
            var label = key ? L(key) : L('regex_explain_unknown').replace('%t', s[i]);
            if (negate) label = L('regex_explain_flags_off', 'deaktiviert: %t').replace('%t', label);
            parts.push(label);
            negate = false;
        }
        return parts.join(', ');
    }

    function classGenericSummary(item) {
        if (!item || item.kind !== 'class_generic' || item.negated || !item.parts) return null;
        var p = item.parts;
        if (p.length !== 3) return null;
        if (p[0].kind === 'shorthand' && p[0].escape === 'word' &&
            p[1].kind === 'char' && p[1].char === '.' &&
            p[2].kind === 'char' && p[2].char === '-') {
            return L('regex_explain_class_word_dot_dash');
        }
        return null;
    }

    function explainClassPart(p) {
        if (!p) return '';
        if (p.kind === 'range') {
            return L('regex_explain_cp_range').replace('%f', p.from || '').replace('%t', p.to || '');
        }
        if (p.kind === 'shorthand') {
            var m = {
                word: L('regex_explain_cp_word'),
                non_word: L('regex_explain_cp_non_word'),
                digit: L('regex_explain_cp_digit'),
                non_digit: L('regex_explain_cp_non_digit'),
                space: L('regex_explain_cp_space'),
                non_space: L('regex_explain_cp_non_space'),
                h_space: L('regex_explain_cp_h_space'),
                v_space: L('regex_explain_cp_v_space'),
                newline: L('regex_explain_escape_newline'),
                cr: L('regex_explain_escape_cr'),
                tab: L('regex_explain_escape_tab')
            };
            return m[p.escape] || L('regex_explain_unknown').replace('%t', p.escape || '');
        }
        if (p.kind === 'char') {
            return L('regex_explain_cp_char').replace('%c', p.char || '');
        }
        return '';
    }

    function explainExtractRoleSuffix(item) {
        if (!item || !item.extractRole) return '';
        if (item.extractRole === 'anchor') return ' ' + L('regex_explain_extract_anchor');
        if (item.extractRole === 'value') return ' ' + L('regex_explain_extract_value');
        return '';
    }

    function explainContextInner(item) {
        if (item.items && item.items.length) {
            return item.items.map(explainItemBody).join(' ');
        }
        return item.text || '';
    }

    function explainItem(item) {
        return explainItemBody(item) + explainExtractRoleSuffix(item);
    }

    function explainItemBody(item) {
        if (!item || !item.kind) return '';
        if (item.kind === 'keep') return L('regex_explain_keep');
        if (item.kind === 'char_optional') return L('regex_explain_char_optional');
        if (item.kind === 'char_any') return L('regex_explain_char_any');
        if (item.kind === 'char_plus') {
            var s = L('regex_explain_char_any') + L('regex_explain_class_plus');
            if (item.optional) s += ' ' + L('regex_explain_optional_suffix');
            return s;
        }
        if (item.kind === 'unknown') return L('regex_explain_unknown').replace('%t', item.raw || '');
        if (item.kind === 'flags') {
            var fl = explainFlagLetters(item.flags);
            if (item.scope === 'rest') fl += ' (' + L('regex_explain_flags_scope_rest') + ')';
            return fl;
        }
        if (item.kind === 'flags_group') {
            var innerFg = (item.items && item.items.length) ? item.items.map(explainItemBody).join(' ') : '';
            return L('regex_explain_flags_group').replace('%f', explainFlagLetters(item.flags)).replace('%t', innerFg);
        }
        if (item.kind === 'class_generic') {
            var cgSum = classGenericSummary(item);
            if (cgSum) return cgSum + explainQuantSuffix(item);
            var cgParts = (item.parts && item.parts.length) ? item.parts.map(explainClassPart).join(', ') : (item.raw || '');
            var cgBase = item.negated ? L('regex_explain_class_generic_negated') : L('regex_explain_class_generic');
            return cgBase.replace('%t', cgParts) + explainQuantSuffix(item);
        }
        if (item.kind === 'escape') {
            var escMap = {
                newline: L('regex_explain_escape_newline'),
                tab: L('regex_explain_escape_tab'),
                cr: L('regex_explain_escape_cr'),
                word: L('regex_explain_escape_word'),
                non_word: L('regex_explain_escape_non_word'),
                non_digit: L('regex_explain_escape_non_digit'),
                non_space: L('regex_explain_escape_non_space'),
                line_break: L('regex_explain_escape_line_break'),
                not_newline: L('regex_explain_escape_not_newline')
            };
            var escS = escMap[item.escapeKind] || L('regex_explain_unknown').replace('%t', item.escapeKind || '');
            if (item.classQuant || item.repeat || item.optional) escS += explainQuantSuffix(item);
            return escS;
        }
        if (item.kind === 'branch_reset') {
            var br = L('regex_explain_branch_reset');
            if (item.items && item.items.length) {
                br += ': ' + item.items.map(explainItemBody).join(' ');
            }
            return br + explainQuantSuffix(item);
        }
        if (item.kind === 'atomic') {
            var atomInner = (item.items && item.items.length) ? item.items.map(explainItemBody).join(' ') : '';
            return L('regex_explain_atomic').replace('%t', atomInner) + explainQuantSuffix(item);
        }
        if (item.kind === 'backref') {
            return L('regex_explain_backref').replace('%r', item.ref || '');
        }
        if (item.kind === 'context') {
            var lk = item.lookKind || 'after';
            var ctxTpl = ({
                before: L('regex_explain_context_before'),
                after: L('regex_explain_context_after'),
                notBefore: L('regex_explain_context_not_before'),
                notAfter: L('regex_explain_context_not_after')
            })[lk] || L('regex_explain_context_after');
            return ctxTpl.replace('%t', explainContextInner(item)) + explainQuantSuffix(item);
        }
        if (item.kind === 'alt') {
            if (item.branches && item.branches.length) {
                var parts = item.branches.map(function (branch) {
                    return branch.map(explainItemBody).join(' ');
                });
                return L('regex_explain_alt').replace('%t', parts.join(', ')) + explainQuantSuffix(item);
            }
        }
        if (item.kind === 'group') {
            if (item.captured && item.items) {
                var capInner = item.items.map(explainItemBody).join(' ');
                return L('regex_explain_group_captured').replace('%t', capInner) + explainQuantSuffix(item);
            }
            if (item.items && item.items.length) {
                return item.items.map(explainItemBody).join(' ') + explainQuantSuffix(item);
            }
        }
        if (item.kind === 'variable' && item.varKind === 'ws') {
            var wsS = L('regex_explain_var_ws');
            if (item.varQuant === 'star') wsS += L('regex_explain_class_star');
            else if (item.varQuant === 'plus') wsS += L('regex_explain_class_plus');
            else if (!item.optional) wsS += L('regex_explain_var_ws_single', ' (ein Leerzeichen)');
            if (item.optional) wsS += ' ' + L('regex_explain_optional_suffix');
            return wsS;
        }
        var seg = { type: item.kind, optional: !!item.optional };
        if (item.kind === 'fixed') {
            seg.text = item.text || '';
            seg.wsFlex = !!item.wsFlex;
        } else if (item.kind === 'variable') {
            seg.varKind = item.varKind || 'any';
        } else if (item.kind === 'class') {
            seg.classKind = item.classKind || 'digits';
            seg.classQuant = item.classQuant || 'plus';
            seg.n = item.n || '';
            seg.m = item.m || '';
        } else if (item.kind === 'alt') {
            seg.texts = item.texts || [];
        } else if (item.kind === 'anchor') {
            seg.anchorKind = item.anchorKind || 'word';
        } else if (item.kind === 'context') {
            seg.lookKind = item.lookKind || 'after';
            seg.text = explainContextInner(item);
        }
        return explainSeg(seg);
    }

    function syncExpert() {
        if (!st.expertEl) return;
        if (!st.expertDirty) st.expertEl.value = assemble();
        syncExpertTextareaHeight(st.expertEl);
        syncPatternView();
    }

    function syncExpertTextareaHeight(el) {
        syncPatternLineLayout();
    }

    // ---- server calls ------------------------------------------------------
    // Error contract: cb receives { ok:false, error:'network' } on connection
    // failure / HTTP non-2xx / timeout, or { ok:false, error:'response' } when
    // the body is not valid JSON. The 'done' guard prevents double callbacks
    // (onreadystatechange + onerror can both fire on network errors).
    function post(body, cb) {
        var xhr = new XMLHttpRequest();
        var done = false;
        function fail(type) { if (done) return; done = true; cb({ ok: false, error: type }); }
        try {
            xhr.open('POST', ENDPOINT, true);
            xhr.setRequestHeader('Content-Type', 'application/json');
            xhr.timeout = 20000;
            xhr.ontimeout = function () { fail('network'); };
            xhr.onerror = function () { fail('network'); };
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4 || done) return;
                if (xhr.status >= 200 && xhr.status < 300) {
                    var parsed;
                    try { parsed = JSON.parse(xhr.responseText); }
                    catch (e) { return fail('response'); }
                    done = true;
                    cb(parsed);
                } else {
                    fail('network');
                }
            };
            xhr.send(JSON.stringify(body));
        } catch (e) {
            fail('network');
        }
    }

    function statusFromError(r) {
        if (r && r.error === 'network') return L('regex_network_error');
        return (r && r.error) || 'error';
    }

    function doLoad() {
        if (!st.path) return;
        setStatus(L('regex_sample_loading'));
        post({ op: 'load', path: st.path, searchAll: st.searchAll, clean_up_spaces: st.clean, source: st.source }, function (r) {
            if (!r || !r.ok) { setStatus(statusFromError(r)); return; }
            saveLastPdf(st.path);
            syncLastDocBtn();
            st.token = r.token;
            st.text = r.text || '';
            renderText(null);
            st.viewerWrapEl.style.display = '';
            st.bodyEl.style.display = '';
            st.segExpanded = false;
            syncSegCollapse();
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

    var explainTimer = null;
    function scheduleExpertExplain() {
        if (!st || !st.expertDirty) return;
        if (explainTimer) clearTimeout(explainTimer);
        explainTimer = setTimeout(runExpertExplain, 300);
    }

    function runExpertExplain() {
        if (!st || !st.expertDirty) return;
        var pattern = st.expertPattern || (st.expertEl ? st.expertEl.value : '');
        if (!pattern) {
            st.expertExplainItems = null;
            st.expertExplainPattern = '';
            st.expertExplainWarnings = null;
            renderPatternPreview();
            return;
        }
        post({ op: 'explain', pattern: pattern, multiline: st.multiline, casesensitive: st.casesensitive }, function (r) {
            if (!st || !st.expertDirty) return;
            if (!r || !r.ok) {
                st.expertExplainItems = null;
                st.expertExplainPattern = '';
                st.expertExplainWarnings = null;
                renderPatternPreview();
                return;
            }
            st.expertExplainItems = r.items || [];
            st.expertExplainPattern = pattern;
            st.expertExplainWarnings = r.warnings || null;
            renderPatternPreview();
        });
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
                setStatus(r.error === 'syntax' ? L('regex_preview_error') : statusFromError(r));
                renderText(null);
                return;
            }
            renderText(r.matches || [], r.offsets || null);
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

        var segBar = h('div', { class: 'synocr-regex-segbar' });
        // Improvement potential (mobile/touch): HTML5 drag & drop has no
        // reliable touch support, so reordering segments via the ⠿ handle does
        // not work on tablets/phones. A future enhancement could add ↑/↓
        // buttons per segment chip as a pointer/touch fallback (call
        // applySegReorder()).
        segBar.addEventListener('dragover', onSegBarDragOver);
        segBar.addEventListener('drop', onSegBarDrop);
        var segToggleBtn = h('button', {
            type: 'button',
            class: 'btn btn-link btn-sm synocr-regex-seg-toggle p-0 mb-1',
            'aria-expanded': 'false'
        }, L('regex_toggle_seg_show', 'Bausteine anzeigen'));
        var segCollapseEl = h('div', { class: 'synocr-regex-seg-collapse', style: 'display:none;' }, [segBar]);
        segToggleBtn.addEventListener('click', function () {
            if (!st) return;
            st.segExpanded = !st.segExpanded;
            syncSegCollapse();
        });

        var patternPreviewEl = h('div', {
            class: 'synocr-regex-pattern-preview font-monospace',
            tabindex: '-1',
            role: 'textbox',
            'aria-readonly': 'true'
        });
        var expertEl = h('textarea', {
            class: 'synocr-regex-expert font-monospace',
            rows: '1',
            spellcheck: 'false',
            tabindex: '-1',
            'aria-hidden': 'true'
        });
        expertEl.addEventListener('input', function () {
            st.expertDirty = true;
            st.expertPattern = expertEl.value;
            renderPatternPreview();
            schedulePreview();
            scheduleExpertExplain();
        });
        expertEl.addEventListener('scroll', syncPatternLineScroll);
        var patternLineWrapEl = h('div', {
            class: 'form-control form-control-sm font-monospace synocr-regex-pattern-line mb-2'
        }, [patternPreviewEl, expertEl]);
        var patternLabelEl = h('span', {
            class: 'form-label small fw-bold mb-0 synocr-has-tip synocr-regex-pattern-label'
        }, L('regex_expert_pattern'));
        var modeToggleBtn = h('button', {
            type: 'button',
            class: 'btn btn-link btn-sm synocr-regex-mode-toggle p-0'
        }, L('regex_btn_expert_mode', 'Experten-RegEx bearbeiten'));
        modeToggleBtn.addEventListener('click', function () {
            if (!st) return;
            if (st.expertDirty) setExpertMode(false);
            else setExpertMode(true);
        });

        var countEl = h('span', { class: 'small fw-bold synocr-regex-count flex-shrink-0' });
        var matchPreviewEl = h('span', { class: 'synocr-regex-match-preview font-monospace', style: 'display:none;' });
        var statusEl = h('span', { class: 'small text-muted synocr-regex-footer-status text-truncate' });

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

        // flags (beside type toolbar)
        var mlId = 'synocr-regex-multiline';
        var csId = 'synocr-regex-casesensitive';
        var mlInp = h('input', { type: 'checkbox', class: 'form-check-input', role: 'switch', id: mlId });
        mlInp.addEventListener('change', function () { st.multiline = mlInp.checked ? 'true' : 'false'; schedulePreview(); scheduleExpertExplain(); });
        var csInp = h('input', { type: 'checkbox', class: 'form-check-input', role: 'switch', id: csId });
        csInp.addEventListener('change', function () { st.casesensitive = csInp.checked ? 'true' : 'false'; schedulePreview(); scheduleExpertExplain(); });
        var toolRow = h('div', { class: 'synocr-regex-toolbar-row d-flex flex-wrap align-items-center gap-1 mb-2' }, [
            h('div', { class: 'd-flex flex-wrap gap-1 synocr-regex-tools' }, [toolFixed, toolVar, toolClass, toolAlt, toolAnchor, toolContext]),
            h('div', { class: 'synocr-regex-flag-switches d-flex flex-wrap align-items-center gap-3 ms-auto' }, [
                h('div', { class: 'form-check form-switch mb-0' }, [mlInp, h('label', { class: 'form-check-label', 'for': mlId, text: L('regex_multiline', 'Multi-Line') })]),
                h('div', { class: 'form-check form-switch mb-0' }, [csInp, h('label', { class: 'form-check-label', 'for': csId, text: L('regex_casesensitive', 'Groß-/Kleinschreibung') })])
            ])
        ]);

        var applyBtn = h('button', { type: 'button', class: 'btn btn-primary btn-sm', style: 'background-color:#0086E5;' }, L('regex_btn_apply'));
        applyBtn.addEventListener('click', function () {
            var pattern = st.expertDirty ? st.expertPattern : assemble();
            var cb = st.onApply;
            hideModal();
            if (typeof cb === 'function') cb({ pattern: pattern, multiline: st.multiline === 'true', casesensitive: st.casesensitive === 'true' });
        });
        var cancelBtn = h('button', { type: 'button', class: 'btn btn-secondary btn-sm', 'data-bs-dismiss': 'modal' }, L('regex_btn_cancel'));

        var footerCenter = h('div', { class: 'synocr-regex-footer-center d-flex align-items-center gap-2 flex-grow-1' }, [
            countEl, matchPreviewEl, statusEl
        ]);
        var footerActions = h('div', { class: 'synocr-regex-footer-actions d-flex align-items-center gap-2 flex-shrink-0' }, [
            cancelBtn, applyBtn
        ]);
        var footerEl = h('div', { class: 'modal-footer bg-light synocr-regex-footer d-flex flex-wrap align-items-center gap-2' }, [
            footerCenter, footerActions
        ]);

        var bodyEl = h('div', { class: 'synocr-regex-body', style: 'display:none;' }, [
            toolRow,
            h('div', { class: 'synocr-regex-seg-section mb-2' }, [segToggleBtn, segCollapseEl]),
            h('div', { class: 'd-flex justify-content-between align-items-center mb-1 gap-2 flex-wrap' }, [
                patternLabelEl,
                modeToggleBtn
            ]),
            patternLineWrapEl,
            viewerWrap
        ]);

        var modalEl = h('div', { id: MODAL_ID, class: 'modal fade', tabindex: '-1', 'aria-hidden': 'true' }, [
            h('div', { class: 'modal-dialog modal-dialog-centered synocr-regex-assistant-modal' }, [
                h('div', { class: 'modal-content' }, [
                    h('div', { class: 'modal-header bg-light' }, [
                        h('h5', { class: 'modal-title' }, L('regex_assistant_title') + ' [BETA]'),
                        h('button', { type: 'button', class: 'btn-close', 'data-bs-dismiss': 'modal', 'aria-label': 'Close' })
                    ]),
                    h('div', { class: 'modal-body' }, [
                        loadSection,
                        bodyEl
                    ]),
                    footerEl
                ])
            ])
        ]);
        document.body.appendChild(modalEl);

        // stash refs
        var M = {};
        M.el = modalEl; M.viewerEl = viewerEl; M.viewerWrapEl = viewerWrap; M.matchPreviewEl = matchPreviewEl; M.bodyEl = bodyEl;
        M.segBarEl = segBar; M.segToggleBtn = segToggleBtn; M.segCollapseEl = segCollapseEl;
        M.expertEl = expertEl; M.patternPreviewEl = patternPreviewEl; M.patternLineWrapEl = patternLineWrapEl;
        M.patternLabelEl = patternLabelEl;
        M.modeToggleBtn = modeToggleBtn; M.countEl = countEl; M.statusEl = statusEl; M.footerEl = footerEl;
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
            segBarEl: M.segBarEl, segToggleBtn: M.segToggleBtn, segCollapseEl: M.segCollapseEl,
            expertEl: M.expertEl, patternPreviewEl: M.patternPreviewEl, patternLineWrapEl: M.patternLineWrapEl,
            patternLabelEl: M.patternLabelEl,
            modeToggleBtn: M.modeToggleBtn, countEl: M.countEl, statusEl: M.statusEl, footerEl: M.footerEl,
            pathLabelEl: M.pathLabelEl, lastDocBtn: M.lastDocBtn, pickBtn: M.pickBtn, loadBtn: M.loadBtn,
            mode: opts.mode === 'extract' ? 'extract' : 'match',
            extractType: opts.extractType === 'dir' ? 'dir' : 'tag',
            multiline: opts.multiline ? 'true' : 'false',
            casesensitive: opts.casesensitive ? 'true' : 'false',
            source: opts.source === 'filename' ? 'filename' : 'content',
            searchAll: 'first', clean: 'true',
            path: '', token: null, text: '', segments: [], selText: '',
            segExpanded: false,
            dragIndex: null, dragChip: null, dragHeight: null, dropPlaceholder: null,
            expertDirty: false, expertPattern: '', expertExplainItems: null, expertExplainPattern: '',
            expertExplainWarnings: null,
            onApply: opts.onApply || null
        };

        var initialPattern = opts.pattern != null ? String(opts.pattern) : '';
        if (initialPattern) {
            if (patternNeedsExpertMode(initialPattern)) {
                st.expertDirty = true;
                st.expertPattern = initialPattern;
            } else {
                var parsed = parsePatternToSegments(initialPattern, st.mode);
                if (parsed.ok) {
                    st.segments = parsed.segments;
                    st.expertDirty = false;
                } else {
                    st.expertDirty = true;
                    st.expertPattern = initialPattern;
                }
            }
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
        M.expertEl.value = st.expertDirty ? st.expertPattern : (initialPattern || assembleSegments(st.segments, st.mode));
        renderMatchPreview([], null);
        renderSegments();
        renderText(null);
        syncSegCollapse();
        syncExpert();
        if (st.expertDirty) scheduleExpertExplain();

        showModal(el);
        syncExpertTextareaHeight(M.expertEl);
        window.requestAnimationFrame(function () { syncExpertTextareaHeight(M.expertEl); });
    }

    window.synocrRegexAssistant = { open: open };
})();
