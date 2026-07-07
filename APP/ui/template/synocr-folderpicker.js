/**
 * synOCR — shared folder/file picker (vanilla JS + jQuery)
 *
 * Open with:
 *   synocr_openPicker(inputId, mode, opts)
 *     mode: 'folder' | 'file'
 *     opts: { extensions:['yml','yaml'], title:'…', confirmLabel:'…',
 *             onSelect:function(fullPath){} }
 *
 * Folder mode: navigate folders, confirm button writes the current folder path.
 * File mode:   navigate folders, click a file (filtered by extensions) to write
 *              its path; create/confirm is hidden.
 *
 * Browses via SYNO.FileStation.List (list_share / list) with a SynoToken from
 * SYNO.API.Auth method=token. Paths are stored as real paths (/volumeX/…).
 */
(function () {
    'use strict';

    var MODAL_ID = 'synocrFolderPickerModal';
    var CONTENT_ID = 'synocrFolderPickerContent';
    var LABEL_ID = 'synocrFolderPickerModalLabel';
    var CONFIRM_ID = 'synocrFolderPickerConfirm';
    var LANG_ID = 'synocr-folderpicker-lang';

    var st = { input: null, mode: 'folder', extensions: null, currentPath: '', sharesMap: {}, sharesRealMap: {}, onSelect: null };
    var lang = {};

    function readLang() {
        var el = document.getElementById(LANG_ID);
        if (!el) return;
        try { var raw = el.textContent.trim(); if (raw) lang = JSON.parse(raw); } catch (e) { lang = {}; }
    }
    function L(k, fb) { return (lang[k] != null ? lang[k] : fb); }

    function resolveSynoToken(cb) {
        function tryApi(ver) {
            $.ajax({
                url: '/webapi/entry.cgi', type: 'GET', timeout: 10000,
                data: { api: 'SYNO.API.Auth', version: ver, method: 'token' },
                success: function (resp) {
                    if (resp && resp.success && resp.data && resp.data.synotoken) { cb(resp.data.synotoken); return; }
                    if (ver === 7) { tryApi(6); return; }
                    cb(urlFallback());
                },
                error: function () { if (ver === 7) { tryApi(6); return; } cb(urlFallback()); }
            });
        }
        function urlFallback() {
            try {
                var t = new URLSearchParams(window.location.search).get('SynoToken');
                if (t) return t;
                if (window.parent !== window) {
                    t = new URLSearchParams(window.parent.location.search).get('SynoToken');
                    if (t) return t;
                }
            } catch (e) {}
            return null;
        }
        tryApi(7);
    }

    function getRelativePath(fullPath) {
        var best = '';
        for (var rp in st.sharesRealMap) {
            if (fullPath.indexOf(rp) === 0 && rp.length > best.length) best = rp;
        }
        if (best) return st.sharesRealMap[best] + fullPath.substring(best.length);
        return fullPath;
    }

    function setCurrentPath(p) { st.currentPath = p; }

    function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

    function loadShares() {
        $('#' + CONTENT_ID).html('<div class="text-center"><img src="./images/status_loading.gif" alt="…"></div>');
        resolveSynoToken(function (token) {
            if (!token) { $('#' + CONTENT_ID).html('<div class="alert alert-warning">' + esc(L('no_token', 'SynoToken')) + '</div>'); return; }
            $.ajax({
                url: '/webapi/entry.cgi', type: 'GET', timeout: 10000,
                data: { api: 'SYNO.FileStation.List', version: 2, method: 'list_share', additional: '["name","path","isdir","perm","real_path"]', SynoToken: token },
                success: function (resp) {
                    if (resp && resp.success) {
                        st.sharesMap = {}; st.sharesRealMap = {};
                        var html = '<ul class="list-group synocr-folderpicker-list"><li class="list-group-item synocr-folderpicker-section">' + esc(L('shares', 'Shares')) + '</li>';
                        if (resp.data && resp.data.shares) {
                            resp.data.shares.forEach(function (share) {
                                st.sharesMap[share.name] = share.additional.real_path;
                                st.sharesRealMap[share.additional.real_path] = share.path;
                                html += '<li class="list-group-item list-group-item-action synocr-folderpicker-item" data-path="' + esc(share.additional.real_path) + '"><i class="bi bi-folder"></i> ' + esc(share.name) + '</li>';
                            });
                        }
                        html += '</ul>';
                        $('#' + CONTENT_ID).html(html);
                        wireItems();
                    } else {
                        $('#' + CONTENT_ID).html('<div class="alert alert-danger">' + esc(L('failed_shares', 'error')) + '</div>');
                    }
                },
                error: function () { $('#' + CONTENT_ID).html('<div class="alert alert-danger">' + esc(L('failed_shares', 'error')) + '</div>'); }
            });
        });
    }

    function loadFolders(fullPath) {
        var folderPath = getRelativePath(fullPath);
        if (folderPath === fullPath) { loadShares(); return; }
        $('#' + CONTENT_ID).html('<div class="text-center"><img src="./images/status_loading.gif" alt="…"></div>');
        resolveSynoToken(function (token) {
            if (!token) { $('#' + CONTENT_ID).html('<div class="alert alert-warning">' + esc(L('no_token', 'SynoToken')) + '</div>'); return; }
            $.ajax({
                url: '/webapi/entry.cgi', type: 'GET', timeout: 10000,
                data: { api: 'SYNO.FileStation.List', version: 2, method: 'list', folder_path: folderPath, additional: '["name","path","isdir","perm"]', sort_by: 'name', sort_direction: 'asc', limit: 200, SynoToken: token },
                success: function (resp) {
                    if (resp && resp.success) {
                        var html = '<ul class="list-group synocr-folderpicker-list">';
                        html += '<li class="list-group-item list-group-item-action synocr-folderpicker-nav" data-path="__shares__"><i class="bi bi-arrow-left"></i> ' + esc(L('back', 'back')) + '</li>';
                        if (folderPath !== '/') {
                            var parent = fullPath.substring(0, fullPath.lastIndexOf('/')) || '/';
                            html += '<li class="list-group-item list-group-item-action synocr-folderpicker-nav" data-path="' + esc(parent) + '"><i class="bi bi-arrow-up"></i> ..</li>';
                        }
                        if (resp.data && resp.data.files) {
                            resp.data.files.forEach(function (f) {
                                if (f.isdir) {
                                    var rel = f.path.substring(folderPath.length);
                                    var next = fullPath + rel;
                                    html += '<li class="list-group-item list-group-item-action synocr-folderpicker-item" data-path="' + esc(next) + '"><i class="bi bi-folder"></i> ' + esc(f.name) + '</li>';
                                } else if (st.mode === 'file') {
                                    var lower = (f.name || '').toLowerCase();
                                    var ok = !st.extensions || st.extensions.length === 0;
                                    if (!ok) { for (var i = 0; i < st.extensions.length; i++) { if (lower.indexOf('.' + st.extensions[i]) !== -1) { ok = true; break; } } }
                                    if (ok) {
                                        var frel = f.path.substring(folderPath.length);
                                        var fpath = fullPath + frel;
                                        html += '<li class="list-group-item list-group-item-action synocr-folderpicker-file" data-path="' + esc(fpath) + '"><i class="bi bi-file-earmark"></i> ' + esc(f.name) + '</li>';
                                    }
                                }
                            });
                        }
                        html += '</ul>';
                        $('#' + CONTENT_ID).html(html);
                        wireItems();
                    } else {
                        $('#' + CONTENT_ID).html('<div class="alert alert-danger">' + esc(L('failed_folders', 'error')) + '</div>');
                    }
                },
                error: function () { $('#' + CONTENT_ID).html('<div class="alert alert-danger">' + esc(L('failed_folders', 'error')) + '</div>'); }
            });
        });
    }

    function wireItems() {
        $('#' + CONTENT_ID + ' .synocr-folderpicker-item').off('click').on('click', function () {
            var p = $(this).attr('data-path');
            setCurrentPath(p);
            loadFolders(p);
        });
        $('#' + CONTENT_ID + ' .synocr-folderpicker-nav').off('click').on('click', function () {
            var p = $(this).attr('data-path');
            if (p === '__shares__') { setCurrentPath(''); loadShares(); return; }
            setCurrentPath(p);
            loadFolders(p);
        });
        $('#' + CONTENT_ID + ' .synocr-folderpicker-file').off('click').on('click', function () {
            var p = $(this).attr('data-path');
            selectPath(p);
        });
    }

    function pickerModalEl() {
        return document.getElementById(MODAL_ID);
    }

    /** Highest z-index among currently visible modals (Bootstrap default base: 1055). */
    function maxOpenModalZ() {
        var maxZ = 1055;
        document.querySelectorAll('.modal.show').forEach(function (m) {
            var z = parseInt(window.getComputedStyle(m).zIndex, 10);
            if (!isNaN(z) && z >= maxZ) maxZ = z;
        });
        return maxZ;
    }

    /** Stack the picker above any modal already open (e.g. target-folder builder). */
    function raisePickerStack(modalEl) {
        if (!modalEl) return 1065;
        if (modalEl.parentElement !== document.body) {
            document.body.appendChild(modalEl);
        }
        var pickerZ = maxOpenModalZ() + 10;
        modalEl.style.zIndex = String(pickerZ);
        return pickerZ;
    }

    function fixPickerBackdrop(pickerZ) {
        var backdrops = document.querySelectorAll('.modal-backdrop');
        if (backdrops.length) {
            backdrops[backdrops.length - 1].style.zIndex = String(pickerZ - 5);
        }
    }

    function showPickerModal(modalEl) {
        var pickerZ = raisePickerStack(modalEl);
        function onShown() { fixPickerBackdrop(pickerZ); }
        var $ = window.jQuery;
        if ($ && $.fn.modal) {
            $(modalEl).one('shown.bs.modal', onShown);
            $(modalEl).modal('show');
            return;
        }
        if (window.bootstrap && bootstrap.Modal) {
            modalEl.addEventListener('shown.bs.modal', onShown, { once: true });
            bootstrap.Modal.getOrCreateInstance(modalEl).show();
        }
    }

    function hidePickerModal(modalEl) {
        if (!modalEl) return;
        var $ = window.jQuery;
        if ($ && $.fn.modal) {
            $(modalEl).modal('hide');
            return;
        }
        if (window.bootstrap && bootstrap.Modal) {
            bootstrap.Modal.getOrCreateInstance(modalEl).hide();
        }
    }

    function selectPath(p) {
        if (st.input) st.input.value = p;
        hidePickerModal(pickerModalEl());
        if (typeof st.onSelect === 'function') { var cb = st.onSelect; st.onSelect = null; cb(p); }
    }

    function confirmCurrent() {
        if (st.mode === 'folder') {
            if (st.currentPath) selectPath(st.currentPath);
        } else {
            // file mode selects on click; confirm selects current folder if any
            if (st.currentPath) selectPath(st.currentPath);
        }
    }

    window.synocr_openPicker = function (inputId, mode, opts) {
        opts = opts || {};
        readLang();
        st.mode = mode || 'folder';
        st.extensions = opts.extensions || null;
        st.onSelect = opts.onSelect || null;
        st.input = (typeof inputId === 'string') ? document.getElementById(inputId) : inputId;
        st.currentPath = '';
        st.sharesMap = {}; st.sharesRealMap = {};
        $('#' + LABEL_ID).text(opts.title || L('title', 'Auswahl'));
        var $conf = $('#' + CONFIRM_ID);
        $conf.text(opts.confirmLabel || L('select', 'OK'));
        // file mode: confirm hidden (selection happens on click)
        $conf.toggle(st.mode !== 'file');
        $conf.off('click').on('click', confirmCurrent);
        showPickerModal(pickerModalEl());
        loadShares();
    };
})();
