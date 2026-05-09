#!/usr/bin/env bash
# Parse-check every staged shell / python file. Catches the entire class of
# "deploy script that fails on first run because of a bad quote".
set -euo pipefail
LC_ALL=C

fails=()
while IFS= read -r f; do
  [[ -z "$f" || ! -f "$f" ]] && continue
  case "$f" in
    *.sh)
      bash -n "$f" 2>&1 | sed "s|^|$f: |" >&2 \
        || fails+=("$f: bash -n")
      ;;
    *.py)
      python3 -m py_compile "$f" 2>&1 | sed "s|^|$f: |" >&2 \
        || fails+=("$f: py_compile")
      ;;
  esac
done <<<"$STAGED"

(( ${#fails[@]} == 0 )) || { printf '%s\n' "${fails[@]}"; exit 1; }
