#!/bin/bash

set -eo pipefail

# Helper for humans to copy files to an existing instance.  It depends on:
#
# * You know the instance-id or name.
# * All requirements listed in the top `LaunchInstances.sh` comment.
# * The local ssh-agent is able to supply the appropriate private key.
#
# Usage: instanceSCP.sh <instance-id|name> <localpath>:<remotepath> [<localpath>:<remotepath> ...]

# shellcheck source-path=SCRIPTDIR
source $(dirname ${BASH_SOURCE[0]})/pw_lib.sh

[[ -n "$1" ]] || \
    die "Must provide EC2 instance ID or name as first argument"

[[ -n "$2" ]] || \
    die "Must provide at least one path in format 'localpath:remotepath' as second argument"

INSTANCE_ID="$1"
shift

# Get instance information
case "$INSTANCE_ID" in
    i-*)
      inst_json=$($AWS ec2 describe-instances --instance-ids "$INSTANCE_ID") ;;
    *)
      inst_json=$($AWS ec2 describe-instances --filter "Name=tag:Name,Values=$INSTANCE_ID") ;;
esac

pub_dns=$(jq -r -e '.Reservations?[0]?.Instances?[0]?.PublicDnsName?' <<<"$inst_json")
if [[ -z "$pub_dns" ]] || [[ "$pub_dns" == "null" ]]; then
    die "Instance '$INSTANCE_ID' does not exist, or does not have a public DNS address allocated (yet)."
fi

# Perform the copy for each path specification
for PATH_SPEC in "$@"; do
    # Validate path specification format
    if [[ ! "$PATH_SPEC" =~ ^([^:]+):(.+)$ ]]; then
        die "Path specification must be in format 'localpath:remotepath', got: $PATH_SPEC"
    fi

    LOCAL_PATH="${BASH_REMATCH[1]}"
    REMOTE_PATH="${BASH_REMATCH[2]}"

    # Verify local path exists
    if [[ ! -e "$LOCAL_PATH" ]]; then
        die "Local path does not exist: $LOCAL_PATH"
    fi

    echo "+ $SCP $LOCAL_PATH ec2-user@$pub_dns:$REMOTE_PATH" >> /dev/stderr
    $SCP "$LOCAL_PATH" "ec2-user@$pub_dns:$REMOTE_PATH"
done
