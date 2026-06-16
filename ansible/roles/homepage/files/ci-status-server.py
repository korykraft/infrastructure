#!/usr/bin/env python3
"""HTTP server that returns latest GitHub Actions CI status for pictubook-app main."""

import json
import os
import time
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = int(os.environ.get("PORT", 9090))
REPO = "korykraft/pictubook-app"
BRANCH = "main"
CACHE_SECONDS = 60
TOKEN_FILE = os.path.expanduser("~/.gh-token")

_cache = {"data": None, "time": 0}


def get_ci_status():
    now = time.time()
    if _cache["data"] and (now - _cache["time"]) < CACHE_SECONDS:
        return _cache["data"]

    try:
        with open(TOKEN_FILE) as f:
            token = f.read().strip()
    except FileNotFoundError:
        return {"workflow": "CI", "status": "no token", "when": "-", "passing": 0}

    url = f"https://api.github.com/repos/{REPO}/actions/runs?branch={BRANCH}&per_page=3"
    req = urllib.request.Request(url, headers={
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "homepage-ci-widget",
    })

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        return {"workflow": "CI", "status": f"API error: {e}", "when": "-", "passing": 0}

    results = []
    for run in data.get("workflow_runs", []):
        conclusion = run.get("conclusion", run.get("status", "unknown"))
        emoji = {
            "success": "PASS",
            "failure": "FAIL",
            "cancelled": "CANCEL",
            "skipped": "SKIP",
        }.get(conclusion, conclusion.upper())
        results.append({
            "workflow": run.get("name", "unknown"),
            "status": emoji,
            "branch": run.get("head_branch", ""),
            "when": run.get("updated_at", "")[:16].replace("T", " "),
            "href": run.get("html_url", ""),
            "passing": 1 if conclusion == "success" else 0,
        })

    if not results:
        result = {"workflow": "pictubook-app", "status": "no runs", "when": "-", "passing": 0}
    else:
        result = results[0]

    _cache["data"] = result
    _cache["time"] = now
    return result


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/ci-status.json":
            data = get_ci_status()
            body = json.dumps(data).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/health":
            self.send_response(200)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    print(f"ci-status server on :{PORT}")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
