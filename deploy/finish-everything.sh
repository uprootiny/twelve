#!/usr/bin/env bash
# finish-everything — consolidated fix.
#
# Does, in one interactive sudo session on nabla:
#   1. Install updated systemd unit (binds 0.0.0.0:47312) and restart twelve
#   2. Strip any existing twelve.solvulator.com block from /etc/caddy/Caddyfile
#      and append the corrected snippet (no broken log path), validate, reload
#   3. Smoke-test loopback through caddy
#
# Does NOT touch GCP firewall — that requires your gcloud auth (the compute
# service account on nabla lacks firewall scope). Run this on your local
# shell after the script succeeds:
#
#     gcloud compute firewall-rules create twelve-direct \
#         --allow=tcp:47312 \
#         --source-ranges=0.0.0.0/0 \
#         --description="twelve workspace walker direct port"
#
# (or from the GCP console, VPC network → Firewall → Create rule.)

set -euo pipefail
NABLA_SSH=(ssh -o RemoteCommand=none -t nabla)

echo "[1/3] update systemd unit (TWELVE_BIND=0.0.0.0) + restart twelve"
"${NABLA_SSH[@]}" 'set -e
  sudo install -m 644 /home/uprootiny/twelve/deploy/twelve.service /etc/systemd/system/twelve.service
  sudo systemctl daemon-reload
  sudo systemctl restart twelve.service
  sleep 1
  sudo systemctl status twelve.service --no-pager | head -6
  echo "  --- twelve listener ---"
  ss -ltn | awk "/:47312\$/{print \"  \"\$0}" | head -3
  echo "  --- loopback healthz ---"
  curl -sS -o /dev/null -w "    %{http_code}\n" http://127.0.0.1:47312/healthz
'

echo "[2/3] strip + re-append twelve block in Caddyfile, validate, reload"
"${NABLA_SSH[@]}" 'set -e
  CF=/etc/caddy/Caddyfile

  TMP="$(sudo mktemp)"
  sudo awk "
    BEGIN { skipping = 0; depth = 0 }
    /^twelve\\.solvulator\\.com[[:space:]]*\\{/ { skipping = 1; depth = 1; next }
    skipping {
      n_open  = gsub(/\\{/, \"&\")
      n_close = gsub(/\\}/, \"&\")
      depth += n_open - n_close
      if (depth <= 0) { skipping = 0 }
      next
    }
    { print }
  " "$CF" | sudo tee "$TMP" >/dev/null

  CFNEW="$(sudo mktemp)"
  sudo bash -c "cat \"$TMP\" /home/uprootiny/twelve/deploy/Caddyfile.snippet > \"$CFNEW\""
  sudo install -m 644 -o root -g root "$CFNEW" "$CF"
  sudo rm -f "$TMP" "$CFNEW"

  echo "  --- new tail ---"
  sudo tail -8 "$CF"
  echo "  --- validate ---"
  sudo caddy validate --config "$CF" --adapter caddyfile 2>&1 | tail -3
  echo "  --- reload ---"
  sudo systemctl reload caddy
  sleep 1
  systemctl is-active caddy
'

echo "[3/3] smoke-tests on nabla"
"${NABLA_SSH[@]/-t/-o BatchMode=yes}" '
  echo "  loopback to twelve via caddy (Host: twelve.solvulator.com):"
  curl -sS -o /dev/null -w "    %{http_code}\n" -k -H "Host: twelve.solvulator.com" https://127.0.0.1/healthz || true
  echo "  direct loopback :47312:"
  curl -sS -o /dev/null -w "    %{http_code}\n" http://127.0.0.1:47312/healthz
'

echo
echo "Now from your machine, after firewall is open for 47312:"
echo "  curl -sS http://twelve.solvulator.com:47312/healthz"
echo "  curl -sS https://twelve.solvulator.com/healthz"
echo
echo "Open browser:"
echo "  https://twelve.solvulator.com/"
echo "  http://twelve.solvulator.com:47312/"
