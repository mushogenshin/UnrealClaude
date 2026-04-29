#!/usr/bin/env bash
# Build the UnrealClaude plugin against UE 5.7 on macOS via UAT.
# Invokable from anywhere — paths are absolute.
#
# Prerequisites:
#   - UE 5.7 installed (Launcher build at $UE_ROOT works fine; no source
#     build needed since 5.7 doesn't have the macOS 26 / Xcode 17 issues
#     the 4.25 port had to fight through).
#   - Plugin sources on branch master (or wherever the 5.7-targeted code
#     lives — NOT ue4.25-port).
#
# Output lands in $REPO_ROOT/Build_5.7. Copy that into your UE 5.7 project's
# Plugins/ directory (Option A in README.md) to use it.

set -euo pipefail

UE_ROOT="${UE_ROOT:-/Users/Shared/EpicGames/UE_5.7}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="${REPO_ROOT}/UnrealClaude/UnrealClaude.uplugin"
OUTPUT="${REPO_ROOT}/Build_5.7"

if [[ ! -x "${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh" ]]; then
  echo "error: RunUAT.sh not found under UE_ROOT=${UE_ROOT}" >&2
  echo "set UE_ROOT to your UE 5.7 engine root, e.g.:" >&2
  echo "  UE_ROOT=\"/Users/Shared/Epic Games/UE_5.7\" $0" >&2
  exit 1
fi

echo "==> Building UnrealClaude plugin (UE 5.7)"
echo "    engine:  ${UE_ROOT}"
echo "    plugin:  ${PLUGIN}"
echo "    output:  ${OUTPUT}"
echo

exec "${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh" BuildPlugin \
  -Plugin="${PLUGIN}" \
  -Package="${OUTPUT}" \
  -TargetPlatforms=Mac
