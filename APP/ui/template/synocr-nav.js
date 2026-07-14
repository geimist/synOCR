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
 * the shared /tmp/synOCR_var.txt). Errors/warnings are never auto-dismissed;
 * callers decide when to invoke.
 */
(function () {
    'use strict';
    var timers = window.__synocrAdTimers || (window.__synocrAdTimers = {});

    window.synocrAutoDismissModal = function (modalEl, delayMs) {
        if (!modalEl) return;
        delayMs = parseInt(delayMs, 10) || 2000;
        var key = modalEl.id;
        if (!key) {
            key = 'synocr-ad-' + Math.random().toString(36).slice(2);
            modalEl.id = key;
        }
        function clear() {
            if (timers[key]) { clearTimeout(timers[key]); timers[key] = null; }
        }
        function arm() {
            clear();
            timers[key] = setTimeout(function () {
                timers[key] = null;
                var btn = modalEl.querySelector('.modal-footer .btn-primary');
                if (btn) { btn.click(); return; }
                if (window.jQuery && window.jQuery.fn.modal) {
                    window.jQuery(modalEl).modal('hide');
                    return;
                }
                if (window.bootstrap && window.bootstrap.Modal) {
                    var inst = window.bootstrap.Modal.getInstance(modalEl) ||
                               window.bootstrap.Modal.getOrCreateInstance(modalEl);
                    if (inst) inst.hide();
                }
            }, delayMs);
        }
        if (!modalEl.dataset.synocrAdBound) {
            modalEl.dataset.synocrAdBound = '1';
            modalEl.addEventListener('hidden.bs.modal', clear);
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
            } catch (e) { return false; }
        }
        if (isShownNow()) {
            arm();
        } else {
            modalEl.addEventListener('shown.bs.modal', arm, { once: true });
        }
    };
})();
