# plugins/

Search plugins for qBittorrent. They are kept here so a rebuilt server gets them back with `../install-plugins.sh`.

Each plugin was read before it was added. They only call the search site's API through qBittorrent's own `retrieve_url` helper. They do not start programs, open sockets or write files.

| File | Source | Site | Notes |
|---|---|---|---|
| `eztvx.py` | [DrPurp/eztvx-qbittorrent-plugin](https://github.com/DrPurp/eztvx-qbittorrent-plugin) | TV shows | Official EZTV JSON API. The poster lookup (OMDb) is optional and needs your own key. |
| `animetosho.py` | [Phlexis96/qBitTorrent-animetosho-search-plugin](https://github.com/Phlexis96/qBitTorrent-animetosho-search-plugin) | Anime | JSON feed |
| `yts.py` | [lazulyra/qbit-plugins](https://codeberg.org/lazulyra/qbit-plugins) | Movies | YTS API |
| `torrentclaw.py` | [LightDestory/qBittorrent-Search-Plugins](https://github.com/LightDestory/qBittorrent-Search-Plugins) | Aggregator (about 10 sources) | Talks only to torrentclaw.com. An API key is optional (`TORRENTCLAW_API_KEY`, not set). |
| `snowfl.py` | [ChocoTonic/snowfl](https://github.com/ChocoTonic/snowfl) | Meta-search | Pinned by checksum. Local changes: magnet links only, and the fallback scrape is limited to snowfl.com. |

## Safety

`SHA256SUMS` lists the exact files and their checksums. It is the only list the install script uses. A file that is not listed, or does not match, is never installed.

`eztvx.py` has three small local changes, noted at the top of the file: OMDb over https, a URL-encoded title, and a strict `imdbID` check.

## Add or update a plugin

1. Read the plugin code.
2. Copy it into this folder.
3. Update `SHA256SUMS` with `sha256sum`.
4. Run `APPLY=1 ../install-plugins.sh`.

More plugins: <https://github.com/qbittorrent/search-plugins/wiki/Unofficial-search-plugins>. Not added: plugins for game repack sites, private trackers (they need accounts), and the Prowlarr plugin (it needs a Prowlarr service).
