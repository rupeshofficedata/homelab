# apps/qbittorrent/

Torrent client with a web UI, tailnet-only.

| File | What it does |
|---|---|
| `qbittorrent.yaml` | 1Gi config PVC, Deployment (`qbittorrent-nox`, non-root), NodePort 30081 (app also listens on 8081: qBittorrent rejects a Host port that differs from its own) |

- **Downloads:** `/srv/homelab/media/downloads` (host folder). Jellyfin mounts the parent read-only, so finished files appear in its library.
- **Access:** `http://<tailscale-ip>:8081` via `tailscale serve --bg --tcp 8081 tcp://127.0.0.1:30081`.
- **Login:** user `admin`; on first start qBittorrent prints a one-time password in the pod log (`kubectl -n qbittorrent logs deploy/qbittorrent`). Set a permanent one in Tools > Options > WebUI.
- **Limits:** no inbound peer port is opened (fewer peers, still works). Traffic leaves via your home IP; add a VPN sidecar if that matters. Config is not in the restic backup (settings only; downloads are re-fetchable).
- `prune: false` in the Argo app so a bad commit cannot delete the config volume.
