# Installing FRUS Explorer Light

FRUS Explorer Light runs as one container on a Mac or a Linux host, serving a research database exported from FRUS Explorer on a Mac. This guide covers phase 1: one person on one machine. The server listens on this machine's 127.0.0.1 only, and has no sign-in.

**What phase 1 offers so far:** the server imports an export, checks it and serves it. There is no browser interface yet; it arrives in session 9. Until then the server answers `/healthz`, `/readyz` and `/api/v1/status`.

## What you need

- **Docker with Compose.** On a Mac, Docker Desktop, Podman Desktop or Colima; Docker Desktop needs a paid subscription in larger organisations. On Linux, Docker Engine with the Compose plugin. This guide uses `docker compose`; it was tested with Docker Desktop 4.93.
- **About 15 GB free for Docker:**
  - the image is 251 MB;
  - the index for the full corpus is 2.8 GB;
  - an import needs room for the export and a copy while it is checked;
  - a later import keeps the previous index for rollback, so a re-import needs about four times the index while it runs.
- **Memory.** Importing and serving the full corpus used about 130 MB, so Docker Desktop's default allocation is plenty.
- **A FRUS Explorer research export** from a Mac running a build that matches the server's index version: 65 today, FRUS Explorer build 49. The server refuses any other version and says which it needs.
- **The TEI volumes**, for the reader, from session 8. They are optional until then.

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

1. Allow Docker Desktop to read FRUS Explorer's data. macOS keeps other apps out of an app's folder: allow it when macOS asks whether Docker may access data from other apps, or turn it on later under **System Settings ▸ Privacy & Security**. Without it, `docker compose up -d` fails with "operation not permitted" on the `Volumes` path.
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

Without `FRUS_TEI_DIR`, Compose mounts an empty `tei` folder beside `compose.yaml`, which is fine until the reader arrives.

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

`/readyz` names each step as it goes, then answers `200` when the index is open. On an Apple silicon Mac, the full corpus was ready about 40 seconds after the copy began.

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
| "… arrived with a -wal file" | This is a copy of a database in use. Export with Export Research Database… instead |

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
