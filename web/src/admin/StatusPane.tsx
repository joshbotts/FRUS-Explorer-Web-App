// Administration ▸ Status (PLAN's S20d): the server's version, mode and sign-in; the index, the volumes it
// serves and its version; the user store and its migration; the backups; the stored keys' key file; the
// job running; and the recovery action that resets the index, after a question, as a job that Jobs
// follows: in Import mode it removes the index, and on a Standalone server (PLAN's S21e) it empties the
// index and indexes the library again. A Standalone server's pane also has the index's upkeep: its room,
// Compact the Index and Check the Index, each a job. Read again every two seconds while a job runs.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { useId, useRef, useState } from 'react';
import { type AdminStatus, checkIndex, compactIndex, indexQuery, resetIndex, statusQuery } from '../api/admin';
import { errorMessage } from '../api/client';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { AdminFrame, ReadFailure, useAdmin } from './AdminPanes';

const words = copy.admin.status;

export function StatusScreen() {
  const { allowed } = useAdmin();
  const status = useQuery({ ...statusQuery, enabled: allowed });
  let body;
  if (status.isError && !status.data) {
    body = <ReadFailure error={status.error} stale={false} />;
  } else if (!status.data) {
    body = <p role="status">{copy.admin.loading}</p>;
  } else {
    body = (
      <>
        {status.isError && <ReadFailure error={status.error} stale />}
        <StatusBody status={status.data} />
      </>
    );
  }
  return <AdminFrame title={words.title}>{body}</AdminFrame>;
}

function StatusBody({ status }: { status: AdminStatus }) {
  const index = status.index;
  const backups = status.backups;
  return (
    <>
      <section aria-labelledby="status-server">
        <h2 id="status-server">{words.server}</h2>
        <dl className="admin-facts">
          <dt>{words.version}</dt>
          <dd>{status.version}</dd>
          <dt>{words.mode}</dt>
          <dd>{words.modes[status.mode]}</dd>
          <dt>{words.auth}</dt>
          <dd>{words.auths[status.auth] ?? status.auth}</dd>
          <dt>{words.started}</dt>
          <dd>{copy.admin.time(status.startedAt)}</dd>
        </dl>
      </section>
      <section aria-labelledby="status-index">
        <h2 id="status-index">{words.index}</h2>
        <dl className="admin-facts">
          <dt>{words.readiness}</dt>
          <dd>{status.readiness.detail}</dd>
          {index ? (
            <>
              <dt>{words.volumes}</dt>
              <dd>{words.served(index.volumes, status.catalogueVolumes, index.documents)}</dd>
              <dt>{words.indexVersion}</dt>
              <dd>{words.indexVersions(index.indexVersion, status.supportedIndexVersion)}</dd>
              {index.exportedAt && (
                <>
                  <dt>{words.exported}</dt>
                  <dd>
                    {copy.admin.time(index.exportedAt)}
                    {index.appVersion && index.appBuild ? ` ${words.exportedBy(index.appVersion, index.appBuild)}` : ''}
                  </dd>
                </>
              )}
            </>
          ) : (
            <>
              <dt>{words.volumes}</dt>
              <dd>{words.noIndex}</dd>
            </>
          )}
        </dl>
      </section>
      <section aria-labelledby="status-store">
        <h2 id="status-store">{words.store}</h2>
        <dl className="admin-facts">
          <dt>{words.store}</dt>
          <dd>{words.stores[status.store.kind]}</dd>
          <dt>{words.migration}</dt>
          <dd>{words.migrations(status.store.migration, status.store.latestMigration)}</dd>
          <dt>{words.backups}</dt>
          {backups ? (
            <dd>
              {words.backupsDaily(backups.daily, backups.kept)}. {words.backupsAt(backups.hour, backups.timeZone)}.
            </dd>
          ) : (
            <dd>{words.backupsService}</dd>
          )}
          {backups && (
            <>
              <dt>{words.backupsNewest}</dt>
              <dd>{backups.newest ? `${backups.newest.name}, ${copy.admin.time(backups.newest.takenAt)}` : words.backupsNone}</dd>
              <dt>{words.backupsHost}</dt>
              <dd>{backups.copiedToHost ? copy.admin.yes : copy.admin.no}</dd>
            </>
          )}
          <dt>{words.keyFile}</dt>
          <dd>
            <code>{status.keys.keyFileId}</code>, {words.keysStored(status.keys.stored)}
          </dd>
        </dl>
      </section>
      <section aria-labelledby="status-jobs">
        <h2 id="status-jobs">{words.jobs}</h2>
        <p>
          {status.jobs.running
            ? `${copy.admin.jobs.kinds[status.jobs.running.kind] ?? status.jobs.running.kind}: ${status.jobs.running.progress ?? copy.admin.jobs.states.running}`
            : words.jobsNone}
          {status.jobs.queued > 0 ? ` ${words.jobsQueued(status.jobs.queued)}.` : ''}{' '}
          <Link to="/admin/jobs">{copy.admin.jobs.title}</Link>
        </p>
      </section>
      {status.mode === 'standalone' && <Upkeep />}
      <Recovery status={status} />
    </>
  );
}

/**
 * A Standalone server's index upkeep (PLAN's S21e): the index's room, with the app's line under it, and
 * Compact the Index and Check the Index, each a job.
 */
function Upkeep() {
  const client = useQueryClient();
  const room = useQuery(indexQuery);
  const [said, setSaid] = useState('');
  const [failure, setFailure] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const storage = room.data?.storage;

  async function ask(what: 'compact' | 'check') {
    if (busy) return;
    setBusy(true);
    setFailure(null);
    setSaid('');
    try {
      if (what === 'compact') {
        await compactIndex(client);
        setSaid(words.compactQueued);
      } else {
        await checkIndex(client);
        setSaid(words.checkQueued);
      }
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setBusy(false);
    }
  }

  let line: string | null = null;
  if (storage?.compaction === 'available') {
    line = words.compactAvailable(copy.admin.bytes(storage.reclaimableBytes), Math.round((100 * storage.reclaimableBytes) / Math.max(storage.fileBytes, 1)));
  } else if (storage?.compaction === 'insufficientSpace') {
    line = words.compactBlocked(copy.admin.bytes(storage.reclaimableBytes), copy.admin.bytes(storage.requiredBytes));
  }
  return (
    <section aria-labelledby="status-upkeep">
      <h2 id="status-upkeep">{words.upkeep}</h2>
      <p className="note">{words.upkeepLead}</p>
      {storage && (
        <dl className="admin-facts">
          <dt>{words.indexFile}</dt>
          <dd>
            {words.indexRoom(copy.admin.bytes(storage.fileBytes), copy.admin.bytes(storage.reclaimableBytes))}
            {line && <p className="note">{line}</p>}
          </dd>
        </dl>
      )}
      <div className="actions">
        <button type="button" aria-disabled={busy || !room.data?.upkeep} onClick={() => void ask('compact')}>
          {words.compact}
        </button>
        <button type="button" aria-disabled={busy || !room.data?.upkeep} onClick={() => void ask('check')}>
          {words.check}
        </button>
        {/* Always on the page, so that the line is announced when it comes. */}
        <p role="status">
          {said && (
            <>
              {said} <Link to="/admin/jobs">{copy.admin.jobs.title}</Link>
            </>
          )}
        </p>
      </div>
      <p className="error" role="alert">
        {failure}
      </p>
    </section>
  );
}

/** The index's reset, after a question: Import mode's, and a Standalone server's, which indexes the library again. */
function Recovery({ status }: { status: AdminStatus }) {
  const client = useQueryClient();
  const [asking, setAsking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [queued, setQueued] = useState(false);
  const opener = useRef<HTMLButtonElement>(null);
  const cancel = useRef<HTMLButtonElement>(null);
  const headingId = useId();
  const messageId = useId();

  async function reset() {
    if (busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await resetIndex(client);
      closeAtOnce(() => {
        setBusy(false);
        setAsking(false);
        setQueued(true);
      });
      opener.current?.focus();
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
    }
  }

  function close() {
    if (busy) return;
    closeAtOnce(() => setAsking(false));
    opener.current?.focus();
  }

  return (
    <section aria-labelledby="status-recovery">
      <h2 id="status-recovery">{words.recovery}</h2>
      <p className="note">{status.mode === 'import' ? words.resetLead : words.resetStandalone}</p>
      <div className="actions">
        <button
          ref={opener}
          type="button"
          className="destructive"
          onClick={() => {
            setQueued(false);
            setFailure(null);
            setAsking(true);
          }}
        >
          {words.reset}
        </button>
        {/* Always on the page, so that the line is announced when it comes. */}
        <p role="status">
          {queued && (
            <>
              {words.resetQueued} <Link to="/admin/jobs">{copy.admin.jobs.title}</Link>
            </>
          )}
        </p>
      </div>
      {asking && (
        <Modal className="confirm" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={cancel} onCancel={close} onClose={() => closeAtOnce(() => setAsking(false))}>
          <h2 id={headingId} tabIndex={-1}>
            {words.resetTitle}
          </h2>
          <p id={messageId}>{status.mode === 'import' ? words.resetMessage : words.resetMessageStandalone}</p>
          {failure && (
            <p className="error" role="alert">
              {failure}
            </p>
          )}
          <div className="actions">
            <button ref={cancel} type="button" aria-disabled={busy} onClick={close}>
              {copy.admin.cancel}
            </button>
            <button type="button" className="destructive" aria-disabled={busy} onClick={() => void reset()}>
              {words.resetConfirm}
            </button>
          </div>
        </Modal>
      )}
    </section>
  );
}
