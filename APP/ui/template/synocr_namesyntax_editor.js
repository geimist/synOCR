/**
 * synOCR — chip editor (contenteditable + hidden canonical §-string)
 *
 * Public API:
 *   var ed = synocrChipEditor.create({
 *     visual:   <HTMLElement contenteditable>,  // required
 *     hidden:   <HTMLInputElement>,             // required (holds canonical §-string)
 *     palette:  <HTMLElement|null>,             // draggable chip source with [data-token]
 *     tokenMap: { '§docr': 'Tag', ... },        // token -> label (drives chip rendering)
 *     onChange: function(canonicalString){}     // optional, fires on every value change
 *   });
 *   ed.setValue('§yocr4/§dirname_RegEx/');      // re-parse a §-string into chips
 *   ed.getValue();                               // serialize current visual to §-string
 *   ed.insertText('/volume1/Ablage/');           // insert literal text at caret
 *   ed.destroy();                                // detach all listeners + drop indicator
 *
 * Legacy auto-init: if #NameSyntax-hidden / #NameSyntax-visual / #NameSyntax-palette
 * exist on DOMContentLoaded, an editor is instantiated automatically (used by GUI_edit.sh).
 */
(function () {
    'use strict';

    var CHIP_CLASS = 'synocr-namesyntax-chip';
    var LEGACY_TOKEN_MAP_ID = 'synocr-name-syntax-token-map';
    var LEGACY_HIDDEN_ID = 'NameSyntax-hidden';
    var LEGACY_VISUAL_ID = 'NameSyntax-visual';
    var LEGACY_PALETTE_ID = 'NameSyntax-palette';

    // ---- pure helpers ------------------------------------------------------

    function sortedTokens(map) {
        return Object.keys(map).sort(function (a, b) {
            return b.length - a.length;
        });
    }

    function makeChip(token, label) {
        var span = document.createElement('span');
        span.className = CHIP_CLASS + ' badge bg-primary';
        span.setAttribute('contenteditable', 'false');
        span.setAttribute('data-token', token);
        span.setAttribute('aria-label', token + ' — ' + label);
        span.setAttribute('draggable', 'true');
        span.appendChild(document.createTextNode(label));
        return span;
    }

    function parseToFragment(s, map, sorted) {
        var frag = document.createDocumentFragment();
        var i = 0;
        var SEC = '\u00A7';

        while (i < s.length) {
            if (s.charAt(i) !== SEC) {
                var litStart = i;
                while (i < s.length && s.charAt(i) !== SEC) {
                    i++;
                }
                frag.appendChild(document.createTextNode(s.slice(litStart, i)));
                continue;
            }

            var matched = false;
            var k;
            for (k = 0; k < sorted.length; k++) {
                var t = sorted[k];
                if (s.slice(i, i + t.length) === t && map[t]) {
                    frag.appendChild(makeChip(t, map[t]));
                    i += t.length;
                    matched = true;
                    break;
                }
            }
            if (!matched) {
                var unkStart = i;
                i++;
                while (i < s.length && s.charAt(i) !== SEC) {
                    i++;
                }
                frag.appendChild(document.createTextNode(s.slice(unkStart, i)));
            }
        }
        return frag;
    }

    function serializeVisual(el) {
        var out = '';
        function walk(node) {
            if (node.nodeType === Node.TEXT_NODE) {
                out += node.textContent;
                return;
            }
            if (node.nodeType === Node.ELEMENT_NODE) {
                if (node.classList && node.classList.contains(CHIP_CLASS)) {
                    out += node.getAttribute('data-token') || '';
                    return;
                }
                var c;
                for (c = node.firstChild; c; c = c.nextSibling) {
                    walk(c);
                }
            }
        }
        var ch;
        for (ch = el.firstChild; ch; ch = ch.nextSibling) {
            walk(ch);
        }
        return out;
    }

    function rangeFromClientInVisual(visual, clientX, clientY) {
        var r = null;
        if (document.caretRangeFromPoint) {
            r = document.caretRangeFromPoint(clientX, clientY);
        } else if (document.caretPositionFromPoint) {
            var pos = document.caretPositionFromPoint(clientX, clientY);
            if (pos && pos.offsetNode) {
                r = document.createRange();
                r.setStart(pos.offsetNode, pos.offset);
                r.collapse(true);
            }
        }
        if (!r || !visual.contains(r.commonAncestorContainer)) {
            return null;
        }
        return r;
    }

    function findContainingChip(fromNode, visual) {
        var n = fromNode;
        if (n && n.nodeType === Node.TEXT_NODE) {
            n = n.parentElement;
        }
        while (n && n !== visual) {
            if (n.nodeType === Node.ELEMENT_NODE && n.classList && n.classList.contains(CHIP_CLASS)) {
                return n;
            }
            n = n.parentElement;
        }
        return null;
    }

    function normalizeDropRange(visual, range, clientX, dragChip) {
        if (!range) {
            return null;
        }
        var host = findContainingChip(range.startContainer, visual);
        if (!host) {
            return range;
        }
        var rect = host.getBoundingClientRect();
        var mid = rect.left + rect.width * 0.5;
        var r2 = document.createRange();
        if (clientX < mid) {
            r2.setStartBefore(host);
        } else {
            r2.setStartAfter(host);
        }
        r2.collapse(true);
        return r2;
    }

    function positionDropIndicator(indicator, wrap, visual, clientX, clientY, dragChip) {
        var r = rangeFromClientInVisual(visual, clientX, clientY);
        r = normalizeDropRange(visual, r, clientX, dragChip);
        if (!r) {
            indicator.style.display = 'none';
            return;
        }
        var rect = r.getBoundingClientRect();
        var wr = wrap.getBoundingClientRect();
        var lineHeight = parseFloat(window.getComputedStyle(visual).lineHeight) || 20;
        var h = Math.max(rect.height > 0 ? rect.height : lineHeight, lineHeight * 0.85);
        var left = rect.left - wr.left;
        var top = rect.top - wr.top;
        indicator.style.left = left + 'px';
        indicator.style.top = top + 'px';
        indicator.style.height = h + 'px';
        indicator.style.display = 'block';
    }

    function ensureCaretInVisual(visual) {
        visual.focus();
        if (window.getSelection().rangeCount === 0) {
            var r = document.createRange();
            r.selectNodeContents(visual);
            r.collapse(false);
            var sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(r);
        }
    }

    function dataTransferHasPlain(dt) {
        if (!dt || !dt.types) {
            return false;
        }
        var i;
        for (i = 0; i < dt.types.length; i++) {
            if (dt.types[i] === 'text/plain') {
                return true;
            }
        }
        return false;
    }

    // ---- legacy token-map resolution (GUI_edit.sh) -------------------------

    function buildMapFromPalette(pal) {
        var m = {};
        if (!pal) {
            return m;
        }
        var items = pal.querySelectorAll('[data-token]');
        var i;
        for (i = 0; i < items.length; i++) {
            var el = items[i];
            var tok = el.getAttribute('data-token');
            if (tok) {
                m[tok] = (el.textContent || '').trim();
            }
        }
        return m;
    }

    function tryParseJsonTokenMap() {
        var el = document.getElementById(LEGACY_TOKEN_MAP_ID);
        if (!el) {
            return {};
        }
        try {
            var raw = el.textContent.trim();
            if (!raw) {
                return {};
            }
            if (el.getAttribute('data-encoding') === 'base64') {
                raw = atob(raw);
            }
            return JSON.parse(raw);
        } catch (e) {
            return {};
        }
    }

    function legacyTokenMap(pal) {
        var fromJson = tryParseJsonTokenMap();
        var fromPal = buildMapFromPalette(pal);
        var merged = {};
        var k;
        for (k in fromJson) {
            if (Object.prototype.hasOwnProperty.call(fromJson, k)) {
                merged[k] = fromJson[k];
            }
        }
        for (k in fromPal) {
            if (Object.prototype.hasOwnProperty.call(fromPal, k)) {
                merged[k] = fromPal[k];
            }
        }
        return merged;
    }

    // ---- factory -----------------------------------------------------------

    function create(opts) {
        opts = opts || {};
        var visual = opts.visual;
        var hidden = opts.hidden;
        var palette = opts.palette || null;
        var tokenMap = opts.tokenMap || {};
        var onChange = opts.onChange || null;

        if (!visual || !hidden) {
            return null;
        }

        var map = tokenMap;
        var sorted = sortedTokens(map);
        var listeners = [];

        function on(target, type, fn, useCapture) {
            target.addEventListener(type, fn, useCapture || false);
            listeners.push({ target: target, type: type, fn: fn, useCapture: useCapture || false });
        }

        var wrap = visual.parentElement;
        var dropIndicator = document.createElement('div');
        dropIndicator.className = 'synocr-namesyntax-drop-indicator';
        dropIndicator.setAttribute('aria-hidden', 'true');
        if (wrap) {
            wrap.appendChild(dropIndicator);
        }
        var internalDragChip = null;

        function hideDropIndicator() {
            dropIndicator.style.display = 'none';
        }

        function syncHidden() {
            var next = serializeVisual(visual);
            if (hidden.value === next) {
                return;
            }
            hidden.value = next;
            // GUI_edit "unsaved changes" wires input/change only on real inputs;
            // programmatic value sets do not fire. Bubble so the same listeners
            // as other fields mark the edit page dirty.
            hidden.dispatchEvent(new Event('input', { bubbles: true }));
            if (onChange) {
                onChange(next);
            }
        }

        function insertChipAtCaret(token) {
            var label = map[token] || token;
            var chip = makeChip(token, label);
            var sel = window.getSelection();
            if (!sel.rangeCount) {
                visual.appendChild(chip);
                syncHidden();
                return;
            }
            var range = sel.getRangeAt(0);
            if (!visual.contains(range.commonAncestorContainer)) {
                range.selectNodeContents(visual);
                range.collapse(false);
            }
            range.deleteContents();
            range.insertNode(chip);
            range.setStartAfter(chip);
            range.collapse(true);
            sel.removeAllRanges();
            sel.addRange(range);
            syncHidden();
        }

        function insertChipAtRange(token, range) {
            if (!range) {
                insertChipAtCaret(token);
                return;
            }
            var label = map[token] || token;
            var chip = makeChip(token, label);
            range.deleteContents();
            range.insertNode(chip);
            range.setStartAfter(chip);
            range.collapse(true);
            var sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
            visual.focus();
            syncHidden();
        }

        function moveChipToRange(chip, range) {
            if (!chip || !range || !visual.contains(range.commonAncestorContainer)) {
                return;
            }
            range.deleteContents();
            range.insertNode(chip);
            range.setStartAfter(chip);
            range.collapse(true);
            var sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
            visual.focus();
            syncHidden();
        }

        // initial render from the hidden input's current value
        visual.innerHTML = '';
        visual.appendChild(parseToFragment(hidden.value || '', map, sorted));

        var debounceTimer;
        function scheduleSync() {
            clearTimeout(debounceTimer);
            debounceTimer = setTimeout(syncHidden, 0);
        }

        on(visual, 'input', scheduleSync);
        on(visual, 'blur', syncHidden);

        on(visual, 'paste', function (e) {
            e.preventDefault();
            var text = e.clipboardData.getData('text/plain');
            if (!text) {
                return;
            }
            var sel = window.getSelection();
            if (!sel.rangeCount) {
                return;
            }
            var range = sel.getRangeAt(0);
            if (!visual.contains(range.commonAncestorContainer)) {
                return;
            }
            range.deleteContents();
            range.insertNode(document.createTextNode(text));
            range.collapse(false);
            sel.removeAllRanges();
            sel.addRange(range);
            syncHidden();
        });

        var form = visual.closest('form');
        if (form) {
            on(form, 'submit', syncHidden);
        }

        on(visual, 'keydown', function (e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                return;
            }

            if (e.key !== 'Backspace' && e.key !== 'Delete') {
                return;
            }

            var sel = window.getSelection();
            if (!sel.rangeCount) {
                return;
            }
            var range = sel.getRangeAt(0);
            if (!range.collapsed) {
                return;
            }

            var node = range.startContainer;
            var offset = range.startOffset;

            if (e.key === 'Backspace') {
                if (node.nodeType === Node.TEXT_NODE && offset > 0) {
                    return;
                }
                if (node.nodeType === Node.TEXT_NODE && offset === 0) {
                    var prev = node.previousSibling;
                    if (prev && prev.classList && prev.classList.contains(CHIP_CLASS)) {
                        e.preventDefault();
                        prev.remove();
                        syncHidden();
                    }
                    return;
                }
                if (node === visual && offset > 0) {
                    var before = visual.childNodes[offset - 1];
                    if (before && before.classList && before.classList.contains(CHIP_CLASS)) {
                        e.preventDefault();
                        before.remove();
                        syncHidden();
                    }
                }
            }

            if (e.key === 'Delete') {
                if (node.nodeType === Node.TEXT_NODE && offset < node.textContent.length) {
                    return;
                }
                if (node.nodeType === Node.TEXT_NODE && offset === node.textContent.length) {
                    var next = node.nextSibling;
                    if (next && next.classList && next.classList.contains(CHIP_CLASS)) {
                        e.preventDefault();
                        next.remove();
                        syncHidden();
                    }
                    return;
                }
                if (node === visual && offset < visual.childNodes.length) {
                    var after = visual.childNodes[offset];
                    if (after && after.classList && after.classList.contains(CHIP_CLASS)) {
                        e.preventDefault();
                        after.remove();
                        syncHidden();
                    }
                }
            }
        });

        on(visual, 'dragstart', function (e) {
            var chip = e.target.closest('.' + CHIP_CLASS);
            if (!chip || !visual.contains(chip)) {
                return;
            }
            internalDragChip = chip;
            e.dataTransfer.setData('text/plain', chip.getAttribute('data-token') || '');
            e.dataTransfer.effectAllowed = 'move';
        });

        on(visual, 'dragover', function (e) {
            if (!wrap || !dataTransferHasPlain(e.dataTransfer)) {
                return;
            }
            e.preventDefault();
            e.dataTransfer.dropEffect = internalDragChip ? 'move' : 'copy';
            positionDropIndicator(dropIndicator, wrap, visual, e.clientX, e.clientY, internalDragChip);
        });

        on(visual, 'drop', function (e) {
            e.preventDefault();
            hideDropIndicator();
            var token = (e.dataTransfer.getData('text/plain') || '').trim();
            var range = rangeFromClientInVisual(visual, e.clientX, e.clientY);
            range = normalizeDropRange(visual, range, e.clientX, internalDragChip || null);

            if (internalDragChip && visual.contains(internalDragChip) && token) {
                if (!range) {
                    visual.appendChild(internalDragChip);
                    syncHidden();
                } else {
                    moveChipToRange(internalDragChip, range);
                }
                internalDragChip = null;
                return;
            }

            if (token && map[token]) {
                insertChipAtRange(token, range);
            }
            internalDragChip = null;
        });

        on(visual, 'dragend', function () {
            internalDragChip = null;
            hideDropIndicator();
        });

        on(document, 'dragend', hideDropIndicator, true);

        if (palette) {
            on(palette, 'dragstart', function (e) {
                var t = e.target.closest('[data-token]');
                if (!t || !palette.contains(t)) {
                    return;
                }
                internalDragChip = null;
                e.dataTransfer.setData('text/plain', t.getAttribute('data-token') || '');
                e.dataTransfer.effectAllowed = 'copy';
            });
            on(palette, 'click', function (e) {
                var t = e.target.closest('[data-token]');
                if (!t || !palette.contains(t)) {
                    return;
                }
                e.preventDefault();
                var tok = (t.getAttribute('data-token') || '').trim();
                if (tok && map[tok]) {
                    ensureCaretInVisual(visual);
                    insertChipAtCaret(tok);
                }
            });
        }

        function setValue(s) {
            visual.innerHTML = '';
            visual.appendChild(parseToFragment(s || '', map, sorted));
            hidden.value = s || '';
            if (onChange) {
                onChange(hidden.value);
            }
        }

        function getValue() {
            return serializeVisual(visual);
        }

        function insertText(text) {
            if (!text) {
                return;
            }
            var sel = window.getSelection();
            if (!sel.rangeCount) {
                visual.appendChild(document.createTextNode(text));
                syncHidden();
                return;
            }
            var range = sel.getRangeAt(0);
            if (!visual.contains(range.commonAncestorContainer)) {
                range.selectNodeContents(visual);
                range.collapse(false);
            }
            range.deleteContents();
            range.insertNode(document.createTextNode(text));
            range.collapse(false);
            sel.removeAllRanges();
            sel.addRange(range);
            syncHidden();
        }

        function destroy() {
            var i;
            for (i = 0; i < listeners.length; i++) {
                var l = listeners[i];
                l.target.removeEventListener(l.type, l.fn, l.useCapture);
            }
            listeners = [];
            if (dropIndicator.parentNode) {
                dropIndicator.parentNode.removeChild(dropIndicator);
            }
        }

        return {
            setValue: setValue,
            getValue: getValue,
            insertText: insertText,
            destroy: destroy
        };
    }

    // ---- legacy auto-init (GUI_edit.sh) ------------------------------------

    function legacyInit() {
        var hidden = document.getElementById(LEGACY_HIDDEN_ID);
        var visual = document.getElementById(LEGACY_VISUAL_ID);
        var palette = document.getElementById(LEGACY_PALETTE_ID);
        if (!hidden || !visual) {
            return;
        }
        create({
            visual: visual,
            hidden: hidden,
            palette: palette,
            tokenMap: legacyTokenMap(palette)
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', legacyInit);
    } else {
        legacyInit();
    }

    window.synocrChipEditor = { create: create };
}());
