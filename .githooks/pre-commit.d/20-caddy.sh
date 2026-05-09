#!/usr/bin/env bash
# Every staged Caddyfile snippet must be `caddy adapt`-clean and `caddy fmt`-clean.
# No-op if caddy isn't installed locally; CI installs it.
set -euo pipefail
LC_ALL=C

command -v caddy >/dev/null 2>&1 || exit 0

fails=()
while IFS= read -r f; do
  case "$f" in
    *Caddyfile* | *.caddyfile) ;;
    *) continue ;;
  esac
  [[ -f "$f" ]] || continue
  caddy adapt --config "$f" --adapter caddyfile >/dev/null 2>&1 \
    || { fails+=("$f: caddy adapt failed"); continue; }
  diff -q <(cat "$f") <(caddy fmt - <"$f") >/dev/null 2>&1 \
    || fails+=("$f: not caddy-fmt'd — run: caddy fmt --overwrite $f")
done <<<"$STAGED"

(( ${#fails[@]} == 0 )) || { printf '%s\n' "${fails[@]}"; exit 1; }
