# synOCR DSM-7-setuid-Helper

## Das Problem

Unter DSM 7 laufen Paket-Skripte (`postinst`, `start-stop-status`, GUI) als **Paket-User `synOCR`**, nicht als root. Das steht in `PKG_DSM7/conf/privilege` (`run-as: package`).

synOCR braucht trotzdem Dinge, die dieser User allein nicht darf:

- in die Gruppen `docker` und `administrators` aufgenommen werden
- Besitz von `/var/run/docker.sock` auf `root:docker` setzen
- verschlüsselte Freigaben auflisten (`synoshare --enum ENC`)

Früher musste der User nach der Installation **einmal** `synOCR-start.sh` als root starten. Genau das ersetzt der Helper: der Paket-User löst eine **enge, fest verdrahtete** Root-Aktion aus, ohne SSH und ohne freien Root-Shell.

Das ist in erster Linie **Benutzerfreundlichkeit**, kein komplettes Sicherheits-Redesign. Wer User `synOCR` plus Docker-Socket kontrolliert, bleibt root-äquivalent — das war vorher schon so.

## Was „setuid“ hier bedeutet

Ein normales Programm läuft mit den Rechten dessen, der es startet. Ein Binary mit gesetztem **setuid-Bit** läuft mit den Rechten des **Dateibesitzers**. Unser Binary gehört `root` und hat Mode **6550** (`-r-sr-x---` bzw. mit setgid `-r-sr-s---`):

- Besitzer `root` → beim Start effektives uid 0
- Gruppe Paket (`synOCR`) darf ausführen
- alle anderen (`others`) dürfen es **nicht** (deshalb `Permission denied` als normaler DSM-Admin per SSH)

DSM setzt Besitz und Mode bei der Paketinstallation über den `tool`-Eintrag in `PKG_DSM7/conf/privilege`. Die Skripte selbst können das nicht, weil `postinst` ebenfalls nur als `synOCR` läuft.

Zwei Binaries im SPK, weil ein Paket `x86_64` und `armv8` abdeckt:

- `APP/bin/helper/synocr-helper-x86_64`
- `APP/bin/helper/synocr-helper-aarch64`

Zur Laufzeit wählt `synocr_helper_bin()` in `APP/ui/includes/functions.sh` per `uname -m`.

`join-groupname: system` in derselben `privilege`-Datei bleibt vorerst. Entfernen hatte früher die GUI blockiert; das ist unabhängig vom Helper und ein eigenes Follow-up.

## Ablauf

```
Install / GUI / synOCR-start.sh  (User synOCR)
        │
        │  nur wenn Helper existiert und setuid hat (-u)
        ▼
synocr-helper-<arch>  selfheal | enc-enum
        │  setuid(0), Umgebung leeren, festes PATH
        │  öffnet synocr-heal.sh, fexecve
        ▼
/var/packages/synOCR/target/ui/includes/synocr-heal.sh
        │  läuft als root
        ▼
selfheal  →  docker-Gruppe, docker.sock, administrators, optionale Dateirechte
enc-enum  →  synoshare --enum ENC  (stdout)
```

Wer ruft wann auf:

| Aufrufer | Verb | Wann |
|----------|------|------|
| `PKG_DSM7/scripts/postinst` | `selfheal` | direkt nach Install, falls setuid schon gesetzt |
| `APP/ui/synOCR-start.sh` | `selfheal` | DSM 7, nicht root, Gruppen/Sock fehlen |
| `APP/ui/GUI_main.sh` | `selfheal` | gleiche Prüfung vor der Statusanzeige |
| `APP/ui/synOCR-start.sh` (Monitoring) | `enc-enum` | verschlüsselte INPUTDIR-Freigaben erkennen |
| Aufgabenplaner als **root** | — | kein Helper; `synOCR-start.sh` heilt direkt (`synogroupmod*`) |

Ist der Helper beim `postinst` noch ohne setuid, heilt der **erste** GUI- oder Paket-Start nach.

## Die zwei Verben

Der C-Helper akzeptiert **genau ein Argument**, ohne weitere Parameter:

| Verb | Zweck |
|------|--------|
| `selfheal` | docker-Gruppe anlegen falls nötig, `chown root:docker` auf den Socket, User `synOCR` in `docker` und `administrators`, optional `python3_env`/`synOCR.sqlite`-Rechte. Idempotent. Log: `ui/etc/selfheal.log` |
| `enc-enum` | `synoshare --enum ENC` — Liste verschlüsselter Share-Namen. Für den Inotify-Start, wenn INPUTDIR noch nicht gemountet ist |

Alles andere wird abgelehnt. Es gibt **keinen** Weg, über den Helper ein beliebiges Skript oder `docker run` zu starten.

## Wichtige Implementierungsdetails

**fexecve:** Das Binary öffnet `synocr-heal.sh` einmal (`O_NOFOLLOW`), prüft die Datei über diesen Descriptor, setzt sie bei Bedarf auf root/`0555` und startet **denselben** Descriptor. So kann niemand die Datei zwischen Prüfung und Ausführung austauschen.

**`$0` ist `/dev/fd/N`:** Genau deshalb darf `synocr-heal.sh` sein Verzeichnis **nicht** aus `$0` ableiten. `APPDIR` ist fest `/var/packages/synOCR/target/ui`.

**Umgebung:** `clearenv()`, dann nur `PATH` (inkl. `/usr/syno/sbin`) und `HOME=/root`. Keine geerbten Variablen vom Aufrufer.

**Direkt als root** (Aufgabenplaner) bleibt erlaubt: `synocr-heal.sh` prüft `id -u`, nicht den Helper.

Manueller Test (als root, Ausführung erfolgt trotzdem über setuid als Paket-User):

```bash
sudo -u synOCR /var/packages/synOCR/target/bin/helper/synocr-helper-$(uname -m) selfheal
```

Ein normaler DSM-User ohne Gruppe `synOCR` bekommt `Permission denied` — das ist gewollt.

## Encrypted INPUTDIR wait

Beim Start von Monitoring prüft `synOCR-start.sh` aktive `INPUTDIR`s. Gehört ein fehlender Pfad zu einem verschlüsselten Share (`enc-enum` oder Fallback `@Share@`), wartet ein Hintergrundprozess, bis der Ordner da ist (Standard 900 s; System-Key `monitor_start_wait`: `0` = aus, `-1` = unbegrenzt). Log: `ui/etc/monitor-wait.log`.

## Binaries neu bauen

Linux-ELFs (statisch, musl), nicht macOS-Mach-O. Erst `zig cc`, sonst Docker/Alpine. Das Makefile ruft nur das Skript:

```
./helper/build.sh
./helper/build.sh --help
make -C helper
```

Ergebnis: `APP/bin/helper/synocr-helper-{x86_64,aarch64}` — die gehören ins Git bzw. ins SPK.

## NAS-Testcheckliste

1. SPK: `./build_spk.sh -v=local --dsm=7`
2. Auf DSM 7 installieren oder upgraden.
3. setuid: `ls -l /var/packages/synOCR/target/bin/helper/synocr-helper-*`
4. Heal-Log: `/var/packages/synOCR/target/ui/etc/selfheal.log`
5. **Nicht** das Startskript als root ausführen. GUI öffnen / Monitoring starten.
6. `synOCR` in `docker` und `administrators`; Socket `root:docker`.
7. Drift: User aus `docker` nehmen oder `chown root:root /var/run/docker.sock` — erneuter Start soll heilen.
8. Verschlüsseltes INPUTDIR: Reboot mit gesperrter Freigabe → Einträge in `monitor-wait.log` → nach Unlock startet inotify.
9. Regression: OCR-Lauf, inotify, Aufgabenplaner als root.
10. GUI startet weiterhin (`join-groupname: system` unverändert).

## Follow-up

- Klären, ob `join-groupname: system` mit stabilem Helper noch nötig ist (`APP/ui/privilege` vs. `PKG_DSM7/conf/privilege`).
