# apps/nextcloud/

File sync and sharing. It needs HTTPS, so it is published with your Tailscale name: `https://<name>.ts.net:8443`.

## Files

| File | What it does |
|---|---|
| `nextcloud.yaml` | Postgres 16 (its own StatefulSet, 5 Gi), Nextcloud (Apache) with a cron sidecar, an app volume (3 Gi), the user files in the host folder `/srv/homelab/files`, and a private NodePort 30443 |
| `install.sh` | Creates the files folder (owned by user 33, the user Nextcloud runs as), then `secrets/nextcloud.enc.yaml` (database password, admin password, Tailscale name), and applies it. Run it before Argo CD syncs the app. |

Publish it: `sudo tailscale serve --bg --https=8443 http://127.0.0.1:30443`.

## Where the data lives

- **Main disk:** the database, the app code and `config.php` (volumes under `/srv/homelab/storage`).
- **A bigger drive (optional):** mount it so `/srv/homelab/files` lives on it. Nothing in the manifest changes.

## Log in

The user is `admin`. To read the generated password:

```bash
sops -d secrets/nextcloud.enc.yaml
```

Change the password after your first login.

## Backup

Every night `platform/backup/backup.sh` turns maintenance mode on, runs `pg_dump`, saves the app volume, `/srv/homelab/files` and the dump with restic, and turns maintenance mode off. Users cannot write while it runs.

## Known gaps

- No Redis cache. That is fine for one user. Add it if the web page feels slow.
- Calendar, Contacts and Office are not set up.
