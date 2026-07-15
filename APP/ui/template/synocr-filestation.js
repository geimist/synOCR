/**
 * synOCR — File Station helpers (path mapping, open folder / file fallback)
 *
 * Uses SYNO.FileStation.List (list_share) + SynoToken from SYNO.API.Auth,
 * same as synocr-folderpicker.js. Exposes window.synocrFileStation.
 */
(function () {
    "use strict";

    var sharesRealMap = {};
    var sharesLoaded = false;
    var sharesLoading = false;
    var sharesWaiters = [];

    function isNasVolumePath(path) {
        return /^\/volume[0-9]+\//.test(String(path || ""));
    }

    function resolveSynoToken(cb) {
        if (typeof jQuery === "undefined") {
            cb(null);
            return;
        }
        function tryApi(ver) {
            jQuery.ajax({
                url: "/webapi/entry.cgi",
                type: "GET",
                timeout: 10000,
                data: { api: "SYNO.API.Auth", version: ver, method: "token" },
                success: function (resp) {
                    if (resp && resp.success && resp.data && resp.data.synotoken) {
                        cb(resp.data.synotoken);
                        return;
                    }
                    if (ver === 7) {
                        tryApi(6);
                        return;
                    }
                    cb(urlFallback());
                },
                error: function () {
                    if (ver === 7) {
                        tryApi(6);
                        return;
                    }
                    cb(urlFallback());
                }
            });
        }
        function urlFallback() {
            try {
                var t = new URLSearchParams(window.location.search).get("SynoToken");
                if (t) {
                    return t;
                }
                if (window.parent !== window) {
                    t = new URLSearchParams(window.parent.location.search).get("SynoToken");
                    if (t) {
                        return t;
                    }
                }
            } catch (e) {}
            return null;
        }
        tryApi(7);
    }

    function realToSharePath(fullPath) {
        var best = "";
        var p = String(fullPath || "");
        var rp;
        for (rp in sharesRealMap) {
            if (Object.prototype.hasOwnProperty.call(sharesRealMap, rp) && p.indexOf(rp) === 0 && rp.length > best.length) {
                best = rp;
            }
        }
        if (best) {
            return sharesRealMap[best] + p.substring(best.length);
        }
        return p;
    }

    function shareDirname(sharePath) {
        var p = String(sharePath || "");
        var i = p.lastIndexOf("/");
        if (i <= 0) {
            return p || "/";
        }
        return p.substring(0, i) || "/";
    }

    function flushSharesWaiters(err) {
        var list = sharesWaiters.slice();
        sharesWaiters = [];
        list.forEach(function (fn) {
            fn(err);
        });
    }

    function ensureShares(cb) {
        if (sharesLoaded) {
            cb(null);
            return;
        }
        sharesWaiters.push(cb);
        if (sharesLoading) {
            return;
        }
        sharesLoading = true;
        if (typeof jQuery === "undefined") {
            sharesLoading = false;
            flushSharesWaiters(new Error("no_jquery"));
            return;
        }
        resolveSynoToken(function (token) {
            if (!token) {
                sharesLoading = false;
                flushSharesWaiters(new Error("no_token"));
                return;
            }
            jQuery.ajax({
                url: "/webapi/entry.cgi",
                type: "GET",
                timeout: 10000,
                data: {
                    api: "SYNO.FileStation.List",
                    version: 2,
                    method: "list_share",
                    additional: '["name","path","isdir","perm","real_path"]',
                    SynoToken: token
                },
                success: function (resp) {
                    sharesRealMap = {};
                    if (resp && resp.success && resp.data && resp.data.shares) {
                        resp.data.shares.forEach(function (share) {
                            if (share.additional && share.additional.real_path && share.path) {
                                sharesRealMap[share.additional.real_path] = share.path;
                            }
                        });
                    }
                    sharesLoaded = true;
                    sharesLoading = false;
                    flushSharesWaiters(null);
                },
                error: function () {
                    sharesLoading = false;
                    flushSharesWaiters(new Error("list_share_failed"));
                }
            });
        });
    }

    function normalizeShareFolderPath(shareFolderPath) {
        var p = String(shareFolderPath || "");
        if (!p) {
            return "/";
        }
        if (p !== "/" && !p.endsWith("/")) {
            p += "/";
        }
        return p;
    }

    function callOpenPathCandidates(topWin, inst, folderPath) {
        var methodNames = ["openPath", "openFile", "openfile", "openFolder", "jumpToPath", "navigateTo", "setPath"];
        var targets = [];
        var i;
        var j;

        function addTarget(obj) {
            if (obj) {
                targets.push(obj);
            }
        }

        addTarget(inst);
        if (inst) {
            addTarget(inst.app);
            addTarget(inst.window);
            addTarget(inst.appWindow);
            addTarget(inst.panel);
            addTarget(inst.module);
            addTarget(inst.contentPanel);
            if (typeof inst.getController === "function") {
                try {
                    addTarget(inst.getController());
                } catch (e) {}
            }
            if (typeof inst.getPanel === "function") {
                try {
                    addTarget(inst.getPanel());
                } catch (e) {}
            }
        }

        for (i = 0; i < targets.length; i++) {
            for (j = 0; j < methodNames.length; j++) {
                var method = methodNames[j];
                if (typeof targets[i][method] === "function") {
                    targets[i][method](folderPath);
                    return true;
                }
            }
        }

        if (inst && inst.constructor && inst.constructor.prototype) {
            for (j = 0; j < methodNames.length; j++) {
                method = methodNames[j];
                if (typeof inst.constructor.prototype[method] === "function") {
                    inst.constructor.prototype[method].call(inst, folderPath);
                    return true;
                }
            }
        }

        var fnPath = topWin.SYNO && topWin.SYNO.SDS && topWin.SYNO.SDS.App &&
            topWin.SYNO.SDS.App.FileStation3 && topWin.SYNO.SDS.App.FileStation3.Instance &&
            topWin.SYNO.SDS.App.FileStation3.Instance.openPath;
        if (typeof fnPath === "function") {
            if (inst) {
                fnPath.call(inst, folderPath);
            } else {
                fnPath(folderPath);
            }
            return true;
        }

        return false;
    }

    function getFileStationInstances(topWin) {
        var mgr = topWin.SYNO && topWin.SYNO.SDS && topWin.SYNO.SDS.AppMgr;
        if (!mgr || typeof mgr.getByAppName !== "function") {
            return [];
        }
        return mgr.getByAppName("SYNO.SDS.App.FileStation3.Instance") || [];
    }

    function tryOpenPathOnRunningInstance(topWin, folderPath) {
        try {
            var apps = getFileStationInstances(topWin);
            var i;
            for (i = apps.length - 1; i >= 0; i--) {
                if (callOpenPathCandidates(topWin, apps[i], folderPath)) {
                    return true;
                }
            }
        } catch (e) {}
        return false;
    }

    function tryLaunchFileStation(shareFolderPath) {
        try {
            var topWin = window.top;
            if (!topWin || topWin === window) {
                return false;
            }
            var sds = topWin.SYNO && topWin.SYNO.SDS;
            if (!sds || typeof sds.AppLaunch !== "function") {
                return false;
            }
            var folderPath = normalizeShareFolderPath(shareFolderPath);
            var launchParam = "openfile=" + encodeURIComponent(folderPath);
            if (tryOpenPathOnRunningInstance(topWin, folderPath)) {
                return true;
            }

            sds.AppLaunch(
                "SYNO.SDS.App.FileStation3.Instance",
                launchParam,
                false,
                function (appInstance) {
                    if (callOpenPathCandidates(topWin, appInstance, folderPath)) {
                        return;
                    }
                    var apps = getFileStationInstances(topWin);
                    if (apps.length) {
                        callOpenPathCandidates(topWin, apps[apps.length - 1], folderPath);
                    }
                }
            );
            return true;
        } catch (e) {
            return false;
        }
    }

    function openDownload(shareFilePath, token) {
        var pathParam = JSON.stringify([shareFilePath]);
        var qs = jQuery.param({
            api: "SYNO.FileStation.Download",
            version: 2,
            method: "download",
            path: pathParam,
            mode: "open",
            SynoToken: token
        });
        window.open("/webapi/entry.cgi?" + qs, "_blank", "noopener,noreferrer");
    }

    function openNasPath(fullPath) {
        if (!isNasVolumePath(fullPath)) {
            return;
        }
        if (typeof jQuery === "undefined") {
            return;
        }
        ensureShares(function (err) {
            if (err) {
                return;
            }
            var sharePath = realToSharePath(fullPath);
            var folderPath = shareDirname(sharePath);
            if (tryLaunchFileStation(folderPath)) {
                return;
            }
            resolveSynoToken(function (token) {
                if (!token) {
                    return;
                }
                openDownload(sharePath, token);
            });
        });
    }

    window.synocrFileStation = {
        isNasVolumePath: isNasVolumePath,
        resolveSynoToken: resolveSynoToken,
        ensureShares: ensureShares,
        realToSharePath: realToSharePath,
        openNasPath: openNasPath
    };
})();
