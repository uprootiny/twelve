#!/usr/bin/env bash
# Friction observed: twelve.py defaults to 9412 (local dev) while production
# runs on 47312 via TWELVE_PORT in the systemd unit. Both are intentional, but
# the production port must appear consistently across deploy artifacts. If a
# commit touches any of those files, all of them must still mention the port.
set -euo pipefail
LC_ALL=C

PROD_PORT=47312
ARTIFACTS=(
  deploy/hub2/Caddyfile.snippet
  deploy/hub2/install.sh
  deploy/nabla/Caddyfile.snippet
  deploy/nabla/twelve.service
  deploy/nabla/finish-everything.sh
)

touched=0
for f in "${ARTIFACTS[@]}"; do
  grep -qxF "$f" <<<"$STAGED" && touched=1
done
(( touched )) || exit 0

missing=()
for f in "${ARTIFACTS[@]}"; do
  [[ -f "$f" ]] || continue
  grep -qF "$PROD_PORT" "$f" || missing+=("$f")
done
(( ${#missing[@]} == 0 )) || {
  printf 'production port %s missing from:\n' "$PROD_PORT"
  printf '  %s\n' "${missing[@]}"
  exit 1
}
