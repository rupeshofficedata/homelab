# Getting started

This guide builds the whole HomeLab, one step at a time. Each step says what it does, how to check it, and how to undo it.

Steps 1 to 6 prepare the computer. Steps 7 to 12 install the apps and the backup.

> [!IMPORTANT]
> Every script is a **preview** by default. It prints the commands it would run and changes nothing. Read the preview first. Run it again with `APPLY=1` to do it for real.

```bash
./bootstrap/scripts/03-storage.sh            # preview only
APPLY=1 ./bootstrap/scripts/03-storage.sh    # do it
```

## The scripts

| Script | What it does | Changes the system? |
|---|---|---|
| `bootstrap/scripts/lib.sh` | Helper functions that all scripts share. You never run it. | No |
| `01-preflight.sh` | Checks that the computer is ready | Never |
| `02-free-ram.sh` | Stops some containers to free memory (optional) | Only with `APPLY=1` |
| `03-storage.sh` | Creates data folders and sets up the backup drive | Only with `APPLY=1` |
| `04-secrets.sh` | Creates the secret key | Only with `APPLY=1` |
| `05-k3s.sh` | Installs k3s | Only with `APPLY=1` |

Settings you may want to change (data folder, drive label, mount point) are in `bootstrap/config.env`. To change them only on your machine, put them in `bootstrap/config.local.env` (git ignores that file).

## Before you start

You need:

- A Linux computer with the **btrfs** filesystem under `/srv`, at least 4 GB of free memory and 100 GB of free disk.
- An external drive for backups, formatted as **exFAT**, with a filesystem label (default label: `homelab-backup`).
- A free [Tailscale](https://tailscale.com) account.
- A copy of this repo (`git clone`).

## Step 1: Install the tools

Install these with your package manager: `age`, `sops`, `gitleaks`, `restic`, `tailscale`, `helm`, `kubectl`, `docker`, `shellcheck`. (`k3s` is installed by step 6.)

Turn on the commit check once for your copy of the repo:

```bash
git config core.hooksPath .githooks
```

- [ ] `./bootstrap/scripts/01-preflight.sh` shows `ok` for every program
- **Undo:** remove the packages with your package manager.

## Step 2: Check the computer

```bash
./bootstrap/scripts/01-preflight.sh
```

It checks programs, free memory, swap, free disk, the filesystem, the backup drive and port 6443. A line that starts with `FIX` needs your attention.

- [ ] No `FIX` line you do not understand
- **Undo:** nothing to undo. This script changes nothing.

## Step 3: Free memory (optional)

Skip this step if no other containers run on the computer.

If other Docker containers use memory you need, list them in `config.local.env`:

```bash
STOP_CONTAINERS_REGEX='^(test-|demo-)'    # matches container names
```

Then:

```bash
./bootstrap/scripts/02-free-ram.sh              # shows which containers match
APPLY=1 ./bootstrap/scripts/02-free-ram.sh      # stops them
```

The names of the stopped containers are saved in `~/.cache/homelab/stopped-containers.txt`.

- [ ] `docker ps` no longer lists them
- **Undo:** `xargs docker start < ~/.cache/homelab/stopped-containers.txt`

## Step 4: Storage and the backup drive

If your desktop mounted the drive automatically, unmount it first. The script refuses to continue while the drive is mounted somewhere else.

```bash
./bootstrap/scripts/03-storage.sh
APPLY=1 ./bootstrap/scripts/03-storage.sh
```

What it does:

1. Creates `/srv/homelab/k3s`, `storage`, `media` and `files`. It turns off copy-on-write for `storage` (better for databases).
2. Creates the empty folder `/mnt/backup` and makes it read-only. If the drive is unplugged, a backup cannot write to the main disk.
3. Adds a line to `/etc/fstab`. The drive then mounts the first time you open `/mnt/backup`, and a missing drive never stops the computer from booting.

- [ ] `lsattr -d /srv/homelab/storage` shows a `C`
- [ ] `ls /mnt/backup` shows the files on the drive
- [ ] `findmnt /mnt/backup` shows `exfat`
- **Undo:** remove the added line from `/etc/fstab`, run `sudo systemctl daemon-reload`, then `sudo chattr -i /mnt/backup` and `sudo rmdir /mnt/backup`. The folders in `/srv/homelab` can be deleted while they are empty. The script never changes files on the drive.

> [!NOTE]
> Eject the drive properly before you unplug it: `sudo umount /mnt/backup`. exFAT has no journal, so unplugging during a write can damage the data.

## Step 5: Create the secret key

```bash
./bootstrap/scripts/04-secrets.sh
APPLY=1 ./bootstrap/scripts/04-secrets.sh
```

It creates the age key `~/.config/sops/age/keys.txt`, unless one exists. Then it copies the **public** half into `.sops.yaml`. The private half never goes into git.

> [!WARNING]
> Back up the key now. Copy it into a password manager and onto the backup drive. Without it, every encrypted secret is lost. See [secrets.md](secrets.md).

- [ ] `~/.config/sops/age/keys.txt` exists and does not show in `git status`
- [ ] `.sops.yaml` has a line `age: age1...` with a real key
- [ ] The key is saved in two places outside the server
- **Undo:** delete the key file and put the placeholder back in `.sops.yaml`. Only do this before you encrypt anything.

## Step 6: Tailscale and k3s

### Tailscale

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
```

This starts Tailscale at boot and prints a login link. Install Tailscale on your phone and laptop and sign in to the same account. Turn off sleep on the server, so uploads and backups can run at night.

- [ ] `tailscale status` lists the server, with a `100.x.x.x` address
- [ ] Your phone and laptop appear in the list
- **Undo:** `sudo tailscale down; sudo systemctl disable --now tailscaled`

### k3s

```bash
./bootstrap/scripts/05-k3s.sh
APPLY=1 ./bootstrap/scripts/05-k3s.sh
```

The script downloads the official installer (you see the steps in the preview), then:

- copies `bootstrap/k3s-config.yaml` to `/etc/rancher/k3s/config.yaml`. This sets the data folders, turns off Traefik and servicelb (we do not need them), and makes NodePorts listen on `127.0.0.1` only.
- starts k3s as a system service.
- saves a kubeconfig to `~/.kube/homelab`, so your normal `~/.kube/config` stays untouched.

Tell `kubectl` where the cluster is:

```bash
export KUBECONFIG=~/.kube/homelab
kubectl get nodes
```

- [ ] `kubectl get nodes` shows one node with status `Ready`
- [ ] `kubectl get pods -A` shows only system pods, all `Running`
- [ ] After a reboot, `systemctl is-active k3s` prints `active`
- **Undo:** `/usr/local/bin/k3s-uninstall.sh` (this also deletes the data in `/srv/homelab/k3s`)

## Step 7: Install Immich

```bash
./apps/immich/install.sh
APPLY=1 ./apps/immich/install.sh
```

The script, in order:

1. Creates the `immich` namespace.
2. Creates `secrets/immich-db.enc.yaml` once. It holds a random database password, encrypted with SOPS. Then it sends the decrypted secret straight to the cluster.
3. Creates the photo volume (150 Gi), the database (a one-pod StatefulSet) and the NodePort 30283.
4. Installs the official Immich Helm chart (version pinned in the script, settings in `apps/immich/values.yaml`).

Run it again after you edit `values.yaml`. That upgrades Immich.

- [ ] `kubectl -n immich get pods` shows the server, machine-learning, valkey and `immich-postgres-0` as `Running`
- [ ] `curl http://127.0.0.1:30283/api/server/ping` prints `{"res":"pong"}`
- [ ] The same request to the server's LAN address on port 30283 gets no answer (the port is private)
- **Undo:** `helm uninstall immich -n immich`, then `kubectl delete -f apps/immich/` and `kubectl delete ns immich`. Deleting the namespace deletes the photo volume, so only do it while the library is empty.

## Step 8: Make Immich reachable on your Tailscale network

```bash
sudo tailscale serve --bg --tcp 2283 tcp://127.0.0.1:30283
tailscale serve status
```

This forwards port 2283 on your tailnet to the private NodePort. The traffic is encrypted by Tailscale. The address is `http://<tailscale-ip>:2283`. Find your address with `tailscale ip -4`.

Open it in a browser, create the admin user, and upload one photo so the backup has something to save.

- [ ] `curl http://<tailscale-ip>:2283/api/server/ping` prints `{"res":"pong"}`
- [ ] The Immich phone app logs in over the tailnet
- **Undo:** `sudo tailscale serve --tcp=2283 off`

> [!NOTE]
> If the phone app refuses an `http://` address, use `tailscale serve --https` instead. This needs HTTPS turned on in the Tailscale admin console.

## Step 9: Turn on Argo CD (GitOps)

Argo CD watches this repo on GitHub and deploys what it finds. It only sees what is on GitHub, so commit and push first. The script refuses to run if you have unpushed changes.

```bash
./argocd/install.sh
APPLY=1 ./argocd/install.sh
```

It installs Argo CD, creates the Grafana admin password (encrypted), and applies the root app. The root app then creates one Argo CD application for each file in `argocd/apps/`. Argo CD takes over Immich too: it adopts the pods that step 7 created.

- [ ] `kubectl -n argocd get applications` lists the apps, and they become `Synced` and `Healthy`
- **Undo:** `kubectl delete application root -n argocd` stops Argo CD managing the apps. The apps keep running.

More detail: [argocd/README.md](../argocd/README.md).

## Step 10: Install the other apps

Each app below has its own `install.sh`. It creates the namespace and the encrypted private settings. Run it **before** Argo CD syncs that app (if you run it later, the app's pods simply start once the secret exists). Then publish the app on the tailnet.

| App | Install | Publish on the tailnet | Address |
|---|---|---|---|
| Vaultwarden | `APPLY=1 ./apps/vaultwarden/install.sh` | `sudo tailscale serve --bg --https=8222 http://127.0.0.1:30222` | `https://<name>.ts.net:8222` |
| Nextcloud | `APPLY=1 ./apps/nextcloud/install.sh` | `sudo tailscale serve --bg --https=8443 http://127.0.0.1:30443` | `https://<name>.ts.net:8443` |
| Jellyfin | none needed | `sudo tailscale serve --bg --tcp 8096 tcp://127.0.0.1:30096` | `http://<tailscale-ip>:8096` |
| qBittorrent | none needed | `sudo tailscale serve --bg --tcp 8081 tcp://127.0.0.1:30081` | `http://<tailscale-ip>:8081` |
| Homepage | `APPLY=1 ./apps/homepage/install.sh` | `sudo tailscale serve --bg --tcp 80 tcp://127.0.0.1:30800` | `http://<tailscale-ip>/` |
| Grafana | none needed | `sudo tailscale serve --bg --tcp 3000 tcp://127.0.0.1:30300` | `http://<tailscale-ip>:3000` |
| Prometheus | none needed | `sudo tailscale serve --bg --tcp 9090 tcp://127.0.0.1:30900` | `http://<tailscale-ip>:9090` |

Vaultwarden and Nextcloud need HTTPS, so their address uses your Tailscale name (find it with `tailscale status`). The install scripts read that name for you.

After an install script creates a new file in `secrets/`, commit and push it:

```bash
git add secrets/ && git commit -m "add encrypted secrets" && git push
```

- [ ] Every app opens from your phone or laptop
- **Undo:** each app has its own notes in `apps/<app>/README.md`.

## Step 11: Turn on the nightly backup

```bash
./platform/backup/install.sh
APPLY=1 ./platform/backup/install.sh
```

The script:

1. Creates `secrets/restic.enc.yaml` once (a random backup password, encrypted).
2. Saves the password in `/etc/homelab/restic-password`, readable by root only. The nightly job needs it when nobody is logged in.
3. Creates the restic repository at `/mnt/backup/homelab-restic`. It refuses if the drive is not mounted.
4. Installs `backup.sh`, its settings, and a systemd timer that runs at 02:30 every night.

Run the first backup now and look at the result:

```bash
sudo systemctl start homelab-backup.service
systemctl status homelab-backup.service --no-pager
sudo restic -r /mnt/backup/homelab-restic --password-file /etc/homelab/restic-password snapshots
systemctl list-timers homelab-backup.timer --no-pager
```

- [ ] The service ends with `Deactivated successfully`, and `snapshots` lists a new snapshot
- [ ] `/var/lib/homelab/last-backup-success` contains a number
- [ ] The next morning, `journalctl -u homelab-backup.service` shows a successful 02:30 run
- [ ] **Unplugged drive test:** unmount the drive, run the service, and see it fail with "backup repository not found". The main disk usage must not change.
- **Undo:** `sudo systemctl disable --now homelab-backup.timer`, delete the two unit files in `/etc/systemd/system/`, then `sudo rm -r /etc/homelab /usr/local/lib/homelab`. The backups on the drive stay.

> [!IMPORTANT]
> `secrets/restic.enc.yaml` is the only portable copy of the backup password. It opens only with the age key. Protect the age key and you protect the backups too.

## Step 12: Test a restore

A backup you have never restored is only a hope. Follow the restore drill in [backup-restore.md](backup-restore.md#restore-drill).

- [ ] Restore drill passed
- [ ] Reboot test: after a reboot, k3s, the `/mnt/backup` automount and Tailscale all start by themselves, and the apps answer on the tailnet

## Done when

Every box above is ticked. Keep the restore drill on your calendar: repeat it after big upgrades.

To check the server later, follow [health-check.md](health-check.md).
