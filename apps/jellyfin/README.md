# apps/jellyfin/

Media server. Plain http on the tailnet: `http://<tailscale-ip>:8096` (no HTTPS needed, unlike Vaultwarden).

| File | What it does |
|---|---|
| `jellyfin.yaml` | PVC (5Gi config + database), Deployment (non-root, no capabilities, 2Gi limit), media mounted **read-only** from `/srv/homelab/media`, loopback NodePort 30096. |

Publish: `sudo tailscale serve --bg --tcp 8096 tcp://127.0.0.1:30096`.

## Where the media goes (moving to another PC)

The manifest reads media from the host folder `/srv/homelab/media`. That path is the only contract:

- **This PC:** a plain folder on the SSD (small library).
- **New PC (256G SSD + 2TB SATA drive):** format the SATA drive (ext4), mount it at `/srv/homelab/media` in `/etc/fstab`, copy media in. No manifest change.

In Jellyfin: Dashboard -> Libraries -> add a library with folder `/media` (or a subfolder like `/media/movies`).

## Known gaps

- **CPU transcoding only.** GPU needs per-machine setup (NVIDIA container toolkit + k3s runtime). Direct play needs no transcoding.
- **Config is not in the nightly restic backup.** The library is rebuildable by rescanning, but users and watch history are not. Use Dashboard -> Backups (built into Jellyfin) until this is wired in.
