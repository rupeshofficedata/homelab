# Secrets: SOPS and age in a public repo

> [!WARNING]
> This repo is **public**. A password committed once stays in git history forever. Everything on this page exists to make that mistake hard.

## The idea

Think of the age key as a house key, and SOPS as a locksmith who locks only the **values** in a file. The names and structure stay readable, so a git diff still makes sense.

| Piece | What it is | Where it lives |
|---|---|---|
| age **public** key (`age1...`) | Locks | In the repo, inside `.sops.yaml` |
| age **private** key (`AGE-SECRET-KEY-...`) | Unlocks | `~/.config/sops/age/keys.txt`, **never in git** |
| `secrets/*.enc.yaml` | The locked files | In the repo |

## Set up the key

`bootstrap/scripts/04-secrets.sh` does this for you (see [getting-started.md](getting-started.md#step-5-create-the-secret-key)). By hand:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt     # prints the public key
```

Put the public key into `.sops.yaml`.

### What `.sops.yaml` says

```yaml
creation_rules:
  - path_regex: secrets/.*\.enc\.ya?ml$
    encrypted_regex: ^(data|stringData)$
    age: age1...your-public-key...
```

| Line | Meaning |
|---|---|
| `path_regex` | Only files named `secrets/<name>.enc.yaml` follow these rules |
| `encrypted_regex` | Only the `data` and `stringData` parts of a Kubernetes Secret are locked. Names and labels stay readable. |
| `age` | The public key the file is locked for. Add a second key to give a spare person or device access. |

## Everyday use

Most secrets are made for you: each `install.sh` script creates one with random passwords and encrypts it. To make one by hand:

```bash
cat > secrets/example.enc.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: example
  namespace: example
stringData:
  password: change-me
EOF
sops --encrypt --in-place secrets/example.enc.yaml
```

This writes the file, then replaces the values with `ENC[AES256_GCM,...]` and adds a `sops:` block. Do not run `git add` on the file before the encrypt step.

```bash
sops secrets/example.enc.yaml                # open decrypted in your editor, locks again on save
sops --decrypt secrets/example.enc.yaml      # print the plain text on the screen
```

Never save decrypted output as a tracked file. `*.dec.yaml` is in `.gitignore` as a safety net.

## How the cluster gets the secrets

The install scripts decrypt a secret in memory and pipe it straight to the cluster:

```bash
sops -d secrets/immich-db.enc.yaml | kubectl apply -f -
```

Argo CD does not read SOPS files itself, so it does not manage these secrets. Each install script is the step that puts a secret in the cluster. This is why you run an app's `install.sh` once before Argo CD syncs the app. (An Argo CD plugin called KSOPS could do this automatically. It is not set up. See the [roadmap](roadmap.md).)

## Back up the keys

Two things must survive the loss of the server:

| Secret | Why it matters | Keep it in |
|---|---|---|
| age private key | Without it, every `*.enc.yaml` file is unreadable | A password manager **and** a copy on the backup drive |
| restic backup password | Without it, the backups cannot be opened, ever | The same two places |

The restic password is stored in `secrets/restic.enc.yaml`. It opens with the age key. So if you protect the age key, you protect the backups too.

> [!WARNING]
> Do **not** keep these only in a Vaultwarden that runs on this server. It disappears together with the server you are trying to recover.

## When something goes wrong

| Situation | Effect | What to do |
|---|---|---|
| **Private key lost** | Encrypted files cannot be read. The backups can still be opened if you know the restic password. | Make a new key. Invent new passwords and encrypt them. Databases remember their old passwords inside their data, so reset them (for Postgres: `ALTER USER`). |
| **Private key leaked** | Anyone can read every secret, including old versions in git history. | Change every password, make a new key, encrypt again, replace the key on the server. Rewriting history is not enough. |
| **Plain secret committed** | If it was pushed, it is public. | Treat it as leaked. Change that password at once. Then remove it from history. |
| **restic password lost** | The backups are unreadable. | No recovery. Prevent it with the two copies above. |

## The pre-commit check

`.githooks/pre-commit` runs before every commit. Turn it on once per clone with `git config core.hooksPath .githooks`.

| Check | It blocks the commit when |
|---|---|
| SOPS | A changed file in `secrets/` has no top-level `sops:` key |
| gitleaks | gitleaks finds something that looks like a secret (or gitleaks is not installed) |
| Shell syntax | `bash -n` fails on a changed `.sh` file |

Also turn on **secret scanning and push protection** on GitHub (repository Settings, Code security).

> [!NOTE]
> A local check can be skipped with `git commit --no-verify`. It stops accidents, not bad intent. GitHub push protection is the second layer.

## Why not Vault or Sealed Secrets?

- **Vault** is one more service to run, back up and unseal. Its unseal keys are the same kind of problem as the age key, for only a few secrets.
- **Sealed Secrets** needs no extra Argo CD part, but its files open only with that cluster's own key. That makes moving to a new server harder.

More in [decisions.md](decisions.md#2-sops--age-not-vault-or-sealed-secrets).
