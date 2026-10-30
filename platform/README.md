# platform/

Services that support the apps.

```text
platform/
  backup/       the nightly backup (restic + systemd timer)
  monitoring/   Prometheus and Grafana (deployed by Argo CD)
```

- The backup job checks that the drive is there before it writes, and fails with a clear message if it is not. See [backup/README.md](backup/README.md).
- Monitoring has three alerts: backup older than 26 hours, `/srv` above 80% full, and swap above 50% for 30 minutes. See [monitoring/README.md](monitoring/README.md).
