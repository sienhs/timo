#!/usr/bin/env bash
# Embedded in CodeBuild's buildspec by Terraform. It does not run application CI itself.
set -euo pipefail
umask 077

: "${GITLAB_URL:?GitLab URL is required}"
: "${RUNNER_VERSION:?Pinned Runner version is required}"
: "${RUNNER_TOKEN:?Store the project Runner authentication token in Secrets Manager first}"

runner_dir=$(mktemp -d /tmp/timo-runner.XXXXXX)
runner_pid=""
cleanup() {
  rm -f -- "$runner_dir/config.toml"
}
stop_runner() {
  if [[ -n "$runner_pid" ]]; then
    kill -TERM "$runner_pid" 2>/dev/null || true
    wait "$runner_pid" || true
  fi
  exit 143
}
trap cleanup EXIT
trap stop_runner TERM INT

# A managed image normally starts Docker already; explicitly start it if needed.
if ! docker info >/dev/null 2>&1; then
  nohup /usr/local/bin/dockerd --host=unix:///var/run/docker.sock \
    --storage-driver=overlay2 >"$runner_dir/docker.log" 2>&1 &
  timeout 60 bash -c 'until docker info >/dev/null 2>&1; do sleep 1; done'
fi

release_url="https://gitlab-runner-downloads.s3.amazonaws.com/v${RUNNER_VERSION}"
curl --fail --silent --show-error --location --retry 3 \
  "$release_url/binaries/gitlab-runner-linux-amd64" -o "$runner_dir/gitlab-runner"
curl --fail --silent --show-error --location --retry 3 \
  "$release_url/release.sha256" -o "$runner_dir/release.sha256"
runner_sha=$(awk '$2 == "binaries/gitlab-runner-linux-amd64" {print $1}' "$runner_dir/release.sha256")
[[ "$runner_sha" =~ ^[0-9a-fA-F]{64}$ ]] || { echo "Runner checksum entry missing" >&2; exit 1; }
printf '%s  %s\n' "$runner_sha" "$runner_dir/gitlab-runner" | sha256sum --check --status
install -m 0755 "$runner_dir/gitlab-runner" /usr/local/bin/gitlab-runner

# JSON string encoding is valid for these TOML string values and keeps tokens out of commands/logs.
python3 - "$runner_dir/config.toml" <<'PY'
import json
import os
import sys

with open(sys.argv[1], "w", encoding="utf-8") as config:
    config.write('concurrent = 1\n[[runners]]\nname = "timo"\n')
    config.write("url = " + json.dumps(os.environ["GITLAB_URL"]) + "\n")
    config.write("token = " + json.dumps(os.environ["RUNNER_TOKEN"]) + "\n")
    config.write('executor = "docker"\n[runners.docker]\n')
    config.write('image = "alpine:3.22"\nprivileged = false\nvolumes = ["/cache"]\n')
    config.write('pull_policy = "always"\n')
PY
unset RUNNER_TOKEN

# The existing project Runner must accept untagged jobs and non-protected feature branches.
# GitLab chooses the matching job; the webhook's job ID is not a forced assignment.
# CI image:/artifacts:/variables: are handled by the Docker executor.
gitlab-runner run-single --config "$runner_dir/config.toml" --runner timo \
  --max-builds 1 --wait-timeout 60 &
runner_pid=$!
wait "$runner_pid"
# Job success/failure is reported by Runner to GitLab. CodeBuild status alone is not a CI verdict.
