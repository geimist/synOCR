# synOCR DSM 7 setuid helper

Lets the package user `synOCR` run a single privileged heal (`selfheal`) so Docker
group membership, `docker.sock` ownership, and `administrators` membership can be
set without asking the user to start `synOCR-start.sh` as root after install.

DSM installs the binaries listed in `PKG_DSM7/conf/privilege` as `root:package`
mode `6550` (setuid). `join-groupname: system` is **kept** for now (removing it
previously prevented the GUI from starting). Revisit after this helper is proven.

Rebuild binaries (`zig cc` or Docker). Prefer the script — Makefile only wraps it:

```
./helper/build.sh
./helper/build.sh --help
make -C helper
```

## NAS test checklist

1. Build SPK: `./build_spk.sh -v=local --dsm=7`
2. Install or upgrade on DSM 7.
3. Confirm setuid: `ls -l /var/packages/synOCR/target/bin/helper/synocr-helper-*`
4. Heal-Log: `/var/packages/synOCR/target/ui/etc/selfheal.log`
5. Do **not** run the start script as root. Open the GUI / start monitoring.
6. Confirm `synOCR` is in `docker` and `administrators`; `docker.sock` is `root:docker`.
7. Drift: remove `synOCR` from `docker` or `chown root:root /var/run/docker.sock`, start again — should self-heal.
8. Regression: OCR run, inotify, Task Scheduler as root still works.
9. GUI still opens (`join-groupname: system` unchanged).

## Follow-up

- Investigate whether `join-groupname: system` is still required once the helper is stable (`APP/ui/privilege` vs `PKG_DSM7/conf/privilege`).
