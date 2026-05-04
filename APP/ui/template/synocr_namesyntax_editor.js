/**
 * synOCR — NameSyntax chip editor (contenteditable + hidden canonical §-string)
 */
(function () {
    'use strict';

    var TOKEN_MAP_ID = 'synocr-name-syntax-token-map';
    var HIDDEN_ID = 'NameSyntax-hidden';
    var VISUAL_ID = 'NameSyntax-visual';
    var PALETTE_ID = 'NameSyntax-palette';
    var CHIP_CLASS = 'synocr-namesyntax-chip';

    function buildMapFromPalette() {
        var m = {};
        var pal = document.getElementById(PALETTE_ID);
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
        var el = document.getElementById(TOKEN_MAP_ID);
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

    function getTokenMap() {
        var fromJson = tryParseJsonTokenMap();
        var fromPal = buildMapFromPalette();
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

    function syncHidden(visual, hidden) {
        var next = serializeVisual(visual);
        if (hidden.value === next) {
            return;
        }
        hidden.value = next;
        // GUI_edit "unsaved changes" wires input/change only on real inputs; programmatic value sets do not fire.
        // Bubble so the same listeners as other fields mark the edit page dirty.
        hidden.dispatchEvent(new Event('input', { bubbles: true }));
    }

    function insertChipAtCaret(visual, hidden, token, map) {
        var label = map[token] || token;
        var chip = makeChip(token, label);
        var sel = window.getSelection();
        if (!sel.rangeCount) {
            visual.appendChild(chip);
            syncHidden(visual, hidden);
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
        syncHidden(visual, hidden);
    }

    /** Range at mouse position inside the editor (Chrome/WebKit + Firefox). */
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

    /** Walk up from a node; return the chip element if the caret is inside a chip (not the visual root). */
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

    /**
     * Never insert into/inside a chip (that would break the flat §-model). Snap to gap before/after the chip.
     * dragChip: optional chip being moved (for edge cases when the range lands on the same node).
     */
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

    function insertChipAtRange(visual, hidden, token, map, range) {
        if (!range) {
            insertChipAtCaret(visual, hidden, token, map);
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
        syncHidden(visual, hidden);
    }

    /** Move an existing chip DOM node to a collapsed range (no duplicate). */
    function moveChipToRange(chip, visual, hidden, range) {
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
        syncHidden(visual, hidden);
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

    function init() {
        var map = getTokenMap();
        var sorted = sortedTokens(map);
        var hidden = document.getElementById(HIDDEN_ID);
        var visual = document.getElementById(VISUAL_ID);

        if (!hidden || !visual) {
            return;
        }

        var raw = hidden.value || '';
        visual.innerHTML = '';
        visual.appendChild(parseToFragment(raw, map, sorted));

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

        document.addEventListener('dragend', hideDropIndicator, true);

        var debounceTimer;
        function scheduleSync() {
            clearTimeout(debounceTimer);
            debounceTimer = setTimeout(function () {
                syncHidden(visual, hidden);
            }, 0);
        }

        visual.addEventListener('input', scheduleSync);
        visual.addEventListener('blur', function () {
            syncHidden(visual, hidden);
        });

        visual.addEventListener('paste', function (e) {
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
            syncHidden(visual, hidden);
        });

        var form = visual.closest('form');
        if (form) {
            form.addEventListener('submit', function () {
                syncHidden(visual, hidden);
            });
        }

        visual.addEventListener('keydown', function (e) {
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
                        syncHidden(visual, hidden);
                    }
                    return;
                }
                if (node === visual && offset > 0) {
                    var before = visual.childNodes[offset - 1];
                    if (before && before.classList && before.classList.contains(CHIP_CLASS)) {
                        e.preventDefault();
                        before.remove();
                        syncHidden(visual, hidden);
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
                        syncHidden(visual, hidden);
                    }
                    return;
                }
                if (node === visual && offset < visual.childNodes.length) {
                    var after = visual.childNodes[offset];
                    if (after && after.classList && after.classList.contains(CHIP_CLASS)) {
                        e.preventDefault();
                        after.remove();
                        syncHidden(visual, hidden);
                    }
                }
            }
        });

        visual.addEventListener('dragstart', function (e) {
            var chip = e.target.closest('.' + CHIP_CLASS);
            if (!chip || !visual.contains(chip)) {
                return;
            }
            internalDragChip = chip;
            e.dataTransfer.setData('text/plain', chip.getAttribute('data-token') || '');
            e.dataTransfer.effectAllowed = 'move';
        });

        visual.addEventListener('dragover', function (e) {
            if (!wrap || !dataTransferHasPlain(e.dataTransfer)) {
                return;
            }
            e.preventDefault();
            e.dataTransfer.dropEffect = internalDragChip ? 'move' : 'copy';
            positionDropIndicator(dropIndicator, wrap, visual, e.clientX, e.clientY, internalDragChip);
        });

        visual.addEventListener('drop', function (e) {
            e.preventDefault();
            hideDropIndicator();
            var token = (e.dataTransfer.getData('text/plain') || '').trim();
            var range = rangeFromClientInVisual(visual, e.clientX, e.clientY);
            range = normalizeDropRange(visual, range, e.clientX, internalDragChip || null);

            if (internalDragChip && visual.contains(internalDragChip) && token) {
                if (!range) {
                    visual.appendChild(internalDragChip);
                    syncHidden(visual, hidden);
                } else {
                    moveChipToRange(internalDragChip, visual, hidden, range);
                }
                internalDragChip = null;
                return;
            }

            if (token && map[token]) {
                insertChipAtRange(visual, hidden, token, map, range);
            }
            internalDragChip = null;
        });

        visual.addEventListener('dragend', function () {
            internalDragChip = null;
            hideDropIndicator();
        });

        var pal = document.getElementById(PALETTE_ID);
        if (pal) {
            pal.addEventListener('dragstart', function (e) {
                var t = e.target.closest('[data-token]');
                if (!t || !pal.contains(t)) {
                    return;
                }
                internalDragChip = null;
                e.dataTransfer.setData('text/plain', t.getAttribute('data-token') || '');
                e.dataTransfer.effectAllowed = 'copy';
            });
            pal.addEventListener('click', function (e) {
                var t = e.target.closest('[data-token]');
                if (!t || !pal.contains(t)) {
                    return;
                }
                e.preventDefault();
                var tok = (t.getAttribute('data-token') || '').trim();
                if (tok && map[tok]) {
                    ensureCaretInVisual(visual);
                    insertChipAtCaret(visual, hidden, tok, map);
                }
            });
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
}());
