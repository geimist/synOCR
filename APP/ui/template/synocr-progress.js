/*
 * Main page live UI: polls index.cgi?page=main-status (see #synocr-progress-config).
 * Loaded outside the <form> after bootstrap — DSM often blocks inline scripts in forms.
 * Updates: progress bars (while running), status icon, open-file row (queued and idle).
 */
(function () {
    "use strict";

    var pollMs = 2500;
    var timer = null;

    function getConfig() {
        var el = document.getElementById("synocr-progress-config");
        if (!el || !el.textContent) {
            return null;
        }
        try {
            return JSON.parse(el.textContent);
        } catch (e) {
            return null;
        }
    }

    function isWorkPending(data) {
        return !!(data.running || (data.files_remaining && data.files_remaining > 0));
    }

    /** Replace DeepL-safe <x id="…"/> placeholders (same variants as synocr_lang_fill_x). */
    function fillXTags(template, values) {
        var out = template || "";
        var id;
        values = values || {};
        for (id in values) {
            if (!Object.prototype.hasOwnProperty.call(values, id)) {
                continue;
            }
            var val = String(values[id]);
            out = out.split('<x id="' + id + '"/>').join(val);
            out = out.split("<x id='" + id + "'/>").join(val);
        }
        return out;
    }

    function formatFilesLabel(cfg, done, total) {
        var tpl = cfg.filesTpl || 'Gesamt: <x id="done"/> von <x id="total"/> Dateien';
        return fillXTags(tpl, { done: String(done), total: String(total) });
    }

    function formatStepFraction(stepIndex, stepTotal) {
        if (!stepTotal || stepTotal <= 0) {
            return "";
        }
        return " (" + String(stepIndex || 0) + "/" + String(stepTotal) + ")";
    }

    /** Green check when idle and no input files; hourglass while running or files queued. */
    function updateMainStatus(cfg, data) {
        var busy = isWorkPending(data);
        var icon = document.getElementById("synocr-main-status-icon");
        if (icon && cfg.iconIdle && cfg.iconBusy) {
            icon.src = busy ? cfg.iconBusy : cfg.iconIdle;
        }

        var openRow = document.getElementById("synocr-open-files-row");
        var openCell = document.getElementById("synocr-open-files-value");
        var remaining = data.files_remaining || 0;
        var showOpenRow = !data.running && remaining > 0;

        if (openRow) {
            openRow.style.display = showOpenRow ? "" : "none";
        }
        if (openCell && showOpenRow) {
            openCell.textContent = String(remaining);
        }
    }

    function updateProgressBars(cfg, data) {
        var box = document.getElementById("synocr-progress");
        if (!box) {
            return;
        }

        if (!data.running) {
            box.style.display = "none";
            return;
        }

        box.style.display = "block";

        var filesBar = document.getElementById("synocr-progress-files-bar");
        var fileBar = document.getElementById("synocr-progress-file-bar");
        var filesLabel = document.getElementById("synocr-progress-files-label");
        var fileNameEl = document.getElementById("synocr-progress-file-name");
        var stepLabelEl = document.getElementById("synocr-progress-step-label");
        var stepFractionEl = document.getElementById("synocr-progress-step-fraction");
        var profileLine = document.getElementById("synocr-progress-profile");
        var profileValue = document.getElementById("synocr-progress-profile-value");

        var pf = data.percent_files || 0;
        var pfile = data.percent_file || 0;

        if (filesBar) {
            filesBar.style.width = pf + "%";
            filesBar.setAttribute("aria-valuenow", pf);
            filesBar.textContent = pf + "%";
        }
        if (fileBar) {
            fileBar.style.width = pfile + "%";
            fileBar.setAttribute("aria-valuenow", pfile);
            fileBar.textContent = pfile + "%";
        }
        if (filesLabel) {
            filesLabel.textContent = formatFilesLabel(cfg, data.files_done || 0, data.files_total || 0);
        }
        if (fileNameEl) {
            fileNameEl.textContent = data.file || "-";
        }
        if (stepLabelEl) {
            stepLabelEl.textContent = data.step_label || "-";
        }
        if (stepFractionEl) {
            stepFractionEl.textContent = formatStepFraction(
                data.step_index || 0,
                data.step_total || 0
            );
        }
        if (profileLine && profileValue) {
            if (data.profile) {
                profileLine.style.display = "block";
                profileValue.textContent = data.profile;
            } else {
                profileLine.style.display = "none";
            }
        }
    }

    function applyStatus(cfg, data) {
        data = data || {};
        updateMainStatus(cfg, data);
        updateProgressBars(cfg, data);
    }

    function startPolling(cfg) {
        if (timer) {
            return;
        }
        if (typeof jQuery === "undefined") {
            return;
        }

        function poll() {
            jQuery.ajax({
                url: cfg.statusUrl,
                dataType: "json",
                cache: false
            })
                .done(function (data) {
                    applyStatus(cfg, data || {});
                })
                .fail(function () {});
        }

        poll();
        timer = setInterval(poll, cfg.pollMs || pollMs);
    }

    function boot() {
        var cfg = getConfig();
        if (!cfg) {
            return;
        }

        if (typeof jQuery !== "undefined") {
            jQuery(function () {
                startPolling(cfg);
            });
        } else {
            document.addEventListener("DOMContentLoaded", function () {
                startPolling(cfg);
            });
        }
    }

    boot();
})();
