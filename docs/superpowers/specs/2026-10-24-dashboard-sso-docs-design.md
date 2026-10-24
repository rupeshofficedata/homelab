# Dashboard, single sign-on and beginner documentation: design

Date: 2026-10-24. Status: draft for approval. Repo: this homelab (k3s + Argo CD, Tailscale-only, public GitHub repo, secrets in SOPS + age).

## Intent

Rupesh runs Immich, Jellyfin, Nextcloud, Vaultwarden, qBittorrent, Grafana, Prometheus and Argo CD at home. Today the front page (Homepage) is a plain list of links with no login, no status, and no help. Other people (family) will use some apps. The goal is one friendly front door: a dashboard that needs a login, shows what is up, explains each app, and lets the admin add and remove users without copying one password into every app. A beginner DevOps reader must also be able to understand and rebuild every part from the docs.

## Goals

1. **Dashboard with login.** Users sign in once. The admin sees everything; normal users see only what the admin allows (decision in "Left to the builder": group-to-app visibility).
2. **Layout A (chosen from mockups):** left sidebar (Apps, Monitoring, Help and diagnose, Docs, Users), apps grouped by category, one card per app.
3. **Card content:** icon, colored status dot (green up, amber slow or degraded, red down, with "down since"), version, a longer description (what it is for, what it stores, who should use it), the open link, and a "first steps / suggestions" panel specific to that app.
4. **Single sign-on (SSO).** One identity service holds accounts. Apps that support OIDC log in through it. Apps that cannot are listed honestly with their own login.
5. **Users page (admin only):** add and remove users, assign group (admin / family). **Profile page (every user):** change display name, upload a profile photo.
6. **Help section:** per-app checks (is it reachable, last log lines, last backup age, disk use) with plain "what to do next" text.
7. **Admin-only credentials panel:** shows the initial username and where to read each app's password, after login only. Secrets are read at runtime from the cluster; nothing is added to git.
8. **Docs:** link to documentation from the dashboard. Each app and platform part has a README (what each file does, how it works) and a guide page with architecture diagram, workflow, prerequisites, and step-by-step deployment, in simple language for a beginner DevOps reader, using only this project's examples.

## Non-goals

- No copying one password into every app (rejected: leaks widen, Vaultwarden cannot be set that way).
- No change to Vaultwarden's or qBittorrent's own login. Vaultwarden master password is encrypted in the browser; qBittorrent has a single WebUI account.
- No public internet exposure. Tailscale only, as today.
- No CI pipeline (earlier decision). No monitoring rebuild (Prometheus + Grafana stay).
- No VPN sidecar in this work (separate, undecided).

## Anti-goals (failure even if it works)

- Any plaintext secret, domain, public IP, tailnet or device name in the public repo.
- A dashboard that holds more power than needed: it must not be able to read photos, files or vault contents.
- Showing default credentials to non-admins.
- Docs that use unrelated examples or assume DevOps experience.

## Constraints

- One PC now (15 GB RAM, about 7 GB free), later a PC with 256 GB SSD plus 2 TB SATA. New services must be small.
- Everything declarative: manifests in `apps/<name>/`, an Argo CD Application in `argocd/apps/`, `prune: false` for anything with data, secrets via SOPS and an `install.sh`.
- Apps are reached through `tailscale serve`. HTTPS only where an app needs it (Vaultwarden, Nextcloud). OIDC redirects require stable, HTTPS-capable URLs for the identity service; this is a constraint on how it is published.
- Existing Homepage (`apps/homepage/`) is replaced by the new dashboard once the new one works; rollback must stay easy.

## Decided with the user

- SSO instead of password copying.
- Layout A with longer descriptions on cards.
- Admin has a Users page (add, remove) and every user has a settings page with a photo option.
- Admin-only default credentials and a help/diagnose section, plus access to documentation.

## My calls (marked as mine, not agreed)

- **Identity service: Pocket ID.** Small, passkey login (works with iPhone Face ID), OIDC provider, admin API, profile pictures. Alternatives (Authelia, Authentik) are heavier or need LDAP. Revisit if passkey-only login blocks a family member.
- **Dashboard: small custom web app**, because Homepage has no login and cannot add users. Default stack: Python (Flask) serving server-rendered HTML with a little vanilla JS. Stateless; users and photos live in Pocket ID.
- **Dashboard calls Pocket ID's admin API** with a scoped API key stored as a SOPS secret.
- **Image build without CI:** the dashboard's `install.sh` builds the image locally and imports it into k3s (`docker build`, `k3s ctr images import`), so a new PC rebuilds it from the repo.
- **Status checks run server-side** (HTTP request to each app's in-cluster Service), shown as up, slow (over 1.5 s) or down.
- **SSO wiring order:** Immich, Grafana, Nextcloud (user_oidc app), then Jellyfin (community SSO plugin). Vaultwarden SSO and others only if stable.
- **Credentials panel** reads `kubectl`-equivalent Secrets through a read-only ServiceAccount limited to named secrets.

## Left to the builder

- Exact framework and file layout of the dashboard app, within the defaults above.
- OIDC claim and group mapping details per app.
- Visual polish: icons, colors, dark/light, mobile layout (must work at phone width).
- Per-app suggestion text and help-check commands.
- Order of work and test method.

## Documentation deliverables (audit result)

Existing: `docs/` (architecture, decisions, getting-started, secrets, backup-restore, migrate-to-new-pc, roadmap) and one short README per app and platform folder. Gaps found: no per-app guide with workflow diagram and prerequisites for Vaultwarden, Jellyfin, Nextcloud, qBittorrent, Homepage; app READMEs explain files but not how the code works step by step; the new identity service and dashboard need the same. Plan: a `docs/apps/<name>.md` guide per app (diagram, prerequisites, deploy steps, verify, rollback, troubleshooting) and a README rewrite per folder that explains each file's code in simple language.

## Risks

- The dashboard (with a Pocket ID admin key and read access to some secrets) becomes a high-value target. Mitigation: tailnet only, least-privilege ServiceAccount, admin-only routes, no secrets in logs.
- Identity service down means nobody can log in to SSO apps. Mitigation: every app keeps a local admin account as break-glass.
- Jellyfin SSO is a third-party plugin and may lag Jellyfin releases.
- OIDC needs HTTPS URLs; mixing HTTP tailnet links may need Tailscale HTTPS for the identity service.

## Builder-check outcomes (my calls, added after review)

- **URLs:** Pocket ID and the dashboard each get their own Tailscale HTTPS port on the same node name (like Vaultwarden 8222 and Nextcloud 8443). The issuer URL is fixed before any app is wired, because passkeys bind to it. Pods reach it through an in-cluster alias (CoreDNS entry or `hostAliases` to the node's Tailscale IP); the build must test this first.
- **Cutover:** the new dashboard runs beside Homepage on a new port. Homepage is removed only after the new one is verified.
- **Visibility:** per group, not per user. Two groups to start: `admin` and `family`. The app-to-group map lives in a ConfigMap that holds group and app names only (no user names).
- **Pocket ID API keys are all-admin, not scoped.** The dashboard therefore holds a full-admin key. Accepted because the dashboard is tailnet-only, admin routes are checked server-side, and the key is a SOPS secret that can be rotated. A narrower design (users page links to Pocket ID's own admin screen) is the fallback if this is not acceptable.
- **Onboarding without email:** the admin issues a one-time login link (Pocket ID supports it) and the user registers a passkey.
- **Accounts:** auto-register on first SSO login for the `family` group; existing admin accounts in Immich, Nextcloud and Jellyfin are linked by email. Every app keeps a local admin as break-glass.
- **OIDC clients:** created by the install script through the Pocket ID API when possible, otherwise listed as manual steps in the guide.
- **Help checks:** disk and backup age come from Prometheus queries (already running). Pod logs need extra read access and are limited to a named list of app namespaces, with output trimmed.
- **Docs:** Mermaid diagrams in Markdown. The dashboard links to the public GitHub repo pages. Pocket ID's SQLite volume is added to the restic backup and the restore doc.
- **Image build:** Docker is present on this PC. New PC needs Docker or Podman, listed as a prerequisite.
