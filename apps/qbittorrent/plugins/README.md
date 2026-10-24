# plugins/

qBittorrent search-engine plugins, kept here so a rebuilt machine gets them back with `../install-plugins.sh`.
Each was read before being added: they only call the search site's API through qBittorrent's own `retrieve_url` helper (no subprocess, sockets or file writes).

| File | Source | Site | Notes |
|---|---|---|---|
| `eztvx.py` | [DrPurp/eztvx-qbittorrent-plugin](https://github.com/DrPurp/eztvx-qbittorrent-plugin) | TV shows | Official EZTV JSON API. OMDb poster lookup is optional and needs your own key. |
| `animetosho.py` | [Phlexis96/qBitTorrent-animetosho-search-plugin](https://github.com/Phlexis96/qBitTorrent-animetosho-search-plugin) | Anime | JSON feed. |
| `yts.py` | [lazulyra/qbit-plugins](https://codeberg.org/lazulyra/qbit-plugins) | Movies | YTS API. |

`SHA256SUMS` pins the exact files; the install script refuses anything that does not match.
Source list: <https://github.com/qbittorrent/search-plugins/wiki/Unofficial-search-plugins>. Not added: Prowlarr plugin (needs a Prowlarr service), Nyaa (last updated 2019).
