// Administration ▸ Corrections (PLAN's S21g), the web's own: the log of the corrections curators made to the index
// everyone shares, newest first, the audit SPEC's risk of shared corrections asks for. Each row says when, who, what,
// a classification's document by its head or its id and a person correction's records by their names, and whether
// the index holds it yet or it waits, for a Standalone server's job or an Import server's next export.
import { useQuery } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { type CorrectionLogEntry, correctionLogQuery } from '../api/people';
import { copy } from '../copy';
import { AdminFrame, ReadFailure, useAdmin } from './AdminPanes';

const words = copy.admin.corrections;

/** What an entry did, in the pane's words. */
export function correctionLine(entry: CorrectionLogEntry): string {
  if (entry.correction === 'classification') {
    const document = entry.title || `${entry.volumeId ?? ''} ${entry.documentId ?? ''}`.trim();
    if (entry.action === 'undone') return words.restored(document);
    return entry.isEditorialNote ? words.asNote(document) : words.asDocument(document);
  }
  const a = entry.nameA ?? '';
  const b = entry.nameB ?? '';
  if (entry.kind === 'merge') return entry.action === 'made' ? words.merged(a, b) : words.mergeUndone(a, b);
  return entry.action === 'made' ? words.separated(a) : words.separationUndone(a);
}

/** When it was made, to the minute, in the browser's time zone. */
function when(text: string): string {
  const date = new Date(text);
  return Number.isNaN(date.getTime())
    ? text
    : date.toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' });
}

export function CorrectionsScreen() {
  const { allowed } = useAdmin();
  const log = useQuery({ ...correctionLogQuery, enabled: allowed });
  let body;
  if (log.isError && !log.data) {
    body = <ReadFailure error={log.error} stale={false} />;
  } else if (!log.data) {
    body = <p role="status">{copy.admin.loading}</p>;
  } else if (log.data.entries.length === 0) {
    body = (
      <>
        <p className="note">{words.lead}</p>
        <p>{words.empty}</p>
      </>
    );
  } else {
    const waiting = log.data.mode === 'import' ? words.waitingExport : words.waitingJob;
    body = (
      <>
        <p className="note">{words.lead}</p>
        {/* A region a keyboard can scroll, where the table is wider than the pane. */}
        <div className="admin-table" role="region" aria-label={words.caption} tabIndex={0}>
          <table>
            <caption>{words.caption}</caption>
            <thead>
              <tr>
                <th scope="col">{words.when}</th>
                <th scope="col">{words.who}</th>
                <th scope="col">{words.what}</th>
                <th scope="col">{words.state}</th>
              </tr>
            </thead>
            <tbody>
              {log.data.entries.map((entry) => (
                <tr key={entry.id}>
                  <td>{when(entry.madeAt)}</td>
                  <td>{entry.userName}</td>
                  <td>
                    {entry.correction === 'classification' && entry.volumeId && entry.documentId ? (
                      <Link to="/doc/$volumeId/$documentId" params={{ volumeId: entry.volumeId, documentId: entry.documentId }}>
                        {correctionLine(entry)}
                      </Link>
                    ) : (
                      correctionLine(entry)
                    )}
                  </td>
                  <td>{entry.appliedAt ? words.applied : waiting}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </>
    );
  }
  return <AdminFrame title={words.title}>{body}</AdminFrame>;
}
