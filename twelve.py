#!/usr/bin/env python3
"""Twelve — workspace walker.

Serves verified-twelve.html with a live /verify endpoint that re-runs
presence checks against the workspace each call. Stdlib only.
"""
import ast
import json
import os
import socket
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
# Workspace root being walked. Default: parent of this script
# (i.e. /Users/uprootiny/Erlich when twelve.py lives in Erlich/twelve/).
# Override with TWELVE_ROOT to walk a different tree (deployed servers).
ROOT = Path(os.environ.get("TWELVE_ROOT", SCRIPT_DIR.parent)).resolve()
INDEX = SCRIPT_DIR / "verified-twelve.html"
PORT = int(os.environ.get("TWELVE_PORT", "9412"))
BIND = os.environ.get("TWELVE_BIND", "127.0.0.1")
HUB2_HOST = os.environ.get("TWELVE_HUB2", "hub2")


def parses(path: Path) -> bool:
    try:
        ast.parse(path.read_text())
        return True
    except Exception:
        return False


def file_info(path: Path) -> dict:
    if not path.exists():
        return {"present": False}
    st = path.stat()
    return {"present": True, "size": st.st_size, "mtime": int(st.st_mtime)}


def hub2_check() -> dict:
    try:
        out = subprocess.run(
            ["ssh", "-o", "ConnectTimeout=3", "-o", "BatchMode=yes",
             "-o", "RemoteCommand=none", HUB2_HOST,
             "stat -c '%s %Y' /tmp/drift-multi-interface.sh 2>/dev/null"],
            capture_output=True, text=True, timeout=8,
        )
        if out.returncode == 0 and out.stdout.strip():
            size, mtime = out.stdout.strip().split()
            return {"present": True, "size": int(size), "mtime": int(mtime),
                    "host": HUB2_HOST, "path": "/tmp/drift-multi-interface.sh"}
        return {"present": False, "host": HUB2_HOST,
                "error": out.stderr.strip()[:120] or "ssh unavailable"}
    except FileNotFoundError:
        return {"present": False, "host": HUB2_HOST, "error": "ssh not installed"}
    except Exception as e:
        return {"present": False, "host": HUB2_HOST, "error": str(e)[:120]}


def verify() -> dict:
    """Re-run all 12 capacity checks. Returns {id: status_dict}."""
    cards: dict = {}

    sv = ROOT / "solvulator/app/server.py"
    cards["01"] = {
        "label": "Solvulator stdlib backend",
        "evidence": file_info(sv),
        "parses": parses(sv) if sv.exists() else False,
        "status": "ok" if sv.exists() and parses(sv) else "fail",
    }

    pwa_files = [ROOT / "solvulator/app/index.html",
                 ROOT / "solvulator/app/manifest.json",
                 ROOT / "solvulator/app/sw.js"]
    cards["02"] = {
        "label": "PWA shell",
        "evidence": [file_info(p) for p in pwa_files],
        "all_present": all(p.exists() for p in pwa_files),
        "status": "ok" if all(p.exists() for p in pwa_files) else "fail",
    }

    sb = ROOT / "hyle-sync/solvulator/static/storyboard.html"
    cards["03"] = {
        "label": "Storyboard 5-zoom UI",
        "evidence": file_info(sb),
        "status": "ok" if sb.exists() else "fail",
    }

    sys_py = ROOT / "hyle-sync/solvulator/src/system.py"
    cards["04"] = {
        "label": "Unified backend (system.py)",
        "evidence": file_info(sys_py),
        "parses": parses(sys_py) if sys_py.exists() else False,
        "status": "ok" if sys_py.exists() and parses(sys_py) else "fail",
    }

    agents_dir = ROOT / "hyle-sync/solvulator/agents"
    agent_md = sorted(agents_dir.glob("[01][0-9]-*.md")) if agents_dir.exists() else []
    cards["05"] = {
        "label": "12 Hebrew agent prompts",
        "count": len(agent_md),
        "files": [p.name for p in agent_md],
        "status": "ok" if len(agent_md) == 12 else "fail",
    }

    pipeline = agents_dir / "pipeline.py"
    env_file = Path.home() / ".env.openrouter"
    cards["06"] = {
        "label": "12-agent pipeline runner",
        "evidence": file_info(pipeline),
        "parses": parses(pipeline) if pipeline.exists() else False,
        "env_openrouter_present": env_file.exists(),
        "status": "ok" if pipeline.exists() and parses(pipeline) and env_file.exists()
                  else ("warn" if pipeline.exists() and parses(pipeline) else "fail"),
        "blocker": None if env_file.exists() else "~/.env.openrouter missing",
    }

    samples = [ROOT / "hyle-sync/solvulator/test/sample-decision-hcj.txt",
               ROOT / "hyle-sync/solvulator/test/sample-demand-execution.txt",
               ROOT / "hyle-sync/solvulator/test/sample.csv"]
    cards["07"] = {
        "label": "Sample legal corpus",
        "evidence": [file_info(p) for p in samples],
        "status": "ok" if all(p.exists() for p in samples) else "fail",
    }

    lien_files = [ROOT / "lien/scrape.clj",
                  ROOT / "lien/extract.bb",
                  ROOT / "lien/vortices.bb",
                  ROOT / "lien/bbmeta.bb",
                  ROOT / "lien/metabase.bb",
                  ROOT / "lien/ontology.edn"]
    cards["08"] = {
        "label": "Lien · ECA notice triage",
        "evidence": [file_info(p) for p in lien_files],
        "status": "ok" if all(p.exists() for p in lien_files) else "fail",
    }

    triage = sorted(ROOT.glob("inbox/solvulator-triage*.html"))
    cards["09"] = {
        "label": "Self-contained triage UIs",
        "count": len(triage),
        "files": [p.name for p in triage],
        "status": "ok" if len(triage) >= 1 else "fail",
    }

    myc = ROOT / "hyle-sync/myclaizer/package.json"
    cards["10"] = {
        "label": "Myclaizer · Vite + React",
        "evidence": file_info(myc),
        "node_modules": (myc.parent / "node_modules").exists(),
        "status": "ok" if myc.exists() else "fail",
    }

    cards["11"] = {
        "label": "Drift detector on hub2",
        "evidence": hub2_check(),
        "status": "ok",  # will downgrade below if check failed
    }
    if not cards["11"]["evidence"].get("present"):
        cards["11"]["status"] = "fail"

    sheets_key = ROOT / "rotated-sheets-key.json"
    cards["12"] = {
        "label": "Google Sheets service-account key",
        "evidence": file_info(sheets_key),
        "status": "ok" if sheets_key.exists() else "fail",
    }

    summary = {
        "live": sum(1 for c in cards.values() if c["status"] == "ok"),
        "warn": sum(1 for c in cards.values() if c["status"] == "warn"),
        "fail": sum(1 for c in cards.values() if c["status"] == "fail"),
    }
    return {
        "checked_at": int(__import__("time").time()),
        "root": str(ROOT),
        "summary": summary,
        "cards": cards,
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("[twelve] %s - %s\n" % (self.address_string(), fmt % args))

    def _send(self, code: int, body: bytes, ctype: str):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            if not INDEX.exists():
                self._send(500, b"verified-twelve.html missing", "text/plain")
                return
            self._send(200, INDEX.read_bytes(), "text/html; charset=utf-8")
            return
        if self.path == "/verify":
            data = json.dumps(verify(), indent=2).encode()
            self._send(200, data, "application/json")
            return
        if self.path == "/healthz":
            self._send(200, b"ok\n", "text/plain")
            return
        self._send(404, b"not found\n", "text/plain")


def main():
    try:
        srv = HTTPServer((BIND, PORT), Handler)
    except OSError as e:
        print(f"[twelve] cannot bind {BIND}:{PORT} — {e}", file=sys.stderr)
        sys.exit(2)
    print(f"[twelve] root   {ROOT}", flush=True)
    print(f"[twelve] serve  http://{BIND}:{PORT}/", flush=True)
    print(f"[twelve] verify http://{BIND}:{PORT}/verify", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n[twelve] bye", flush=True)


if __name__ == "__main__":
    main()
