/**
 * synOCR — left navigation: collapse to icon-only mode (localStorage).
 */
(function () {
    'use strict';

    var STORAGE_KEY = 'synocr_nav_collapsed';

    function init() {
        var layout = document.querySelector('.synocr-layout');
        var btn = document.getElementById('synocr-nav-toggle');
        if (!layout || !btn) return;

        var labelCollapse = btn.getAttribute('data-label-collapse') || 'Collapse navigation';
        var labelExpand = btn.getAttribute('data-label-expand') || 'Expand navigation';

        function setCollapsed(collapsed) {
            layout.classList.toggle('synocr-layout--nav-collapsed', collapsed);
            btn.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
            btn.setAttribute('aria-label', collapsed ? labelExpand : labelCollapse);
            btn.setAttribute('title', collapsed ? labelExpand : labelCollapse);
        }

        var collapsed = false;
        try {
            collapsed = window.localStorage.getItem(STORAGE_KEY) === 'true';
        } catch (e) { /* ignore */ }

        setCollapsed(collapsed);

        btn.addEventListener('click', function () {
            collapsed = !collapsed;
            try {
                window.localStorage.setItem(STORAGE_KEY, collapsed ? 'true' : 'false');
            } catch (e) { /* ignore */ }
            setCollapsed(collapsed);
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();

/**
 * synOCR — auto-dismiss positive confirmation modals.
 *
 * Save/success receipts should not force a manual click. After `delayMs`,
 * this clicks the modal's primary footer button — which for a dismiss-only
 * modal closes it, and for a submit button navigates exactly as a manual
 * click would (preserving current behaviour, incl. profile state carried via
 * the shared /tmp/synOCR_var.txt). A thin countdown bar above the footer
 * shows remaining time (rAF-driven width). Errors/warnings are never
 * auto-dismissed; callers decide when to invoke.
 */
(function () {
    'use strict';
    var states = window.__synocrAdStates || (window.__synocrAdStates = {});

    function dismissModal(modalEl) {
        var btn = modalEl.querySelector('.modal-footer .btn-primary');
        if (btn) {
            // Prefer real navigation for <a href> (reliable after profile delete etc.)
            if (btn.tagName === 'A' && btn.getAttribute('href')) {
                window.location.assign(btn.href);
                return;
            }
            var form = btn.form || (btn.closest && btn.closest('form'));
            if (form && btn.tagName === 'BUTTON' && typeof form.requestSubmit === 'function') {
                try {
                    form.requestSubmit(btn);
                    return;
                } catch (e) { /* fall through to click */ }
            }
            btn.click();
            return;
        }
        if (window.jQuery && window.jQuery.fn.modal) {
            window.jQuery(modalEl).modal('hide');
            return;
        }
        if (window.bootstrap && window.bootstrap.Modal) {
            var inst = window.bootstrap.Modal.getInstance(modalEl) ||
                       window.bootstrap.Modal.getOrCreateInstance(modalEl);
            if (inst) inst.hide();
        }
    }

    function ensureTimerBar(modalEl) {
        var content = modalEl.querySelector('.modal-content');
        var footer = modalEl.querySelector('.modal-footer');
        var existing = modalEl.querySelector('.synocr-ad-timer');
        if (existing) {
            existing.parentNode.removeChild(existing);
        }
        var track = document.createElement('div');
        track.className = 'synocr-ad-timer';
        track.setAttribute('aria-hidden', 'true');
        var bar = document.createElement('div');
        bar.className = 'synocr-ad-timer__bar';
        track.appendChild(bar);
        if (footer && footer.parentNode) {
            footer.parentNode.insertBefore(track, footer);
        } else if (content) {
            content.appendChild(track);
        } else {
            return null;
        }
        if (content) {
            content.classList.add('synocr-ad-modal');
        }
        return bar;
    }

    function removeTimerBar(modalEl) {
        var track = modalEl.querySelector('.synocr-ad-timer');
        if (track && track.parentNode) {
            track.parentNode.removeChild(track);
        }
        var content = modalEl.querySelector('.modal-content');
        if (content) {
            content.classList.remove('synocr-ad-modal');
        }
    }

    window.synocrAutoDismissModal = function (modalEl, delayMs) {
        if (!modalEl) return;
        delayMs = parseInt(delayMs, 10) || 2000;
        var key = modalEl.id;
        if (!key) {
            key = 'synocr-ad-' + Math.random().toString(36).slice(2);
            modalEl.id = key;
        }

        var st = states[key];
        if (st) {
            if (st.rafId) {
                cancelAnimationFrame(st.rafId);
                st.rafId = null;
            }
        }

        st = states[key] = {
            totalMs: delayMs,
            startedAt: null,
            rafId: null,
            bar: null
        };

        function stopRaf() {
            if (st.rafId) {
                cancelAnimationFrame(st.rafId);
                st.rafId = null;
            }
            st.startedAt = null;
        }

        function setBarPct(pct) {
            if (!st.bar) return;
            st.bar.style.width = (Math.max(0, Math.min(100, pct)) ) + '%';
        }

        function resetAll() {
            stopRaf();
            removeTimerBar(modalEl);
            delete states[key];
        }

        function finish() {
            stopRaf();
            setBarPct(0);
            removeTimerBar(modalEl);
            dismissModal(modalEl);
        }

        function tick() {
            var elapsed = Date.now() - st.startedAt;
            var remaining = st.totalMs - elapsed;
            if (remaining <= 0) {
                st.rafId = null;
                finish();
                return;
            }
            setBarPct((remaining / st.totalMs) * 100);
            st.rafId = requestAnimationFrame(tick);
        }

        function arm() {
            stopRaf();
            st.bar = ensureTimerBar(modalEl);
            setBarPct(100);
            st.startedAt = Date.now();
            st.rafId = requestAnimationFrame(tick);
        }

        if (!modalEl.dataset.synocrAdBound) {
            modalEl.dataset.synocrAdBound = '1';
            modalEl.addEventListener('hidden.bs.modal', resetAll);
        }

        // Bootstrap 5 adds the `show` class asynchronously (in _showElement, after
        // the backdrop transition), so classList.contains('show') is unreliable at
        // call time. The Modal instance sets `_isShown` synchronously in show(),
        // so prefer that; fall back to the shown.bs.modal event otherwise.
        function isShownNow() {
            if (modalEl.classList.contains('show')) return true;
            try {
                var inst = window.bootstrap && window.bootstrap.Modal &&
                           window.bootstrap.Modal.getInstance(modalEl);
                return !!(inst && inst._isShown);
            } catch (e) {
                return false;
            }
        }
        if (isShownNow()) {
            arm();
        } else {
            modalEl.addEventListener('shown.bs.modal', arm, { once: true });
        }
    };
})();
