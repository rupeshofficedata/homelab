# Immich: GPU, auto-update and tuning

This page records what was set up for Immich on 2026-11-19, with the commands to check each part.
Every command runs on the server.

What was done:

1. Fixed Immich crashing from lack of memory (OOM).
2. Turned on automatic Immich updates.
3. Made Immich use the graphics card (GPU) for face/search/OCR and video work.
4. Tuned how many jobs run at once.
5. Cleaned up failed jobs and freed disk space.

Before you start, tell `kubectl` where the cluster is (once per terminal):

```bash
export KUBECONFIG=~/.kube/homelab
```

## 1. Fix "out of memory" crashes

**Problem.** Immich restarted again and again. Linux killed it because it used more memory than its limit ("OOMKilled").

**Check if it happened:**

```bash
journalctl -k --since "3 days ago" | grep -i "killed process"
kubectl -n immich get pods
```

Look at the `RESTARTS` column. A high number that keeps growing means crashes.

**Fix.** The memory limits live in `apps/immich/values.yaml`:

| Part | Old limit | New limit | Why |
|---|---|---|---|
| Immich server | 4Gi | 6Gi | Making thumbnails used about 3.7 GB |
| Machine learning (ML) | 2Gi | 3Gi | Face and search jobs on the GPU used more than 2 GB |

Edit the number, then `git add`, `git commit`, `git push`. Argo CD applies it by itself in about a minute.

**Check:**

```bash
kubectl -n immich get deploy immich-server -o jsonpath='{.spec.template.spec.containers[0].resources.limits}'
```

You should see the new limit.

## 2. Automatic Immich updates

**How it works.** Renovate (a bot on GitHub) opens a pull request (PR) when a new Immich version comes out. The file `renovate.json` now says:

- Small updates (minor and patch, like 3.4.1 to 3.4.2) **merge by themselves** after the release is 3 days old. The wait lets bad releases get pulled.
- Big updates (major, like 3.x to 4.x) stay manual. You merge them yourself.

The server image and the ML image are updated together.

**Safety net.** There is no backup before an auto-update. The nightly backup (02:33) is your safety net.

**Check:**

```bash
gh pr list                       # open update PRs
kubectl -n immich get deploy immich-server -o jsonpath='{.spec.template.spec.containers[0].image}'
```

To merge an update yourself right away: `gh pr merge <number> --squash --delete-branch`. Then wait one minute and run the second command to confirm the new version.

**Turn auto-merge off:** in `renovate.json`, delete the rule called "Auto-merge immich minor/patch".

## 3. Use the GPU

The server has an NVIDIA GTX 1080. Immich can use it for:

| Job | What the GPU does |
|---|---|
| Machine learning (smart search, faces, OCR) | Runs the models 5 to 10 times faster than the CPU |
| Video transcoding | Uses the chip's hardware video encoder (NVENC) |

Thumbnails do **not** use the GPU. That part always runs on the CPU.

### 3a. Check that the PC sees the GPU

```bash
nvidia-smi
```

You should see a table with `GeForce GTX 1080`. If the command is missing or fails, fix the NVIDIA driver first.

### 3b. Install the container toolkit (once, on the host)

This lets containers use the GPU.

```bash
sudo pacman -S nvidia-container-toolkit
sudo systemctl restart k3s
```

Wait about two minutes. All apps go down briefly while k3s restarts.

Do **not** run `nvidia-ctk runtime configure`. k3s finds the NVIDIA runtime by itself. That command writes files k3s does not read.

**Check k3s found it:**

```bash
sudo grep -n nvidia /srv/homelab/k3s/agent/etc/containerd/config.toml
kubectl get runtimeclass nvidia
```

Both should print something.

### 3c. Let Kubernetes hand out the GPU

The file `argocd/apps/nvidia-gpu.yaml` installs the "NVIDIA device plugin". It tells Kubernetes that the GPU exists. It splits the one card into **3 slots** (time-slicing). Immich server, Immich ML, and one spare slot so that updates can start a new pod before the old one stops.

**Check:**

```bash
kubectl -n kube-system get pods | grep nvdp
kubectl get node -o jsonpath='{.items[0].status.allocatable}' | tr ',' '\n' | grep gpu
```

You should see one `nvdp` pod `2/2 Running`, and `"nvidia.com/gpu":"3"`.

### 3d. Point Immich at the GPU

The file `apps/immich/values-gpu.yaml` is a separate "overlay" file:

- It switches the ML image to the `-cuda` version.
- It gives the server and ML pods one GPU slot each.

It is loaded by `argocd/apps/immich.yaml`. Because that file has `ignoreMissingValueFiles: true`, **deleting `values-gpu.yaml` is enough to go back to CPU.**

**Check the pods got the GPU:**

```bash
kubectl -n immich get pods
kubectl -n immich exec deploy/immich-server -- nvidia-smi -L
```

You should see `GPU 0: NVIDIA GeForce GTX 1080`.

**Check ML really uses CUDA.** Use the real ML pod name from `get pods`:

```bash
kubectl -n immich logs <ml-pod-name> | grep -i provider
```

You want `CUDAExecutionProvider`. If you only see `CPUExecutionProvider`, the GPU is not used. (The line appears when the first job runs.)

### 3e. Turn on hardware video encoding

Immich Admin → Settings → Video Transcoding → Hardware Acceleration → **NVENC**. (This was set through the API: `ffmpeg.accel = nvenc`.)

**Check while a video uploads:**

```bash
watch -n1 nvidia-smi
```

An `ffmpeg` process should appear in the list.

### 3f. See the GPU working

Run this in one terminal:

```bash
watch -n1 nvidia-smi
```

In Immich Admin → Jobs, start a job such as Smart Search. The `Volatile GPU-Util` and memory numbers go up while it runs.

## 4. Job concurrency (how many jobs run at once)

Higher numbers are faster but use more memory. This PC has 12 CPU threads, 16 GB RAM and 8 GB of GPU memory. These values were tested. Settings in Immich: Admin → Settings → Job Settings.

| Job | Value | Notes |
|---|---|---|
| Thumbnail generation | 3 | Memory is the limit, not CPU |
| Video conversion | 2 | NVENC |
| Smart search | 3 | 4 made the ML pod run out of memory |
| Face detection | 2 | |
| OCR | 1 | Uses the most GPU memory |

**Tuning rule.** Raise one number at a time. Watch memory and GPU memory for a minute:

```bash
kubectl top pods -n immich
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv
free -h
```

Go back down if:

- a pod restarts (`kubectl -n immich get pods`, look at `RESTARTS`),
- GPU memory is full (close to 8192 MiB),
- the PC has less than about 3 GB of RAM available.

**Why GPU jobs can restart:** when the GPU is nearly full, a pod can be killed. Check with `kubectl -n immich describe pod <name> | grep -A3 "Last State"`. `OOMKilled` means memory ran out.

## 5. Clean up failed jobs

Immich keeps a count of failed jobs, even old ones. To clear them, Admin → Jobs → each queue → **Clear failed jobs**. Then start **Thumbnail Generation** with "Missing" so anything that failed is made again.

**Check:** the failed counts go to 0 and stay at 0.

## 6. Free disk space

The 80% disk warning is about the whole disk (`/`), not only `/srv`. `/home`, `/var` and `/srv` share one drive.

```bash
df -h /                                   # how full
sudo du -xh --max-depth=1 /home/$USER | sort -rh | head     # biggest folders
```

Safe cleanups:

```bash
sudo k3s crictl rmi --prune     # remove unused container images
uv cache prune                  # unused Python download cache
paru -Scc                       # old package downloads (asks questions)
```

Check afterwards: `df -h /` and `kubectl get pods -A` (everything still `Running`).

## 7. Problems you may hit

| What you see | Meaning | Fix |
|---|---|---|
| New ML pod stays `Pending` | No free GPU slot. `kubectl -n immich describe pod <name>` says `Insufficient nvidia.com/gpu`. | Check the slot count in step 3c. It must be at least 3. |
| ML pod `OOMKilled` | Too little memory for the jobs | Lower the concurrency or raise the ML memory limit (step 1) |
| `CPUExecutionProvider` only | GPU not used | Check steps 3b to 3d |
| Pods `Running` but apps slow | Many jobs running at once | Lower concurrency (step 4) |
| `nvidia-smi` fails in the pod | Toolkit missing or k3s not restarted | Redo step 3b |

## 8. Going back to CPU only (new PC without a GPU)

Your data does not need to change. Face and search data live in the database. Transcoded videos live in the library. Only the speed changes.

```bash
git rm apps/immich/values-gpu.yaml argocd/apps/nvidia-gpu.yaml
git commit -m "chore: drop GPU overlay for CPU-only PC"
git push
```

Then in Immich Admin → Video Transcoding set Hardware Acceleration to **Disabled**. Do not install `nvidia-container-toolkit` on the new PC. Lower job concurrency to suit the new CPU.

Check: `kubectl -n immich get pods` shows ML on image `v3.x.x` without `-cuda`.
