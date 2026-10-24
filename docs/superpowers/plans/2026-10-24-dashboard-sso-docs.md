# Dashboard, SSO and Beginner Docs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a login-gated dashboard (layout A) backed by Pocket ID single sign-on, wire SSO into the apps that support it, and write beginner-level docs for every app.

**Architecture:** Pocket ID (OIDC provider, SQLite on a PVC) runs on k3s and is published on its own Tailscale HTTPS port. A small stateless Flask dashboard is an OIDC client of Pocket ID, checks app health from inside the cluster, and calls Pocket ID's admin API for the Users page. Apps follow the existing pattern: manifests in `apps/<name>/`, an Argo CD Application with `prune: false`, SOPS secrets created by `install.sh`.

**Tech Stack:** k3s, Argo CD, Pocket ID, Python 3 + Flask + Authlib + requests + PyYAML, pytest, Docker (local image build), Tailscale serve, SOPS + age, Mermaid.

**Spec:** `docs/superpowers/specs/2026-10-24-dashboard-sso-docs-design.md`

## Global Constraints

- Repo is public: no plaintext secret, domain, public IP, tailnet name or device name in any committed file. Only `secrets/*.enc.yaml` (SOPS) may hold secrets; hostnames and the Tailscale IP come from the secret or from `tailscale` at runtime.
- Every script is a dry run unless `APPLY=1`; every secret is applied with `sops -d | kubectl apply -f -`.
- Apps with data use `prune: false`; manifests follow `apps/jellyfin/jellyfin.yaml` (non-root, drop ALL capabilities, resource limits, `enableServiceLinks: false`, loopback NodePort 30xxx).
- Dashboard must work at phone width, show status as green (up), amber (slower than 1.5 s) or red (down, with "down since").
- Admin-only routes are enforced on the server. Credentials are shown only to the `admin` group and are never logged.
- Each app keeps a local admin login as break-glass. Vaultwarden and qBittorrent keep their own logins.
- Docs: simple English, beginner DevOps level, only this project's examples, Mermaid diagrams, each file explained.
- KUBECONFIG for all cluster commands: `~/.kube/homelab`. Run `git push` after each commit; gitleaks pre-commit must pass.

## Review Focus

- Pocket ID issuer URL changes after passkeys are enrolled: all passkeys break. Test pins the issuer once and the dashboard refuses to start if the discovery document's `issuer` differs from the configured one.
- Pod cannot resolve or reach the Tailscale HTTPS issuer URL: SSO apps fail at login. Task 2 tests it from inside a pod before any app is wired.
- Status check target is down or hangs: dashboard must still render (per-check timeout 3 s, parallel checks).
- A non-admin opens `/users`, `/credentials` or calls their POST/DELETE endpoints directly: must get 403.
- Admin tries to delete their own account or the last admin: must be refused.
- Uploaded profile photo is huge or not an image: reject over 2 MB or non-PNG/JPEG/WebP.
- Pocket ID is down: dashboard shows a clear "sign-in service unavailable" page, not a stack trace.
- Credentials panel Secret is missing: show "not found" for that app, others still render.

---

## File Structure

```
apps/pocket-id/        pocket-id.yaml  install.sh  README.md
apps/dashboard/        dashboard.yaml  install.sh  Dockerfile  README.md
                       src/app.py        routes + app factory
                       src/config.py     Settings loaded from env
                       src/catalog.py    load apps.yaml, group visibility
                       src/status.py     check_all() health probes
                       src/auth.py       OIDC login, session, require_group
                       src/pocketid.py   Pocket ID admin API client
                       src/creds.py      read allow-listed Secrets
                       src/help.py       diagnostics (Prometheus, logs)
                       src/apps.yaml     app metadata (no domains)
                       src/templates/, src/static/
                       tests/            pytest files per module
argocd/apps/           pocket-id.yaml  dashboard.yaml
platform/backup/       backup.sh (Pocket ID block)
platform/monitoring/   values.yaml (Grafana oauth)
apps/immich|nextcloud|jellyfin   SSO settings
docs/apps/             one guide per app (Task 10)
```

---

### Task 1: Deploy Pocket ID

**Files:**
- Create: `apps/pocket-id/pocket-id.yaml`, `apps/pocket-id/install.sh`, `apps/pocket-id/README.md`, `argocd/apps/pocket-id.yaml`

**Interfaces:**
- Produces: Service `pocket-id.pocket-id.svc:1411`; NodePort 30411; Tailscale HTTPS port 8411; SOPS secret `secrets/pocket-id.enc.yaml` with keys `encryption-key` (32 random bytes, base64) and `app-url` (`https://<node>.<tailnet>.ts.net:8411`, built at install time from `tailscale status`).

- [ ] **Step 1: Write `pocket-id.yaml`.** PVC 1Gi `pocket-id-data` at `/app/data`; Deployment `ghcr.io/pocket-id/pocket-id` pinned to the newest stable tag at write time (`# renovate:` comment above, like Jellyfin), env `APP_URL` and `ENCRYPTION_KEY` from the secret, `TRUST_PROXY=true`, non-root, `Recreate`, readiness `GET /healthz` or the documented health path; NodePort 30411.
- [ ] **Step 2: Write `install.sh`** (dry run default): generate the encryption key once, build `app-url`, encrypt to `secrets/pocket-id.enc.yaml`, apply, and run `sudo tailscale serve --bg --https=8411 http://127.0.0.1:30411` (print the command if not root).
- [ ] **Step 3: Write `argocd/apps/pocket-id.yaml`** copied from `argocd/apps/jellyfin.yaml` (`prune: false`).
- [ ] **Step 4: Verify.** Run `APPLY=1 ./apps/pocket-id/install.sh`, then `curl -s "$APP_URL/.well-known/openid-configuration" | jq .issuer`. Expected: the exact `APP_URL`. Pod `Ready`.
- [ ] **Step 5: Write README** (each file's purpose and how it works) and commit `feat: Pocket ID`.

### Task 2: Bootstrap Pocket ID and prove cluster reachability

**Files:**
- Modify: `apps/pocket-id/README.md`, `apps/pocket-id/install.sh` (helper `--issuer-check`)
- Modify (cluster): CoreDNS custom config or `hostAliases` per consuming Deployment

**Interfaces:**
- Produces: groups `admin` and `family`; the admin user with a passkey; API key stored in SOPS secret `secrets/pocket-id-api.enc.yaml` (key `api-key`); issuer URL fixed for good.

- [ ] **Step 1: Manual bootstrap, documented step by step in the README:** open `$APP_URL/setup`, create the admin, register a passkey, create groups `admin` and `family`, create an API key (expiry 1 year), save it with `install.sh --store-api-key`.
- [ ] **Step 2: Reachability test.** Run `kubectl run curl --rm -it --image=curlimages/curl -- curl -s "$APP_URL/.well-known/openid-configuration"` from a pod. Expected: JSON. If it fails, add the in-cluster alias (CoreDNS `hosts` entry mapping the node name to the node's Tailscale IP) and repeat until it passes.
- [ ] **Step 3: Commit** `feat: Pocket ID bootstrap and in-cluster reachability`.

### Task 3: SSO for Immich

**Files:** Modify `apps/immich/values.yaml` or document the in-app OAuth settings (Immich stores OAuth in its DB config).

- [ ] **Step 1:** In Pocket ID create OIDC client `immich` with callback URLs from Immich's docs (web `/auth/login`, `/user-settings`, and the mobile `app.immich:///oauth-callback`); store client id/secret in SOPS `secrets/sso-immich.enc.yaml`.
- [ ] **Step 2:** Configure Immich (Administration > Authentication): issuer `$APP_URL`, auto-register on, button text "Sign in with HomeLab". Document the exact fields in the README.
- [ ] **Step 3: Verify.** Log in with a `family` test user through the browser and through the iPhone app. Expected: account created, photos untouched. Existing admin still logs in with email and password.
- [ ] **Step 4: Commit.**

### Task 4: SSO for Grafana

**Files:** Modify `platform/monitoring/values.yaml` (`grafana.grafana.ini.auth.generic_oauth`), create `secrets/sso-grafana.enc.yaml` and apply it as a Secret referenced through `envFromSecret`.

- [ ] **Step 1:** Add `generic_oauth` (enabled, name HomeLab, client id/secret from env, scopes `openid profile email groups`, role mapping: group `admin` → `Admin`, else `Viewer`).
- [ ] **Step 2: Verify.** Argo sync Healthy; login as an `admin` group user shows Admin role; a `family` user is Viewer. Local `admin` login still works.
- [ ] **Step 3: Commit.**

### Task 5: SSO for Nextcloud

**Files:** Modify `apps/nextcloud/install.sh` (enable app `user_oidc`, configure provider via `occ user_oidc:provider`), `apps/nextcloud/README.md`.

- [ ] **Step 1:** Add the OIDC client in Pocket ID; store `secrets/sso-nextcloud.enc.yaml`.
- [ ] **Step 2:** Script: `occ app:install user_oidc` and `occ user_oidc:provider homelab --clientid=... --clientsecret=... --discoveryuri="$APP_URL/.well-known/openid-configuration"` with unique-uid mapping on email. Dry run prints the commands.
- [ ] **Step 3: Verify.** Log in with a `family` user; file area is created; admin's existing files unaffected (compare file count before and after).
- [ ] **Step 4: Commit.**

### Task 6: SSO for Jellyfin (best effort)

**Files:** Modify `apps/jellyfin/README.md`; plugin install is manual in the Jellyfin UI.

- [ ] **Step 1:** Read the community SSO-Auth plugin's current compatibility against Jellyfin 12.3. If incompatible, record "not supported yet" in the README and the dashboard card and stop this task.
- [ ] **Step 2:** If compatible: document plugin install, provider settings, and test a `family` login. Local admin stays.
- [ ] **Step 3: Commit.**

### Task 7: Dashboard core (catalog, status, session)

**Files:**
- Create: `apps/dashboard/src/{config,catalog,status,auth,app}.py`, `apps/dashboard/src/apps.yaml`, `apps/dashboard/tests/test_catalog.py`, `test_status.py`, `test_auth.py`

**Interfaces:**
- Produces:
  - `config.Settings` (dataclass): `issuer: str`, `client_id: str`, `client_secret: str`, `secret_key: str`, `pocketid_url: str`, `pocketid_api_key: str`, `apps_file: str`.
  - `catalog.load_apps(path: str) -> list[AppEntry]`; `AppEntry`: `id, name, category, icon, description, details, first_steps: list[str], health_url, open_port, scheme, groups: list[str], login_note, doc`.
  - `catalog.visible_to(apps: list[AppEntry], user_groups: set[str]) -> list[AppEntry]`.
  - `status.check_all(apps, timeout=3.0, slow_after=1.5) -> dict[str, Status]`; `Status`: `state` in `{"up","slow","down"}`, `latency_ms`, `down_since: datetime | None`.
  - `auth.require_group(*groups)` decorator returning 403 for other users; `auth.current_user() -> User(sub, name, email, groups)`.
- `apps.yaml` carries descriptions and in-cluster `health_url`s only; the browser link is built at request time from the request's own host plus `open_port`, so no domain is stored.

- [ ] **Step 1: Write failing tests.** `test_catalog.py::test_family_does_not_see_admin_only_apps`; `test_status.py::test_slow_when_latency_over_threshold` (fake server sleeps 2 s → `slow`), `::test_down_on_connection_refused`, `::test_checks_run_in_parallel` (5 hanging targets finish in under 4 s); `test_auth.py::test_non_admin_gets_403`, `::test_issuer_mismatch_refuses_startup`.
- [ ] **Step 2: Run** `pytest apps/dashboard/tests -v`. Expected: FAIL.
- [ ] **Step 3: Implement** the modules to the signatures above. Use Authlib's Flask client for OIDC (authorization code + PKCE), `groups` claim for roles; remember `down_since` in memory per app.
- [ ] **Step 4: Run tests.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dashboard): catalog, status, auth`.

### Task 8: Dashboard UI (layout A)

**Files:** Create `apps/dashboard/src/templates/{base,apps,help,docs}.html`, `apps/dashboard/src/static/app.css`, `app.js`, `apps/dashboard/tests/test_views.py`.

**Interfaces:** Consumes Task 7. Produces routes `GET /` (apps), `GET /help`, `GET /docs`, `GET /api/status` (JSON for live dot refresh every 30 s).

- [ ] **Step 1: Failing tests.** `test_views.py::test_apps_page_groups_by_category`, `::test_card_shows_description_version_and_status_dot`, `::test_status_api_requires_login`.
- [ ] **Step 2: Implement.** Sidebar (Apps, Monitoring, Help, Docs, Users for admins), category sections, cards with icon, dot, version, long description, expandable "first steps" panel; CSS custom properties with dark and light themes; breakpoint so the sidebar collapses at phone width. Follow the approved mockup A.
- [ ] **Step 3: Content.** Fill `apps.yaml` for Immich, Jellyfin, Nextcloud, Vaultwarden, qBittorrent, Grafana, Prometheus, Argo CD, Pocket ID with real descriptions and 3 to 5 first-step suggestions each (for example Immich: enable the iOS background upload, set a storage template; Jellyfin: add `/media` library; Nextcloud: install the desktop sync client; Vaultwarden: add the browser extension; qBittorrent: set a permanent WebUI password).
- [ ] **Step 4: Run tests; open the page at 390 px and 1280 px widths in the browser.** Expected: PASS and no horizontal scroll.
- [ ] **Step 5: Commit.**

### Task 9: Users, profile and credentials

**Files:** Create `apps/dashboard/src/{pocketid,creds}.py`, templates `users.html`, `profile.html`, `credentials.html`, tests `test_pocketid.py`, `test_users.py`, `test_creds.py`.

**Interfaces:**
- `pocketid.Client(base_url, api_key)` with `list_users() -> list[PUser]`, `create_user(name, email, group) -> PUser`, `delete_user(user_id) -> None`, `one_time_link(user_id) -> str`, `set_photo(user_id, data: bytes, content_type: str) -> None`. Endpoint paths are verified against Pocket ID's API reference during implementation.
- `creds.read_allowed(namespace_secret_keys: dict) -> dict[str, dict[str, str] | None]` reading only the keys named in `apps.yaml` `credentials:` blocks.
- Routes: `GET/POST /users`, `POST /users/<id>/delete`, `POST /users/<id>/link` (admin); `GET/POST /profile` (any user); `GET /credentials` (admin).

- [ ] **Step 1: Failing tests** (Pocket ID faked with `responses`): `test_non_admin_cannot_post_users`; `test_cannot_delete_self_or_last_admin`; `test_photo_over_2mb_rejected`; `test_photo_wrong_type_rejected`; `test_missing_secret_shows_not_found_for_that_app_only`; `test_credentials_never_in_logs`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Users page lists users, add form (name, email, group), delete with confirm, "make login link" button that shows the one-time URL once. Profile: display name, photo upload (PNG/JPEG/WebP, max 2 MB). Credentials: table of app, username, where to read the password, and the password for admins only.
- [ ] **Step 4: Run tests; expect PASS.**
- [ ] **Step 5: Commit.**

### Task 10: Help and diagnose

**Files:** Create `apps/dashboard/src/help.py`, `templates/help.html` additions, `tests/test_help.py`.

**Interfaces:** `help.diagnose(app_id) -> Diagnosis(reachable: bool, latency_ms, last_logs: list[str], hint: str)`; `help.platform_health() -> dict` with `backup_age_hours`, `disk_used_percent` from Prometheus (`homelab_backup_last_success_timestamp_seconds`, node filesystem metrics).

- [ ] **Step 1: Failing tests:** `test_logs_are_trimmed_to_50_lines_and_redacted` (lines containing `password=`, `token=` or `Bearer` are replaced with `[redacted]`); `test_hint_for_down_app_mentions_argo_sync`; `test_prometheus_unreachable_returns_none_values`.
- [ ] **Step 2–4: Implement, run, pass.** Help page: one row per app with a "Diagnose" button, platform strip (backup age, disk), and fixed advice text per failure (pod not ready → `kubectl -n <ns> get pods`; backup older than 26 h → check the drive is mounted).
- [ ] **Step 5: Commit.**

### Task 11: Package and deploy the dashboard

**Files:** Create `apps/dashboard/Dockerfile`, `dashboard.yaml`, `install.sh`, `README.md`, `argocd/apps/dashboard.yaml`.

- [ ] **Step 1: Dockerfile.** `python:3.12-slim`, non-root user, `gunicorn`, copies `src/`. Pinned requirements file.
- [ ] **Step 2: `dashboard.yaml`.** Deployment (image `homelab/dashboard:<git-sha>`, `imagePullPolicy: Never`), ServiceAccount with a Role limited to `get` on named Secrets and `list`/`get` `pods/log` in the app namespaces listed; NodePort 30500; env from secrets `dashboard-oidc`, `pocket-id-api`.
- [ ] **Step 3: `install.sh`.** Dry run default. With `APPLY=1`: `docker build`, `docker save | sudo k3s ctr images import -`, create OIDC client for the dashboard in Pocket ID via the API, store `secrets/sso-dashboard.enc.yaml`, apply, and `tailscale serve --https=8500`.
- [ ] **Step 4: Verify.** Login with the admin passkey; `/users` works; a `family` test user gets 403 on `/users`; stopping the Jellyfin deployment turns its dot red within 30 s, restoring it turns it green.
- [ ] **Step 5: Commit.**

### Task 12: Cut over from Homepage

**Files:** Modify `argocd/apps/homepage.yaml` (delete after verification), `apps/homepage/README.md`, `README.md`.

- [ ] **Step 1:** Run both for a day; confirm every card link opens the right app from a phone on the tailnet.
- [ ] **Step 2:** Remove Homepage (`kubectl delete application homepage -n argocd`, delete `argocd/apps/homepage.yaml`, keep `apps/homepage/` in git history only), turn off its `tailscale serve` port 80 forward.
- [ ] **Step 3: Commit.** Rollback is `git revert` plus `APPLY=1 ./apps/homepage/install.sh`.

### Task 13: Back up and restore-test Pocket ID

**Files:** Modify `platform/backup/backup.sh`, `platform/backup/install.sh` (add `PID_GLOB`), `docs/backup-restore.md`.

- [ ] **Step 1:** Add block: quiesce by `sqlite3 .backup` through `kubectl exec` (or copy while scaled to 0), restic tag `pocket-id`, retention 7/4/12.
- [ ] **Step 2: Verify.** Run the backup by hand, restore into a scratch dir, run `PRAGMA integrity_check` and count users. Expected: `ok` and the right count.
- [ ] **Step 3: Commit.**

### Task 14: Documentation for beginners

**Files:** Create `docs/apps/{immich,jellyfin,nextcloud,vaultwarden,qbittorrent,pocket-id,dashboard,monitoring,argocd,backup}.md`; rewrite per-folder READMEs for `apps/*/`, `platform/*/`, `argocd/`, `bootstrap/`, `secrets/`; update `docs/README.md` and `docs/architecture.md`.

**Interfaces:** Each guide has these sections in order: What it is, Why we use it, Architecture (Mermaid), Workflow (Mermaid sequence), Prerequisites, Step-by-step deployment (with expected output after each step), Verify, Roll back, Troubleshooting, File-by-file explanation (each file: what it does, how the key lines work).

- [ ] **Step 1: Template.** Write `docs/apps/_template.md` with the section list above and a "words explained" box (Pod, Deployment, PVC, NodePort, SOPS, Argo CD sync) reused by every guide.
- [ ] **Step 2: Write each guide** from the real manifests and scripts; run every deployment step on a dry run to check the commands are right. Use only this project's examples.
- [ ] **Step 3: Rewrite folder READMEs** so each file has a "How it works" paragraph.
- [ ] **Step 4: Check.** Every `docs/apps/*.md` has all ten sections (`grep -c '^## '` equals 10); every link resolves (`grep -o '](.*)'` manual spot-check or a link checker); gitleaks passes; no domain, tailnet or device name appears (`grep -ri 'ts.net'` returns nothing).
- [ ] **Step 5: Commit** `docs: beginner guides for every app`.

### Task 15: Final verification

- [ ] **Step 1:** Fresh-eyes walk: from a phone on the tailnet log in with a passkey, open each app card, check dots, add a user, issue a login link, log in as that user on Immich.
- [ ] **Step 2:** Run all pytest suites, `shellcheck` on new scripts, `gitleaks detect`.
- [ ] **Step 3:** Update `README.md` status, `docs/roadmap.md`, and commit.

---

## Self-review

- **Spec coverage:** SSO (Tasks 1–6), layout A and cards (7–8), Users and profile photo (9), credentials panel (9), help (10), docs access (8, 14), docs deliverables (14), backup (13), cutover (12), constraints (Global Constraints). Gap noted: Vaultwarden SSO is intentionally not built (spec non-goal).
- **Risk:** Task 6 (Jellyfin SSO) may end as "not supported"; Pocket ID API endpoint paths are verified in Task 9 before coding against them.
