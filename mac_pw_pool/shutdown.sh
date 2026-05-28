#!/bin/bash

# Script intended to be called by automation only.
# Should never be called from any other context.

# Log on the off-chance it somehow helps somebody debug something one day
(

echo "Starting ${BASH_SOURCE[0]} at $(date -u -Iseconds)"

PWNAME=$(uname -n)
PWUSER=$PWNAME-worker

if id -u "$PWUSER" &> /dev/null; then
    # Try to not reboot while a CI job is running.
    # GitHub Actions imposes a configurable timeout (default 2-hours for self-hosted runners).
    now=$(date -u +%s)
    timeout_at=$((now+60*60*2))
    echo "Waiting up to 2 hours for any pre-existing GitHub Actions worker (i.e. running job)"
    while pgrep -u $PWUSER -q -f "Runner.Worker"; do
        if [[ $(date -u +%s) -gt $timeout_at ]]; then
            echo "Timeout waiting for Runner.Worker to terminate"
            break
        fi
        echo "Found Runner.Worker still running, waiting..."
        sleep 60
    done
fi

echo "Initiating shutdown at $(date -u -Iseconds)"

# This script is run with a sleep in front of it
# as a workaround for darwin's shutdown-command
# terminal weirdness.

sudo shutdown -h now "Automatic instance recycling"

) < /dev/null >> setup.log 2>&1
