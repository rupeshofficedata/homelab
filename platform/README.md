# platform/

Cluster services that support the apps. **`backup/` is built; `monitoring/` arrives in Phase 1b.**

## Planned layout

```
platform/
  backup/       restic systemd timer: nightly library + DB dump to /mnt/backup (BUILT, Phase 1a)
  monitoring/   kube-prometheus-stack: Prometheus + Grafana, 7-day retention (Phase 1b)
```

## Design notes

- The backup job checks the drive before writing and fails loudly if it is absent. See [backup/README.md](backup/README.md).
- Monitoring alerts planned: backup older than 26 h, drive not mounted, SSD above 80 %, high swap.
