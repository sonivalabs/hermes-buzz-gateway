#!/usr/bin/env bash
# Local placeholder guard — refuses to let a real-looking secret or
# identifier into the repo. Run before every commit (or wire into a hook).
#
#   ./scripts/scan.sh
#
# NOTE: scans the WORKING TREE only. It cannot see secrets committed earlier
# and later deleted — rotate any key that was ever committed, and consider the
# CI workflow (gitleaks with --uncommitted) for history scanning.
set -euo pipefail
cd "$(dirname "$0")/.."

patterns=(
  'nsec1[A-Za-z0-9]{20,}'
  'npub1[A-Za-z0-9]{20,}'
  '[a-f0-9]{64}'
  'BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE'
  '"Bearer [A-Za-z0-9._-]{20,}'
  # GitHub tokens
  'gh[pousr]_[A-Za-z0-9]{30,}'
  'github_pat_[A-Za-z0-9_]{30,}'
  # AWS access key id
  'AKIA[0-9A-Z]{16}'
  # OpenAI / generic sk-
  'sk-[A-Za-z0-9]{20,}'
  # Slack
  'xox[abprs]-[A-Za-z0-9-]{20,}'
  # Google / generic service-account style
  '(AIza[0-9A-Za-z_-]{20,})'
)

# PATTERNS that must produce NO hits (exclude .git so we don't flag our own refs)
grep_or_pp() { grep -rInE "$1" . --exclude-dir=.git --exclude-dir=target 2>/dev/null || true; }

rc=0
for p in "${patterns[@]}"; do
  hits="$(grep_or_pp "$p")"
  if [[ -n "$hits" ]]; then
    echo "::error::Possible secret/identifier leak:"
    echo "$hits"
    rc=1
  fi
done

# Literal IPs (allow placeholders like <HOST>)
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
