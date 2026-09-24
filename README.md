# generic-web-server

Localhost-only PowerShell demo: static files from `www/` plus allowlisted API scripts under `controller/api/`.

## Run

```powershell
pwsh -File .\web.ps1 -Port 8080
```

Open http://localhost:8080/ and use **Call /api/hello**.

## Security model

This server is for **local demos only**.

- Binds to `http://localhost:<port>/` only — do **not** change the prefix to `+` or `*`, and do not open the port on the firewall.
- Static files must resolve under `www/`; API scripts are **allowlisted** under `controller/api/`.
- Each process generates a random token, injects it into HTML it serves (`<meta name="local-token">`), and requires `X-Local-Token` on API calls. If an `Origin` header is present, it must be `http://localhost:<port>` or `http://127.0.0.1:<port>`.
- This reduces casual cross-site calls from other websites in a browser. It does **not** stop malware already running as your user on the same machine.
- Keep secrets out of git (see `.gitignore`).

### Recommended habits

1. Keep APIs read-only / low-impact (no arbitrary file read, shell exec, or system changes).
2. Avoid reflecting untrusted query/body data into HTML; prefer `textContent` in pages.
3. Stop the server when you are done; a random high port is fine.
4. Run as a normal user (not admin) and keep the OS up to date.

### Manual check: missing token → 401

1. Start the server: `pwsh -File .\web.ps1 -Port 8080`
2. Open http://localhost:8080/ and use **Call /api/hello** — should return **200** with JSON.
3. In another terminal (no token header):

```powershell
Invoke-WebRequest -Uri http://localhost:8080/api/hello -UseBasicParsing
```

Expect **401** and a small JSON error body. If you get **200**, the token gate is not active.
