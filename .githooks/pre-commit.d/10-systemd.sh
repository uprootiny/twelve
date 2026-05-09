#!/usr/bin/env bash
# Validate any staged systemd unit file. No-op on hosts without
# systemd-analyze (developer macs); CI on Ubuntu will catch it.
set -euo pipefail
LC_ALL=C

command -v systemd-analyze >/dev/null 2>&1 || exit 0

fails=()
while IFS= read -r f; do
  [[ "$f" == *.service || "$f" == *.timer || "$f" == *.socket ]] || continue
  [[ -f "$f" ]] || continue
  systemd-analyze verify "$f" 2>&1 | sed "s|^|$f: |" >&2 \
    || fails+=("$f")
done <<<"$STAGED"

(( ${#fails[@]} == 0 )) || { printf '%s\n' "${fails[@]}"; exit 1; }
