# Getting started: Phase 0 and Phase 1a

Phase 0 prepares the PC: checks, free RAM, storage, secrets key, k3s. Phase 1a (steps 7 to 10) installs Immich, publishes it on the tailnet and sets up the nightly backup ([roadmap.md](roadmap.md)).

> [!NOTE]
> **Status on the reference machine:** Phase 0 is applied and checked. Phase 1a is built; the manual backup and a mechanical restore drill passed. Not yet verified: restore with real photos, reboot test, iPhone upload, unplugged-drive test, the timer's first scheduled run. Unchecked boxes below are the open items.

> [!IMPORTANT]
> Every script is a **dry run**. It prints the commands it would run. Nothing changes until you run it again with `APPLY=1`. Read the preview first.

```bash
./bootstrap/scripts/03-storage.sh            # preview only
APPLY=1 ./bootstrap/scripts/03-storage.sh    # actually do it
```

In fish, set variables inline the same way: `env APPLY=1 ./bootstrap/scripts/03-storage.sh`.

## Scripts at a glance

| Script | Purpose | Changes system? |
|--------|---------|-----------------|
| `lib.sh` | Shared helpers (`log`, `warn`, `die`, `need`, `run`, config loading). Sourced, never run directly. | No |
| `01-preflight.sh` | Read-only health check | No |
| `02-free-ram.sh` | Stop containers to free RAM | Only with `APPLY=1` |
| `03-storage.sh` | Data dirs, drive mountpoint, fstab | Only with `APPLY=1` |
| `04-secrets.sh` | Generate age key, write public key to `.sops.yaml` | Only with `APPLY=1` |
| `05-k3s.sh` | Install and configure k3s | Only with `APPLY=1` |

Machine-specific values (paths, drive label, stop list) live in `bootstrap/config.env`.

## Step 0: prerequisites

```bash
sudo pacman -S age sops gitleaks restic tailscale shellcheck
```

Installs the tools the scripts and git hooks need. `k3s` itself is installed by step 5.

Git hooks are already enabled for this clone (`git config core.hooksPath .githooks`). To re-enable on a fresh clone, run that command once.

- [ ] `pacman -Q age sops gitleaks restic tailscale shellcheck` lists all six
- **Rollback:** `sudo pacman -Rns <package>`

## Step 1: preflight (read-only)

```bash
./bootstrap/scripts/01-preflight.sh
```

Reports missing tools, available RAM, swap use, free disk, whether the drive labelled `Backup Plus` is found, running containers that match the stop list, and whether port 6443 is free. Lines marked `FIX` need attention before you continue.

- [ ] No `FIX` lines you do not understand
- **Rollback:** nothing to undo

## Step 2: free RAM

```bash
./bootstrap/scripts/02-free-ram.sh              # shows which containers match
APPLY=1 ./bootstrap/scripts/02-free-ram.sh      # stops them
```

Stops running containers whose names match `STOP_REGEX` in `bootstrap/config.env` (default `^(opssquad|visitorcounter|jenkins)`). Other containers are left alone. Stopped names are saved to `~/.cache/homelab/stopped.txt`.

- [ ] `docker ps` no longer lists the matched containers
- [ ] `free -h` shows more available memory
- **Rollback:**

```bash
xargs docker start < ~/.cache/homelab/stopped.txt
```

Starts exactly the containers this script stopped.

## Step 3: storage and drive mount

Unmount the drive first if the desktop mounted it (for example under `/run/media/...`). The script refuses to continue while it is mounted elsewhere.

```bash
udisksctl unmount -b /dev/disk/by-label/Backup\\x20Plus   # only if mounted
./bootstrap/scripts/03-storage.sh
APPLY=1 ./bootstrap/scripts/03-storage.sh
```

The script:
1. Creates `/srv/homelab/k3s` and `/srv/homelab/storage` and sets `chattr +C` on `storage` (no copy-on-write; set while empty).
2. Creates `/mnt/backup` and sets `chattr +i` so nothing can write there while the drive is absent.
3. Adds an `/etc/fstab` line for the drive (found by label `Backup Plus`) with `nofail,x-systemd.automount` so a missing drive never blocks boot.

If `udisksctl` cannot match the device name, find it with `lsblk -f` and unmount with `udisksctl unmount -b /dev/sdX1`.

- [x] `lsattr -d /srv/homelab/storage` shows `C`
- [x] `i` is set on the bare directory. Once the drive is mounted, `lsattr -d /mnt/backup` shows the drive's root instead, so check through a bind mount: `d=$(mktemp -d); sudo mount --bind / "$d"; lsattr -d "$d/mnt/backup"; sudo umount "$d"; rmdir "$d"`
- [x] `ls /mnt/backup` auto-mounts the drive and shows your files; `findmnt /mnt/backup` shows `exfat`
- **Rollback:** remove the added line from `/etc/fstab`, run `sudo systemctl daemon-reload`, `sudo chattr -i /mnt/backup`, and `sudo rmdir /mnt/backup`. The directories under `/srv/homelab` are empty and safe to delete. Your 605 GB on the drive is never touched.

> [!NOTE]
> After the fstab change the drive mounts at `/mnt/backup` on first access, not under `/run/media`. Eject it properly before unplugging: `sudo umount /mnt/backup`.

## Step 4: secrets key

```bash
./bootstrap/scripts/04-secrets.sh
APPLY=1 ./bootstrap/scripts/04-secrets.sh
```

Runs `age-keygen` to create `~/.config/sops/age/keys.txt` if it does not exist, then writes the **public** key into `.sops.yaml`. The private key never enters the repo.

**Back it up now.** Copy the private key to a cloud password manager and to the drive. Details and reasons: [secrets.md](secrets.md).

- [x] `~/.config/sops/age/keys.txt` exists and is not in `git status`
- [x] `.sops.yaml` contains an `age1...` public key, not the placeholder
- [ ] Private key stored in two places outside this PC's SSD. A copy is on the drive (`/mnt/backup/homelab-keys/age-keys.txt`, unencrypted, same drive as the backups). **Still to do:** add a copy in a cloud password manager.
- **Rollback:** delete the key file and restore the placeholder in `.sops.yaml`. Only safe before you have encrypted anything.

## Step 5: Tailscale (manual)

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
```

Starts the daemon at boot and prints a login URL. `tailscale status` may warn that MagicDNS will probably not work because systemd-resolved and NetworkManager are wired together incorrectly. Plain `100.x` addresses work regardless, and that is what this guide uses. Then install the Tailscale app on the iPhone and laptop and sign in to the same account. Disable PC suspend so uploads can arrive (system settings, or `sudo systemctl mask sleep.target suspend.target`).

- [x] `tailscale status` lists the PC (it shows a `100.x` address)
- [ ] iPhone and laptop appear in `tailscale status` (the iPhone has not been seen yet)
- [ ] Phone on mobile data can reach the PC's Tailscale address
- **Rollback:** `sudo tailscale down; sudo systemctl disable --now tailscaled`; `sudo systemctl unmask sleep.target suspend.target` if you masked them.

## Step 6: k3s

```bash
./bootstrap/scripts/05-k3s.sh
APPLY=1 ./bootstrap/scripts/05-k3s.sh
```

The script downloads `https://get.k3s.io`, you see it in the dry run before it is executed as root, then it:
- installs `bootstrap/k3s-config.yaml` to `/etc/rancher/k3s/config.yaml` (`data-dir: /srv/homelab/k3s`, local-path storage at `/srv/homelab/storage`, Traefik and servicelb disabled, and `kube-proxy-arg: nodeport-addresses=127.0.0.0/8` so NodePorts listen on loopback only),
- starts k3s as a systemd service,
- copies the kubeconfig to `~/.kube/homelab` so your existing kind contexts in `~/.kube/config` are untouched.

Use it:

```bash
export KUBECONFIG=~/.kube/homelab     # bash/zsh
set -x KUBECONFIG ~/.kube/homelab     # fish
kubectl get nodes
```

- [x] `kubectl get nodes` shows one `Ready` node (k3s v1.36.5)
- [x] `kubectl get pods -A` shows only system pods, all Running
- [ ] `ip route` has no overlapping subnets with your Docker/kind networks (not checked while kind was stopped)
- [ ] After reboot, `systemctl is-active k3s` is `active` (reboot test not done)
- **Rollback:** `/usr/local/bin/k3s-uninstall.sh` (removes k3s and its data under `/srv/homelab/k3s`).

## Step 7: Immich (Phase 1a)

```bash
./apps/immich/install.sh
APPLY=1 ./apps/immich/install.sh
```

What `install.sh` does, in order:
1. Applies `namespace.yaml`.
2. Creates `secrets/immich-db.enc.yaml` once, with a random DB password encrypted by SOPS. The plaintext never touches disk. Then it decrypts that file in memory and pipes it to `kubectl apply`.
3. Applies `pvc.yaml` (150 Gi `local-path` volume for the library), `postgres.yaml` (a single-pod StatefulSet) and `nodeport.yaml` (NodePort 30283).
4. Runs `helm upgrade --install` with the official chart `oci://ghcr.io/immich-app/immich-charts/immich`, version `0.13.4` (pinned in the script), values from `apps/immich/values.yaml`: Immich image `v3.2.0`, valkey enabled, memory limits of 2 Gi for the server and machine-learning pods.

Re-run it after editing `values.yaml` to upgrade; it is idempotent.

- [x] `kubectl -n immich get pods` shows server, machine-learning, valkey and `immich-postgres-0` all `Running` and ready
- [x] `curl http://127.0.0.1:30283/api/server/ping` returns `{"res":"pong"}`
- [x] The same request to the LAN address on port 30283 gets no answer (loopback-only NodePort)
- **Rollback:** `helm uninstall immich -n immich`, then `kubectl delete -f apps/immich/` and `kubectl delete ns immich`. Deleting the namespace deletes the volumes under `/srv/homelab/storage`, so only do it before real photos are in.

## Step 8: publish Immich on the tailnet

```bash
sudo tailscale serve --bg --tcp 2283 tcp://127.0.0.1:30283
tailscale serve status
```

Forwards tailnet port 2283 to the loopback NodePort. This is a plain TCP forward: WireGuard encrypts it on the tailnet, but there is no HTTPS certificate, so the URL is `http://<tailscale-ip>:2283`, for example `http://<tailscale-ip>:2283`. Use your own `100.x` address from `tailscale ip -4`.

- [x] `curl http://<tailscale-ip>:2283/api/server/ping` from the PC returns `{"res":"pong"}`
- [ ] Immich iOS app accepts the `http://` URL and logs in. **Not verified yet.** If the app refuses plain HTTP, switch to `tailscale serve --https` and enable HTTPS in the Tailscale admin console.
- [ ] iPhone on mobile data reaches the server (needs the iPhone on the tailnet first)
- **Rollback:** `sudo tailscale serve --tcp=2283 off`.

Open `http://<tailscale-ip>:2283` in a browser, create the admin user, and upload one photo to have something real to back up.

## Step 9: nightly backup (Phase 1a)

```bash
./platform/backup/install.sh
APPLY=1 ./platform/backup/install.sh
```

The script:
1. Creates `secrets/restic.enc.yaml` once (random repository password, SOPS-encrypted).
2. Writes the password to the root-only file `/etc/homelab/restic-password`, because unattended runs need it on disk.
3. Initialises the restic repository at `/mnt/backup/homelab-restic` (refuses if the drive is not mounted).
4. Installs `backup.sh` to `/usr/local/lib/homelab/`, writes `/etc/homelab/backup.env`, installs `homelab-backup.service` and `homelab-backup.timer`, and enables the timer (02:30 daily, `Persistent=true`, up to 10 minutes of random delay).

Run it once by hand and look at the result:

```bash
sudo systemctl start homelab-backup.service
systemctl status homelab-backup.service --no-pager
sudo restic -r /mnt/backup/homelab-restic --password-file /etc/homelab/restic-password snapshots
systemctl list-timers homelab-backup.timer --no-pager
```

- [x] The service finishes with `Deactivated successfully` and a snapshot appears (first one: `38d67282`, 17.6 MiB, empty library plus an 18 MB DB dump)
- [x] `/var/lib/homelab/last-backup-success` contains a timestamp
- [ ] The timer's first scheduled run (02:30) succeeded. Check with `journalctl -u homelab-backup.service`
- [ ] Unplugged-drive test: with the drive removed, a manual run exits non-zero with "backup repo not reachable" and SSD usage is unchanged
- **Rollback:** `sudo systemctl disable --now homelab-backup.timer`, delete the unit files from `/etc/systemd/system/`, `sudo rm -r /etc/homelab /usr/local/lib/homelab`. The repository on the drive stays; delete `/mnt/backup/homelab-restic` yourself if you want it gone.

> [!IMPORTANT]
> `secrets/restic.enc.yaml` is the only portable copy of the repository password. It opens only with the age key, so the age key copy in a cloud password manager protects your backup too.

## Step 10: restore drill

Prove the backup restores before trusting it. The commands that were run, and what they showed, are in [backup-restore.md](backup-restore.md#restore-drill). A restore with real photos is still open: upload a few photos, run a backup, then repeat the drill.

- [x] Mechanical drill: restore to `/var/tmp`, `pg_restore --list` reads the dump (142 tables), `restic check` reports no errors
- [ ] Drill with real photos opened in a scratch Immich
- [ ] Reboot test: after a reboot k3s, the `/mnt/backup` automount and `tailscaled` all come back by themselves and Immich answers on the tailnet
- **Rollback:** the drill only writes to a scratch directory; delete it.

## Done when

All checklists above pass, including the open boxes. Next: Phase 1b (Argo CD and monitoring), see [roadmap.md](roadmap.md). Do not start it before the restore drill with real photos passes.
