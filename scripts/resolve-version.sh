#!/usr/bin/env bash
# Resolve application version from CI tag context or repository tags.
# Output format: x.y.z (without leading "v").

set -euo pipefail

explicit_input="${1:-}"

normalize_version() {
  local raw="${1:-}"
  raw="${raw#v}"
  echo "$raw"
}

is_semver_core() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

if [[ -n "$explicit_input" ]]; then
  version="$(normalize_version "$explicit_input")"
  if is_semver_core "$version"; then
    echo "$version"
    exit 0
  fi
fi

# Prefer explicit tag context from GitHub Actions.
if [[ -n "${GITHUB_REF:-}" && "${GITHUB_REF}" =~ ^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  version="$(normalize_version "${GITHUB_REF#refs/tags/}")"
  echo "$version"
  exit 0
fi

if [[ "${GITHUB_REF_TYPE:-}" == "tag" && -n "${GITHUB_REF_NAME:-}" ]]; then
  version="$(normalize_version "${GITHUB_REF_NAME}")"
  if is_semver_core "$version"; then
    echo "$version"
    exit 0
  fi
fi

# Fallback: highest published tag or committed app version. A fork may import
# newer code before publishing its next tag; prebuild must not downgrade it.
latest_tag="$(git tag --list "v*.*.*" --sort=-version:refname | sed -n '1p')"
manifest_version="$(sed -n 's/^version:[[:space:]]*\([^[:space:]+]*\).*$/\1/p' pubspec.yaml 2>/dev/null || true)"
candidates=()
for candidate in "$latest_tag" "$manifest_version"; do
  version="$(normalize_version "$candidate")"
  if is_semver_core "$version"; then
    candidates+=("$version")
  fi
done
if (( ${#candidates[@]} )); then
  printf '%s\n' "${candidates[@]}" | sort -V | tail -n 1
  exit 0
fi

echo "Unable to resolve version from explicit input, CI tag context, repository tags, or pubspec.yaml" >&2
exit 1
