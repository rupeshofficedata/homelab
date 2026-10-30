# apps/

One folder for each app that HomeLab runs.

```text
apps/
  immich/        photos                  (see immich/README.md)
  nextcloud/     files and sync          (see nextcloud/README.md)
  vaultwarden/   password manager        (see vaultwarden/README.md)
  jellyfin/      movies and shows        (see jellyfin/README.md)
  qbittorrent/   torrent downloads       (see qbittorrent/README.md)
  homepage/      start page with links   (see homepage/README.md)
```

## Rules for every app

- Each folder holds everything for that app: the manifests (YAML files), the settings, and a short README.
- Versions are **pinned**. Renovate opens a pull request for a new version, and Argo CD deploys it when you merge.
- Secrets are not here. They are encrypted in [`../secrets/`](../secrets/).
- App data lives under `/srv/homelab/storage`, in volumes that k3s creates (`local-path`).
- Every app has a **NodePort** that listens on `127.0.0.1` only. `tailscale serve` makes it reachable on your tailnet.
- An `install.sh` (where there is one) creates the namespace and the encrypted private settings. It is a preview unless you set `APPLY=1`.

Argo CD deploys the apps from the files in [`../argocd/apps/`](../argocd/apps/).
