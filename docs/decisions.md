# Decisions

Why the project is built this way. Each decision lists what was chosen, what was rejected, and what would make us look at it again.

## Summary

| # | Topic | Choice | Rejected | Look again when |
|---|---|---|---|---|
| 1 | Platform | **k3s + Argo CD** | Docker Compose | Swap stays above 4 GB for a week |
| 2 | Secrets | **SOPS + age** | HashiCorp Vault, Sealed Secrets | Many apps or often-changing credentials |
| 3 | Remote access | **Tailscale** | Pangolin, Cloudflare Tunnel | You must share with people who will not install Tailscale |
| 4 | Repo | **Public** | Private | A secret leaks, or you want it private |
| 5 | Backup tool | **restic** | Borg, Kopia, rsync | You want a backup web page (Kopia) |
| 6 | Backup drive | **A folder on the exFAT drive** | Repartition the drive | You can format the drive as ext4 |
| 7 | Testing and CI | **None.** Renovate opens update pull requests | GitHub Actions, Jenkins | Bad changes keep breaking syncs |
| 8 | Offsite copy | **Later** | Cloud copy now | Before you rely on the server for photos you have nowhere else |
| 9 | Immich install | **Official Helm chart**, versions pinned | Plain manifests | The chart is no longer maintained |
| 10 | Backup runner | **systemd timer on the host** | Kubernetes CronJob | Backups should show up as cluster objects, or you add a second node |
| 11 | Immich database | **One-pod Postgres StatefulSet** | CloudNativePG operator | You need replicas or automatic failover |
| 12 | Publishing apps | **Private NodePort + `tailscale serve`** | Ingress, NodePort on all interfaces | You want a certificate and a name for every app |

## 1. k3s and Argo CD instead of Docker Compose

Argo CD needs Kubernetes, and "rebuild everything from git" is the main goal. The price is memory: Kubernetes, Argo CD and monitoring use more than Docker Compose would.

Rule: if swap stays above 4 GB for a week, move the apps to Docker Compose.

## 2. SOPS + age, not Vault or Sealed Secrets

- **SOPS + age.** Secrets sit in git, encrypted. One key to protect. This is the choice.
- **Vault.** Secrets stay out of git, but you must run, back up and unseal a service. Its unseal keys are the same kind of key problem, for only a handful of secrets.
- **Sealed Secrets.** Simple with Argo CD, but the files open only with that one cluster's key. A new server needs the old key first.
- **Secrets by hand.** Works for a few secrets, but it is not GitOps.

How we use it: [secrets.md](secrets.md).

## 3. Tailscale, not Pangolin

Pangolin is a tunnel you host yourself. It needs a server with a public IP address, a domain name and open ports, which in practice means a rented VPS. It shows apps to the whole internet behind its own login.

Tailscale connects your own devices from anywhere, with no public address and no open router ports. Use Pangolin only if you must share with people who will not install Tailscale. (Look at Tailscale Funnel and Tailscale node sharing first. They are lighter.)

## 4. Public repo

Chosen on purpose. The result: secrets are encrypted with SOPS, a pre-commit check scans for secrets, GitHub push protection is turned on, and domain names, public IPs, Tailscale names and device names stay out. See [secrets.md](secrets.md).

## 5. restic

- **Borg** needs a Borg program on the storage side and is less simple with non-Linux filesystems.
- **Kopia** has a nice web page but is one more part to run.
- **restic** is one program. A restic repository is just a folder of files, so it works on exFAT and opens on any system.

## 6. A folder on the exFAT drive

You cannot shrink an exFAT drive in place with common Linux tools. The safe ways need another computer or a full copy. A folder avoids all that. The limits: exFAT has no journal and no Linux permissions, so the drive is only a restic target. Live data stays on the main disk. See [backup-restore.md](backup-restore.md#known-weaknesses).

## 7. No CI

Argo CD already deploys. A CI pipeline would only check files. Instead, **Renovate** (a free GitHub app) opens a pull request when a chart or image has a new version. You merge it, and Argo CD deploys it. Nothing merges by itself.

Settings: `renovate.json`. It watches the chart versions in `argocd/apps/`, the Immich server tag and the Argo CD version. Immich and Postgres updates get a `backup-first` label: run `sudo systemctl start homelab-backup` before you merge them.

Add a small `helm lint` plus gitleaks workflow only if broken syncs become a problem.

## 8. Offsite copy later

Until it exists, live data and backup are in one place. See [backup-restore.md](backup-restore.md#known-weaknesses).

## 9. Immich Helm chart

The official chart is in `immich-app/immich-charts`. Its old HTTP repository is gone, so it installs from `oci://ghcr.io/immich-app/immich-charts/immich`. The chart version is pinned in `apps/immich/install.sh`. The Immich version is pinned in `apps/immich/values.yaml`. The chart does not follow Immich releases, so you update both on purpose (or merge the Renovate pull request).

The chart has no database. It needs Postgres with the vectorchord extension. The Postgres version must be the same when you restore.

## 10. Backup runs from a systemd timer, not a CronJob

The drive is an **automount**: it mounts when something opens the folder. A pod that binds `/mnt/backup` can get the idle trigger or an empty folder, depending on timing. A host service avoids this. `ls /mnt/backup` starts the mount, `restic` and `kubectl` are already on the host, and `Persistent=true` runs the backup after a night when the computer was off.

The cost: Argo CD does not manage the job, and the backup alert reads a timestamp file instead of job metrics. Details: [backup-restore.md](backup-restore.md).

## 11. Postgres as a plain StatefulSet

The Immich chart example uses the CloudNativePG operator, which adds an operator and extra resource types for one database. A StatefulSet with Immich's own Postgres image (pinned by digest) is one file, and it is the build that Immich is tested with. Limits: 1 Gi of memory, a 10 Gi volume, no replication. Backups use `pg_dump` through `kubectl exec`.

## 12. Private NodePort and `tailscale serve`

Each app has a NodePort. `bootstrap/k3s-config.yaml` sets `nodeport-addresses=127.0.0.0/8`, so the port answers only on the server itself. `tailscale serve` forwards a port on your tailnet to it. The home network cannot reach the app. Only Tailscale can.

Apps that need HTTPS (Nextcloud, Vaultwarden) use `tailscale serve --https`, which gets a certificate for your Tailscale name. The other apps use a plain TCP forward. Tailscale encrypts it, but it has no certificate, so the address starts with `http://`.
