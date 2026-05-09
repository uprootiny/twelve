#!/usr/bin/env bash
# Reject placeholder credential files that look like they should be real.
# Cause: a 2-byte rotated-sheets-key.json was sitting in the repo's parent
# directory long enough to confuse a deploy probe. .gitignore already blocks
# the obvious shapes; this catches anything that slips by with .example-less
# naming.
set -euo pipefail
LC_ALL=C

fails=()
while IFS= read -r f; do
  case "$f" in
    *.example | *.sample | *.tmpl) continue ;;
    *.json | *.key | *.pem | *credentials* | *-key.* )
      [[ -f "$f" ]] || continue
      sz=$(wc -c <"$f" | tr -d ' ')
      (( sz < 8 )) && fails+=("$f: $sz bytes — placeholder? rename to ${f}.example or fill it in")
      ;;
  esac
done <<<"$STAGED"

(( ${#fails[@]} == 0 )) || { printf '%s\n' "${fails[@]}"; exit 1; }
