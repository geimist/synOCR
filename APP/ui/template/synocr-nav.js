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
