#!/bin/bash

# Register a GitHub Actions self-hosted runner for the specified organization.
# This script is called by setup.sh during instance initialization.
#
# Prerequisites:
# * The GITHUB_TOKEN environment variable must be set (fine-grained PAT with admin:org permission)
# * The actions-runner software must already be downloaded and extracted
# * The runner name must be provided as first argument
#
# Usage: register_runner.sh <runner-name>

set -eo pipefail

msg() { echo "##### ${1:-No message provided}"; }
die() { echo "ERROR: ${1:-No error message provided}"; exit 1; }

[[ -n "$GITHUB_TOKEN" ]] || \
    die "GITHUB_TOKEN environment variable must be set"

[[ "$#" -ge 1 ]] || \
    die "Must provide runner name as first argument"

RUNNER_NAME="$1"
GITHUB_ORG="podman-io"
RUNNER_GROUP="mac-pool"
RUNNER_LABELS="self-hosted,macOS,ARM64,github"

# Directory where actions-runner is installed (in worker user's home)
# Extract worker username from runner name (e.g., MacM1-7 → MacM1-7-worker)
PWUSER="${RUNNER_NAME}-worker"
RUNNER_DIR="/Users/$PWUSER/actions-runner"

[[ -d "$RUNNER_DIR" ]] || \
    die "Actions runner directory not found: $RUNNER_DIR"

msg "Requesting registration token from GitHub API for org '$GITHUB_ORG'"

# Get registration token from GitHub API
# Ref: https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-an-organization
REG_TOKEN_JSON=$(curl -sSLf \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/orgs/$GITHUB_ORG/actions/runners/registration-token") || \
    die "Failed to get registration token from GitHub API"

REG_TOKEN=$(echo "$REG_TOKEN_JSON" | jq -r '.token')

[[ -n "$REG_TOKEN" ]] && [[ "$REG_TOKEN" != "null" ]] || \
    die "Failed to extract registration token from API response"

msg "Configuring runner '$RUNNER_NAME' for org '$GITHUB_ORG'"

# Configure the runner
# --unattended: non-interactive mode
# --url: organization URL
# --token: registration token (1 hour expiry)
# --name: runner name (must match instance name)
# --runnergroup: runner group name
# --labels: comma-separated labels
# --work: working directory for jobs
cd "$RUNNER_DIR"

./config.sh \
    --unattended \
    --url "https://github.com/$GITHUB_ORG" \
    --token "$REG_TOKEN" \
    --name "$RUNNER_NAME" \
    --runnergroup "$RUNNER_GROUP" \
    --labels "$RUNNER_LABELS" \
    --work "/private/tmp/actions-runner/_work" || \
    die "Failed to configure runner"

msg "Runner '$RUNNER_NAME' registered successfully"
