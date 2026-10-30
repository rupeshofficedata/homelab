# apps/jellyfin/

A media server for movies and shows. It uses plain `http` on your tailnet: `http://<tailscale-ip>:8096`.

## Files

| File | What it does |
|---|---|
| `jellyfin.yaml` | A 5 Gi volume (settings and database), the Deployment (non-root, no extra privileges, 2 Gi memory limit), the media folder `/srv/homelab/media` mounted **read-only**, and a private NodePort 30096 |

Publish it: `sudo tailscale serve --bg --tcp 8096 tcp://127.0.0.1:30096`.

## Where the media goes

The app reads media from the host folder `/srv/homelab/media`. That folder is the only agreement between the app and the machine:

- By default it is a normal folder on the main disk.
- For a big library, format a separate drive (for example ext4), mount it at `/srv/homelab/media` in `/etc/fstab`, and copy your media in. Nothing in the manifest changes.

In Jellyfin: Dashboard, Libraries, add a library and choose the folder `/media` (or a subfolder like `/media/movies`).

## Known gaps

- **CPU transcoding only.** A GPU needs extra setup on each machine. Direct play does not transcode, so it works without a GPU.
- **Settings are not in the nightly backup.** Libraries can be scanned again, but users and watch history cannot. Use Dashboard, Backups (built into Jellyfin) until this is added.
