#!/bin/bash
# shellcheck disable=SC2034
# Add synOCR package repository to /usr/syno/etc/packages/feeds (DSM).
# Prepares merged JSON under synOCR etc/, then uses Docker to overwrite the
# existing feeds file in place (cat new > feeds) so owner/mode stay unchanged.

# Environment (required):
#   SYNOCR_APP_HOME       — synOCR UI root (directory containing etc/); absolute after canonicalize
#   SYNOCR_REPO_NAME      — display name for Package Center
#   SYNOCR_REPO_FEED      — feed URL
# Optional:
#   SYNOCR_REPO_HOST_PATTERN — if set, grep -Fq on feeds counts as "already present"
#
# Exit codes:
#   0  success (feed was added)
#   7  feed already present; nothing changed
#   2  docker not available
#   3  feeds file missing or not readable
#   4  feeds is not a JSON array or invalid JSON
#   5  merge / validation failed
#   6  docker in-place write failed
#   8  missing environment

set -u

FEEDS_HOST="/usr/syno/etc/packages/feeds"
ALPINE_IMAGE="alpine:3.19"

if [ -z "${SYNOCR_APP_HOME:-}" ] || [ -z "${SYNOCR_REPO_NAME:-}" ] || [ -z "${SYNOCR_REPO_FEED:-}" ]; then
    exit 8
fi
if [ ! -d "${SYNOCR_APP_HOME}" ]; then
    exit 8
fi
SYNOCR_APP_HOME=$(cd "${SYNOCR_APP_HOME}" && pwd) || exit 8

SYNOCR_ETC="${SYNOCR_APP_HOME}/etc"
NEW_FILE="${SYNOCR_ETC}/packages_feeds.new.$$"

if ! command -v docker >/dev/null 2>&1; then
    exit 2
fi
if ! docker info >/dev/null 2>&1; then
    exit 2
fi

if [ ! -r "${FEEDS_HOST}" ]; then
    exit 3
fi

if ! jq -e 'type == "array"' "${FEEDS_HOST}" >/dev/null 2>&1; then
    exit 4
fi

if jq -e --arg feed "${SYNOCR_REPO_FEED}" '.[] | select(.feed == $feed or .feed == ($feed + "/") or .feed == ($feed | sub("/$"; "")))' "${FEEDS_HOST}" >/dev/null 2>&1; then
    exit 7
fi
if [ -n "${SYNOCR_REPO_HOST_PATTERN:-}" ] && grep -Fq "${SYNOCR_REPO_HOST_PATTERN}" "${FEEDS_HOST}"; then
    exit 7
fi

umask 022
if ! jq --arg name "${SYNOCR_REPO_NAME}" --arg feed "${SYNOCR_REPO_FEED}" '. + [{"name": $name, "feed": $feed}]' "${FEEDS_HOST}" > "${NEW_FILE}.tmp" 2>/dev/null; then
    rm -f "${NEW_FILE}.tmp" 2>/dev/null
    exit 5
fi
if ! jq -e . "${NEW_FILE}.tmp" >/dev/null 2>&1; then
    rm -f "${NEW_FILE}.tmp" 2>/dev/null
    exit 5
fi
if ! mv -f "${NEW_FILE}.tmp" "${NEW_FILE}" 2>/dev/null; then
    rm -f "${NEW_FILE}.tmp" 2>/dev/null
    exit 5
fi

backup_path="${SYNOCR_ETC}/packages_feeds.backup.$(date +%s)"
if ! cp -p "${FEEDS_HOST}" "${backup_path}" 2>/dev/null; then
    rm -f "${NEW_FILE}" 2>/dev/null
    exit 5
fi

if ! docker run --rm \
    -v "${FEEDS_HOST}:/target/feeds:rw" \
    -v "${NEW_FILE}:/source/new:ro" \
    "${ALPINE_IMAGE}" \
    sh -c 'cat /source/new > /target/feeds' >/dev/null 2>&1; then
    rm -f "${NEW_FILE}" 2>/dev/null
    exit 6
fi

rm -f "${NEW_FILE}" 2>/dev/null
exit 0
