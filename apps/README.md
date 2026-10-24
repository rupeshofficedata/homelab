# apps/

One folder per self-hosted application. **`immich/` is built (Phase 1a); the rest arrive in Phase 2.**

## Planned layout

```
apps/
  immich/        manifests + Helm values (built, see immich/README.md)
  vaultwarden/   password manager (built, see vaultwarden/README.md)
  jellyfin/      media server (built, see jellyfin/README.md)
  nextcloud/     files and sync (Phase 2)
  homepage/      dashboard (built, see homepage/README.md)
```

## Conventions

- Each app folder is self-contained: values, extra manifests, and a short README explaining each file.
- Chart and image versions are **pinned**. Renovate proposes bumps as pull requests; Argo CD deploys on merge.
- Secrets live in [`../secrets/`](../secrets/), never here.
- Data lives under `/srv/homelab/storage` through k3s `local-path` volumes.
