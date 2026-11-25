#!/usr/bin/env python3
"""Homelab dashboard: service status from Docker and HTTP checks, plus bookmarks.

Standard library only. Runs in the `dashboard` stack.
"""
import http.client
import json
import os
import re
import socket
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

APP_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.environ.get("CONFIG_FILE", "/config/services.json")
BOOKMARKS_FILE = os.environ.get("BOOKMARKS_FILE", "/data/bookmarks.json")
SERVICE_GROUPS_FILE = os.environ.get("SERVICE_GROUPS_FILE", "/data/service-groups.json")
BACKUPS_DIR = os.environ.get("BACKUPS_DIR", "/backups")
DOCKER_SOCK = os.environ.get("DOCKER_SOCK", "/var/run/docker.sock")
CHECK_HOST = os.environ.get("CHECK_HOST", "host.docker.internal")
STACKS_DIR = os.environ.get("STACKS_DIR", "/home/kory/docker")
PORT = int(os.environ.get("PORT", "3005"))
STATUS_MAX_AGE = 8  # seconds a computed status is reused
CHECK_TIMEOUT = 4

MAX_GROUPS, MAX_BOOKMARKS, MAX_NAME, MAX_URL = 100, 300, 80, 2000


class UnixHTTPConnection(http.client.HTTPConnection):
    def __init__(self, path, timeout=5):
        super().__init__("localhost", timeout=timeout)
        self._path = path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self._path)


def docker_containers():
    conn = UnixHTTPConnection(DOCKER_SOCK)
    try:
        conn.request("GET", "/containers/json?all=1")
        resp = conn.getresponse()
        if resp.status != 200:
            raise RuntimeError(f"Docker answered {resp.status}")
        return json.loads(resp.read())
    finally:
        conn.close()


def load_config():
    try:
        with open(CONFIG_FILE) as f:
            cfg = json.load(f)
    except (OSError, ValueError) as e:
        return {"services": {}, "extras": [], "hidden": [], "link_host": "", "error": f"services.json could not be read: {e}"}
    return {
        "services": cfg.get("services") or {},
        "extras": cfg.get("extras") or [],
        "hidden": cfg.get("hidden") or [],
        "link_host": cfg.get("link_host") or "",
    }


def http_check(port, path):
    """Return (answering, milliseconds or None, detail)."""
    start = time.monotonic()
    conn = http.client.HTTPConnection(CHECK_HOST, port, timeout=CHECK_TIMEOUT)
    try:
        conn.request("GET", path or "/", headers={"User-Agent": "homelab-dashboard"})
        status = conn.getresponse().status
        ms = round((time.monotonic() - start) * 1000)
        if status >= 500:
            return False, ms, f"Answers with error {status}"
        return True, ms, ""
    except (OSError, http.client.HTTPException) as e:
        reason = "Timed out" if isinstance(e, socket.timeout) else "No answer"
        return False, None, f"{reason} on port {port}"
    finally:
        conn.close()


def summarize_container(c):
    status = c.get("Status", "")
    exit_code = None
    m = re.match(r"Exited \((\d+)\)", status)
    if m:
        exit_code = int(m.group(1))
    health = "unhealthy" if "(unhealthy)" in status else "healthy" if "(healthy)" in status else ""
    return {
        "name": (c.get("Names") or ["?"])[0].lstrip("/"),
        "state": c.get("State", ""),
        "health": health,
        "exit_code": exit_code,
        "status": status,
    }


def build_status():
    cfg = load_config()
    result = {"generated": time.time(), "services": [], "config_error": cfg.get("error"), "docker_error": None,
              "link_host": cfg["link_host"]}

    projects = {}
    try:
        for c in docker_containers():
            labels = c.get("Labels") or {}
            info = summarize_container(c)
            project = labels.get("com.docker.compose.project") or info["name"]
            p = projects.setdefault(project, {"containers": [], "dir": ""})
            p["containers"].append(info)
            p["dir"] = p["dir"] or labels.get("com.docker.compose.project.working_dir", "")
    except Exception as e:  # socket missing, permission denied, bad answer
        result["docker_error"] = f"Docker status is unavailable: {e}"

    entries = []
    for project, p in projects.items():
        if project in cfg["hidden"]:
            continue
        sc = cfg["services"].get(project, {})
        cs = sorted(p["containers"], key=lambda c: c["name"])
        running = [c for c in cs if c["state"] == "running"]
        unwell = [c for c in cs if c["state"] == "restarting" or c["health"] == "unhealthy"]
        # A container that ran once and exited cleanly (a migration) is not a fault.
        stopped = [c for c in cs if c["state"] != "running" and c["state"] != "restarting" and c["exit_code"] != 0]
        entry = {
            "id": project,
            "name": sc.get("name") or project,
            "about": sc.get("about", ""),
            "port": sc.get("port"),
            "path": sc.get("path", "/"),
            "open": sc.get("open"),
            "open_port": sc.get("open_port"),
            "managed": p["dir"].startswith(STACKS_DIR),
            "containers": cs,
            "ms": None,
            "detail": "",
        }
        if not running:
            entry["state"] = "stopped"
        elif unwell or stopped:
            entry["state"] = "degraded"
            names = ", ".join(c["name"] for c in unwell + stopped)
            entry["detail"] = f"Not running properly: {names}"
        else:
            entry["state"] = "up"
        entries.append(entry)

    for x in cfg["extras"]:
        entries.append({
            "id": "extra:" + str(x.get("id") or x.get("name")),
            "name": x.get("name", "?"), "about": x.get("about", ""),
            "port": x.get("port"), "path": x.get("path", "/"), "open": x.get("open"), "open_port": x.get("open_port"),
            "managed": False, "containers": [], "ms": None, "detail": "", "state": "up",
        })

    to_check = [e for e in entries if e["port"] and e["state"] != "stopped"]
    if to_check:
        with ThreadPoolExecutor(max_workers=min(16, len(to_check))) as pool:
            for e, (ok, ms, detail) in zip(to_check, pool.map(lambda e: http_check(e["port"], e["path"]), to_check)):
                e["ms"] = ms
                if not ok:
                    e["state"] = "down"
                    e["detail"] = detail

    result["services"] = entries
    result["backup"] = backup_status()
    return result


def backup_status():
    try:
        runs = sorted(d for d in os.listdir(BACKUPS_DIR) if re.match(r"^20\d\d-", d))
    except OSError:
        return {"available": False}
    good = [d for d in runs if not os.path.exists(os.path.join(BACKUPS_DIR, d, "FAILED"))]
    info = {"available": True, "count": len(good), "last_ok": None, "last_failed": bool(runs) and runs[-1] not in good}
    if good:
        try:
            info["last_ok"] = time.mktime(time.strptime(good[-1], "%Y-%m-%d_%H%M%S"))
        except ValueError:
            info["last_ok"] = os.stat(os.path.join(BACKUPS_DIR, good[-1])).st_mtime
    return info


_status_lock = threading.Lock()
_status_cache = None


def get_status():
    global _status_cache
    with _status_lock:
        if _status_cache is None or time.time() - _status_cache["generated"] > STATUS_MAX_AGE:
            _status_cache = build_status()
        return _status_cache


# ── Bookmarks ────────────────────────────────────────────────────────────────

_bookmarks_lock = threading.Lock()


def load_doc(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return {"groups": []}


def clean_text(value, what):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{what} needs a name")
    value = " ".join(value.split())
    if len(value) > MAX_NAME:
        raise ValueError(f"{what} name is longer than {MAX_NAME} characters")
    return value


def clean_bookmarks(doc):
    """Validate what the page sent and rebuild it from known fields only."""
    if not isinstance(doc, dict) or not isinstance(doc.get("groups"), list):
        raise ValueError("Expected a list of groups")
    if len(doc["groups"]) > MAX_GROUPS:
        raise ValueError(f"No more than {MAX_GROUPS} groups")
    groups, seen = [], set()

    def new_id(given):
        ok = isinstance(given, str) and re.fullmatch(r"[A-Za-z0-9-]{4,40}", given) and given not in seen
        value = given if ok else uuid.uuid4().hex[:12]
        seen.add(value)
        return value

    for g in doc["groups"]:
        if not isinstance(g, dict) or not isinstance(g.get("bookmarks", []), list):
            raise ValueError("A group is malformed")
        if len(g.get("bookmarks", [])) > MAX_BOOKMARKS:
            raise ValueError(f"No more than {MAX_BOOKMARKS} bookmarks in a group")
        marks = []
        for b in g.get("bookmarks", []):
            if not isinstance(b, dict):
                raise ValueError("A bookmark is malformed")
            url = b.get("url")
            if not isinstance(url, str) or len(url) > MAX_URL:
                raise ValueError("A bookmark address is missing or too long")
            url = url.strip()
            parsed = urlparse(url)
            if parsed.scheme not in ("http", "https") or not parsed.netloc:
                raise ValueError(f"Address must start with http:// or https://: {url[:60]}")
            marks.append({"id": new_id(b.get("id")), "name": clean_text(b.get("name"), "Bookmark"), "url": url})
        groups.append({"id": new_id(g.get("id")), "name": clean_text(g.get("name"), "Group"), "bookmarks": marks})
    return {"groups": groups}


def clean_service_groups(doc):
    """Groups of services. A service is named by its id and sits in one group at most."""
    if not isinstance(doc, dict) or not isinstance(doc.get("groups"), list):
        raise ValueError("Expected a list of groups")
    if len(doc["groups"]) > MAX_GROUPS:
        raise ValueError(f"No more than {MAX_GROUPS} groups")
    groups, seen_ids, placed = [], set(), set()
    for g in doc["groups"]:
        if not isinstance(g, dict) or not isinstance(g.get("services", []), list):
            raise ValueError("A group is malformed")
        gid = g.get("id")
        if not (isinstance(gid, str) and re.fullmatch(r"[A-Za-z0-9-]{4,40}", gid) and gid not in seen_ids):
            gid = uuid.uuid4().hex[:12]
        seen_ids.add(gid)
        services = []
        for s in g.get("services", []):
            if not isinstance(s, str) or not 0 < len(s) <= 200:
                raise ValueError("A service in a group is malformed")
            if s not in placed:
                placed.add(s)
                services.append(s)
        if len(placed) > MAX_BOOKMARKS:
            raise ValueError("Too many services in groups")
        groups.append({"id": gid, "name": clean_text(g.get("name"), "Group"), "services": services})
    return {"groups": groups}


def save_doc(path, doc):
    tmp = f"{path}.{uuid.uuid4().hex[:8]}.tmp"
    with open(tmp, "w") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


# ── HTTP ─────────────────────────────────────────────────────────────────────

# What the page may read and replace: address -> (file, validator)
STORES = {
    "/api/bookmarks": (BOOKMARKS_FILE, clean_bookmarks),
    "/api/service-groups": (SERVICE_GROUPS_FILE, clean_service_groups),
}

class Handler(BaseHTTPRequestHandler):
    server_version = "homelab-dashboard"

    def log_message(self, fmt, *args):
        if self.path != "/healthz" and not self.path.startswith("/api/status"):
            super().log_message(fmt, *args)

    def send_body(self, code, body, content_type):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def send_json(self, code, obj):
        self.send_body(code, json.dumps(obj).encode(), "application/json")

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/":
            with open(os.path.join(APP_DIR, "index.html"), "rb") as f:
                self.send_body(200, f.read(), "text/html; charset=utf-8")
        elif path == "/healthz":
            self.send_body(200, b"ok", "text/plain")
        elif path == "/api/status":
            self.send_json(200, get_status())
        elif path in STORES:
            file, _ = STORES[path]
            try:
                self.send_json(200, load_doc(file))
            except (OSError, ValueError) as e:
                self.send_json(500, {"error": f"{os.path.basename(file)} could not be read: {e}"})
        else:
            self.send_json(404, {"error": "Not found"})

    def do_PUT(self):
        store = STORES.get(urlparse(self.path).path)
        if not store:
            return self.send_json(404, {"error": "Not found"})
        file, clean = store
        # Requiring JSON keeps other websites from changing things via a form post.
        if self.headers.get("Content-Type", "").split(";")[0].strip() != "application/json":
            return self.send_json(415, {"error": "Send JSON"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = -1
        if not 0 < length <= 2_000_000:
            return self.send_json(413, {"error": "Too large"})
        try:
            doc = clean(json.loads(self.rfile.read(length)))
        except ValueError as e:
            return self.send_json(400, {"error": str(e)})
        try:
            with _bookmarks_lock:
                save_doc(file, doc)
        except OSError as e:
            return self.send_json(500, {"error": f"Could not write {os.path.basename(file)}: {e}"})
        self.send_json(200, doc)


if __name__ == "__main__":
    print(f"dashboard listening on :{PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
