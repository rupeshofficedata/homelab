# apps/nextcloud/

File sync and sharing. HTTPS on the tailnet only: `https://<machine>.<tailnet>.ts.net:8443` (the phone and desktop clients need HTTPS).

| File | What it does |
|---|---|
| `nextcloud.yaml` | Postgres 16 (own StatefulSet, 5Gi), Nextcloud Apache + cron sidecar, app volume (3Gi), user files from host folder `/srv/homelab/files`, loopback NodePort 30443. |
| `install.sh` | Creates the files folder (owned by uid 33), then `secrets/nextcloud.enc.yaml` (DB password, admin password, tailnet name; all SOPS-encrypted) and applies it. Run before Argo syncs the app. |

Publish: `sudo tailscale serve --bg --https=8443 http://127.0.0.1:30443`.

## Storage layout (new PC: SSD for apps, big drive for data)

- **SSD:** database, app code, `config.php` (PVCs under `/srv/homelab/storage`).
- **Big drive:** mount it so that `/srv/homelab/files` (and `/srv/homelab/media` for Jellyfin) live on it. No manifest change.

## Login

User `admin`. Read the generated password: `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops -d secrets/nextcloud.enc.yaml`. Change it after first login.

## Backup

Nightly (`platform/backup/backup.sh`): maintenance mode on, `pg_dump`, restic of app volume + `/srv/homelab/files` + dump, maintenance mode off. Users cannot write for the duration of the run.

## Known gaps

- No Redis cache: fine for one user, add it if the web UI feels slow.
- Calendar, Contacts and Office are not set up.
