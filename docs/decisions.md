# Decisions

Short records of why things are the way they are. Each row says what would make us revisit it.

> [!NOTE]
> "Not verified" means the claim has not been checked against current upstream docs and must be before relying on it.

## Summary

| # | Decision | Choice | Why | Rejected | Revisit when |
|---|----------|--------|-----|----------|--------------|
| 1 | Platform | **k3s + Argo CD** | GitOps from day one; same repo rebuilds the lab on a new PC | Docker Compose | **Swap stays above 4 GB for a week** -> fall back to Compose for Phase 1 apps |
| 2 | Secrets | **SOPS + age** | Files live in Git, lock with one key you own, nothing extra running in the cluster | HashiCorp Vault; Sealed Secrets; hand-made secrets only | Many apps or rotating credentials make Vault worth it (Phase 2, learning) |
| 3 | Remote access | **Tailscale** (host install) | Private by default, no VPS, no open router ports, free | Pangolin; Cloudflare Tunnel | You need to share with people who will not install Tailscale |
| 4 | Repo visibility | **Public** | Portfolio value; your explicit choice | Private | A secret leaks, or you stop wanting it public |
| 5 | Backup tool | **restic** | One static binary, encrypted, deduplicated; repo is plain files so it works on exFAT and any OS | Borg; Kopia; rsync | Need a UI or native cloud-sync features (Kopia) |
| 6 | Drive layout | **Folder on the existing exFAT drive** | Keeps the 605 GB untouched; zero resize risk; restic needs no Linux permissions | Shrink exFAT and add ext4; copy-out and repartition | You move to the new PC: reformat to ext4 for journaling |
| 7 | CI | **None**; Renovate opens version-bump PRs | Argo CD already does CD; CI would only lint | GitHub Actions, local Jenkins | Bad manifests keep breaking syncs: add `helm lint` + gitleaks |
| 8 | Offsite copy | **Later** (Phase 2) | Cost and setup; accepted risk for now | Cloud copy in Phase 1 | Before trusting the lab with irreplaceable photos you do not keep elsewhere |
| 9 | Immich install | **Official Helm chart `0.13.4`**, Immich `v3.2.0`, both pinned | Checked at build time: the chart repo is active and now published only as OCI | Plain manifests | Chart is unmaintained: use plain manifests or Compose |
| 10 | Backup runner | **Host systemd timer** (not a k8s CronJob) | Avoids hostPath and mount-propagation problems with the autofs drive; restic and kubectl run directly on the host | k8s CronJob | Phase 1b wants backups visible as cluster objects, or a second node appears |
| 11 | Immich database | **Single-pod Postgres StatefulSet** with Immich's own image | One pod, one volume, no operator; same image Immich's docker-compose uses | CloudNativePG operator | Need replicas, failover or managed backups |
| 12 | Publishing Immich | **Loopback NodePort + `tailscale serve --tcp`** | NodePort bound to 127.0.0.0/8 is unreachable from the LAN; the tailnet reaches it only through `tailscaled` | Ingress/Traefik; NodePort on all interfaces; `tailscale serve --https` | The iOS app rejects plain HTTP, or you want a certificate and a name |

## Details

### 1. k3s + Argo CD vs Docker Compose

Argo CD needs Kubernetes, and a Git-driven rebuild is the goal. The cost is RAM: about 5 GB is free with the kind clusters and Jenkins running, so they are stopped while the lab runs (`02-free-ram.sh`). Kill criterion: if swap stays above 4 GB for a week, move Phase 1 apps to Compose and keep Argo for the new PC.

### 2. SOPS + age vs Vault vs Sealed Secrets

- **SOPS + age**: secrets sit in Git locked. Needs the KSOPS plugin in Argo CD. One key to guard. See [secrets.md](secrets.md).
- **Vault**: secrets stay out of Git, but you run, back up and unseal a service. Unseal keys are the same problem as the age key, for roughly five secrets.
- **Sealed Secrets**: simplest with Argo, but files open only with that cluster's key, so a new PC needs the old controller key restored first.
- **By hand**: fine for four secrets, but not GitOps.

### 3. Tailscale vs Pangolin

Pangolin is a self-hosted tunneling reverse proxy. Per its docs it needs a Linux server with a **public IP**, a **domain** and open ports (80, 443, 51820/21820 UDP), in practice a rented VPS. It exposes services publicly behind its own login. The self-hosted price and licence terms were not found on the pricing page and are **not verified**. Tailscale reaches your own devices from anywhere with none of that. Revisit Pangolin only to share with people who will not install Tailscale. (Tailscale Funnel and node sharing are lighter options to check first.)

### 4. Public repo

Chosen deliberately. Consequences: SOPS only, pre-commit hook, GitHub push protection, and keep domains, public IPs, tailnet and device names out. See [secrets.md](secrets.md).

### 5. restic

Chosen over Borg (needs a server-side binary and handles non-POSIX filesystems less simply) and Kopia (nice UI, extra moving part). Restic repositories are directories of files, so exFAT works.

### 6. exFAT folder vs repartition

Shrinking exFAT in place is not supported by common Linux tools. Safe routes (Windows shrink, or copy everything out) need extra hardware or a Windows PC. Using a folder avoids all of it. Limits: no journal and no Linux permissions, so it is a restic target only. Live data stays on the SSD. See [backup-restore.md](backup-restore.md).

### 7. No CI

Renovate (a free GitHub app) opens PRs when a chart or image has a new version. You merge; Argo CD deploys. Add a small `helm lint` + gitleaks workflow only if broken syncs become a problem.

Config: `renovate.json` (repo root). It watches the Argo chart versions, the Immich server tag and the Argo CD version. Immich and Postgres PRs get a `backup-first` label: run `sudo systemctl start homelab-backup` before merging. Nothing auto-merges.

### 8. Offsite later

Until then there are two copies in one place. The iPhone itself and iCloud (keep it on) act as an informal third copy. See [backup-restore.md](backup-restore.md#known-weaknesses).

### 9. Immich Helm chart

Verified when Phase 1a was built: the official chart lives in `immich-app/immich-charts`. Its old HTTP Helm repo was removed, so it is installed from `oci://ghcr.io/immich-app/immich-charts/immich`. Version `0.13.4` is pinned in `apps/immich/install.sh`; the Immich image `v3.2.0` (the chart's `appVersion`) is pinned in `apps/immich/values.yaml`. The chart does not update with Immich releases, so bumps are deliberate. The chart ships no database: it expects a Postgres with the vectorchord extension and, optionally, its own valkey (enabled in our values). The Postgres version must match on restore.

### 10. Backup runner: systemd timer, not a CronJob

The earlier plan was a Kubernetes CronJob. The job needs the exFAT drive, which is an **autofs** mount: a pod's `hostPath` bind of `/mnt/backup` can capture the idle trigger or an empty directory depending on timing, and mount propagation has to be tuned. A host service avoids all of it: `ls /mnt/backup` triggers the mount, `restic` and `kubectl` are already on the host, and `Persistent=true` catches up after the PC was off. Cost: the job is not a cluster object, so Argo CD does not manage it and the Phase 1b alert reads a timestamp file instead of job metrics. Details: [backup-restore.md](backup-restore.md).

### 11. Postgres as a plain StatefulSet

The chart does not include a database. The chart's own example uses CloudNativePG, which adds an operator and CRDs for a single instance. A StatefulSet with `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0`, pinned by digest and taken from Immich's docker-compose, is one file and uses the extension build Immich is tested with. Limits: 1 Gi memory, 10 Gi volume, no replication. Backups are `pg_dump` through `kubectl exec`.

### 12. Loopback NodePort and `tailscale serve`

`apps/immich/nodeport.yaml` exposes the server on NodePort 30283. `bootstrap/k3s-config.yaml` sets `kube-proxy-arg: nodeport-addresses=127.0.0.0/8`, so the port answers on loopback only (checked: loopback returns 200, the LAN address gets nothing). `sudo tailscale serve --bg --tcp 2283 tcp://127.0.0.1:30283` forwards tailnet port 2283 to it. The forward is plain TCP inside WireGuard: encrypted in transit, but no HTTPS certificate, so the URL is `http://<tailscale-ip>:2283`. Whether the Immich iOS app accepts a plain `http://` URL is **not verified**. MagicDNS names are not relied on because `tailscale status` reports a systemd-resolved/NetworkManager conflict.
