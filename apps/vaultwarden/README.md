# apps/vaultwarden/

Password manager, Bitwarden-compatible. Served over HTTPS on the tailnet only (the web vault needs a secure context): `https://<machine>.<tailnet>.ts.net:8222`.

| File | What it does |
|---|---|
| `vaultwarden.yaml` | PVC (2Gi, SQLite in `/data`), Deployment (non-root, no capabilities, 256Mi limit, `Recreate` strategy), loopback NodePort 30222. No `ADMIN_TOKEN`, so `/admin` is off. |
| `install.sh` | Creates `secrets/vaultwarden.enc.yaml` (`DOMAIN` contains the tailnet name, so SOPS-encrypted) and applies it. Run before Argo syncs the app. |

Publish: `sudo tailscale serve --bg --https=8222 http://127.0.0.1:30222`.

## First account, then close signups

`SIGNUPS_ALLOWED` is now `"false"` (closed). It was `"true"` only so the first account can be created. Anyone on the tailnet could register while it is open, so close it right away:

1. Open the URL, create your account.
2. Set `SIGNUPS_ALLOWED` to `"false"` in `vaultwarden.yaml`, commit, push. Argo applies it.

## Backup

`platform/backup/backup.sh` runs `vaultwarden backup` (consistent SQLite copy) then restic backs up the whole `/data` folder with tag `vaultwarden`, nightly. Old `db_*.sqlite3` copies in `/data` are small; delete the oldest by hand now and then.
