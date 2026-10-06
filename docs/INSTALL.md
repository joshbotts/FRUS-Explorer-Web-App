# Installing FRUS Explorer Light

FRUS Explorer Light runs as one container on a Mac or a Linux host, serving a research database exported from FRUS Explorer on a Mac. This guide covers phase 1: one person on one machine. The server listens on this machine's 127.0.0.1 only, and has no sign-in.

**What phase 1 offers so far:** the server imports an export, checks it and serves it: it searches the index with the app's query language, lists the published catalogue and each volume's documents, and renders a document's page from the TEI volumes. The browser interface arrives in session 9. Until then `curl` reaches it all through the API (step 6).

## What you need

- **Docker with Compose.** On a Mac, Docker Desktop, Podman Desktop or Colima; Docker Desktop needs a paid subscription in larger organisations. On Linux, Docker Engine with the Compose plugin. This guide uses `docker compose`; it was tested with Docker Desktop 4.93.
- **About 15 GB free for Docker:**
  - the image is about 400 MB, with the app's data files;
  - the index for the full corpus is 2.8 GB;
  - an import needs room for the export and a copy while it is checked;
  - a later import keeps the previous index for rollback, so a re-import needs about four times the index while it runs.
- **Memory.** Importing and serving the full corpus used about 130 MB, and the reader levelled off at about 170 MB over the largest volumes, so Docker Desktop's default allocation is plenty.
- **A FRUS Explorer research export** from a Mac running a build that matches the server's index version: 65 today, FRUS Explorer build 49. The server refuses any other version and says which it needs.
- **The TEI volumes**, which the reader renders documents from. Without them the server still imports and serves the index.

## 1. Get the Compose file

```bash
mkdir ~/frus-light
```

```bash
cd ~/frus-light && curl -fsSLO https://raw.githubusercontent.com/joshbotts/FRUS-Explorer-Web-App/main/compose.yaml
```

The data lives in a Docker volume named after this folder (`frus-light_frus-data`), so keep using the same folder.

## 2. Point it at the TEI volumes

The server mounts a folder of TEI volumes read-only. Settings go in a file named `.env` beside `compose.yaml`.

**On a Mac with FRUS Explorer,** use the app's own folder, which holds the TEI files and the figure images:

1. Let Docker Desktop read FRUS Explorer's data, which macOS keeps from other apps. In **System Settings ▸ Privacy & Security ▸ Files & Folders** (macOS 27), find **Docker** and turn on **FRUS Explorer** beneath it. Docker is listed there only after it has tried to read the folder. If it is missing, carry on to step 3. If macOS asks, allow it. If `docker compose up -d` fails with "operation not permitted" on the `Volumes` path, turn the setting on here and run the command again.
2. Write the path into `.env`:

```bash
echo "FRUS_TEI_DIR=$HOME/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/Volumes" > .env
```

**On Linux, or a Mac without FRUS Explorer,** clone the TEI volumes from the Office of the Historian's repository. A shallow clone fetches the current files only, about 3 GB; the full history is 14 GB. It has the same TEI XML as FRUS Explorer downloads, but not the figure images.

```bash
git clone --depth 1 https://github.com/HistoryAtState/frus.git
```

```bash
echo "FRUS_TEI_DIR=$PWD/frus/volumes" > .env
```

Without `FRUS_TEI_DIR`, Compose mounts an empty `tei` folder beside `compose.yaml`, and the reader has no volumes to render.

## 3. Start the server

```bash
docker compose up -d
```

```bash
curl -s -w '  %{http_code}\n' http://localhost:8080/readyz
```

It answers `"step":"waiting_for_export"` with status `503`: the server is running and has no index yet. `curl http://localhost:8080/healthz` answers `{"status":"ok"}` whenever the server is up.

## 4. Export the research database on the Mac

In FRUS Explorer, open **Settings ▸ Data & Recovery ▸ Export Research Database…**. Leave **Include My Notes, Summaries, and Tags** off: in phase 1 the server holds the corpus only, and it refuses an export that includes your writing. The full corpus exports to about 2.8 GB.

## 5. Import it

Copy the file into the server's drop zone, with your export's path in place of the example:

```bash
docker compose cp ~/Documents/frus-index.sqlite frus:/data/import/
```

The server waits until the copy has finished, then checks the export and installs it. Follow it with:

```bash
curl -s -w '  %{http_code}\n' http://localhost:8080/readyz
```

`/readyz` names each step as it goes, then answers `200` when the index is open, saying how many documents and volumes it serves. On an Apple silicon Mac, the full corpus was ready about 40 seconds after the copy began.

| Step | What the server is doing |
| --- | --- |
| `waiting_for_export` | Waiting for a file in the drop zone, or for one still being copied |
| `copying_export` | Copying the export beside the live index |
| `checking_format` | Checking that it is a FRUS Explorer research export |
| `checking_versions` | Checking the index and FTS schema versions |
| `checking_writing` | Checking that it holds no notes, summaries or tags |
| `checking_integrity` | Checking the database and both full-text indexes |
| `installing_index` | Making the copy the live index, keeping the old one for rollback |
| `opening_index` | Opening the index read-only |
| `ready` | Serving the index |

`curl http://localhost:8080/api/v1/status` shows the versions, the index's document and volume counts, and the last import's outcome.

The installed export is removed from the drop zone, so you can delete your own copy or keep it. Restarting the server copies nothing: the index stays in the volume.

## 6. Search and read

Until the browser interface arrives, `curl` shows what it will. A search takes the search box's text in `keywords`, with the app's query language, and answers with the exact count and the first page of results, best first:

```bash
curl -s 'http://localhost:8080/api/v1/search?keywords=NEAR(khrushchev+berlin,+10)&limit=5'
```

`curl -G --data-urlencode 'keywords=…'` writes the text safely. Each result's `snippet` marks the matches with `<b>` and is otherwise plain text. `/api/v1/search/inspect` takes the same parameters and shows what the query compiles to.

The catalogue lists all 553 volumes, saying which the index holds and which have TEI in your folder, and each volume lists its documents in reading order:

```bash
curl -s 'http://localhost:8080/api/v1/volumes?subseries=1961-63&limit=3'
```

```bash
curl -s 'http://localhost:8080/api/v1/volumes/frus1961-63v06/documents?limit=5'
```

A document's page, as the reader renders it from the TEI folder, in `colorScheme` `light` or `dark` and `textSize` `small`, `medium`, `large` or `extraLarge`:

```bash
curl -s 'http://localhost:8080/api/v1/volumes/frus1961-63v06/documents/d1/html?colorScheme=dark' -o d1.html
```

The first document of a volume takes about half a second while the server parses the volume; the rest are immediate. The reader works without an index. Figure images come from FRUS Explorer's own folder of volumes, which holds them; with a clone of HistoryAtState/frus, figures show a placeholder.

An error names its cause in a `code`: `INDEX_NOT_READY` for a search before an import has finished, `EMPTY_QUERY` for a query with nothing left to search, `TEI_NOT_AVAILABLE` when the volume is not in your TEI folder, and `DOCUMENT_NOT_FOUND` or `VOLUME_NOT_FOUND` for an id the volume or the catalogue lacks.

## If an import is refused

A refused file stays in the drop zone. `/api/v1/status` says why, under `lastImport`; `/readyz` says so too while no index is being served. A refusal about the file itself is not retried until the file changes. A problem on the server's side, such as too little disk space, is retried every minute. `docker compose logs frus` shows the whole story, and `docker compose exec frus rm /data/import/<file>` clears a file from the drop zone.

| The server says | What to do |
| --- | --- |
| "This export is index version N; this server serves index version M" | Update FRUS Explorer or the server so they match, then export again |
| "Let FRUS Explorer finish re-indexing, then export again" | Leave FRUS Explorer open until indexing ends |
| "This export includes your notes, summaries and tags" | Export again with Include My Notes, Summaries, and Tags turned off |
| "The server cannot read …" | The file kept permissions only you can read. Copy it again with `docker compose cp -a`, which gives it to the server's user; it is tried again within a minute |
| "needs about N GB free beside the index" | Free space for Docker; the import is tried again by itself |
| "… is not a SQLite database" or "… is damaged" | Export again with Export Research Database… |
| "… arrived with a -wal file", or "a -journal file that may hold an unfinished transaction" | This is a copy of a database in use. First remove that file, with `docker compose exec frus rm /data/import/<file>-wal` (or `-journal`). Then export with Export Research Database… and copy the new export in. Keep that order: a new export copied while the side file is there is refused too, and removing the side file afterwards does not try it again |
| "… is a symbolic link, not an export" | `docker compose cp` copied the link, not the file. Run the same copy again with `docker compose cp -L`, which follows the link: the export replaces the link of the same name and is imported |

## Upgrading

```bash
docker compose pull && docker compose up -d
```

`edge` is the newest build of the project's main branch that passed its smoke test on both architectures. The index stays in the volume. If the new server serves a different index version, `/readyz` answers `index_version_mismatch`, naming both versions: export again from a matching FRUS Explorer build and copy it in. To stay on one build, set `FRUS_IMAGE=ghcr.io/joshbotts/frus-explorer-light:sha-<commit>` in `.env`, where `<commit>` is the first 7 characters of a commit on the main branch.

## Stopping and removing

| Command | Effect |
| --- | --- |
| `docker compose stop` | Stops the server, keeping everything |
| `docker compose down` | Removes the container, keeping the index in the volume |
| `docker compose down --volumes` | Removes the index too; you would import again |

## Settings

These go in `.env` beside `compose.yaml`.

| Setting | Default | Meaning |
| --- | --- | --- |
| `FRUS_TEI_DIR` | `./tei` | Folder of TEI volumes, mounted read-only |
| `FRUS_HOST_PORT` | `8080` | Port on this machine's 127.0.0.1 |
| `FRUS_IMAGE` | `ghcr.io/joshbotts/frus-explorer-light:edge` | The image to run |
| `COMPOSE_PROFILES` | none | `pdf` starts Gotenberg, a 700 MB download, for PDF export when it arrives in phase 3 |

## Notes

- **Only this machine can reach the server.** Sharing it wider waits for phase 3's local accounts, behind a TLS reverse proxy.
- **Keep `/data` in the Docker volume.** On a Mac, a folder shared from macOS is not a local filesystem to SQLite. On Linux, replacing the volume with a host folder in `compose.yaml` works if that folder is writable by UID 10001, the server's user.
- **On Linux,** the TEI files must be readable by UID 10001; a clone made with the usual umask is. On a host with SELinux enforcing, add `,z` after `ro` in the TEI volume line of `compose.yaml`. To run `docker` without `sudo`, your user must be in the `docker` group.
- **Backups** start in phase 2, when the server holds your own notes. Until then the index can always be imported again.
- **Podman and Colima** run the same Compose file; this guide has not been tested with them yet.
