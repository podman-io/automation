#!/bin/bash

# Cleanup script for CI artifacts between GitHub Actions runs
# This script backs up the current run to a "previous run" directory,
# removes the previous-previous run, and cleans temporary files.
#
# Should be called between CI runs or as part of maintenance.

set -eo pipefail

PWNAME=$(uname -n)
PWUSER=$PWNAME-worker

die() { echo "ERROR: ${1:-No error message provided}"; exit 1; }

# Verify we're running as the correct user
[[ "$USER" == "ec2-user" ]] || die "Must run as 'ec2-user'"

# Verify the worker user exists
id "$PWUSER" &> /dev/null || die "Worker user '$PWUSER' does not exist"

# Check if any jobs are currently running
pgrep -u "$PWUSER" -q -f "Runner.Worker" && die "Cannot cleanup while a job is running"

CI_WORK_DIR="/Users/$PWUSER/ci"
CI_TEMP_DIR="/private/tmp/ci"
CI_WORK_PREV="/Users/$PWUSER/ci.previous"
CI_TEMP_PREV="/private/tmp/ci.previous"

# Check if both directories are already empty (already rotated)
if [[ -d "$CI_WORK_DIR" ]] && [[ -d "$CI_TEMP_DIR" ]]; then
    if [[ -z "$(ls -A "$CI_WORK_DIR" 2>/dev/null)" ]] && [[ -z "$(ls -A "$CI_TEMP_DIR" 2>/dev/null)" ]]; then
        echo "Directories already empty, skipping rotation"
        exit 0
    fi
fi

# Rotate CI work directory: current -> previous, delete old previous
if [[ -d "$CI_WORK_DIR" ]]; then
    [[ -d "$CI_WORK_PREV" ]] && sudo rm -rf "$CI_WORK_PREV"
    [[ -n "$(ls -A "$CI_WORK_DIR" 2>/dev/null)" ]] && sudo cp -a "$CI_WORK_DIR" "$CI_WORK_PREV"
    sudo rm -rf "$CI_WORK_DIR"/* "$CI_WORK_DIR"/.??*
    sudo chown "$PWUSER:staff" "$CI_WORK_DIR"
    sudo chmod 0755 "$CI_WORK_DIR"
fi

# Rotate CI temp directory: current -> previous, delete old previous
if [[ -d "$CI_TEMP_DIR" ]]; then
    [[ -d "$CI_TEMP_PREV" ]] && sudo rm -rf "$CI_TEMP_PREV"
    [[ -n "$(ls -A "$CI_TEMP_DIR" 2>/dev/null)" ]] && sudo cp -a "$CI_TEMP_DIR" "$CI_TEMP_PREV"
    sudo rm -rf "$CI_TEMP_DIR"/* "$CI_TEMP_DIR"/.??*
    sudo chown "$PWUSER:staff" "$CI_TEMP_DIR"
    sudo chmod 1770 "$CI_TEMP_DIR"
fi

# Clean up podman-machine storage
sudo rm -rf "/Users/$PWUSER/.local/share/containers" "/Users/$PWUSER/.config/containers"

# Clean up build artifacts and caches
sudo rm -rf "/Users/$PWUSER/.cache" "/Users/$PWUSER/go/pkg" "/Users/$PWUSER/Library/Caches"

# Clean up system temp files (excluding ci and ci.previous)
sudo find /private/tmp -maxdepth 1 -user "$PWUSER" ! -name "ci" ! -name "ci.previous" -exec rm -rf {} + 2>/dev/null || true

echo "Cleanup complete at $(date -u -Iseconds)"
