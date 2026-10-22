# HomeLab: k3s + Argo CD, Immich phone backup first

> [!NOTE]
> **Status legend:** `[x]` done and checked, `[~]` built but not fully verified, `[ ]` not done. Last updated after Phase 1a was built. Nothing is committed to Git or pushed to GitHub yet.

## Context
Build portable homelab on current CachyOS PC (15G RAM, GTX 1080, 201G free SSD, btrfs + snapper), later move to another PC.
Goal now: iPhone (<100GB) photo backup via Immich -> nightly restic copy to external drive "Backup Plus"
(1.8T exFAT, 605G existing data, left untouched). Later: Jellyfin, Nextcloud, Vaultwarden, dashboard.
Share link was login-gated; stack taken from pasted chat (Immich, Jellyfin, Nextcloud, Homepage, restic, Tailscale).

## Decisions (settled)
- Repo: **public** GitHub + SOPS/age for secrets.
- Secrets: SOPS + age (not Vault). Vault optional in Phase 2 for learning.
- Master secrets kept OUTSIDE cluster and git: age private key + restic password -> cloud password manager (not self-hosted Vaultwarden) + copy on drive.
- Access: **Tailscale** only (host install). Immich is published with `tailscale serve --tcp` as plain HTTP inside WireGuard (no certificate yet). No VPS, no open router ports. Pangolin only if sharing with non-Tailscale users later.
- Offsite copy: later (Phase 2). Until then drive only = 2 copies in 1 place; risk accepted.
- Platform: **k3s + Argo CD**. kind clusters and Jenkins stopped while homelab runs.
- Drive: exFAT folder only as restic target; existing 605G untouched. Reformat/partition deferred.
- Kill criterion: if swap stays >4G for a week, fall back to Docker Compose for Phase 1 apps.

## Public repo safeguards
- Enable GitHub secret scanning + push protection.
- Pre-commit hook: gitleaks + require `sops:` metadata in every `secrets/*.yaml`.
- Commit nothing until `.gitignore` and `.sops.yaml` exist. A plain secret in history is permanent.
- Keep out of repo: domain names, public IPs, tailnet name, device names, photo samples.
- Photos, DB dumps, restic repo never in git.
- Leak response: rotate password, new age key, re-encrypt.

## Repo layout (`~/Projects/HomeLab`)
```
bootstrap/   k3s install, argocd install, sops/age + KSOPS setup, key backup (README)
apps/        immich/ jellyfin/ nextcloud/ homepage/ vaultwarden/ (Helm values + kustomize)
platform/    monitoring/ (kube-prometheus-stack), backup/ (restic + systemd timer)
argocd/      root app-of-apps + one Application per dir
secrets/     *.enc.yaml only (SOPS + age). age private key NEVER in repo
docs/        guides (see README.md in this folder)
```

## Phase 0: prerequisites (ask before each destructive step) - DONE
Five scripts in `bootstrap/scripts/`, each a dry run unless `APPLY=1`. Walkthrough: [getting-started.md](getting-started.md).
- [x] 1. `01-preflight.sh`: read-only checks (tools, RAM, swap, disk, drive, ports).
- [x] 2. `02-free-ram.sh`: stop kind clusters (opssquad, visitorcounter) and Jenkins. After k3s install check `ip route` for subnet/port clashes (not yet checked).
- [x] 3. `03-storage.sh`: plain dirs `/srv/homelab/{k3s,storage}` (`/srv` is its own btrfs subvolume `@srv`, not snapshotted by snapper, so no new subvolume), `chattr +C` on `storage`; drive mount by label at `/mnt/backup` with `x-systemd.automount,nofail`; `chattr +i /mnt/backup` on the empty mountpoint so nothing writes to the SSD when the drive is absent.
- [~] 4. `04-secrets.sh`: generate the age key, write the public key into `.sops.yaml`; store the private key in a cloud password manager + on the drive. Done: key generated, copy on the drive (unencrypted, same drive as the backups). **Open:** copy into a cloud password manager.
- [x] 5. `05-k3s.sh`: install k3s v1.36.5 (single node, local-path storage, NodePorts loopback-only, kubeconfig at `~/.kube/homelab`). Enabled on boot; reboot not yet tested.

Manual, outside the scripts:
- [x] `git init` (local, hooks path set; no commit yet)
- [ ] Public GitHub repo + push protection
- [x] Tailscale installed and logged in on the PC
- [ ] Tailscale on iPhone and laptop
- [ ] Disable suspend on the PC
- [ ] Pre-commit hook tested (`gitleaks` is installed; the hook has not run on a real commit)

## Phase 1a: photos + backup working (manual helm, no Argo yet) - BUILT, partly verified
- [x] 1. Immich via `helm upgrade --install` (`apps/immich/install.sh`). Official chart `0.13.4` (OCI), Immich `v3.2.0`, both pinned. Library PVC (150 Gi, local-path) under `/srv/homelab/storage`; Postgres is a single-pod StatefulSet (Immich's image, pinned by digest); valkey enabled; ML on CPU; memory limits 2 Gi server/ML, 1 Gi Postgres. All pods Running.
- [~] 2. Exposed on the tailnet with a loopback NodePort (30283) and `sudo tailscale serve --bg --tcp 2283 tcp://127.0.0.1:30283`. Works from the PC at `http://<tailscale-ip>:2283`. Plain HTTP inside WireGuard, no certificate. **Open:** iOS app with an `http://` URL; iPhone not yet on the tailnet.
- [x] 3. Database backup is a `pg_dump -Fc` through `kubectl exec` inside the backup job (replaces "use Immich's built-in dump", which does not depend on Immich's schedule).
- [~] 4. Nightly backup is a **host systemd timer** (`platform/backup/`), not a CronJob: 02:30 daily, `Persistent=true`. `backup.sh` checks the repo `config` file exists (fails loudly if the drive is absent), backs up library + dump to `/mnt/backup/homelab-restic/`, then `forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune` and a Sunday `restic check --read-data-subset=5%`. First manual run passed (snapshot `38d67282`, 17.6 MiB). **Open:** first scheduled run, unplugged-drive test.
- [ ] 5. iPhone: Immich app, tailnet URL, choose albums, Background App Refresh on, iCloud "Optimize Storage" off (or expect slow downloads), first upload at home on Wi-Fi.
- [~] 6. **Restore drill:** mechanical drill passed (restore to scratch dir, dump readable with 142 tables, `restic check` clean). **Open:** drill with real photos in a scratch Immich, and the reboot test (k3s, drive mount, Tailscale return by themselves).
Gate: do not start 1b until the restore drill with real photos and the reboot test pass.

## Phase 1b: GitOps + monitoring
1. Argo CD (`argocd` ns), root app-of-apps. KSOPS plugin + age key as hand-made k8s secret.
2. Move Immich and restic to Argo-managed manifests (secrets via SOPS).
3. `kube-prometheus-stack`: 7d retention, low requests. Alerts: backup last success >26h, drive not mounted, SSD >80%, swap high.
4. Renovate (free GitHub app) opens PRs for chart/image bumps; merge = Argo deploys. No CI pipeline.

## Phase 2 (later)
Vaultwarden, Jellyfin (GTX 1080 NVENC via nvidia device plugin), Nextcloud (+Postgres), Homepage dashboard, Grafana dashboards.
Offsite copy (B2/S3). Reformat/partition drive to ext4 (Windows shrink) when moving. Optional Vault for learning.

## Move to new PC
Install k3s -> Argo CD -> apply root app -> restore age key -> `restic restore` into PVCs. Written in `docs/migrate-to-new-pc.md`.

## Risks
- RAM ~5G free: stop kind/Jenkins, CPU limits, 7d retention, kill criterion above. Swap was ~5 GB in use during setup; keep watching it.
- Public repo leak: SOPS only, hooks, push protection.
- PC asleep/off: no uploads. Suspend disabled.
- Drive unplugged: mountpoint guard + alert. exFAT unsafe removal: eject properly, weekly check.
- Lost age key: secrets must be recreated, and the restic password (stored only in `secrets/restic.enc.yaml` and root-only `/etc/homelab/restic-password`) is lost with it, making the backup unreadable. The age key is the single point to protect; its only copy besides the SSD is unencrypted on the same drive.
- Two copies in one place (live data + drive); the library is backed up while Immich runs.
- btrfs snapshots bloating: keep all homelab data under `/srv/homelab` (`@srv` is not snapshotted by snapper).

## Verification
- [x] `kubectl get pods -A` Running (Argo apps Synced/Healthy: 1b).
- [ ] Test photo from iPhone over Tailscale appears in Immich.
- [x] `restic snapshots` and `restic check` succeed; [ ] unplugged-drive test fails safely with SSD usage unchanged.
- [~] Restore drill passes (mechanical: yes; with real photos: not yet); [ ] reboot test passes.
- Grafana shows node + backup metrics (1b).
