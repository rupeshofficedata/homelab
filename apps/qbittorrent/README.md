# apps/qbittorrent/

A torrent client with a web page, reachable only on your tailnet.

## Files

| File | What it does |
|---|---|
| `qbittorrent.yaml` | A 1 Gi settings volume, the Deployment (`qbittorrent-nox`, non-root), and a NodePort 30081. The app also listens on port 8081, because qBittorrent rejects a Host port that is different from its own. |
| `install-plugins.sh` | Copies the checked search plugins into the running pod (see below) |
| `plugins/` | The search plugins and their checksums |

## Facts

- **Downloads** go to `/srv/homelab/media/downloads` (a host folder). Jellyfin mounts the folder above it read-only, so finished files appear in its library.
- **Address:** `http://<tailscale-ip>:8081`. Publish it with `sudo tailscale serve --bg --tcp 8081 tcp://127.0.0.1:30081`.
- **Login:** the user is `admin`. On first start qBittorrent prints a one-time password in the pod log (`kubectl -n qbittorrent logs deploy/qbittorrent`). Set a permanent password in Tools, Options, WebUI.
- **Limits:**
  - No inbound peer port is opened. Downloads still work, with fewer peers.
  - Traffic leaves through your home IP address. Add a VPN sidecar if that matters.
  - Settings are not in the restic backup. Downloads can be fetched again.
- The Argo CD app has `prune: false`, so a bad commit cannot delete the settings volume.

## Search plugins

`plugins/` holds search plugins that were read before they were added. `install-plugins.sh` copies them into the pod:

```bash
APPLY=1 ./apps/qbittorrent/install-plugins.sh
```

The plugins live on the settings volume, so they survive restarts. Run the script again only after a new install or a wiped volume. More in [plugins/README.md](plugins/README.md).
