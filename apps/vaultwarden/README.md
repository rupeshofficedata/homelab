# apps/vaultwarden/

A password manager that works with the Bitwarden apps. It needs HTTPS, so it is published with your Tailscale name: `https://<name>.ts.net:8222`.

## Files

| File | What it does |
|---|---|
| `vaultwarden.yaml` | A 2 Gi volume (the SQLite database in `/data`), the Deployment (non-root, no extra privileges, 256 Mi memory limit, one pod at a time), and a private NodePort 30222. There is no `ADMIN_TOKEN`, so the `/admin` page is off. |
| `install.sh` | Creates `secrets/vaultwarden.enc.yaml`, which holds the web address (it contains your Tailscale name), and applies it. Run it before Argo CD syncs the app. |

Publish it: `sudo tailscale serve --bg --https=8222 http://127.0.0.1:30222`.

## Sign-ups are closed

`SIGNUPS_ALLOWED` is `"false"`, so nobody can create an account. To create the first account, set it to `"true"` in `vaultwarden.yaml`, commit and push, and wait for Argo CD. Create your account. Then set it back to `"false"` straight away. While it is open, anyone on your tailnet can register.

## Backup

`platform/backup/backup.sh` runs `vaultwarden backup` (a safe copy of the database). Then restic saves the whole `/data` folder every night. The old `db_*.sqlite3` copies in `/data` are small. Delete the oldest ones by hand now and then.
