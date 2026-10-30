# apps/homepage/

One start page with a link to every app. Address: `http://<tailscale-ip>/`.

## Files

| File | What it does |
|---|---|
| `homepage.yaml` | A ConfigMap (the theme), the Deployment (pinned image, 256 Mi memory limit, no access to the Kubernetes API), and a private NodePort 30800 |
| `install.sh` | Creates `secrets/homepage.enc.yaml` and applies it. It holds the list of links and the allowed hosts, which contain your Tailscale address, so they are encrypted. Run it before Argo CD syncs the app. |

Publish it: `sudo tailscale serve --bg --tcp 80 tcp://127.0.0.1:30800`.

## Add or change a link

1. Edit the list inside `install.sh`.
2. Delete `secrets/homepage.enc.yaml`.
3. Run `APPLY=1 ./apps/homepage/install.sh`.
4. Commit the new encrypted file.
