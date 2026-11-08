#!/usr/bin/env bash
# Installs every scanner, checksum- or hash-pinned, into $BIN and $VENVS. Runs without secrets.
# Usage: install-scanners.sh   env: BIN VENVS RUNNER_TEMP
set -euo pipefail
sec=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$BIN" "$VENVS"
cd "$RUNNER_TEMP"
get() {
  local url=$1 api=$2 file=${1##*/}
  local options=(--retry 4 --retry-delay 2 --retry-max-time 300
    --connect-timeout 20 --max-time 120 --silent --show-error --fail --location)
  echo "Downloading $file"
  if curl "${options[@]}" --output "$file" "$url"; then
    return 0
  fi
  # The release download CDN can retain a failing redirect. The asset API
  # provides a separate official route to the same immutable, checksum-pinned file.
  echo "Release download failed; trying GitHub asset API for $file" >&2
  curl "${options[@]}" --header 'Accept: application/octet-stream' \
    --output "$file" "$api"
}

get https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz \
  https://api.github.com/repos/gitleaks/gitleaks/releases/assets/378332058
echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks_8.30.1_linux_x64.tar.gz" | sha256sum -c -
tar -xzf gitleaks_8.30.1_linux_x64.tar.gz -C "$BIN" gitleaks

get https://github.com/google/osv-scanner/releases/download/v2.6.0/osv-scanner_linux_amd64 \
  https://api.github.com/repos/google/osv-scanner/releases/assets/562414718
echo "ca69b3d3cd08f889a49dc0a383122f71cc528b83803671df5fd874d97485b108  osv-scanner_linux_amd64" | sha256sum -c -
install -m 755 osv-scanner_linux_amd64 "$BIN/osv-scanner"

get https://github.com/aquasecurity/trivy/releases/download/v0.70.0/trivy_0.70.0_Linux-64bit.tar.gz \
  https://api.github.com/repos/aquasecurity/trivy/releases/assets/398381981
echo "8b4376d5d6befe5c24d503f10ff136d9e0c49f9127a4279fd110b727929a5aa9  trivy_0.70.0_Linux-64bit.tar.gz" | sha256sum -c -
tar -xzf trivy_0.70.0_Linux-64bit.tar.gz -C "$BIN" trivy

get https://github.com/ossf/scorecard/releases/download/v5.5.0/scorecard_5.5.0_linux_amd64.tar.gz \
  https://api.github.com/repos/ossf/scorecard/releases/assets/403812999
echo "83b90a05c1540ef1390db1cd5711e5fd04be9c1d8537fb84d39d02092d6a8dff  scorecard_5.5.0_linux_amd64.tar.gz" | sha256sum -c -
tar -xzf scorecard_5.5.0_linux_amd64.tar.gz -C "$BIN" scorecard

# one venv per tool; --no-deps: the lockfiles are complete (mobsfscan's overrides semgrep's mcp/pyjwt pins)
pids=()
for t in semgrep mobsfscan zizmor; do
  { python3 -m venv "$VENVS/$t" \
      && "$VENVS/$t/bin/pip" install --quiet --require-hashes --no-deps -r "$sec/requirements-$t.txt"; } &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p" || exit 1; done
