#!/usr/bin/env bash
# Build the UnrealClaude plugin against UE 4.25-plus on macOS via UAT.
# Invokable from anywhere — paths are absolute.
#
# Prerequisites:
#   - UE 4.25-plus source-built and working at $UE_ROOT (this is what we
#     patched during the macOS 26 / Xcode 17 bring-up — see PORTING_NOTES.md).
#   - Plugin sources on branch ue4.25-port of this repo.
#
# Output lands in $REPO_ROOT/Build. Copy that into your UE 4.25 project's
# Plugins/ directory (Option A in README.md) to use it.

set -euo pipefail

UE_ROOT="${UE_ROOT:-/Users/Shared/EpicGames/UE_4.25-plus}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="${REPO_ROOT}/UnrealClaude/UnrealClaude.uplugin"
OUTPUT="${REPO_ROOT}/Build"

if [[ ! -x "${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh" ]]; then
  echo "error: RunUAT.sh not found under UE_ROOT=${UE_ROOT}" >&2
  echo "set UE_ROOT to your UE 4.25-plus engine root, e.g.:" >&2
  echo "  UE_ROOT=/path/to/UE_4.25-plus $0" >&2
  exit 1
fi

echo "==> Building UnrealClaude plugin"
echo "    engine:  ${UE_ROOT}"
echo "    plugin:  ${PLUGIN}"
echo "    output:  ${OUTPUT}"
echo

exec "${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh" BuildPlugin \
  -Plugin="${PLUGIN}" \
  -Package="${OUTPUT}" \
  -TargetPlatforms=Mac
