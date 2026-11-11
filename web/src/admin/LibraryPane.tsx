// Administration ▸ Library (PLAN's S21c): every catalogue volume with its state, not downloaded, waiting,
// downloading, downloaded, indexed or failed, with why; Download for one, Download All for every volume not
// downloaded, each a job of the server's queue, which Jobs follows and a cancel stops between two volumes;
// and Remove…, after a question, for a downloaded volume the index does not hold. A Standalone server's:
// an Import server lists its TEI folder and the index, and a server under FRUS_OFFLINE downloads nothing,
// which the pane says. Read again every two seconds while a download waits or runs.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useMemo, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { type AdminLibrary, downloadVolumes, isDownloading, type LibraryStatus, type LibraryVolume, libraryQuery, removeVolume } from '../api/library';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { AdminFrame, ReadFailure, useAdmin } from './AdminPanes';

const words = copy.admin.library;

/** The order the counts are said in. */
const statuses: LibraryStatus[] = ['downloaded', 'indexed', 'queued', 'downloading', 'failed', 'notDownloaded'];

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
  const filterId = useId();
  const shownId = useId();

  const volumes = useMemo(() => {
    const wanted = filter.trim().toLowerCase();
    return library.volumes.filter(
      (volume) =>
        (shown === 'all' || volume.status === shown || (shown === 'queued' && volume.status === 'downloading')) &&
        (!wanted || volume.volumeId.toLowerCase().includes(wanted) || volume.title.toLowerCase().includes(wanted)),
    );
  }, [library.volumes, filter, shown]);

  async function download(request: { volumeIds: string[] } | { all: true }, key: string) {
    if (busy) return;
    setBusy(key);
    setFailure(null);
    try {
      const job = await downloadVolumes(client, request);
      setSaid(job?.subject ? words.queued(job.subject) : words.queuedPlain);
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setBusy(null);
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
  const notDownloaded = library.counts.notDownloaded ?? 0;

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
            aria-disabled={busy !== null || notDownloaded === 0}
            onClick={() => {
              if (notDownloaded > 0) void download({ all: true }, 'all');
            }}
          >
            {words.downloadAll}
          </button>{' '}
          <span className="note">{notDownloaded === 0 ? words.allDownloaded : words.downloadAllNote(notDownloaded)}</span>
        </p>
      )}
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
      <div ref={area} className="admin-table" role="region" aria-label={words.caption} tabIndex={0}>
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
                  {volume.status === 'indexed' && !volume.downloaded && <p className="note">{words.indexedWithoutFile}</p>}
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
                  {library.downloads && !isDownloading(volume) && (
                    <button
                      type="button"
                      data-download={volume.volumeId}
                      aria-disabled={busy !== null}
                      aria-label={(volume.downloaded ? words.downloadAgainA11y : words.downloadA11y)(volume.volumeId)}
                      onClick={() => void download({ volumeIds: [volume.volumeId] }, volume.volumeId)}
                    >
                      {volume.downloaded ? words.downloadAgain : words.download}
                    </button>
                  )}{' '}
                  {library.mode === 'standalone' && volume.downloaded && !volume.indexed && !isDownloading(volume) && (
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
          onRemoved={(volume) => setSaid(words.removed(volume.volumeId))}
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

/** "Remove this volume?", with Remove and Keep It, which waits for the removal and the Library read again. */
function RemoveConfirmation({
  volume,
  onRemoved,
  onClose,
}: {
  volume: LibraryVolume;
  onRemoved: (volume: LibraryVolume) => void;
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
      await removeVolume(client, volume.volumeId);
      setBusy(false);
      onRemoved(volume);
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
      <p id={messageId}>{words.removeMessage}</p>
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
