// Administration ▸ Jobs (PLAN's S20d): every job the server holds, newest first, each its kind and what it
// works on, its state, its line of progress with how far through it is, who asked and when it was queued,
// started and finished, and why it failed; and Cancel… for one the server still takes a cancel for,
// after a question, whose answer a status line says. Read again every two seconds while a job waits or
// runs.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { type AdminJob, cancelJob, jobsQuery } from '../api/admin';
import { errorMessage } from '../api/client';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { AdminFrame, ReadFailure, useAdmin } from './AdminPanes';

const words = copy.admin.jobs;

/** A job's name in the list: its kind, and what it works on. */
export function jobName(job: AdminJob): string {
  const kind = words.kinds[job.kind] ?? job.kind;
  return job.subject ? `${kind}: ${job.subject}` : kind;
}

export function JobsScreen() {
  const { allowed } = useAdmin();
  const jobs = useQuery({ ...jobsQuery, enabled: allowed });
  let body;
  if (jobs.isError && !jobs.data) {
    body = <ReadFailure error={jobs.error} stale={false} />;
  } else if (!jobs.data) {
    body = <p role="status">{copy.admin.loading}</p>;
  } else if (jobs.data.jobs.length === 0) {
    body = (
      <>
        <p className="note">{words.lead}</p>
        <p>{words.empty}</p>
      </>
    );
  } else {
    body = (
      <>
        <p className="note">{words.lead}</p>
        {jobs.isError && <ReadFailure error={jobs.error} stale />}
        <JobTable jobs={jobs.data.jobs} />
      </>
    );
  }
  return <AdminFrame title={words.title}>{body}</AdminFrame>;
}

function JobTable({ jobs }: { jobs: AdminJob[] }) {
  const [cancelling, setCancelling] = useState<AdminJob | null>(null);
  const [said, setSaid] = useState('');
  const area = useRef<HTMLDivElement>(null);
  return (
    // A region a keyboard can scroll, where the table is wider than the pane.
    <div ref={area} className="admin-table" role="region" aria-label={words.caption} tabIndex={0}>
      {/* Always on the page, so that what a cancel did is announced when it comes. */}
      <p role="status">{said}</p>
      <table>
        <caption>{words.caption}</caption>
        <thead>
          <tr>
            <th scope="col">{words.job}</th>
            <th scope="col">{words.state}</th>
            <th scope="col">{words.progress}</th>
            <th scope="col">{words.askedBy}</th>
            <th scope="col">{words.queued}</th>
            <th scope="col">{words.started}</th>
            <th scope="col">{words.finished}</th>
            <th scope="col">{words.actions}</th>
          </tr>
        </thead>
        <tbody>
          {jobs.map((job) => (
            <tr key={job.id} data-id={job.id}>
              {/* Focusable from a script alone: where focus goes once a cancel has taken the row's button. */}
              <th scope="row" tabIndex={-1} data-job={job.id}>
                {jobName(job)}
              </th>
              <td>
                <span className={`job-state ${job.state}`}>{words.states[job.state]}</span>
                {job.state === 'running' && job.cancelRequestedAt ? <span className="note"> · {words.stopping}</span> : null}
              </td>
              <td>
                {job.progress}
                {job.fraction !== undefined && job.state === 'running' && (
                  <>
                    {' '}
                    <progress max={1} value={job.fraction} aria-label={job.progress ?? words.progress}>
                      {words.percent(job.fraction)}
                    </progress>
                  </>
                )}
                {job.error && <p className="error">{job.error}</p>}
              </td>
              <td>{job.requestedBy ?? words.theServer}</td>
              <td>{copy.admin.time(job.queuedAt)}</td>
              <td>{job.startedAt ? copy.admin.time(job.startedAt) : ''}</td>
              <td>{job.finishedAt ? copy.admin.time(job.finishedAt) : ''}</td>
              <td>
                {job.cancellable && !job.cancelRequestedAt && (
                  <button type="button" data-cancel={job.id} aria-label={words.cancelA11y(jobName(job))} onClick={() => setCancelling(job)}>
                    {words.cancel}
                  </button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {cancelling && (
        <CancelConfirmation
          key={cancelling.id}
          job={cancelling}
          onCancelled={(job) => setSaid(job.state === 'cancelled' ? words.cancelled(jobName(job)) : words.stopAsked(jobName(job)))}
          onClose={(cancelled) => {
            const id = cancelling.id;
            closeAtOnce(() => setCancelling(null));
            // After a cancel the row's button goes, so focus goes to the row; else back to its button.
            const target = cancelled
              ? area.current?.querySelector<HTMLElement>(`th[data-job="${CSS.escape(id)}"]`)
              : area.current?.querySelector<HTMLButtonElement>(`button[data-cancel="${CSS.escape(id)}"]`);
            (target ?? document.querySelector<HTMLElement>('main h1'))?.focus();
          }}
        />
      )}
    </div>
  );
}

/** "Cancel this job?", with Cancel Job and Keep It, which waits for the cancel sent and the list read again. */
function CancelConfirmation({
  job,
  onCancelled,
  onClose,
}: {
  job: AdminJob;
  onCancelled: (job: AdminJob) => void;
  onClose: (cancelled: boolean) => void;
}) {
  const client = useQueryClient();
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const keep = useRef<HTMLButtonElement>(null);
  const headingId = useId();
  const messageId = useId();

  async function cancel() {
    if (busy) return;
    setBusy(true);
    setFailure(null);
    try {
      const answered = await cancelJob(client, job.id);
      setBusy(false);
      onCancelled(answered ?? job);
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
        {words.cancelTitle}
      </h2>
      <p id={messageId}>
        {jobName(job)}. {words.cancelMessage}
      </p>
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
          {words.keepRunning}
        </button>
        <button type="button" className="destructive" aria-disabled={busy} onClick={() => void cancel()}>
          {words.cancelConfirm}
        </button>
      </div>
    </Modal>
  );
}
