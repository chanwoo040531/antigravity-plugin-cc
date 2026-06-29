#!/usr/bin/env bash
#
# Verify the plugin version is consistent across all manifests, and — when a
# release tag is supplied — that it matches the tag and has CHANGELOG notes.
#
# Usage:
#   scripts/check-version.sh            # CI mode: assert the 3 version fields agree
#   scripts/check-version.sh v0.3.0     # release mode: also assert they equal the
#                                       # tag (minus the leading "v") and that
#                                       # CHANGELOG.md has a matching section.
#
# The version lives in three places that must stay in sync:
#   - plugins/agy/.claude-plugin/plugin.json   .version
#   - .claude-plugin/marketplace.json          .metadata.version
#   - .claude-plugin/marketplace.json          .plugins[0].version
#
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

plugin_manifest="plugins/agy/.claude-plugin/plugin.json"
marketplace_manifest=".claude-plugin/marketplace.json"
changelog="plugins/agy/CHANGELOG.md"

# Validate JSON before reading any field.
jq empty "$plugin_manifest" "$marketplace_manifest"

plugin_version="$(jq -r '.version' "$plugin_manifest")"
marketplace_metadata_version="$(jq -r '.metadata.version' "$marketplace_manifest")"
marketplace_plugin_version="$(jq -r '.plugins[0].version' "$marketplace_manifest")"

echo "plugin.json .version                 = $plugin_version"
echo "marketplace.json .metadata.version   = $marketplace_metadata_version"
echo "marketplace.json .plugins[0].version = $marketplace_plugin_version"

# All three must agree with each other regardless of mode.
if [ "$plugin_version" != "$marketplace_metadata_version" ] || \
   [ "$plugin_version" != "$marketplace_plugin_version" ]; then
  echo "ERROR: version fields are out of sync." >&2
  exit 1
fi

# CI mode: mutual agreement is all we can check without a tag.
if [ "$#" -eq 0 ]; then
  echo "OK: all version fields agree ($plugin_version)."
  exit 0
fi

# Release mode: compare against the tag, stripped of its single leading "v".
tag="$1"
tag_version="${tag#v}"
echo "release tag                          = $tag (version $tag_version)"

if [ "$tag_version" != "$plugin_version" ]; then
  echo "ERROR: tag $tag does not match plugin version $plugin_version." >&2
  exit 1
fi

# The CHANGELOG must carry a section for this exact version, or the release
# notes would be silently empty. Match a whole-line "## <version>" header.
if ! grep -qxE "## ${tag_version//./\\.}" "$changelog"; then
  echo "ERROR: $changelog has no '## $tag_version' section for the release notes." >&2
  exit 1
fi

echo "OK: tag, all version fields, and CHANGELOG section agree ($tag_version)."
