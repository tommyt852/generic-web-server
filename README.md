# generic-web-server

Localhost-only PowerShell demo: static files from `www/` plus allowlisted API scripts under `controller/api/`.

## Safety

- Bind only `http://localhost:<port>/` — do not use `+` or `*`.
- Not for public internet exposure.
- Keep secrets out of git (see `.gitignore`).

Hardened `web.ps1` and demo `/api/hello` land in follow-up commits.
