#!/usr/bin/env bash
# Local placeholder guard — refuses to let a real-looking secret or
# identifier into the repo. Run before every commit (or wire into a hook).
#
#   ./scripts/scan.sh
#
# Exits non-zero if anything sensitive-looking is found.
set -euo pipefail
cd "$(dirname "$0")/.."

patterns=(
  'nsec1[A-Za-z0-9]{20,}'
  'npub1[A-Za-z0-9]{20,}'
  '[a-f0-9]{64}'
  'BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE'
  '"Bearer [A-Za-z0-9._-]{20,}'
)

# Pattern that must produce NO hits (use GNU-agnostic grep)
grep_or_pp() { grep -rInE "$1" . --exclude-dir=.git --exclude=scan.sh 2>/dev/null || true; }

rc=0
for p in "${patterns[@]}"; do
  hits="$(grep_or_pp "$p")"
  if [[ -n "$hits" ]]; then
    echo "::error::Possible secret/identifier leak:"
    echo "$hits"
    rc=1
  fi
done

# Literal IPs (but allow <HOST> style placeholders)
iphits="$(grep_or_pp '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b')"
if [[ -n "$iphits" ]]; then
  echo "::error::Literal IP found (use <HOST/RELAY_HOST> placeholders):"
  echo "$iphits"
  rc=1
fi

if [[ $rc -eq 0 ]]; then
  echo "scan: OK — no real secrets, keys, or IPs detected."
fi
exit $rc
