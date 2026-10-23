# apps/homepage/

One page that links to every app, served on the tailnet at `http://<tailscale-ip>/`.

| File | What it does |
|---|---|
| `homepage.yaml` | ConfigMap (theme), Deployment (pinned image, 256Mi limit, no Kubernetes API access), loopback NodePort 30800. |
| `install.sh` | Creates `secrets/homepage.enc.yaml` (link list + allowed hosts, includes the Tailscale address, so SOPS-encrypted) and applies it. Run once before Argo syncs the app. |

Publish it: `sudo tailscale serve --bg --tcp 80 tcp://127.0.0.1:30800`.

To add an app, edit the heredoc in `install.sh`, delete `secrets/homepage.enc.yaml`, re-run with `APPLY=1`, then commit the new encrypted file.
