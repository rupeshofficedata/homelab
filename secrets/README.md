# secrets/

Kubernetes Secrets encrypted with **SOPS + age**. This repo is public, so this is the only place secrets may exist, and only in encrypted form.

## Rules

- File names end in `.enc.yaml` (matches `path_regex` in [`../.sops.yaml`](../.sops.yaml)).
- Only values under `data` / `stringData` are encrypted; names and keys stay readable for review.
- The pre-commit hook rejects any staged file here without a top-level `sops:` block.
- The age **private** key never lives in the repo.

## Everyday commands

```bash
sops -e -i secrets/immich-db.enc.yaml   # encrypt a new file in place
sops secrets/immich-db.enc.yaml         # edit: decrypts in your editor, re-encrypts on save
```

Full guide, key backup, and what happens if the key is lost: [../docs/secrets.md](../docs/secrets.md).

## Currently

No secrets yet. The first ones arrive in Phase 1a: Immich DB password and the restic repository password.
