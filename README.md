# twelve

A workspace walker. One page, twelve cards, each showing a **verified-present**
capacity of a workspace — every card is backed by a parse, a stat, or an SSH
probe re-run on each `/verify` request. Below the grid are recipes for
composing those capacities into something runnable now.

The point: *no claim from memory.* If a file isn't there, the card goes red.
If a service is down, the card goes red. The page can't lie.

## Quickstart (local)

```sh
./twelve.sh up        # 127.0.0.1:9412 — opens nothing public
./twelve.sh open      # also opens browser
./twelve.sh status
./twelve.sh down
```

`twelve.sh` is idempotent. PID and log live in `.twelve.pid` / `.twelve.log`
(both gitignored). It refuses to start if the port is held by a process it
doesn't own.

## Routes

| route       | what it does                                       |
| ----------- | -------------------------------------------------- |
| `/`         | the 12-card walkthrough page                       |
| `/verify`   | JSON: presence/parse/probe re-run fresh per call   |
| `/healthz`  | text "ok"                                          |

## Configure

| env var       | default                | meaning                                    |
| ------------- | ---------------------- | ------------------------------------------ |
| `TWELVE_PORT` | `9412`                 | listen port                                |
| `TWELVE_BIND` | `127.0.0.1`            | bind address (`0.0.0.0` for caddy upstream) |
| `TWELVE_ROOT` | parent of script       | workspace tree to inventory                |
| `TWELVE_HUB2` | `hub2`                 | ssh host for the remote drift-detector card |

## Layout

```
twelve.py             stdlib HTTP server + verify()
twelve.sh             idempotent up/down/status/open
verified-twelve.html  the UI; auto-fetches /verify when served via http
deploy/hub2/          production deploy on hub2 (publicly reachable)
deploy/nabla/         historical nabla deploy (kept for reference; nabla is
                      tailscale-only — see DEPLOY.md)
DESIGN.md             why this shape — verified-present principle,
                      sheet-isomorphism, what twelve isn't
DEPLOY.md             fleet topology + production deploy + family pattern
HOSTS.md              fleet snapshot — which host serves what
```

## Production

Live at:

- **https://twelve.raindesk.dev/** — caddy-fronted on hub2, browser-friendly
- **http://149.102.137.139:47312/** — direct port on hub2

Both reverse-proxy to (or directly serve) the same `twelve.py` running as a
user-level systemd unit on hub2. See `DEPLOY.md` for how to add a new
surface and the family pattern.

## Hygiene

- Stdlib only (Python 3.9+); no dependencies.
- Local: binds 127.0.0.1 by default.
- No secrets read from disk except a presence-check of `~/.env.openrouter`.
- `.gitignore` excludes `*-key.json`, `.env*`, `*.pem`, runtime PID/log.
