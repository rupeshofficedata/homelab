# Roadmap

What is built, what is not finished, and what may come next.

Marks: `[x]` built, `[~]` built but not fully checked, `[ ]` not done.

## Goal

A home server you can rebuild from this repo. It keeps photos, files and passwords private, and backs them up every night. It is reachable only through Tailscale.

## Built

### Base (the `bootstrap/` scripts)

- [x] Checks, storage folders, backup drive mount, age key, k3s
- [x] Tailscale on the server
- [x] Every script is a preview unless `APPLY=1` is set

### Apps

- [x] Immich (photos), with its own Postgres and valkey
- [x] Vaultwarden (passwords), sign-ups closed
- [x] Nextcloud (files), with its own Postgres
- [x] Jellyfin (media), CPU transcoding only
- [x] qBittorrent (downloads), with checked search plugins
- [x] Homepage (start page)

### Platform

- [x] Nightly restic backup of Immich, Vaultwarden and Nextcloud (systemd timer)
- [x] Argo CD (core) manages the apps from this repo
- [x] Prometheus and Grafana, with the alerts `BackupStale`, `SrvDiskAlmostFull` and `HighSwapUse`
- [x] Renovate opens pull requests for new versions
- [x] Pre-commit check: encrypted secrets, gitleaks, shell syntax

## To finish

- [ ] Keep a copy of the age key in a password manager
- [ ] Turn on GitHub secret scanning and push protection
- [ ] Put Jellyfin settings in the nightly backup (today use Jellyfin's own backup page)
- [ ] Phone upload: check that the Immich phone app works over the tailnet
- [ ] Full restore drill in a scratch Immich ([backup-restore.md](backup-restore.md#full-drill)). The file and database restore drills have passed.

## Ideas for later

- **Offsite backup copy** (for example to object storage). This removes the "two copies in one place" risk.
- **Alertmanager** with a receiver (email or chat), so alerts reach you.
- **Argo CD plugin KSOPS**, so Argo CD can apply encrypted secrets itself.
- **A VPN sidecar for qBittorrent**, so downloads leave through a VPN.
- **GPU transcoding for Jellyfin.** This needs per-machine setup.
- **A dashboard with a login page** and single sign-on, to replace the plain Homepage.
- **Format the backup drive as ext4** for a journal, if the drive can be wiped.

## Risks

| Risk | What helps |
|---|---|
| Not enough memory | Memory limits on every app, 7-day Prometheus retention. If swap stays above 4 GB for a week, move to Docker Compose. |
| Leak from the public repo | SOPS only, the pre-commit check, GitHub push protection |
| Server asleep or off | Turn off sleep. The timer catches up at the next start. |
| Drive unplugged | The drive guard in `backup.sh`, the read-only empty mount point, the `BackupStale` alert |
| Lost age key | Keep two copies of it (password manager and drive) |
| Two copies, one place | Offsite copy (see ideas) |
| Snapshots growing | All data is under `/srv/homelab`, which system snapshots do not include |

## Checks

- [x] `kubectl get pods -A` shows everything `Running`. Argo CD apps are `Synced` and `Healthy`.
- [x] `restic snapshots` and `restic check` work
- [x] The unplugged-drive test fails safely, and the main disk usage does not change
- [x] Reboot test: k3s, the drive mount and Tailscale all start by themselves
- [ ] A photo from the phone, sent over Tailscale, shows up in Immich
- [x] File restore and database restore drills pass
- [x] Grafana shows server and backup metrics
