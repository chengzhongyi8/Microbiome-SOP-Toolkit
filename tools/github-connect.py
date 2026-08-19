#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
github-connect — local CONNECT proxy for reaching github.com from networks
where the DNS-assigned GitHub IP is blocked or unstable.

What it does
------------
Probes a list of well-known GitHub web IPs, picks the first reachable one,
and starts a tiny TCP tunnel on 127.0.0.1:8443.  Any client that sends an
HTTP CONNECT for github.com (git, gh, curl with HTTPS_PROXY) is transparently
forwarded to that reachable IP with TLS intact (SNI preserved).

Usage
-----
    python3 tools/github-connect.py start     # start the proxy (daemon)
    python3 tools/github-connect.py stop      # stop it
    python3 tools/github-connect.py status    # is it running?
    python3 tools/github-connect.py test      # print which candidate IPs respond
    python3 tools/github-connect.py git       # print git/gh commands to use it

After `start`, route git through it for this shell (or add to ~/.gitconfig):

    export HTTPS_PROXY=http://127.0.0.1:8443
    git -c http.proxy=http://127.0.0.1:8443 push origin main
    # or permanently:  git config --global http.proxy http://127.0.0.1:8443

Notes
-----
- Requires only the Python standard library.
- The candidate IP list changes over time; run `test` and edit CANDIDATES if
  none respond.
- api.github.com is usually reachable even when github.com is not, so the
  GitHub API (repo creation, etc.) typically works without this tool.
"""
import json
import os
import socket
import subprocess
import sys
import threading

HOST = "127.0.0.1"
PORT = 8443
# Well-known GitHub web IPs (US + Asia).  Order matters: first reachable wins.
CANDIDATES = [
    "140.82.114.4",
    "140.82.121.3",
    "140.82.116.3",
    "140.82.112.3",
    "20.205.243.166",
]
PID_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".github-connect.pid")
LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".github-connect.log")


def probe(ip, timeout=4):
    """Return True if https://github.com works when routed via ip."""
    try:
        r = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "--connect-timeout", str(timeout),
             "--max-time", str(timeout + 2),
             "--resolve", "github.com:443:" + ip, "https://github.com/"],
            capture_output=True)
        return r.returncode == 0
    except Exception:
        return False


def official_web_ips():
    """Fetch GitHub's current web IP list from api.github.com/meta (usually
    reachable even when github.com is blocked).  Only concrete /24-or-larger
    entries are returned; api.github.com is excluded (it must stay direct)."""
    try:
        r = subprocess.run(
            ["curl", "-s", "--max-time", "10", "https://api.github.com/meta"],
            capture_output=True, text=True)
        meta = json.loads(r.stdout)
        out = []
        for cidr in meta.get("web", []):
            if "/" not in cidr:
                continue
            base, plen = cidr.split("/")
            try:
                plen = int(plen)
            except ValueError:
                continue
            if plen >= 24:
                out.append(base)
        return out
    except Exception:
        return []


def pick():
    # 1) official GitHub web IPs (auto-updating), then 2) hardcoded fallback
    candidates = official_web_ips() or CANDIDATES
    for ip in candidates:
        if probe(ip):
            return ip
    return None


def _pipe(a, b):
    try:
        while True:
            data = a.recv(65536)
            if not data:
                break
            b.sendall(data)
    except Exception:
        pass
    finally:
        for s in (a, b):
            try:
                s.close()
            except Exception:
                pass


def _handle(client, remote_ip):
    try:
        req = b""
        while b"\r\n\r\n" not in req:
            chunk = client.recv(4096)
            if not chunk:
                client.close()
                return
            req += chunk
        if req.split(b"\r\n", 1)[0].split()[0] != b"CONNECT":
            client.close()
            return
        remote = socket.create_connection((remote_ip, 443), timeout=30)
        client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        t1 = threading.Thread(target=_pipe, args=(client, remote))
        t2 = threading.Thread(target=_pipe, args=(remote, client))
        t1.daemon = True
        t2.daemon = True
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except Exception:
        try:
            client.close()
        except Exception:
            pass


def serve(remote_ip):
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((HOST, PORT))
    srv.listen(32)
    with open(LOG_FILE, "a") as fh:
        fh.write("github-connect listening on %s:%d -> %s:443\n" % (HOST, PORT, remote_ip))
    while True:
        c, _ = srv.accept()
        threading.Thread(target=_handle, args=(c, remote_ip), daemon=True).start()


def daemonize(remote_ip):
    sys.stdout.flush()
    sys.stderr.flush()
    if os.fork() > 0:
        return
    os.setsid()
    if os.fork() > 0:
        os._exit(0)
    sys.stdout.flush()
    with open(os.devnull, "wb") as devnull:
        os.dup2(devnull.fileno(), sys.stdout.fileno())
        os.dup2(devnull.fileno(), sys.stderr.fileno())
    with open(PID_FILE, "w") as fh:
        fh.write(str(os.getpid()))
    serve(remote_ip)


def is_running():
    if not os.path.exists(PID_FILE):
        return False
    try:
        pid = int(open(PID_FILE).read().strip())
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def cmd_start():
    if is_running():
        print("github-connect already running (pid %s). stop it first." % open(PID_FILE).read().strip())
        return 1
    remote = pick()
    if not remote:
        print("ERROR: no reachable GitHub IP found among:")
        for ip in CANDIDATES:
            print("   %s  %s" % (ip, "OK" if probe(ip) else "blocked"))
        print("Edit CANDIDATES in this script, or use a VPN/proxy.")
        return 1
    print("using %s; starting proxy on %s:%d ..." % (remote, HOST, PORT))
    daemonize(remote)
    print("started. route git/curl through it, e.g.:")
    print('  export HTTPS_PROXY=http://%s:%d' % (HOST, PORT))
    print("  git config --global http.proxy http://%s:%d" % (HOST, PORT))
    return 0


def cmd_stop():
    if not is_running():
        print("not running.")
        return 0
    pid = int(open(PID_FILE).read().strip())
    try:
        os.kill(pid, 15)
    except Exception:
        pass
    try:
        os.remove(PID_FILE)
    except Exception:
        pass
    print("stopped.")
    return 0


def cmd_status():
    if is_running():
        print("running (pid %s)" % open(PID_FILE).read().strip())
    else:
        print("not running")
    return 0


def cmd_test():
    for ip in CANDIDATES:
        print("%-15s %s" % (ip, "OK" if probe(ip) else "blocked"))
    return 0


def cmd_git():
    print("# route git through the proxy for one command:")
    print("git -c http.proxy=http://%s:%d push origin main" % (HOST, PORT))
    print("# or permanently:")
    print("git config --global http.proxy http://%s:%d" % (HOST, PORT))
    print("# gh/curl also honour HTTPS_PROXY:")
    print("export HTTPS_PROXY=http://%s:%d" % (HOST, PORT))
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    cmd = sys.argv[1]
    if cmd == "start":
        return cmd_start()
    if cmd == "stop":
        return cmd_stop()
    if cmd == "status":
        return cmd_status()
    if cmd == "test":
        return cmd_test()
    if cmd == "git":
        return cmd_git()
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main())
