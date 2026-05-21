#!/bin/bash

# Launch GitHub Actions runner listener & manager process.
# Intended to be called once from setup.sh on M1 Macs.

set -o pipefail

msg() { echo "##### ${1:-No message message provided}"; }
die() { echo "ERROR: ${1:-No error message provided}"; exit 1; }

for varname in PWUSER PWREADYURL PWREADY GITHUB_TOKEN; do
    varval="${!varname}"
    [[ -n "$varval" ]] || \
        die "Env. var. \$$varname is unset/empty."
done

[[ "$USER" == "ec2-user" ]] || \
    die "Expecting to execute as 'ec2-user'."

# All operations assume this CWD
cd $HOME

# For whatever reason, when this script is run through ssh, the default
# environment isn't loaded automatically.
. /etc/profile

# This can be leftover under certain conditions
# shellcheck disable=SC2154
sudo pkill -u $PWUSER -f "Runner.Listener" || true

# Configuring a launchd agent to run the runner process is a major
# PITA and seems to require rebooting the instance.  Work around
# this with a really hacky loop masquerading as a system service.
# envar exported to us
# shellcheck disable=SC2154
RUNNER_DIR="/Users/$PWUSER/actions-runner"

while [[ "$PWREADY" == "true" ]]; do  # Change tag to shutdown this "service"
    # The $PWUSER has access to kill it's own listener, or it could crash.
    if ! pgrep -u $PWUSER -f -q "Runner.Listener"; then
        msg "$(date -u -Iseconds) Starting GitHub Actions runner as $PWUSER"
        # This is intended for user's setup.log
        # shellcheck disable=SC2024
        sudo su -l $PWUSER -c "cd $RUNNER_DIR && ./run.sh &" >>setup.log 2>&1 &
        sleep 10  # eek!
    fi

    # This can fail on occasion for some reason
    # envar exported to us
    # shellcheck disable=SC2154
    if ! PWREADY=$(curl -sSLf $PWREADYURL); then
        PWREADY="recheck"
    fi

    # Avoid re-launch busy-wait
    sleep 10

    # Second-chance
    if [[ "$PWREADY" == "recheck" ]] && ! PWREADY=$(curl -sSLf $PWREADYURL); then
        msg "Failed twice to obtain PWPoolReady instance tag.  Disabling runner."
        break
    fi
done

set +e

msg "PWPoolReady tag '$PWREADY'."
msg "Terminating $PWUSER GitHub Actions runner process"
# N/B: This will _not_ stop the runner (i.e. a running task)
sudo pkill -u $PWUSER -f "Runner.Listener"
