# synOCR DSM7 `getroot` / Docker-Worker Doku

## Zielbild: Wie das SPK fuer `getroot` angepasst wuerde

Diese Sektion beschreibt den technisch gewuenschten Endzustand fuer ein SPK mit `getroot`:

1. `APP/ocr_docker` bleibt ein normaler Docker-Build-Kontext (kein Symlink) mit `Dockerfile` und `getroot`.
2. `PKG_DSM7/conf/resource` enthaelt den Docker-Block, damit DSM den Worker starten kann.
3. Der Mount fuer Host-Root wird getrennt vom Build-Kontext gefuehrt:
   - `build`: `ocr_docker`
   - `volumes[].host_dir`: `host_root`
4. `APP/host_root` ist im Paket zunaechst ein normales Verzeichnis (Platzhalter).
5. Erst **nach** der Worker-Phase wird in `postinst` aus `host_root` ein Symlink auf `/`:
   - `rm -rf "${SYNOPKG_PKGDEST}/host_root"`
   - `ln -s / "${SYNOPKG_PKGDEST}/host_root"`
6. `APP/ocr_docker/getroot` fuehrt im Container als root aus:
   - `chroot /mnt/synoroot/ /usr/syno/synoman/webman/3rdparty/synOCR/check_permissions.sh`
7. `check_permissions.sh` setzt Docker-/Admin-Gruppen und Docker-Socket-Rechte.
8. Umfangreiche Diagnose-Logs bleiben aktiv (`pkg_diag.sh`, lifecycle trace, history log).

Hinweis: Dieser Ablauf funktioniert fuer **Neuinstallation** mit Docker-Resource prinzipiell, scheitert aber im Legacy-Upgradefall (siehe Root Cause unten).

## Problem in unserem Fall (Root Cause)

### Beobachtetes Fehlverhalten

- Upgrade von `1.5.2` auf `1.5.99.3` bricht mit:
  - `Acquire docker for synOCR when 0x0002 (fail)`
- Fehler tritt auf, bevor `postinst` ausgefuehrt wird.
- `postinst`/`postupgrade` laufen zwar spaeter, koennen den Worker-Fehler aber nicht mehr verhindern.

### Warum das passiert

1. In DSM7 wird `conf/resource` vom Framework frueh verarbeitet; der Docker-Worker wird im Upgrade-Pfad bereits vor `postinst` akquiriert.
2. Laut Synology-Doku ist Docker-Resource `Updatable: No` (nicht dynamisch im Lifecycle umschaltbar).
3. Die Versuche, `conf/resource` im `preinst` fuer Upgrade auf minimal umzuschreiben, scheiterten mit `Permission denied`:
   - die entpackte `conf/resource` war im relevanten Moment fuer den Paketuser nicht beschreibbar.
4. Deshalb konnte der Docker-Block im selben SPK nicht rechtzeitig entfernt werden, und DSM versucht weiterhin den fehlerhaften `Acquire docker`-Pfad.

### Ergebnis

Mit **einem einzigen SPK** war in unseren Tests kein robuster Zustand erreichbar, der gleichzeitig:
- Neuinstallation mit automatischem `getroot` (Docker-Worker aktiv),
- und Legacy-Upgrade von `1.5.2` (Docker-Worker darf nicht aktiv werden)

zuverlaessig abdeckt.

## Wiederverwendbarer Prompt fuer spaetere Wiederaufnahme

Folgenden Prompt kannst du direkt in eine neue Agent-Session geben:

```text
Kontext:
Wir haben ein DSM7-SPK (synOCR) mit getroot-Helper via Docker-Resource-Worker.
Neuinstallation funktioniert, aber Upgrade von 1.5.2 -> 1.5.99.x scheitert mit:
"Acquire docker for synOCR when 0x0002 (fail)".
Wichtige Erkenntnisse aus bisherigen Tests:
- Docker-Worker wird im Upgrade vor postinst akquiriert.
- postinst kommt zu spaet, um Acquire-Fehler zu verhindern.
- Umschreiben von conf/resource in preinst schlug mit Permission denied fehl.
- Synology-Doku: Docker-Resource ist "Updatable: No".
- Zwei unterschiedliche SPKs wollen wir NICHT (zu komplex fuer Nutzer).

Aufgabe:
1) Analysiere den aktuellen Code- und Skriptstand im Repo.
2) Entwickle eine EIN-SPK-Strategie, die:
   - Legacy-Upgrade robust macht
   - und moeglichst viel der getroot-Automatisierung erhaelt.
3) Wenn technisch nicht loesbar, liefere eine klare, belegte Entscheidungsvorlage:
   - Option A: Docker-Resource beibehalten, Legacy-Upgrade bleibt limitiert
   - Option B: Docker-Resource entfernen, Upgrade stabil, Rechte-Setup manuell.
4) Hinterlege konkrete Dateiaenderungen (Patch) und Testplan.

Bitte arbeite streng logbasiert:
- synopkg.log
- /var/log/packages/synOCR.log
- /tmp/synOCR.upgrade-debug.log
- /tmp/synOCR.lifecycle.trace
und gib fuer jede Schlussfolgerung den Log-Hinweis an.
```

## Kurzfazit

Das Problem war nicht SQL, nicht xattrs und nicht nur ein Symlink-Layoutthema, sondern ein DSM-Framework-Uebergang:
Der Docker-Resource-Worker im Upgrade-Lifecycle ist der harte Engpass. Ohne veraenderbare Resource-Phase vor `Acquire docker` laesst sich der Legacy-Upgradefall im Ein-SPK-Ansatz nur eingeschraenkt abbilden.
