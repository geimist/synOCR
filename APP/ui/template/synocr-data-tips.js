/**
 * synOCR — shared data-tip tooltips (rules editor, processing history, …)
 */
(function () {
    "use strict";

    var tipPopupEl = null;
    var tipActiveHost = null;
    var lang = null;

    function ensureTipPopup() {
        if (!tipPopupEl) {
            tipPopupEl = document.createElement("div");
            tipPopupEl.className = "synocr-tip-popup";
            tipPopupEl.hidden = true;
            document.body.appendChild(tipPopupEl);
        }
        return tipPopupEl;
    }

    function positionTipPopup(host) {
        var popup = ensureTipPopup();
        var hostRect = host.getBoundingClientRect();
        var popupRect = popup.getBoundingClientRect();
        var gap = 6;
        var left = hostRect.left + (hostRect.width - popupRect.width) / 2;
        var top = hostRect.top - popupRect.height - gap;
        if (top < gap) {
            top = hostRect.bottom + gap;
        }
        left = Math.max(gap, Math.min(left, window.innerWidth - popupRect.width - gap));
        top = Math.max(gap, Math.min(top, window.innerHeight - popupRect.height - gap));
        popup.style.left = Math.round(left) + "px";
        popup.style.top = Math.round(top) + "px";
    }

    function hideDataTip() {
        if (tipPopupEl) {
            tipPopupEl.hidden = true;
            tipPopupEl.classList.remove("synocr-tip-popup-wide", "synocr-tip-popup-rich", "synocr-tip-popup-path");
            tipPopupEl.textContent = "";
        }
        tipActiveHost = null;
    }

    function tipPartsFromKey(baseKey) {
        if (!baseKey || !lang) {
            return null;
        }
        var title = lang[baseKey + "_t"];
        var parts = [];
        if (title != null && String(title) !== "") {
            parts.push({ type: "title", text: String(title) });
        }
        var i = 1;
        while (i <= 12) {
            var k = baseKey + "_" + i;
            if (lang[k] == null || String(lang[k]) === "") {
                break;
            }
            parts.push({ type: "p", text: String(lang[k]) });
            i++;
        }
        if (!parts.length) {
            if (lang[baseKey] != null && String(lang[baseKey]) !== "") {
                return [{ type: "p", text: String(lang[baseKey]) }];
            }
            return null;
        }
        return parts;
    }

    function renderTipPopup(host) {
        var popup = ensureTipPopup();
        var tipKey = host.getAttribute("data-tip-key");
        var parts = tipKey ? tipPartsFromKey(tipKey) : null;
        popup.textContent = "";
        popup.classList.remove("synocr-tip-popup-rich");
        if (parts && parts.length) {
            popup.classList.add("synocr-tip-popup-rich");
            parts.forEach(function (part) {
                var el = document.createElement(part.type === "title" ? "div" : "p");
                el.className = part.type === "title" ? "synocr-tip-title" : "synocr-tip-line";
                el.textContent = part.text;
                popup.appendChild(el);
            });
            return;
        }
        var text = host.getAttribute("data-tip");
        if (text && text.indexOf("\n") >= 0) {
            popup.classList.add("synocr-tip-popup-rich");
            var lines = text.split("\n");
            if (lines[0]) {
                var titleEl = document.createElement("div");
                titleEl.className = "synocr-tip-title";
                titleEl.textContent = lines[0];
                popup.appendChild(titleEl);
            }
            for (var li = 1; li < lines.length; li++) {
                if (!lines[li]) {
                    continue;
                }
                var lineEl = document.createElement("p");
                lineEl.className = "synocr-tip-line";
                lineEl.textContent = lines[li];
                popup.appendChild(lineEl);
            }
            return;
        }
        if (text) {
            popup.textContent = text;
        }
    }

    function showDataTip(host) {
        if (!host.getAttribute("data-tip") && !host.getAttribute("data-tip-key")) {
            return;
        }
        renderTipPopup(host);
        var popup = ensureTipPopup();
        if (!popup.childNodes.length && !popup.textContent) {
            return;
        }
        popup.classList.toggle("synocr-tip-popup-wide", !!host.closest("#synocr-regex-assistant-modal") || host.classList.contains("synocr-job-target"));
        popup.classList.toggle("synocr-tip-popup-path", host.classList.contains("synocr-job-target"));
        popup.hidden = false;
        positionTipPopup(host);
        tipActiveHost = host;
    }

    function bindOnce() {
        if (document._synocrDataTipsBound) {
            return;
        }
        document._synocrDataTipsBound = true;
        document.body.addEventListener("mouseover", function (e) {
            var host = e.target.closest("[data-tip],[data-tip-key]");
            if (!host) {
                if (tipActiveHost && !tipActiveHost.contains(e.target)) {
                    hideDataTip();
                }
                return;
            }
            if (host !== tipActiveHost) {
                showDataTip(host);
            }
        });
        document.body.addEventListener("mouseout", function (e) {
            if (!tipActiveHost) {
                return;
            }
            if (e.target.closest("[data-tip],[data-tip-key]") !== tipActiveHost) {
                return;
            }
            var rel = e.relatedTarget;
            if (rel && tipActiveHost.contains(rel)) {
                return;
            }
            hideDataTip();
        });
        document.body.addEventListener("focusin", function (e) {
            var host = e.target.closest("[data-tip],[data-tip-key]");
            if (host) {
                showDataTip(host);
            }
        });
        document.body.addEventListener("focusout", function (e) {
            if (tipActiveHost && e.target === tipActiveHost) {
                hideDataTip();
            }
        });
        window.addEventListener("scroll", function () {
            if (tipActiveHost && tipPopupEl && !tipPopupEl.hidden) {
                positionTipPopup(tipActiveHost);
            }
        }, true);
    }

    function applyDataTip(el, text) {
        if (!el || !text) {
            return;
        }
        el.setAttribute("data-tip", text);
        el.removeAttribute("title");
    }

    function setLang(l) {
        lang = l;
    }

    window.synocrDataTips = {
        bindOnce: bindOnce,
        applyDataTip: applyDataTip,
        setLang: setLang
    };
})();
