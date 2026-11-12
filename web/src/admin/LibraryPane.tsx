// Administration ▸ Library (PLAN's S21c): every catalogue volume with its state, not downloaded, waiting,
// downloading, downloaded, indexing, indexed or failed, with why; Download for one, Download All for every
// volume not downloaded, each a job of the server's queue, which Jobs follows and a cancel stops between two
// volumes; Index for one and Index All Waiting (PLAN's S21d), for a volume downloaded and not indexed, or
// whose last pass did not index it; Remove…, after a question, for a downloaded volume, which for one the
// index holds is a job that takes it out of the index first (PLAN's S21e); and Side-Load a Volume, a TEI file
// of the admin's, which the server checks, keeps and indexes, and lists with the catalogue's when the
// catalogue lacks it. A Standalone server's: an Import server lists its TEI folder and the index, and a server
// under FRUS_OFFLINE downloads nothing, which the pane says. Read again every two seconds while a download or
// an indexing job waits or runs.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useId, useMemo, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import {
  type AdminLibrary,
  downloadVolumes,
  indexVolumes,
  isDownloading,
  type LibraryStatus,
  type LibraryVolume,
  libraryQuery,
  removeVolume,
  sideloadLimit,
  sideloadVolume,
  waitsForIndex,
} from '../api/library';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { AdminFrame, ReadFailure, useAdmin } from './AdminPanes';

const words = copy.admin.library;

/** The order the counts are said in. */
const statuses: LibraryStatus[] = ['downloaded', 'indexed', 'indexing', 'queued', 'downloading', 'failed', 'notDownloaded'];

/** A volume's state in words: an Import server's folder is its TEI mount, which it does not download into. */
function statusWord(volume: LibraryVolume, mode: AdminLibrary['mode']): string {
  if (mode === 'import' && (volume.status === 'downloaded' || volume.status === 'notDownloaded')) {
    return words.importStatuses[volume.status];
  }
  return words.statuses[volume.status];
}

export function LibraryScreen() {
  const { allowed } = useAdmin();
  const library = useQuery({ ...libraryQuery, enabled: allowed });
  let body;
  if (library.isError && !library.data) {
    body = <ReadFailure error={library.error} stale={false} />;
  } else if (!library.data) {
    body = <p role="status">{copy.admin.loading}</p>;
  } else {
    body = (
      <>
        {library.isError && <ReadFailure error={library.error} stale />}
        <Library library={library.data} />
      </>
    );
  }
  return <AdminFrame title={words.title}>{body}</AdminFrame>;
}

function Library({ library }: { library: AdminLibrary }) {
  const client = useQueryClient();
  const [said, setSaid] = useState('');
  const [failure, setFailure] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [removing, setRemoving] = useState<LibraryVolume | null>(null);
  const [filter, setFilter] = useState('');
  const [shown, setShown] = useState<LibraryStatus | 'all'>('all');
  const area = useRef<HTMLDivElement>(null);
  // The element in a row that had focus last: a reading of the Library can take its button away, as when a
  // job takes the volume, and focus then goes to the row rather than to the page.
  const lastFocused = useRef<{ element: HTMLElement; row: string } | null>(null);
  const filterId = useId();
  const shownId = useId();

  useEffect(() => {
    const last = lastFocused.current;
    if (!last || last.element.isConnected) return;
    const active = document.activeElement;
    if (active && active !== document.body && active.isConnected) return;
    area.current?.querySelector<HTMLElement>(`th[data-volume="${CSS.escape(last.row)}"]`)?.focus();
  }, [library]);

  const volumes = useMemo(() => {
    const wanted = filter.trim().toLowerCase();
    return library.volumes.filter(
      (volume) =>
        (shown === 'all' || volume.status === shown || (shown === 'queued' && volume.status === 'downloading')) &&
        (!wanted || volume.volumeId.toLowerCase().includes(wanted) || volume.title.toLowerCase().includes(wanted)),
    );
  }, [library.volumes, filter, shown]);

  async function ask(what: 'download' | 'index', request: { volumeIds: string[] } | { all: true }, key: string) {
    if (busy) return;
    setBusy(key);
    setFailure(null);
    setSaid('');
    try {
      if (what === 'download') {
        const job = await downloadVolumes(client, request);
        setSaid(job?.subject ? words.queued(job.subject) : words.queuedPlain);
      } else {
        const job = await indexVolumes(client, request);
        setSaid(job?.subject ? words.indexQueued(job.subject) : words.indexQueuedPlain);
      }
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setBusy(null);
      // A volume a download or an indexing holds has no Download or Index: focus goes to its row, while it
      // was on the button or nowhere, and the button has gone.
      if ('volumeIds' in request) {
        window.requestAnimationFrame(() => {
          const active = document.activeElement;
          const button = area.current?.querySelector<HTMLButtonElement>(`button[data-${what}="${CSS.escape(key)}"]`);
          if (!button && (!active || active === document.body || !active.isConnected || area.current?.contains(active))) {
            (area.current?.querySelector<HTMLElement>(`th[data-volume="${CSS.escape(key)}"]`) ?? document.querySelector<HTMLElement>('main h1'))?.focus();
          }
        });
      }
    }
  }

  const counts = statuses
    .filter((status) => (library.counts[status] ?? 0) > 0)
    .map((status) =>
      words.count(
        library.counts[status] ?? 0,
        library.mode === 'import' && (status === 'downloaded' || status === 'notDownloaded') ? words.importStatuses[status] : words.statuses[status],
      ),
    );
  // What Download All asks for: every volume whose file is not here and that no download waits for, as the
  // server takes it, a failed one and an indexed one with no file among them.
  const missing = library.volumes.filter((volume) => !volume.downloaded && !isDownloading(volume)).length;
  const waiting = library.volumes.filter(isDownloading).length;
  // What Index All Waiting asks for, as the server takes it, an upgrade's volumes still to go among them.
  const upgrading = library.indexing.upgrade?.volumes;
  const unindexed = library.mode === 'standalone' ? library.volumes.filter((volume) => waitsForIndex(volume, upgrading)).length : 0;

  return (
    <>
      <p className="note">{library.mode === 'standalone' ? words.lead : words.leadImport}</p>
      {library.unavailable ? (
        <p className="note">{library.unavailable}</p>
      ) : (
        <p className="note">{library.source === 'github' ? words.fromGitHub : words.fromMirror}</p>
      )}
      <p>{counts.join(' · ')}</p>
      {library.downloads && (
        <p>
          <button
            type="button"
            aria-disabled={busy !== null || missing === 0}
            onClick={() => {
              if (missing > 0) void ask('download', { all: true }, 'all');
            }}
          >
            {words.downloadAll}
          </button>{' '}
          <span className="note">
            {missing > 0 ? words.downloadAllNote(missing) : waiting > 0 ? words.allWaiting(waiting) : words.allDownloaded}
          </span>
        </p>
      )}
      {library.mode === 'standalone' && (
        <p>
          <button
            type="button"
            aria-disabled={busy !== null || unindexed === 0}
            onClick={() => {
              if (unindexed > 0) void ask('index', { all: true }, 'index-all');
            }}
          >
            {words.indexAll}
          </button>{' '}
          <span className="note">{unindexed > 0 ? words.indexAllNote(unindexed) : words.noneWaitsForIndex}</span>
        </p>
      )}
      {library.indexing.active && (
        <p className="note">{library.indexing.volume ? words.indexing(library.indexing.volume) : words.indexingWaits}</p>
      )}
      {library.indexing.upgrade && library.indexing.upgrade.volumes.length > 0 && (
        <p className="note">{words.upgrade(library.indexing.upgrade.to, library.indexing.upgrade.volumes.length)}</p>
      )}
      {library.mode === 'standalone' && <Sideload onSaid={setSaid} />}
      {/* Always on the page, so that what a download or a removal did is announced when it comes. */}
      <p role="status">{said}</p>
      <p className="error" role="alert">
        {failure}
      </p>
      <div className="library-filters">
        <label htmlFor={filterId}>{words.filter}</label>
        <input id={filterId} type="search" value={filter} onChange={(event) => setFilter(event.target.value)} />
        <label htmlFor={shownId}>{words.show}</label>
        <select id={shownId} value={shown} onChange={(event) => setShown(event.target.value as LibraryStatus | 'all')}>
          <option value="all">{words.showAll}</option>
          {statuses
            .filter((status) => status !== 'downloading')
            .map((status) => (
              <option key={status} value={status}>
                {library.mode === 'import' && (status === 'downloaded' || status === 'notDownloaded')
                  ? words.importStatuses[status]
                  : words.shows[status]}
              </option>
            ))}
        </select>
      </div>
      <p className="note" aria-live="polite">
        {words.shownCount(volumes.length, library.volumes.length)}
      </p>
      {/* A region a keyboard can scroll, where the table is wider than the pane. */}
      <div
        ref={area}
        className="admin-table"
        role="region"
        aria-label={words.caption}
        tabIndex={0}
        onFocus={(event) => {
          const target = event.target as HTMLElement;
          const row = target.closest('tr[data-volume]')?.getAttribute('data-volume');
          lastFocused.current = row ? { element: target, row } : null;
        }}
      >
        <table>
          <caption>{words.caption}</caption>
          <thead>
            <tr>
              <th scope="col">{words.volume}</th>
              <th scope="col">{words.state}</th>
              <th scope="col">{words.file}</th>
              <th scope="col">{words.actions}</th>
            </tr>
          </thead>
          <tbody>
            {volumes.map((volume) => (
              <tr key={volume.volumeId} data-volume={volume.volumeId}>
                {/* Focusable from a script alone: where focus goes once a removal has taken the row's button. */}
                <th scope="row" tabIndex={-1} data-volume={volume.volumeId}>
                  {volume.volumeId}
                  <br />
                  <span className="note">{volume.title}</span>
                </th>
                <td>
                  <span className={`library-state ${volume.status}`}>{statusWord(volume, library.mode)}</span>
                  {volume.indexed && volume.status !== 'indexed' && <span className="note"> · {words.statuses.indexed}</span>}
                  {volume.sideloaded && <span className="note"> · {words.sideloadedMark}</span>}
                  {volume.indexed && !volume.downloaded && (
                    <p className="note">{library.downloads ? words.indexedWithoutFile : words.indexedWithoutFileHere}</p>
                  )}
                  {volume.requestedBy && <p className="note">{words.askedBy(volume.requestedBy)}</p>}
                  {volume.error && <p className={volume.status === 'failed' ? 'error' : 'note'}>{volume.error}</p>}
                </td>
                <td>
                  {volume.downloaded && volume.bytes !== undefined ? (
                    <>
                      {copy.admin.bytes(volume.bytes)}
                      {volume.downloadedAt && <> · {copy.admin.time(volume.downloadedAt)}</>}
                      {volume.figures !== undefined && volume.figures > 0 && <> · {words.figures(volume.figures)}</>}
                    </>
                  ) : (
                    <span className="note">{words.catalogueSize(copy.admin.bytes(volume.catalogueBytes))}</span>
                  )}
                </td>
                <td>
                  {/* An indexed volume's file is not replaced until the corrections check comes, nor one a pass reads. */}
                  {library.downloads && !isDownloading(volume) && volume.status !== 'indexing' && !(volume.indexed && volume.downloaded) && (
                    <button
                      type="button"
                      data-download={volume.volumeId}
                      aria-disabled={busy !== null}
                      aria-label={(volume.downloaded ? words.downloadAgainA11y : words.downloadA11y)(volume.volumeId)}
                      onClick={() => void ask('download', { volumeIds: [volume.volumeId] }, volume.volumeId)}
                    >
                      {volume.downloaded ? words.downloadAgain : words.download}
                    </button>
                  )}{' '}
                  {library.mode === 'standalone' && waitsForIndex(volume, upgrading) && (
                    <button
                      type="button"
                      data-index={volume.volumeId}
                      aria-disabled={busy !== null}
                      aria-label={words.indexA11y(volume.volumeId)}
                      onClick={() => void ask('index', { volumeIds: [volume.volumeId] }, volume.volumeId)}
                    >
                      {words.index}
                    </button>
                  )}{' '}
                  {/* Not while an indexing job waits or runs, which may take the volume; an indexed one leaves the index first. */}
                  {library.mode === 'standalone' && volume.downloaded && !isDownloading(volume) && !library.indexing.active && (
                    <button
                      type="button"
                      data-remove={volume.volumeId}
                      aria-label={words.removeA11y(volume.volumeId)}
                      onClick={() => setRemoving(volume)}
                    >
                      {words.remove}
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {removing && (
        <RemoveConfirmation
          key={removing.volumeId}
          volume={removing}
          onRemoved={(volume, queued) => setSaid(queued ? words.removalQueued(volume.volumeId) : words.removed(volume.volumeId))}
          onClose={(removed) => {
            const id = removing.volumeId;
            closeAtOnce(() => setRemoving(null));
            // After a removal the row's button goes, so focus goes to the row; else back to its button.
            const target = removed
              ? area.current?.querySelector<HTMLElement>(`th[data-volume="${CSS.escape(id)}"]`)
              : area.current?.querySelector<HTMLButtonElement>(`button[data-remove="${CSS.escape(id)}"]`);
            (target ?? document.querySelector<HTMLElement>('main h1'))?.focus();
          }}
        />
      )}
    </>
  );
}

/**
 * "Remove this volume?", with Remove and Keep It, which waits for the removal, or for an indexed volume the
 * removal's job to be queued, and the Library read again.
 */
function RemoveConfirmation({
  volume,
  onRemoved,
  onClose,
}: {
  volume: LibraryVolume;
  onRemoved: (volume: LibraryVolume, queued: boolean) => void;
  onClose: (removed: boolean) => void;
}) {
  const client = useQueryClient();
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const keep = useRef<HTMLButtonElement>(null);
  const headingId = useId();
  const messageId = useId();

  async function remove() {
    if (busy) return;
    setBusy(true);
    setFailure(null);
    try {
      const job = await removeVolume(client, volume.volumeId);
      setBusy(false);
      onRemoved(volume, job !== null);
      onClose(true);
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
    }
  }

  return (
    <Modal
      className="confirm"
      role="alertdialog"
      labelledBy={headingId}
      describedBy={messageId}
      initial={keep}
      onCancel={() => {
        if (!busy) onClose(false);
      }}
      onClose={() => onClose(false)}
    >
      <h2 id={headingId} tabIndex={-1}>
        {words.removeTitle(volume.volumeId)}
      </h2>
      <p id={messageId}>{volume.indexed ? words.removeMessageIndexed : words.removeMessage}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button
          ref={keep}
          type="button"
          aria-disabled={busy}
          onClick={() => {
            if (!busy) onClose(false);
          }}
        >
          {words.keep}
        </button>
        <button type="button" className="destructive" aria-disabled={busy} onClick={() => void remove()}>
          {words.removeConfirm}
        </button>
      </div>
    </Modal>
  );
}

/**
 * Side-Load a Volume (PLAN's S21e): a TEI file the admin chooses, sent as it is, and what the server made of it:
 * its indexing's job, or why it refused the file, in its words.
 */
function Sideload({ onSaid }: { onSaid: (said: string) => void }) {
  const client = useQueryClient();
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const input = useRef<HTMLInputElement>(null);
  const inputId = useId();
  const headingId = useId();

  async function send() {
    if (busy) return;
    setFailure(null);
    onSaid('');
    if (!file) {
      setFailure(words.sideloadChoose);
      input.current?.focus();
      return;
    }
    if (file.size > sideloadLimit) {
      setFailure(words.sideloadTooLarge(copy.admin.bytes(file.size)));
      return;
    }
    setBusy(true);
    try {
      const answer = await sideloadVolume(client, file);
      onSaid(words.sideloaded(answer.volumeId));
      setFile(null);
      if (input.current) input.current.value = '';
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section aria-labelledby={headingId} className="library-sideload">
      <h2 id={headingId}>{words.sideload}</h2>
      <p className="note">{words.sideloadLead}</p>
      <p>
        <label htmlFor={inputId}>{words.sideloadFile}</label>{' '}
        <input
          ref={input}
          id={inputId}
          type="file"
          accept=".xml,application/xml,text/xml"
          onChange={(event) => setFile(event.target.files?.[0] ?? null)}
        />{' '}
        <button type="button" aria-disabled={busy} onClick={() => void send()}>
          {words.sideloadButton}
        </button>
      </p>
      <p className="error" role="alert">
        {failure}
      </p>
    </section>
  );
}
