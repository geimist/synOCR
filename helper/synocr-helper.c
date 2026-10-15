/*
 * synocr-helper.c
 *
 * Narrow setuid-root launcher for synOCR (DSM 7).
 * Installed by DSM as owner root:<package>, mode 6550 (setuid), from
 * PKG_DSM7/conf/privilege "tool" entries.
 *
 * Purpose (usability, not a security redesign):
 *   DSM 7 package scripts (postinst, start-stop-status, GUI) run as the
 *   package user "synOCR", which cannot join groups or chown docker.sock.
 *   Users previously had to start synOCR-start.sh once as root. This helper
 *   lets the package user run hardcoded privileged verbs instead.
 *
 * Allowed verbs (no extra arguments):
 *   selfheal   – docker/administrators heal script
 *   enc-enum   – list encrypted shared folder names (synoshare --enum ENC)
 *
 * The heal script is opened once, ownership/mode is locked through that
 * descriptor, then executed via fexecve so it cannot be swapped between
 * check and run.
 *
 * Rebuild:
 *   ./helper/build.sh
 *   make -C helper
 */

#define _GNU_SOURCE
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifndef TARGET_SCRIPT
#define TARGET_SCRIPT "/var/packages/synOCR/target/ui/includes/synocr-heal.sh"
#endif

static int verb_allowed(const char *verb)
{
    return strcmp(verb, "selfheal") == 0 || strcmp(verb, "enc-enum") == 0;
}

int main(int argc, char *argv[])
{
    if (argc != 2 || !verb_allowed(argv[1])) {
        fprintf(stderr, "synocr-helper: allowed verbs: selfheal, enc-enum (no extra arguments)\n");
        return 1;
    }

    /* setuid binary gives euid=0; promote ruid so the exec'd script is genuinely root. */
    if (setuid(0) != 0) {
        perror("synocr-helper: setuid(0) failed");
        return 1;
    }

    if (clearenv() != 0) {
        fprintf(stderr, "synocr-helper: clearenv failed\n");
        return 1;
    }
    setenv("PATH", "/usr/bin:/bin:/usr/sbin:/sbin:/usr/syno/bin:/usr/syno/sbin", 1);
    setenv("HOME", "/root", 1);

    /* No O_CLOEXEC: kernel runs a script through /dev/fd/N. */
    int fd = open(TARGET_SCRIPT, O_RDONLY | O_NOFOLLOW);
    if (fd < 0) {
        perror("synocr-helper: cannot open script");
        return 1;
    }
    struct stat st;
    if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode)) {
        fprintf(stderr, "synocr-helper: script is not a regular file\n");
        return 1;
    }
    /* postinst / first UI run: script is often still owned by the package user. */
    if (st.st_uid != 0) {
        if (fchown(fd, 0, st.st_gid) != 0 || fchmod(fd, 0555) != 0 ||
            fstat(fd, &st) != 0) {
            perror("synocr-helper: cannot secure script");
            return 1;
        }
    }
    if (st.st_uid != 0 || (st.st_mode & (S_IWGRP | S_IWOTH)) != 0) {
        fprintf(stderr, "synocr-helper: script is not root owned and write protected\n");
        return 1;
    }

    char *args[] = { (char *)TARGET_SCRIPT, argv[1], NULL };
    extern char **environ;
    fexecve(fd, args, environ);

    perror("synocr-helper: exec failed");
    return 1;
}
