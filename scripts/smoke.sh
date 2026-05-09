#!/usr/bin/env bash
# Post-deploy smoke. Derives the list of public surfaces from every Caddyfile
# snippet under deploy/, then probes each: 200, TLS-clean, body > 0 bytes.
# Also asserts (when run on the deploy host) that the systemd unit named in
# any *.service file under deploy/ is `is-active` — closes the gap where a
# stray nohup'd process answers healthz while the unit is `inactive`.
#
# Run anywhere — exits 0 only if every check is green.
set -euo pipefail
LC_ALL=C

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
red=0

# 1. surfaces from Caddy snippets
mapfile -t hosts < <(
  awk '
    /^[a-z0-9._-]+\.(raindesk\.dev|solvulator\.com|hyperstitious\.org|hyperstitious\.art)[[:space:]]*\{/ {
      sub(/[[:space:]]*\{$/, ""); print
    }
  ' "$ROOT"/deploy/*/Caddyfile.snippet 2>/dev/null | sort -u
)

if (( ${#hosts[@]} == 0 )); then
  echo "smoke: no public surfaces declared in deploy/*/Caddyfile.snippet"
  exit 1
fi

printf 'public surfaces (%d):\n' "${#hosts[@]}"
for h in "${hosts[@]}"; do
  url="https://$h/"
  read -r code size time < <(curl -sS -o /dev/null \
    -w "%{http_code} %{size_download} %{time_total}\n" \
    --max-time 8 "$url" 2>/dev/null || echo "000 0 -")
  if [[ "$code" == "200" && "${size:-0}" -gt 0 ]]; then
    printf '  ok   %-44s %s %4sB %ss\n' "$url" "$code" "$size" "$time"
  else
    printf '  FAIL %-44s %s %4sB %ss\n' "$url" "$code" "$size" "$time"
    red=1
  fi
done

# 2. systemd-unit liveness — only meaningful on the deploy host itself.
if command -v systemctl >/dev/null 2>&1; then
  for svc in "$ROOT"/deploy/*/*.service; do
    [[ -f "$svc" ]] || continue
    name="$(basename "$svc" .service)"
    state="$(systemctl --user is-active "$name" 2>/dev/null || systemctl is-active "$name" 2>/dev/null || echo unknown)"
    if [[ "$state" == "active" ]]; then
      printf '  ok   %-44s active\n' "$name.service"
    else
      printf '  FAIL %-44s %s (expected active)\n' "$name.service" "$state"
      red=1
    fi
  done
fi

exit "$red"
