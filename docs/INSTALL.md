# Installing FRUS Explorer Light

FRUS Explorer Light runs as one container on a Mac or a Linux host, serving a research database exported from FRUS Explorer on a Mac. This guide covers phase 1: one person on one machine. The server listens on this machine's 127.0.0.1 only, and has no sign-in.

**What phase 1 offers so far:** the server imports an export, checks it and serves it, with a browser interface at http://localhost:8080. You can browse the catalogue and a volume's contents, search the index with the app's query language, and read a document, rendered from the TEI volumes. In the reader, links lead to other documents, their notes and the documents on printed pages; people and terms open cards; and Cite copies the citation, or its BibTeX or RIS record.

## What you need

- **Docker with Compose.** On a Mac, Docker Desktop, Podman Desktop or Colima; Docker Desktop needs a paid subscription in larger organisations. On Linux, Docker Engine with the Compose plugin. This guide uses `docker compose`; it was tested with Docker Desktop 4.93.
- **About 15 GB free for Docker:**
  - the image is about 400 MB, with the app's data files;
  - the index for the full corpus is 2.8 GB;
  - an import needs room for the export and a copy while it is checked;
  - a later import keeps the previous index for rollback, so a re-import needs about four times the index while it runs;
  - an export made with your notes, summaries and tags needs about twice the index more while the server removes them from its copy, about 20 GB in all for the full corpus.
- **Memory.** Importing and serving the full corpus used about 130 MB, and the reader levelled off at about 170 MB over the largest volumes, so Docker Desktop's default allocation is plenty. A search ordered by date, or read in its timeline, holds up to 7,500 results, as the app's search window does, and the server keeps the last two such searches: by estimate, up to about 40 MB more. It also keeps the pages and counts of the last four searches, a few megabytes at most.
- **A FRUS Explorer research export** from a Mac running a build that matches the server's index version: 71 today, FRUS Explorer 1.0 (build 1776). The server refuses any other version and says which it needs.
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

In FRUS Explorer, open **Settings ▸ Data & Recovery ▸ Export Research Database…**. Leave **Include My Notes, Summaries, and Tags** off, and bring your research with the app's JSON export instead: see [Bring your research from the Mac](#bring-your-research-from-the-mac). With it on, the server keeps your writing in your research data before it serves the index, but the index holds only part of it: for each document one block of its notes, joined, and its newest summary, and your tags. The full corpus exports to about 2.8 GB.

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
| `checking_writing` | Checking that it holds no notes, summaries or tags, or, for an export made with them, reading them |
| `stripping_writing` | For an export made with your notes, summaries and tags: removing them from the copy with FRUS Explorer's own steps, each named as the app names it |
| `checking_integrity` | Checking the database and both full-text indexes |
| `moving_writing` | For an export made with your notes, summaries and tags: keeping them in your research data |
| `installing_index` | Making the copy the live index, keeping the old one for rollback |
| `opening_index` | Opening the index read-only |
| `ready` | Serving the index |

`curl http://localhost:8080/api/v1/status` shows the versions, the index's document and volume counts, and the last import's outcome: for an export made with your writing, what was kept in your research data. While an index is served, a new import runs behind it, and `/readyz` stays `200`, so follow a re-import there.

The installed export is removed from the drop zone, so you can delete your own copy or keep it. Restarting the server copies nothing: the index stays in the volume.

## 6. Browse, search, read, cite and tag

Open http://localhost:8080 in a browser.

- **Browse** lists the 553 volumes of the published catalogue. Type a title or volume number in the box above them to narrow the list, or choose a subseries, or show only the volumes this server indexes. A volume shows its sections: from the index when it holds them, otherwise read from the volume's TEI. A section lists its documents. The index names the documents it holds; the others are named by their number, or a preface or other prose section by its title, and the reader opens them from the TEI. Where a section prints text of its own outside its documents and sections, such as a meeting's list of those present or a footnote on its heading, the section lists it first, as **Read** and the section's title, as the app does; the reader opens it, and its **Previous** and **Next** lead to the text before and after it. The index holds these rows, so a volume this server has not indexed lists none.
- **Search** takes the app's query language: **Search syntax**, under the box, sums it up. The results come best first, with the exact count, and the filters narrow them by kind of document, date and front matter. **Sort** reads them by **Relevance** or by date, **Date ↑** oldest first or **Date ↓** most recent first, with undated documents last. A search keeps its 7,500 most relevant results, as the app does, so a larger match is read by date within those, and the results say so. Each result names its volume and, unless its title already begins with it, its document number, then its dateline, or for a result that prints none, such as a chapter of an older volume, the day or span of days the index dates it by, as the app's search does. A search you replace with another stops on the server at once, as the app's does, so the new one does not wait behind it. Over the whole corpus, a search for an exact word (`=word`) reads every document that holds a word with the same stem, and answers in under two seconds. The server keeps a search's page and count a while, so the concordance of the page reads the page it found, and another page of the search does not count it again.
- **The Query Inspector**, under the filters, shows what the query compiles to as you type it. The ▾ button beside it, named **Show term detail**, lists each term with its tags and how many indexed documents hold it, and **Count each term in scope…** counts each within the filters. A search that finds nothing names the term that matched nothing.
- **Facets**, beside the results, break the whole match down by year, volume, person, document type, archival provenance and subject, each counted when you open it. Choose years or volumes to include or exclude, then press **Apply**; a person, a type or a subject narrows the search at once. A year, a person or a subject shows as a token above the results, which clears it, and a type sets the Document type filter.
- **Reading**, beside **Sort**, shows the results as a **List**, a **Timeline** or a **Concordance**, as the app's search window does:
  - the **Timeline** counts by year the results the search keeps, as a **Chart**, whose counts are all in the **Table of the counts** beneath it, or as a **List** of each year's documents, in the order **Sort** gives them. Results with no date are left out, and counted. When a search reaches the 7,500 results it keeps, it says that its shape is theirs, not the whole match's;
  - the **Concordance** lines up every occurrence of the search's words in the page of results on screen, each between the words either side of it, and **Align by** orders the lines by what comes before the word, what follows it, the date or the volume. A line opens its document. On a narrow screen the lines scroll sideways. A phrase, a prefix or an exact word may match a document without giving it a line, and the concordance says how many did.
- **A result** opens the document in the reader, with **Previous** and **Next** for its neighbours in the volume, **Text Size**, **Reading Width** and **Open on history.state.gov**. **Reading Width**, as in the app's Settings, sets how long the lines may grow: **Narrow**, **Standard** or **Wide**, about 70, 90 or 130 characters a line at Medium text in Chrome, where the app, drawing in Safari's engine, gives about 77, 100 or 145; Standard to begin with; a narrow window, or Cite open beside the document, makes them shorter. **Appearance**, at the top, follows the system or stays light or dark. Each choice is kept in this browser.
- **Links in a document** work as they do in the app:
  - a cross-reference opens the document it names, or the note in it, and **Back** returns to the document you were reading. A note is brought into view and highlighted for a moment, as in the app;
  - a person's name opens a card with their entry from the volume's list of names and, once an export is imported, how many indexed documents mention them; a term opens its definition. **Done** or Escape closes the card;
  - a reference to a printed page, such as "p. 387", opens the document on that page, as the app does: the one the index places there or, in a volume this server has not indexed, the one FRUS Explorer's page map names. Where the map names none, such as the first page of a range across documents, the link opens the volume in **Browse**, which names the page;
  - a reference to a whole volume, such as "volume V", opens the volume in **Browse**. For a volume outside the catalogue, such as a microfiche supplement, the reader says so and offers its page on history.state.gov;
  - a reference that resolves nowhere opens an explanation;
  - a document in a volume this server does not have offers its page on history.state.gov.
- **Cite** opens the citation beside the document, in the History at State, Chicago or Turabian style. **Copy Citation** copies it as plain text, and **Copy URL** the document's address on history.state.gov. **Copy BibTeX** and **Copy RIS** copy its record for a reference manager such as Zotero, and **Save as .bib** saves the BibTeX as a file. The browser allows copying at http://localhost but not at another machine's address over plain http, so the panel then selects the text for you to copy.
- **Citation Lookup**, from **Find by Citation** beside **Search syntax**, finds the documents a citation names, as the app's Citation Lookup does. **Paste Citation** takes a citation as it is written, in any of the app's own styles, a footnote's or an informal one (*FRUS 1961–63, vol. V, doc. 84*), or a history.state.gov link, and fills the **Parsed Fields** from it; you can change a field before you look it up, and **Return** in the citation looks it up. **Structured Entry** takes the fields as you type them. **Batch** takes a chapter's footnotes, split on their numbers, and lists each with what it found and a count of each kind above them, worst first with **Needs work first**, or as pasted; a note whose one answer is a document opens it. Each result says how it was matched, in the app's words: an exact match, by page, one of several documents on a page, or a best guess and why. A volume this server does not index is offered as a volume to download, as the app offers it: **View Volume** opens its page in **Browse**, which says what this server holds of it. Before an import, every volume a citation names is one of those. The form stays as you left it while you open documents from it, and in this browser tab.
- **Highlights**, as in the app: select text in a document and a bar above it offers the four colours and **Note**; a colour makes a highlight, kept on the server, and **⇧⌘H** on a Mac, or **Ctrl+Shift+H** elsewhere, makes a yellow one, as the app's Highlight Selection ▸ Yellow does. **Alt+F10** moves into the bar, where the arrow keys choose a colour. Selecting text by keyboard needs the browser's caret browsing, **F7** in Chrome. Clicking a highlight asks **Remove Highlight**. A highlight made against an earlier version of the document's text is drawn in amber and answers no click, as in the app; the Research rail removes it.
- **Notes**, as in the app: **Note** in the bar, or **Add Note** in the Research rail, opens a new note on the document, and after you make a highlight the rail offers **Add Note to Highlight**, which links the note to it. The note's editor has the app's bold, italic, underline, text colour and link (**⌘B**, **⌘I**, **⌘U**, and **⌘K** for a link, or **Ctrl** elsewhere), and its **Formatting** switch, kept by this browser; its tags, its projects and the document's summaries, which **Insert into note** adds to it; and **Delete**, **Discard** (or **Escape**) and **Save**. A selection inside a footnote gets a bar with **Note** alone. Notes keep their formatting as the Mac keeps it, so a note made on the Mac keeps its formatting here until you change its text.
- **Research**, at the top, opens **All Notes**: every note, newest first, filtered by project, tag or text, as in the app. A note opens its editor, and **Delete…** asks first.
- **Research**, beside **Cite**, opens the Research rail. Its **Summary** section shows the document's summaries, one at a time, newest first, with the app's arrows for older ones, each labelled AI summary, AI · edited or Yours; **Write a Summary** writes your own, which alone you can edit or delete. Its **Notes** section lists the document's notes, newest first, with **Add Note**; both are open until you close them, as in the app. Its **Highlights** section lists the document's highlights, each with its colour, which you can change there, as the app cannot, and **Remove…**, which asks as a click on the highlight does. Its **Tags** section, closed until you open it and then as you left it, as Highlights is, lists the document's tags: **×** takes one off, and **Add Tag** opens the tag picker. There **New Tag** makes a tag and switches it on, **Your Tags** switches the others on and off, **Done** gives the document the tags switched on, and **Cancel** deletes the tags you made there, as in the app.
- **Settings**, at the top, lists your tags under **Tags**, and under **Data** counts what you have here under **Contents**, as the app's export sheet does, and offers **Export as JSON**, the file FRUS Explorer's own Export as JSON writes, and **Export Notes as Markdown**: one ZIP file of every note, each as the app's Markdown export writes it. **Data** also imports your research from the Mac: see [Bring your research from the Mac](#bring-your-research-from-the-mac) and [Take your research with you](#take-your-research-with-you). A tag opens its editor, to rename it, to merge it into another, which then carries its documents, or to delete it, which takes it off every document; **New Tag…** makes one. Tags are kept on the server, in its store in the Docker volume, so any browser on this machine sees the same ones.

The address of every screen, search and document can be bookmarked or shared with another browser on this machine. Everything works from the keyboard, starting with **Skip to content**, the first stop of the Tab key.

### Bring your research from the Mac

Your notes, highlights, tags, summaries, projects, collections and the rest come from FRUS Explorer's JSON export, apart from the research database the server serves:

1. In FRUS Explorer, open **Settings ▸ Data & Recovery** and turn on **Include AI-Generated Summaries** if you want your summaries too, then choose **Export as JSON**.
2. In the browser, open **Settings ▸ Data**, choose the file under **Import a JSON Export**, and press **Import**.

The import runs on the server and the pane follows it. Its report gives, for each kind of record, how many the file held, how many came in, how many replaced an older copy you had here, and how many were kept because the copy here was as new; and it says what a file from an older FRUS Explorer cannot carry. Each record keeps its id from the Mac, so importing the same file again changes nothing, and a later export brings only what changed. Nothing is deleted: a record you delete on the Mac stays here until you delete it here.

A research database exported with **Include My Notes, Summaries, and Tags** on brings less, and the server takes it only as a last resort: for each document one note, its notes joined into one block as the index keeps them, and its newest summary, with no prompt; and your tags, on the documents that carry them. The import's report, in `/api/v1/status`, counts them. The rail and All Notes say **From a research database** of each such note, and the Summary section of each such summary. A later export's block replaces the earlier one, and what a JSON import already brought is not added again; but a JSON import after a research database's brings your notes beside its blocks, which you can then delete.

An export of format version 6, which FRUS Explorer wrote until the format reached version 7, and which the report names, carries no saved searches, working corpora, volume scopes, corrections, reviewed changes, Suggested Next leads or synced settings, no formatting of notes, and no structure of collections: a section heading, a note block or an apparatus block arrives as an entry the server keeps but does not show. A summary made with one of FRUS Explorer's own prompts arrives without its prompt's name, which the export does not carry.

### Take your research with you

**Settings ▸ Data ▸ Export as JSON** saves `frus-research-export.json`, the file FRUS Explorer's Export as JSON writes, at the format version this server's FRUS Explorer writes: everything you have here, each record under its id, with one key more that the app passes over, `frusExplorerLight`, which gives its own version and says whether the file holds your summaries and the server's corrections of its index. As on the Mac, the summaries come only with **Include AI-Generated Summaries** turned on, your own among them. Imported into this server again, it changes nothing; imported into another, it brings everything it holds, but the corrections for someone who is not a curator there. FRUS Explorer itself imports no JSON export yet, so the file is a backup and a way to another server rather than to the Mac.

### The API

Everything the browser shows comes from the API, which `curl` reaches too. A search takes the search box's text in `keywords`, with the app's query language, and answers with the exact count and the first page of results, best first:

```bash
curl -s 'http://localhost:8080/api/v1/search?keywords=NEAR(khrushchev+berlin,+10)&limit=5'
```

`curl -G --data-urlencode 'keywords=…'` writes the text safely. Each result's `snippet` marks the matches with `<b>` and is otherwise plain text, and `drawnDate` gives its date in words, which the browser shows for a result with no `dateline`. `sort=dateAscending` or `sort=dateDescending` pages the 7,500 results a search keeps by date. `/api/v1/search/inspect` takes the same parameters and shows what the query compiles to, with the Query Inspector's account of each term; `scopedCounts=true` counts each within the filters, and `emptyConjuncts=true` names the terms that match nothing. `/api/v1/search/timeline` counts by year the 7,500 results a search keeps, and `documents=true` lists each year's documents; `/api/v1/search/concordance` takes a search and its page, and gives each occurrence of its words on that page with the words either side, and the lines' order by each of the app's alignments.

The catalogue lists all 553 volumes, saying which the index holds and which have TEI in your folder, and each volume lists its documents in reading order:

```bash
curl -s 'http://localhost:8080/api/v1/volumes?subseries=1961-63&limit=3'
```

```bash
curl -s 'http://localhost:8080/api/v1/volumes/frus1961-63v06/documents?limit=5'
```

A volume's sections are in `structure` on `/api/v1/volumes/frus1961-63v06`, and `structureSource` says whether they came from the index or the TEI; `hasOwnText` marks a section whose own text the index holds. A section lists its documents, and that text's row in `ownText`:

```bash
curl -s 'http://localhost:8080/api/v1/volumes/frus1961-63v06/sections/comp1'
```

A document's page, as the reader renders it from the TEI folder, in `colorScheme` `light` or `dark`, `textSize` `small`, `medium`, `large` or `extraLarge`, and `readingWidth` `narrow`, `standard` (the default) or `wide`:

```bash
curl -s 'http://localhost:8080/api/v1/volumes/frus1961-63v06/documents/d1/html?colorScheme=dark' -o d1.html
```

The first document of a volume takes about half a second while the server parses the volume; the rest are immediate. The reader works without an index. Figure images come from FRUS Explorer's own folder of volumes, which holds them; with a clone of HistoryAtState/frus, figures show a placeholder.

A document's citation, in `style` `historyAtState` (the default), `chicago` or `turabian`, as Markdown in `citation` and as plain text in `plainText`:

```bash
curl -s 'http://localhost:8080/api/v1/volumes/frus1961-63v06/documents/d1/citation?style=chicago'
```

What a link in a document's page leads to, given the link as the page writes it:

```bash
curl -s -G 'http://localhost:8080/api/v1/volumes/frus1961-63v06/documents/d1/link' --data-urlencode 'href=frusexplorer://person/p_KNS2'
```

Citation Lookup takes a citation's text, as Paste Citation does, and answers with the documents it may name, best first, each with the app's label for how it was matched:

```bash
curl -s -G 'http://localhost:8080/api/v1/citation-lookup' --data-urlencode 'text=FRUS, 1961–1963, vol. VI, doc. 1'
```

It takes Structured Entry's fields instead as `subseries`, `volumeNumber`, `partNumber`, `documentNumber` and `pageNumber`, and `/api/v1/citation-lookup/fields` shows what a text fills them with. A block of footnotes, sent as the form field `text`, is triaged note by note, up to 500 at a time:

```bash
curl -s 'http://localhost:8080/api/v1/citation-lookup/batch' --data-urlencode $'text=1. FRUS, 1961–1963, vol. VI, doc. 1.\n2. FRUS, 1961–1963, vol. V, doc. 84.'
```

Your tags, highlights, notes and summaries are under `/api/v1/me`. A change to them must carry the token `GET /api/v1/me` gives, in `X-CSRF-Token`, come from the server's own address, in `Origin`, and send JSON, as the browser does: a server with no sign-in is guarded so against other pages open in your browser. With the token in a variable:

```bash
token=$(curl -s http://localhost:8080/api/v1/me | sed -nE 's/.*"csrfToken":"([^"]+)".*/\1/p')
```

```bash
curl -s -X POST http://localhost:8080/api/v1/me/tags -H "X-CSRF-Token: $token" -H 'Origin: http://localhost:8080' -H 'Content-Type: application/json' --data '{"name": "Primary source"}'
```

`GET /api/v1/me/tags` lists them, and `PUT /api/v1/me/volumes/frus1961-63v06/documents/d1/tags` with `{"tagIds": [...]}` gives a document exactly those. `GET /api/v1/me/volumes/frus1961-63v06/documents/d1/highlights` lists a document's highlights, with the document's `renderingVersion`. A `POST` there with `{"startOffset", "endOffset", "colorTag", "renderingVersion"}` makes one over those offsets into the document's text, in that version of the text, and `PATCH` or `DELETE /api/v1/me/highlights/{id}` changes its `colorTag` or removes it. `GET /api/v1/me/notes` lists your notes, and `/api/v1/me/volumes/frus1961-63v06/documents/d1/notes` a document's, where a `POST` with `{"bodyText", "runs": null, "userTagIds": [], "projectIds": [], "selectedSummaryIds": []}` makes a plain one; `GET`, `PUT` and `DELETE /api/v1/me/notes/{id}` read, save and delete one, and `GET /api/v1/me/notes/export` gives every note as a ZIP of Markdown files. `GET /api/v1/me/volumes/frus1961-63v06/documents/d1/summaries` lists a document's summaries, where a `POST` with `{"responseText"}` writes your own. A `POST /api/v1/me/import` with a JSON export as its body, `application/json`, imports it as a job and answers where to follow it, `GET /api/v1/me/import/{id}`, which gives the report once it is done. `GET /api/v1/me/export` gives the export, with `?includeGeneratedSummaries=true` your summaries too, and `GET /api/v1/me/export/contents` how many records of each kind it carries. A note's text may be 1 MiB, in a change of 4 MiB at most; an export 128 MiB; any other change may be 64 KiB. The token lasts until the server restarts.

An error names its cause in a `code`: `INDEX_NOT_READY` for a search before an import has finished, `EMPTY_QUERY` for a query with nothing left to search, `TEI_NOT_AVAILABLE` when the volume is not in your TEI folder, and `DOCUMENT_NOT_FOUND`, `SECTION_NOT_FOUND`, `VOLUME_NOT_FOUND`, `TAG_NOT_FOUND`, `HIGHLIGHT_NOT_FOUND`, `NOTE_NOT_FOUND` or `SUMMARY_NOT_FOUND` for an id the volume, the catalogue, your tags, highlights, notes or summaries lack, `SUMMARY_READ_ONLY` for a change to a summary you did not write here, `TOO_MANY_CITATIONS` for a block of more than 500 citations, `DOCUMENT_CHANGED` for a highlight asked for in a version of the document's text the server no longer has, `INVALID_EXPORT` for a file that is not a JSON export or whose records cannot be read, `UNSUPPORTED_FORMAT_VERSION` for an export newer than the server reads, `IMPORT_IN_PROGRESS` while another of your imports runs, and `IMPORT_NOT_FOUND` for an import the server does not know, as after a restart. Under `/api/v1/me` the guard refuses a request, read or change, that was not sent to the address in `FRUS_PUBLIC_URL` as `HOST_NOT_ALLOWED`, such as one to http://127.0.0.1:8081 for a server at http://localhost:8080; and a change without the current token as `CSRF_TOKEN_INVALID`, and from another page as `ORIGIN_NOT_ALLOWED`.

## If an import is refused

A refused file stays in the drop zone. `/api/v1/status` says why, under `lastImport`; `/readyz` says so too while no index is being served. A refusal about the file itself is not retried until the file changes. A problem on the server's side, such as too little disk space, is retried every minute. `docker compose logs frus` shows the whole story, and `docker compose exec frus rm /data/import/<file>` clears a file from the drop zone.

| The server says | What to do |
| --- | --- |
| "This export is index version N; this server serves index version M" | Update FRUS Explorer or the server so they match, then export again |
| "Let FRUS Explorer finish re-indexing, then export again" | Leave FRUS Explorer open until indexing ends |
| "This export includes your notes, summaries and tags, and this server keeps no research data" | The server runs with `FRUS_USER_DATA=off`. Export again with Include My Notes, Summaries, and Tags turned off. The refused copy holds your writing, so remove it from the drop zone with `docker compose exec frus rm /data/import/<file>` |
| "The server cannot read …" | The file kept permissions only you can read. Copy it again with `docker compose cp -a`, which gives it to the server's user; it is tried again within a minute |
| "needs about N GB free beside the index" | Free space for Docker; the import is tried again by itself. Removing your writing from an export made with it needs about twice the export's size more |
| "… is not a SQLite database" or "… is damaged" | Export again with Export Research Database… |
| "… arrived with a -wal file", or "a -journal file that may hold an unfinished transaction" | This is a copy of a database in use. First remove that file, with `docker compose exec frus rm /data/import/<file>-wal` (or `-journal`). Then export with Export Research Database… and copy the new export in. Keep that order: a new export copied while the side file is there is refused too, and removing the side file afterwards does not try it again |
| "… is a symbolic link, not an export" | `docker compose cp` copied the link, not the file. Run the same copy again with `docker compose cp -L`, which follows the link: the export replaces the link of the same name and is imported |

## Upgrading

```bash
docker compose pull && docker compose up -d
```

`edge` is the newest build of the project's main branch that passed its smoke test on both architectures. The index stays in the volume. If the new server serves a different index version, `/readyz` answers `index_version_mismatch`, naming both versions: export again from a matching FRUS Explorer build and copy it in. The first such change came with FRUS Explorer build 50, which moved the index from version 65 to 69, and the second with 1.0 (build 1776), which moved it to 71.

### Releases

A release is a build of the main branch that passed its smoke test and that the project's owner chose to publish, with notes. Each is named `<version>-<build>.<n>`, such as `1.0-1776.1`: the version and build of the FRUS Explorer app whose exports it serves, and its number among that build's releases. Its notes, on the project's [releases page](https://github.com/joshbotts/FRUS-Explorer-Web-App/releases), name the image's digest, the FRUS Explorer build to export from, the index version and whether it changed since the last release, and the pull requests it brings. Once an image is pulled, its labels give the build and the index version too:

```bash
docker image inspect --format '{{json .Config.Labels}}' ghcr.io/joshbotts/frus-explorer-light:edge
```

Choose what to follow with `FRUS_IMAGE` in `.env`:

| `FRUS_IMAGE` | Follows |
| --- | --- |
| `ghcr.io/joshbotts/frus-explorer-light:edge`, the default | Each build of the main branch that passes its smoke test |
| `ghcr.io/joshbotts/frus-explorer-light:<version>-<build>`, such as `:1.0-1776` | Each release for that FRUS Explorer build. Once the server moves to a later build, it stays on this build's last release |
| `ghcr.io/joshbotts/frus-explorer-light:<version>-<build>.<n>`, such as `:1.0-1776.1`, or the digest a release names, `ghcr.io/joshbotts/frus-explorer-light@sha256:…` | One release, which never moves |
| `ghcr.io/joshbotts/frus-explorer-light:sha-<commit>`, where `<commit>` is the first 7 characters of a commit on the main branch | One build of the main branch |

Before releases began, `:1.0-1776` moved with `edge`.

To hear of each release, watch the repository on GitHub for releases only (Watch, then Custom, then Releases), or follow its feed, `https://github.com/joshbotts/FRUS-Explorer-Web-App/releases.atom`. When a release's notes say the index version changed, export again from the FRUS Explorer build they name, upgrade, and copy the new export in as in [5. Import it](#5-import-it); until then `/readyz` answers `index_version_mismatch`.

## Stopping and removing

| Command | Effect |
| --- | --- |
| `docker compose stop` | Stops the server, keeping everything |
| `docker compose down` | Removes the container, keeping the index in the volume |
| `docker compose down --volumes` | Removes the index and your research data too; you would import again, and your tags, highlights, notes and summaries would be gone |

## Behind a reverse proxy

Compose publishes the server on this machine's 127.0.0.1 only. A reverse proxy on the same machine, such as nginx, can give it an address others reach, with TLS: a host of its own, such as `https://frus.example.org/`, or a path of a site that serves other things, such as `https://example.org/frus-explorer/`. **The server has no sign-in yet,** so anyone who can reach the proxy can use it, your tags and highlights included, which they can read and change: keep the proxy behind your own network rules or sign-in until sign-in through the proxy arrives later in phase 2, or set `FRUS_USER_DATA=off` in `.env` for a read-only server, which keeps no tags or highlights and offers none.

Write the address people will open into `.env`, then make the container again, which keeps the index in the volume:

```bash
echo "FRUS_PUBLIC_URL=https://example.org/frus-explorer/" >> .env
```

```bash
docker compose up -d
```

With a path, the server answers the browser app, the reader and the API under it, and `/healthz` and `/readyz` both under it and at the root, so Docker's health check and a proxy's both work. Other paths at the root answer 404, apart from `/`, which leads to the path. The proxy forwards the path as it is, and does not strip it. The address may also end in no path, as `https://frus.example.org` does.

These are nginx `location` blocks, for the `server` block that serves the host with TLS. Each passes the host people used, which the server checks a change to their research data was sent to, and forwards to the port in `FRUS_HOST_PORT`, 8080 by default. Each raises nginx's own limit on a request's size, 1 MiB, to the 128 MiB an import of a Mac JSON export may send, the largest request the server takes, which holds every other request to its own smaller limit; another proxy needs a limit of 128 MiB or more too. A change must also come from a page at the address in `FRUS_PUBLIC_URL`, so set it to the address people open.

**At the root of its own host,** with `FRUS_PUBLIC_URL=https://frus.example.org`:

<!-- compose-smoke: nginx at the root -->
```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    client_max_body_size 128m;
}
```

**Under a path,** with `FRUS_PUBLIC_URL=https://example.org/frus-explorer/`:

<!-- compose-smoke: nginx under a path -->
```nginx
location /frus-explorer/ {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    client_max_body_size 128m;
}
```

`proxy_pass` names no path, so nginx forwards `/frus-explorer/search` as it is, and it answers `/frus-explorer` with a redirect to `/frus-explorer/`. `scripts/compose-smoke` runs both recipes, and the browser suite through the second. With another proxy, forward the path unchanged in the same way: in Caddy, `handle /frus-explorer/*` with `reverse_proxy 127.0.0.1:8080`, not `handle_path`, which strips it; in Apache, `ProxyPass /frus-explorer/ http://127.0.0.1:8080/frus-explorer/`; in Traefik, a router with no StripPrefix middleware.

## Settings

These go in `.env` beside `compose.yaml`.

| Setting | Default | Meaning |
| --- | --- | --- |
| `FRUS_TEI_DIR` | `./tei` | Folder of TEI volumes, mounted read-only |
| `FRUS_HOST_PORT` | `8080` | Port on this machine's 127.0.0.1 |
| `FRUS_PUBLIC_URL` | `http://localhost:8080`, on `FRUS_HOST_PORT` | The address people open. Behind a reverse proxy, its address, which may end in a path such as `/frus-explorer/`: see Behind a reverse proxy. A change to your research data is taken only from a page at this address; on this machine, `localhost`, `127.0.0.1` and `[::1]` at its port are one address |
| `FRUS_USER_DATA` | `on` | `off` makes a read-only server, which keeps no tags, highlights, notes or other research data and refuses any change |
| `FRUS_IMAGE` | `ghcr.io/joshbotts/frus-explorer-light:edge` | The image to run: a release, or `edge` (see [Releases](#releases)) |
| `COMPOSE_PROFILES` | none | `pdf` starts Gotenberg, a 700 MB download, for PDF export when it arrives in phase 3 |

## Notes

- **Only this machine can reach the server,** unless a reverse proxy on it forwards to it, as Behind a reverse proxy sets out. The server has no sign-in of its own until phase 3's local accounts; sign-in through the proxy comes before them, in phase 2.
- **Keep `/data` in the Docker volume.** On a Mac, a folder shared from macOS is not a local filesystem to SQLite. On Linux, replacing the volume with a host folder in `compose.yaml` works if that folder is writable by UID 10001, the server's user.
- **On Linux,** the TEI files must be readable by UID 10001; a clone made with the usual umask is. On a host with SELinux enforcing, add `,z` after `ro` in the TEI volume line of `compose.yaml`. To run `docker` without `sudo`, your user must be in the `docker` group.
- **Backups** of your research data, which the server keeps in `/data/app/app.db` in the volume, start later in phase 2 with a daily copy. Until then, keep the volume, and the index can always be imported again. Already, an upgrade that changes the layout of the server's own store, `/data/app/app.db`, first copies it into `/data/backups`. If the change fails, the server leaves the store as it was and does not start, and its log names the copy; Compose starts it again, and it tries again without taking another copy.
- **Going back to an older server** after such an upgrade: the older server cannot open the changed store, and does not start. Put the copy back first, with the server stopped. List the copies with `docker compose run --rm --no-deps --entrypoint ls frus /data/backups`, then, naming the newest `app-…-before-migration-….db`:

  ```bash
  docker compose stop
  docker compose run --rm --no-deps --entrypoint sh frus -c 'rm -f /data/app/app.db-wal /data/app/app.db-shm && cp /data/backups/<copy> /data/app/app.db'
  ```

  Then set `FRUS_IMAGE` to the older server and run `docker compose up -d`.
- **Podman and Colima** run the same Compose file; this guide has not been tested with them yet.
