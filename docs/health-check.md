# Health check

How to check that HomeLab is healthy, step by step, and what to do when something is wrong.

Run these steps after a reboot, after an upgrade, or any time something feels off. All commands run on the server.

## Before you start

Tell `kubectl` where the cluster is. Do this once in each new terminal:

```bash
export KUBECONFIG=~/.kube/homelab
```

Find your server's Tailscale address. You need it in step 4:

```bash
tailscale ip -4          # for example 100.x.x.x
```

## Step 1: Is k3s running?

```bash
systemctl is-active k3s
```

| You see | Meaning |
|---|---|
| `active` | Good. Go to step 2. |
| `inactive` or `failed` | k3s is stopped. **All apps are down, and the nightly backup will fail.** Start it: `sudo systemctl start k3s`, wait one or two minutes, then go to step 2. |

Does k3s start by itself after a reboot?

```bash
systemctl is-enabled k3s
```

`enabled` means yes. `disabled` means you must start it by hand after every reboot. Turn on start at boot with `sudo systemctl enable k3s`.

## Step 2: Are all the apps running?

```bash
kubectl get pods -A
```

Every line should say `Running`, and the `READY` column should be full (for example `1/1` or `2/2`).

| You see | Meaning and fix |
|---|---|
| `Pending` or `ContainerCreating` | Still starting. Wait a minute and look again. |
| `CrashLoopBackOff` or `Error` | The app keeps crashing. Read its log: `kubectl -n <namespace> logs <pod-name>` |
| `0/1` for a long time | The app is not ready. Look at the events: `kubectl -n <namespace> describe pod <pod-name>` |
| `The connection to the server ... was refused` | k3s is not running. Go back to step 1. |

## Step 3: Is Tailscale sharing the apps?

```bash
tailscale serve status
```

You should see one entry for each app. Each entry points to `127.0.0.1:<NodePort>`:

| Tailscale port | Points to | App |
|---|---|---|
| 80 | 30800 | Homepage |
| 2283 | 30283 | Immich |
| 8096 | 30096 | Jellyfin |
| 8081 | 30081 | qBittorrent |
| 3000 | 30300 | Grafana |
| 9090 | 30900 | Prometheus |
| 8443 (https) | 30443 | Nextcloud |
| 8222 (https) | 30222 | Vaultwarden |

If an entry is missing, add it again with the matching command in [getting-started.md](getting-started.md#step-10-install-the-other-apps).

## Step 4: Does every app answer?

Test them all at once. Put your Tailscale address in `IP`:

```bash
IP=100.x.x.x
for port in 80 2283 8096 8081 3000 9090; do
  echo "$port: $(curl -s -o /dev/null -m 5 -w '%{http_code}' http://$IP:$port/)"
done
```

For the two HTTPS apps, use your Tailscale name (`tailscale status` shows it):

```bash
NAME=yourpc.yourtailnet.ts.net
for port in 8443 8222; do
  echo "$port: $(curl -s -o /dev/null -m 8 -w '%{http_code}' https://$NAME:$port/)"
done
```

How to read the numbers:

| Code | Meaning |
|---|---|
| `200` | OK. The page loads. |
| `302` | OK. The app sends you to its login page. |
| `401` | OK. The app wants you to log in. |
| `000` | No answer. The app or the Tailscale forward is down. Check steps 2 and 3. |
| `502` or `503` | Tailscale works, but the app behind it does not. Check step 2. |

## Step 5: Did the last backup work?

```bash
systemctl status homelab-backup.service --no-pager
```

Look for `Deactivated successfully`. If you see `failed`, read why:

```bash
journalctl -u homelab-backup.service -e
```

When was the last good backup?

```bash
sudo cat /var/lib/homelab/last-backup-success | xargs -I{} date -d @{}
```

It should be less than one day old. When is the next one?

```bash
systemctl list-timers homelab-backup.timer --no-pager
```

Common backup errors:

| Error in the log | Meaning and fix |
|---|---|
| `backup repository not found at ... (is the drive plugged in?)` | The drive is missing. Plug it in, check with `ls /mnt/backup`, then run `sudo systemctl start homelab-backup.service`. |
| `The connection to the server 127.0.0.1:6443 was refused` | k3s is not running. Do step 1, then run the backup again. |
| `the database dump is empty` | The database pod has a problem. Do step 2. |

To run a backup now: `sudo systemctl start homelab-backup.service`. It takes a few minutes.

## Step 6: Is the backup data healthy?

List the snapshots:

```bash
sudo restic -r /mnt/backup/homelab-restic --password-file /etc/homelab/restic-password snapshots
```

You should see recent snapshots tagged `immich`, `vaultwarden` and `nextcloud`. The newest are at the bottom.

Check the data (this takes a while):

```bash
sudo restic -r /mnt/backup/homelab-restic --password-file /etc/homelab/restic-password check
```

It should end with `no errors were found`. The nightly job already runs a small check every Sunday.

## Step 7: Look at the alerts

Open Prometheus in a browser: `http://<tailscale-ip>:9090/alerts`.

| Alert | Meaning |
|---|---|
| `Watchdog` (firing) | **Normal.** It always fires, to prove that alerting works. |
| `PrometheusNotConnectedToAlertmanagers` | **Normal.** Alertmanager is turned off on purpose. |
| `BackupStale` | No good backup for 26 hours. Do step 5. |
| `SrvDiskAlmostFull` | `/srv` is more than 80% full. Free space, or move media to a bigger drive. |
| `HighSwapUse` | The server is short of memory. Look at `free -h` and stop what you do not need. |

To see the backup age yourself, open `http://<tailscale-ip>:9090/graph` and run:

```text
time() - homelab_backup_last_success_timestamp_seconds
```

The answer is in seconds. Below `86400` means the last backup is less than one day old.

## An app does not open on my phone or laptop

The server checks above all pass, but a device cannot open an app:

1. Open the Tailscale app on the device. Check that it says **Connected**.
2. Reload the page. If the server was down earlier, the browser may show an old error.
3. On a phone, switch Wi-Fi off and on, or disconnect and connect Tailscale.
4. Check the address: `http://` for most apps, `https://` with the Tailscale name for Nextcloud and Vaultwarden.
5. Still failing? Run step 4 from the server. If the server gets an answer, the problem is on the device.

## Quick daily check

Three commands cover most problems:

```bash
systemctl is-active k3s                                   # active
kubectl get pods -A | grep -v Running                     # only the header line
systemctl status homelab-backup.service --no-pager | grep -E 'Active|Deactivated'
```
