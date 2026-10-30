# HomeLab documentation

HomeLab is a home server that runs on **k3s** and **Argo CD**. It hosts Immich, Nextcloud, Vaultwarden, Jellyfin and more. **Tailscale** keeps it private. **restic** backs it up every night.

Each page explains the idea first, then the commands.

## Where to start

| You want to... | Read |
|---|---|
| Understand the words used here | [glossary.md](glossary.md) |
| See how the pieces fit together | [architecture.md](architecture.md) |
| Build the server step by step | [getting-started.md](getting-started.md) |
| Understand why each tool was chosen | [decisions.md](decisions.md) |
| Keep passwords safe in a public repo | [secrets.md](secrets.md) |
| Check that everything works, and fix it | [health-check.md](health-check.md) |
| Know your data is safe, and restore it | [backup-restore.md](backup-restore.md) |
| Move everything to another computer | [migrate-to-new-pc.md](migrate-to-new-pc.md) |
| See what is built and what is next | [roadmap.md](roadmap.md) |

## Quick answers

- **"I committed a password."** Go to [secrets.md](secrets.md#when-something-goes-wrong).
- **"I lost my key."** Go to [secrets.md](secrets.md#when-something-goes-wrong).
- **"An app is down."** Go to [health-check.md](health-check.md).
- **"Is my data safe?"** Go to [backup-restore.md](backup-restore.md).
- **"I bought a new computer."** Go to [migrate-to-new-pc.md](migrate-to-new-pc.md).

## Habits used in every page

- Commands are for bash. Set a variable for one command like this: `APPLY=1 ./script.sh`.
- Scripts are **previews** unless you set `APPLY=1`.
- Marks: `[x]` means checked, `[ ]` means not checked yet.
- No secret, domain name, public IP address or device name belongs in this repo or in these pages.
