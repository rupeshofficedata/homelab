# secrets/

Kubernetes Secrets encrypted with **SOPS + age**. The repo is public, so this folder is the only place a secret may exist, and only in encrypted form.

## Rules

- File names end in `.enc.yaml`. This matches `path_regex` in [`../.sops.yaml`](../.sops.yaml).
- Only the values under `data` and `stringData` are encrypted. Names and keys stay readable, so you can review a change.
- The pre-commit check rejects any changed file here that has no top-level `sops:` block.
- The age **private** key is never in the repo.

## The files

| File | Made by | Holds |
|---|---|---|
| `immich-db.enc.yaml` | `apps/immich/install.sh` | The Immich database login |
| `nextcloud.enc.yaml` | `apps/nextcloud/install.sh` | Database and admin passwords, Tailscale name |
| `vaultwarden.enc.yaml` | `apps/vaultwarden/install.sh` | The web address |
| `homepage.enc.yaml` | `apps/homepage/install.sh` | The list of links and allowed hosts |
| `grafana-admin.enc.yaml` | `argocd/install.sh` | The Grafana admin login |
| `restic.enc.yaml` | `platform/backup/install.sh` | The backup password |

## Everyday commands

```bash
sops -e -i secrets/example.enc.yaml   # encrypt a new file in place
sops secrets/example.enc.yaml         # edit: opens decrypted, locks again on save
sops -d secrets/example.enc.yaml      # print the decrypted text
```

Full guide, key backup, and what to do when a key is lost: [../docs/secrets.md](../docs/secrets.md).
