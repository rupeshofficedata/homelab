# plugins/

qBittorrent search-engine plugins, kept here so a rebuilt machine gets them back with `../install-plugins.sh`.
Each was read before being added: they only call the search site's API through qBittorrent's own `retrieve_url` helper (no subprocess, sockets or file writes).

| File | Source | Site | Notes |
|---|---|---|---|
| `eztvx.py` | [DrPurp/eztvx-qbittorrent-plugin](https://github.com/DrPurp/eztvx-qbittorrent-plugin) | TV shows | Official EZTV JSON API. OMDb poster lookup is optional and needs your own key. |
| `animetosho.py` | [Phlexis96/qBitTorrent-animetosho-search-plugin](https://github.com/Phlexis96/qBitTorrent-animetosho-search-plugin) | Anime | JSON feed. |
| `yts.py` | [lazulyra/qbit-plugins](https://codeberg.org/lazulyra/qbit-plugins) | Movies | YTS API. |
| `torrentclaw.py` | [LightDestory/qBittorrent-Search-Plugins](https://github.com/LightDestory/qBittorrent-Search-Plugins) | Aggregator (~10 sources) | Talks only to torrentclaw.com. Optional API key via `TORRENTCLAW_API_KEY` env var (not set). |
| `snowfl.py` | [ChocoTonic/snowfl](https://github.com/ChocoTonic/snowfl) | Meta-search | Fetched from the GitHub release `latest`; pinned here by hash. |

`SHA256SUMS` pins the exact files and is the only list the install script uses. `eztvx.py` carries three small local patches (OMDb over https, URL-encoded title, strict `imdbID` check), noted at its top.
Source list: <https://github.com/qbittorrent/search-plugins/wiki/Unofficial-search-plugins>. Active in 2026 but skipped: game-repack sites (FitGirl, GOG-games), private trackers (need accounts/keys), anime niche (acgrip, nekoBT, TsukiHime). Not added: Prowlarr plugin (needs a Prowlarr service), Nyaa (last updated 2019).
