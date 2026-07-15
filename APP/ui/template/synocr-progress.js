/*
 * Main page live UI: polls index.cgi?page=main-status (see #synocr-progress-config).
 * Loaded outside the <form> after bootstrap — DSM often blocks inline scripts in forms.
 * Updates: progress bars (while running), status icon, open-file row (queued and idle),
 * global PDF/page totals (synocr-global-stats-value), processing history list.
 * After run ends: hold at 100% (doneHoldMs), subtle ring countdown, then fade-out (doneFadeMs).
 */
(function () {
    "use strict";

    var pollMs = 2500;
    var timer = null;
    var wasRunning = false;
    var lastKnownStepTotal = 0;
    var lastKnownStepIndex = 0;
    /** @type {"hidden"|"running"|"doneHold"|"fading"} */
    var progressPhase = "hidden";
    var holdTimer = null;
    var fadeTimer = null;
    var fadeListener = null;
    var lastStatusData = null;
    var lastJobsHash = "";
    var historyClearScope = null;

    var RING_RADIUS = 8;
    var RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS;

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
        return fillXTags(cfg.filesTpl || "", { done: String(done), total: String(total) });
    }

    function formatStepFraction(stepIndex, stepTotal) {
        if (!stepTotal || stepTotal <= 0) {
            return "";
        }
        return "(" + String(stepIndex || 0) + "/" + String(stepTotal) + ") ";
    }

    function clearCompletionTimers() {
        if (holdTimer) {
            clearTimeout(holdTimer);
            holdTimer = null;
        }
        if (fadeTimer) {
            clearTimeout(fadeTimer);
            fadeTimer = null;
        }
    }

    function getProgressElements() {
        return {
            box: document.getElementById("synocr-progress"),
            filesBar: document.getElementById("synocr-progress-files-bar"),
            fileBar: document.getElementById("synocr-progress-file-bar"),
            filesLabel: document.getElementById("synocr-progress-files-label"),
            fileNameEl: document.getElementById("synocr-progress-file-name"),
            stepLabelEl: document.getElementById("synocr-progress-step-label"),
            stepFractionEl: document.getElementById("synocr-progress-step-fraction"),
            profileLine: document.getElementById("synocr-progress-profile"),
            profileValue: document.getElementById("synocr-progress-profile-value"),
            ring: document.getElementById("synocr-progress-done-ring")
        };
    }

    function setBarPercent(bar, pct, animated) {
        if (!bar) {
            return;
        }
        bar.style.width = pct + "%";
        bar.setAttribute("aria-valuenow", pct);
        bar.textContent = pct + "%";
        bar.classList.remove("progress-bar-striped", "progress-bar-animated");
        if (animated) {
            bar.classList.add("progress-bar-striped", "progress-bar-animated");
        }
    }

    function resetProgressVisualState(box) {
        if (!box) {
            return;
        }
        box.classList.remove("synocr-progress--done", "synocr-progress--hiding");
        box.style.opacity = "";
        box.style.transition = "";

        var ring = document.getElementById("synocr-progress-done-ring");
        if (ring) {
            ring.classList.remove("synocr-progress-done-ring--active");
            var arc = ring.querySelector(".synocr-progress-done-ring__arc");
            if (arc) {
                arc.style.transition = "";
                arc.style.strokeDasharray = "";
                arc.style.strokeDashoffset = "";
            }
        }
    }

    function removeFadeListener(box) {
        if (fadeListener && box) {
            box.removeEventListener("transitionend", fadeListener);
            fadeListener = null;
        }
    }

    function hideProgressBox(box) {
        if (!box) {
            return;
        }
        clearCompletionTimers();
        removeFadeListener(box);
        resetProgressVisualState(box);
        box.style.display = "none";
        progressPhase = "hidden";
        updateGlobalStats(lastStatusData);
    }

    function startRingCountdown(cfg, ring) {
        if (!ring) {
            return;
        }
        var arc = ring.querySelector(".synocr-progress-done-ring__arc");
        if (!arc) {
            return;
        }
        var holdMs = cfg.doneHoldMs || 5000;
        ring.classList.add("synocr-progress-done-ring--active");
        arc.style.strokeDasharray = String(RING_CIRCUMFERENCE);
        arc.style.strokeDashoffset = "0";
        arc.style.transition = "none";
        arc.getBoundingClientRect();
        arc.style.transition = "stroke-dashoffset " + holdMs + "ms linear";
        arc.style.strokeDashoffset = String(RING_CIRCUMFERENCE);
    }

    function applyDoneHoldUI(cfg, data) {
        var el = getProgressElements();
        var box = el.box;
        if (!box) {
            return;
        }

        var total = data.files_total || 0;
        var done = data.files_done || 0;
        if (total > 0 && done < total) {
            done = total;
        }

        box.style.display = "block";
        box.style.opacity = "1";
        box.classList.add("synocr-progress--done");
        box.classList.remove("synocr-progress--hiding");

        setBarPercent(el.filesBar, 100, false);
        setBarPercent(el.fileBar, 100, false);

        if (el.stepFractionEl) {
            var stepTotal = Math.max(
                data.step_total || 0,
                lastKnownStepTotal || 0,
                data.step_index || 0,
                lastKnownStepIndex || 0
            );
            if (stepTotal > 0) {
                el.stepFractionEl.textContent = formatStepFraction(stepTotal, stepTotal);
            }
        }
        if (el.stepLabelEl) {
            el.stepLabelEl.textContent = cfg.doneStepText || cfg.allDoneText || data.step_label || "-";
        }

        if (el.filesLabel) {
            if (cfg.allDoneText) {
                el.filesLabel.textContent = cfg.allDoneText;
            } else {
                el.filesLabel.textContent = formatFilesLabel(cfg, done, total || done);
            }
        }
        if (el.profileLine) {
            el.profileLine.style.display = "none";
        }

        startRingCountdown(cfg, el.ring);
    }

    function beginFadeOut(cfg, box) {
        if (!box) {
            return;
        }
        progressPhase = "fading";
        box.classList.remove("synocr-progress--done");
        box.classList.add("synocr-progress--hiding");

        var ring = document.getElementById("synocr-progress-done-ring");
        if (ring) {
            ring.classList.remove("synocr-progress-done-ring--active");
        }

        var fadeMs = cfg.doneFadeMs || 500;
        box.style.transition = "opacity " + fadeMs + "ms ease";
        removeFadeListener(box);

        fadeListener = function (e) {
            if (e.target !== box || e.propertyName !== "opacity") {
                return;
            }
            removeFadeListener(box);
            if (fadeTimer) {
                clearTimeout(fadeTimer);
                fadeTimer = null;
            }
            hideProgressBox(box);
        };
        box.addEventListener("transitionend", fadeListener);

        fadeTimer = setTimeout(function () {
            fadeTimer = null;
            removeFadeListener(box);
            hideProgressBox(box);
        }, fadeMs + 150);

        box.style.opacity = "1";
        box.getBoundingClientRect();
        box.style.opacity = "0";
    }

    function startDoneHold(cfg, data) {
        var box = document.getElementById("synocr-progress");
        if (!box) {
            return;
        }
        clearCompletionTimers();
        removeFadeListener(box);
        progressPhase = "doneHold";
        applyDoneHoldUI(cfg, data);

        var holdMs = cfg.doneHoldMs || 5000;
        holdTimer = setTimeout(function () {
            holdTimer = null;
            beginFadeOut(cfg, box);
        }, holdMs);
    }

    function cancelCompletionAndShowRunning(cfg, data) {
        var el = getProgressElements();
        var box = el.box;
        if (!box) {
            return;
        }
        clearCompletionTimers();
        removeFadeListener(box);
        resetProgressVisualState(box);
        progressPhase = "running";
        wasRunning = true;
        box.style.display = "block";
        box.style.opacity = "1";
        renderRunningProgress(cfg, data, el);
    }

    function renderRunningProgress(cfg, data, el) {
        el = el || getProgressElements();
        var pf = data.percent_files || 0;
        var pfile = data.percent_file || 0;

        if (data.step_total && data.step_total > 0) {
            lastKnownStepTotal = data.step_total;
        }
        if (data.step_index && data.step_index > 0) {
            lastKnownStepIndex = data.step_index;
        }

        setBarPercent(el.filesBar, pf, true);
        setBarPercent(el.fileBar, pfile, true);

        if (el.filesLabel) {
            el.filesLabel.textContent = formatFilesLabel(cfg, data.files_done || 0, data.files_total || 0);
        }
        if (el.fileNameEl) {
            el.fileNameEl.textContent = data.file || "-";
        }
        if (el.stepLabelEl) {
            el.stepLabelEl.textContent = data.step_label || "-";
        }
        if (el.stepFractionEl) {
            el.stepFractionEl.textContent = formatStepFraction(
                data.step_index || 0,
                data.step_total || 0
            );
        }
        if (el.profileLine && el.profileValue) {
            if (data.profile) {
                el.profileLine.style.removeProperty("display");
                el.profileValue.textContent = data.profile;
            } else {
                el.profileLine.style.display = "none";
            }
        }
    }

    function escapeHtml(text) {
        return String(text || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;");
    }

    function jobsHash(jobs) {
        if (!jobs || !jobs.length) {
            return "0";
        }
        return jobs.map(function (job) {
            return [
                job.id,
                job.status,
                job.source,
                job.output_dir || "",
                (job.targets || []).join("|")
            ].join(":");
        }).join(";");
    }

    function statusMeta(cfg, status) {
        if (status === "success") {
            return { cls: "synocr-job-row--success", badge: "success", label: cfg.historyStatusSuccess || "success" };
        }
        if (status === "failed") {
            return { cls: "synocr-job-row--failed", badge: "failed", label: cfg.historyStatusFailed || "failed" };
        }
        return { cls: "synocr-job-row--running", badge: "running", label: cfg.historyStatusRunning || "running" };
    }

    function renderStatusBadge(meta) {
        var label = escapeHtml(meta.label);
        return (
            '<span class="synocr-job-status-badge synocr-job-status-badge--' +
            escapeHtml(meta.badge) +
            '">' +
            label +
            "</span>"
        );
    }

    function normalizeDirPrefix(prefix) {
        if (!prefix) {
            return "";
        }
        var p = String(prefix).replace(/\/+$/, "");
        return p ? p + "/" : "";
    }

    function pathDisplayShort(full, prefix) {
        if (!full) {
            return "";
        }
        var normPrefix = normalizeDirPrefix(prefix);
        if (!normPrefix) {
            return full;
        }
        var f = String(full);
        if (f.indexOf(normPrefix) === 0) {
            var rest = f.slice(normPrefix.length).replace(/^\/+/, "");
            if (rest) {
                return rest;
            }
            var parts = f.split("/");
            return parts[parts.length - 1] || f;
        }
        return f;
    }

    function renderTargets(targets, outputDir) {
        if (!targets || !targets.length) {
            return "-";
        }
        return targets.map(function (target) {
            var safeFull = escapeHtml(target);
            var safeDisplay = escapeHtml(pathDisplayShort(target, outputDir));
            return '<div class="synocr-job-target synocr-has-tip" data-tip="' + safeFull + '">' + safeDisplay + "</div>";
        }).join("");
    }

    function renderHistoryRows(cfg, jobs) {
        if (!jobs || !jobs.length) {
            return '<tr><td colspan="5" class="text-muted small">' + escapeHtml(cfg.historyEmpty || "-") + "</td></tr>";
        }
        return jobs.map(function (job) {
            var meta = statusMeta(cfg, job.status);
            var source = escapeHtml(job.source || "");
            var profile = escapeHtml(job.profile || "");
            var started = escapeHtml(job.started_at || "");
            return (
                '<tr class="synocr-job-row ' + meta.cls + '" data-job-id="' + escapeHtml(String(job.id || "")) + '">' +
                '<td class="synocr-job-time small text-nowrap">' + started + "</td>" +
                '<td class="synocr-job-profile small">' + profile + "</td>" +
                '<td class="synocr-job-source small" title="' + source + '">' + source + "</td>" +
                '<td class="synocr-job-targets small">' + renderTargets(job.targets, job.output_dir) + "</td>" +
                '<td class="synocr-job-status small text-nowrap text-end">' + renderStatusBadge(meta) + "</td>" +
                "</tr>"
            );
        }).join("");
    }

    function updateHistoryCount(count) {
        var el = document.getElementById("synocr-processing-history-count");
        if (!el) {
            return;
        }
        var n = count || 0;
        el.textContent = String(n);
        el.hidden = n < 1;
    }

    function updateProcessingHistory(cfg, data) {
        var tbody = document.getElementById("synocr-processing-history-tbody");
        if (!tbody) {
            return;
        }
        var jobs = (data && data.jobs) ? data.jobs : [];
        var hash = jobsHash(jobs);
        if (hash === lastJobsHash) {
            return;
        }
        lastJobsHash = hash;
        tbody.innerHTML = renderHistoryRows(cfg, jobs);
        updateHistoryCount(jobs.length);
        updateHistoryClearVisibility(jobs.length);
    }

    function isHistoryExpanded() {
        var body = document.getElementById("synocr-processing-history-body");
        return !!(body && body.classList.contains("show"));
    }

    function updateHistoryClearVisibility(count) {
        var wrap = document.getElementById("synocr-processing-history-clear-wrap");
        if (!wrap) {
            return;
        }
        wrap.hidden = !isHistoryExpanded() || !(count > 0);
    }

    function initHistoryClear(cfg) {
        if (!cfg || !cfg.historyClearUrl) {
            return;
        }

        var body = document.getElementById("synocr-processing-history-body");
        var modalEl = document.getElementById("synocr-history-clear-modal");
        var modalBody = document.getElementById("synocr-history-clear-modal-body");
        var confirmBtn = document.getElementById("synocr-history-clear-confirm");
        if (!body || !modalEl || !modalBody || !confirmBtn) {
            return;
        }

        var modal = typeof bootstrap !== "undefined" && bootstrap.Modal
            ? bootstrap.Modal.getOrCreateInstance(modalEl)
            : null;

        function refreshClearVisibility() {
            var jobs = (lastStatusData && lastStatusData.jobs) ? lastStatusData.jobs : [];
            var count = jobs.length;
            if (!lastStatusData) {
                var badge = document.getElementById("synocr-processing-history-count");
                if (badge && !badge.hidden) {
                    count = parseInt(badge.textContent, 10) || 0;
                }
            }
            updateHistoryClearVisibility(count);
        }

        body.addEventListener("shown.bs.collapse", refreshClearVisibility);
        body.addEventListener("hidden.bs.collapse", refreshClearVisibility);

        document.querySelectorAll("[data-synocr-history-clear]").forEach(function (btn) {
            btn.addEventListener("click", function () {
                historyClearScope = btn.getAttribute("data-synocr-history-clear");
                modalBody.textContent = historyClearScope === "failed_running"
                    ? (cfg.historyClearConfirmProblems || "")
                    : (cfg.historyClearConfirmSuccess || "");
                if (modal) {
                    modal.show();
                }
            });
        });

        confirmBtn.addEventListener("click", function () {
            if (!historyClearScope || typeof jQuery === "undefined") {
                return;
            }
            confirmBtn.disabled = true;
            jQuery.ajax({
                url: cfg.historyClearUrl,
                data: { scope: historyClearScope },
                dataType: "json",
                cache: false
            })
                .done(function (res) {
                    if (res && res.ok) {
                        lastJobsHash = "";
                        if (modal) {
                            modal.hide();
                        }
                        jQuery.ajax({
                            url: cfg.statusUrl,
                            dataType: "json",
                            cache: false
                        }).done(function (data) {
                            applyStatus(cfg, data || {});
                        });
                    }
                })
                .always(function () {
                    confirmBtn.disabled = false;
                    historyClearScope = null;
                });
        });

        refreshClearVisibility();
    }

    function updateGlobalStats(data) {
        var el = document.getElementById("synocr-global-stats-value");
        if (!el || !data || data.global_ocrcount == null || data.global_pagecount == null) {
            return;
        }
        el.textContent = String(data.global_ocrcount) + " / " + String(data.global_pagecount);
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

        if (data.running) {
            if (progressPhase === "doneHold" || progressPhase === "fading") {
                cancelCompletionAndShowRunning(cfg, data);
                return;
            }
            if ((data.files_done || 0) === 0 && (data.step_index || 0) <= 1) {
                lastKnownStepIndex = data.step_index || 0;
                if (data.step_total && data.step_total > 0) {
                    lastKnownStepTotal = data.step_total;
                }
            } else {
                if (data.step_total && data.step_total > 0) {
                    lastKnownStepTotal = data.step_total;
                }
                if (data.step_index && data.step_index > 0) {
                    lastKnownStepIndex = data.step_index;
                }
            }
            progressPhase = "running";
            wasRunning = true;
            box.style.display = "block";
            box.style.opacity = "1";
            renderRunningProgress(cfg, data);
            return;
        }

        if (progressPhase === "doneHold" || progressPhase === "fading") {
            return;
        }

        if (wasRunning && progressPhase === "running") {
            wasRunning = false;
            if (!data.step_total && lastKnownStepTotal > 0) {
                data = Object.assign({}, data, {
                    step_total: lastKnownStepTotal,
                    step_index: lastKnownStepTotal
                });
            }
            startDoneHold(cfg, data);
            return;
        }

        if (progressPhase !== "hidden") {
            hideProgressBox(box);
        } else {
            box.style.display = "none";
        }
    }

    function applyStatus(cfg, data) {
        data = data || {};
        lastStatusData = data;
        updateMainStatus(cfg, data);
        updateGlobalStats(data);
        updateProgressBars(cfg, data);
        updateProcessingHistory(cfg, data);
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

        if (window.synocrDataTips) {
            window.synocrDataTips.bindOnce();
        }

        initHistoryClear(cfg);

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
