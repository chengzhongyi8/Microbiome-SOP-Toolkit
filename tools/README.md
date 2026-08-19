# tools/ — optional utilities

## github-connect.py

Local CONNECT proxy for reaching `github.com` from networks where the
DNS-assigned GitHub IP is blocked or unstable (common on some research and
mainland-China networks).  It probes well-known GitHub web IPs, picks a
reachable one, and tunnels git/gh/curl TLS traffic through it.

```bash
python3 tools/github-connect.py test    # which candidate IPs respond
python3 tools/github-connect.py start   # start proxy on 127.0.0.1:8443 (daemon)
export HTTPS_PROXY=http://127.0.0.1:8443
git push origin main                    # or: git -c http.proxy=... push
python3 tools/github-connect.py stop
```

Requires only the Python standard library.  `api.github.com` (repo creation,
API calls) is usually reachable even when `github.com` is not, so most API
work needs no proxy at all.
