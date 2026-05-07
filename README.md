# twelve

A workspace walker. Serves a single page that shows the latest dozen
**verified-present** capacities of a workspace, well-composed into recipes
for what can be brought live immediately.

Each `/verify` re-runs file-presence, parse, and SSH-reachability checks
against the workspace it walks. No claims from memory.

## Run locally

```sh
./twelve.sh up        # default: 127.0.0.1:9412, walks ../
./twelve.sh open      # also opens browser
./twelve.sh status
./twelve.sh down
```

## Configure

| env var       | default                 | meaning                                    |
| ------------- | ----------------------- | ------------------------------------------ |
| `TWELVE_PORT` | `9412`                  | listen port                                |
| `TWELVE_BIND` | `127.0.0.1`             | bind address (`0.0.0.0` for caddy upstream) |
| `TWELVE_ROOT` | parent of this script   | workspace tree to inventory                |
| `TWELVE_HUB2` | `hub2`                  | ssh host for the remote drift-detector card |

## Routes

- `/`         — the walkthrough UI
- `/verify`   — JSON of all 12 capacity checks, freshly re-run
- `/healthz`  — text "ok"

## Hygiene

- Stdlib only (Python 3.9+).
- Binds 127.0.0.1 by default.
- No secrets read from disk except `~/.env.openrouter` *presence* check
  (the file is not opened or transmitted).
- `.gitignore` excludes `*-key.json`, `.env*`, `*.pem`, runtime PID/log.

## Layout

```
twelve.py             stdlib HTTP server + verify()
twelve.sh             idempotent up/down/status/open
verified-twelve.html  the UI, fetches /verify when served via http
```
