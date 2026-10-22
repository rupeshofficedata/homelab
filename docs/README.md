# HomeLab documentation

A portable homelab: **k3s + Argo CD** on one PC, **Immich** for iPhone photo backup, **restic** to an external drive, **Tailscale** for private access. Built in phases; each page says what is built and what is only designed.

> [!NOTE]
> Status legend used across these pages: **Built** = exists in the repo. **Planned** = designed, not written. Roadmap and getting-started also use `[x]` done and checked, `[~]` built but not fully verified, `[ ]` not done. **Untested design** = written or specified but never run end to end.

## Reading order

| # | Page | What you get |
|---|------|--------------|
| 1 | [architecture.md](architecture.md) | Components, data flow, storage layout, why each piece exists |
| 2 | [decisions.md](decisions.md) | Every major choice, what was rejected, when to revisit |
| 3 | [getting-started.md](getting-started.md) | Phase 0 and 1a walkthrough: bootstrap scripts, Immich, tailnet access, backup timer, restore drill, with checks and rollback |
| 4 | [secrets.md](secrets.md) | SOPS + age for a public repo: setup, key backup, loss and leak plans |
| 5 | [backup-restore.md](backup-restore.md) | The systemd-timer restic backup, what is verified, restore drill, restore on a new PC |
| 6 | [migrate-to-new-pc.md](migrate-to-new-pc.md) | Ordered steps to rebuild everything elsewhere |
| 7 | [roadmap.md](roadmap.md) | Phases 0 to 2, risks, verification checklist |

## Which page do I need?

- **"What is this and why?"** Start with [architecture.md](architecture.md), then [decisions.md](decisions.md).
- **"Set it up today."** [getting-started.md](getting-started.md).
- **"I committed a password" / "I lost my key."** [secrets.md](secrets.md).
- **"Is my data safe?"** [backup-restore.md](backup-restore.md).
- **"I bought a new PC."** [migrate-to-new-pc.md](migrate-to-new-pc.md).

## Conventions

- Shell commands work in bash and fish unless a fish-specific variant is shown.
- Bootstrap scripts are **dry runs** unless you set `APPLY=1`.
- No secret, domain, public IP, tailnet name or device name belongs in this repo or these docs.
