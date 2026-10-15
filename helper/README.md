# synOCR DSM 7 setuid helper

Lets the package user `synOCR` run narrow privileged verbs so Docker group
membership, `docker.sock` ownership, `administrators` membership, and encrypted
share enumeration work without a manual root start of `synOCR-start.sh`.

Allowed verbs (no extra arguments):

| Verb | Purpose |
|------|---------|
| `selfheal` | docker / administrators / permissions heal |
| `enc-enum` | `synoshare --enum ENC` (for inotify wait on encrypted INPUTDIRs) |

DSM installs the binaries listed in `PKG_DSM7/conf/privilege` as `root:package`
mode `6550` (setuid). `join-groupname: system` is **kept** for now (removing it
previously prevented the GUI from starting). Revisit after this helper is proven.

Rebuild binaries (`zig cc` or Docker). Prefer the script — Makefile only wraps it:

```
./helper/build.sh
./helper/build.sh --help
make -C helper
```

## Encrypted INPUTDIR wait

At package/monitor start, `synOCR-start.sh` checks active `INPUTDIR`s. If a
missing path belongs to an encrypted share (`enc-enum` or `@Share@` fallback),
a background waiter polls until the folder appears (default 900s; system key
`monitor_start_wait`: `0`=off, `-1`=unlimited). Log: `ui/etc/monitor-wait.log`.

## NAS test checklist

1. Build SPK: `./build_spk.sh -v=local --dsm=7`
2. Install or upgrade on DSM 7.
3. Confirm setuid: `ls -l /var/packages/synOCR/target/bin/helper/synocr-helper-*`
4. Heal-Log: `/var/packages/synOCR/target/ui/etc/selfheal.log`
5. Do **not** run the start script as root. Open the GUI / start monitoring.
6. Confirm `synOCR` is in `docker` and `administrators`; `docker.sock` is `root:docker`.
7. Drift: remove `synOCR` from `docker` or `chown root:root /var/run/docker.sock`, start again — should self-heal.
8. Encrypted INPUTDIR: reboot with share locked → waiter in `monitor-wait.log` → after unlock, inotify starts.
9. Regression: OCR run, inotify, Task Scheduler as root still works.
10. GUI still opens (`join-groupname: system` unchanged).

## Follow-up

- Investigate whether `join-groupname: system` is still required once the helper is stable (`APP/ui/privilege` vs `PKG_DSM7/conf/privilege`).
