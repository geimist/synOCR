#!/bin/bash
# shellcheck disable=SC1091

APPDIR=$(cd "$(dirname "$0")" || exit 1; pwd)
LOGFILE="/var/log/packages/synOCR.permissions.log"
PATH="/usr/syno/sbin:/usr/syno/bin:/usr/local/bin:/opt/usr/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

cd "${APPDIR}" || exit 1
source "./includes/functions.sh"

if touch "${LOGFILE}" 2>/dev/null; then
    exec >>"${LOGFILE}" 2>&1
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') - check_permissions.sh start"
echo "PATH=${PATH}"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: check_permissions.sh must run as root."
    exit 10
fi

if [ ! -S /var/run/docker.sock ]; then
    echo "ERROR: docker.sock not available."
    exit 20
fi

if ! command -v synogroup >/dev/null 2>&1; then
    echo "ERROR: synogroup command not found in PATH."
    exit 21
fi

if check_permissions_needed; then
    echo "Permissions are not complete - applying fixes."
    synogroupmoddocker || exit 30
    synogroupmoduser add administrators synOCR || exit 40
else
    echo "Permissions already complete - no change required."
fi

if check_permissions_needed; then
    echo "ERROR: Permission check still failing after fix."
    exit 50
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - check_permissions.sh done"
exit 0
