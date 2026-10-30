# Glossary

Short meanings of the words used in this project.

| Word | Meaning |
|---|---|
| **Kubernetes** | A system that starts your apps, restarts them if they crash, and keeps them running. |
| **k3s** | A small version of Kubernetes that runs well on one computer. |
| **Node** | A computer in the cluster. This project has one. |
| **Cluster** | The group of nodes that Kubernetes manages. |
| **Namespace** | A named folder inside the cluster. Each app has its own, for example `immich`. |
| **Pod** | One running copy of an app (one or more containers). |
| **Deployment / StatefulSet** | A rule that says "keep this pod running". A StatefulSet is used for databases. |
| **PVC (volume)** | Disk space that an app asks for. It keeps its data when the pod restarts. |
| **Secret** | A Kubernetes object that holds a password or key. |
| **Manifest** | A YAML file that describes something to create in the cluster. |
| **Helm / chart** | A package manager for Kubernetes. A chart is one package, for example the Immich chart. |
| **NodePort** | A port on the server that leads to an app. Here it only listens on the server itself (`127.0.0.1`). |
| **Argo CD** | A tool that watches this repo and makes the cluster match it. |
| **GitOps** | Working style: the git repo is the truth, and a tool applies it to the server. |
| **Tailscale** | A private network between your devices. |
| **Tailnet** | Your own Tailscale network. |
| **`tailscale serve`** | Tailscale feature that makes a port on the server reachable inside the tailnet. |
| **SOPS** | A tool that encrypts the values inside a file, so the file can be stored in git. |
| **age** | A small encryption tool. SOPS uses an age key pair: a public key locks, a private key unlocks. |
| **restic** | A backup tool. It encrypts, and it saves only what changed. |
| **Snapshot** | One saved copy of your data at one moment, inside the restic repository. |
| **Dry run** | A run that only shows what would happen. All scripts here are dry runs unless you set `APPLY=1`. |
| **Renovate** | A bot that opens a pull request when a new version of an app or chart is out. |
