// Administration ▸ Backups (PLAN's S20d): when the server backs up its user store, the backups and copies
// it keeps, as the archive's manifest lists them, each its kind, when it was taken, its size, its
// migration and whether the host's folder holds it too; and the newest, to download, S14b's archive. A
// PostgreSQL store's backups are its database service's, which the pane says.
import { useQuery } from '@tanstack/react-query';
import { backupsQuery, statusQuery } from '../api/admin';
import { servedPath } from '../api/base';
import { copy } from '../copy';
import { AdminFrame, ReadFailure, useAdmin } from './AdminPanes';

const words = copy.admin.backups;

export function BackupsScreen() {
  const { allowed } = useAdmin();
  const backups = useQuery({ ...backupsQuery, enabled: allowed });
  const status = useQuery({ ...statusQuery, enabled: allowed });
  const schedule = status.data?.backups;
  let body;
  if (backups.isError && !backups.data) {
    body = <ReadFailure error={backups.error} stale={false} />;
  } else if (!backups.data) {
    body = <p role="status">{copy.admin.loading}</p>;
  } else if (!backups.data.backedUp) {
    body = <p>{words.service}</p>;
  } else {
    const list = backups.data.backups;
    body = (
      <>
        <p className="note">{schedule ? words.lead(schedule.hour, schedule.timeZone) : words.leadPlain}</p>
        {backups.isError && <ReadFailure error={backups.error} stale />}
        {list.some((backup) => backup.kind === 'daily') && (
          <p>
            {/* A link, so that the browser saves the archive as it comes, however large. */}
            <a href={servedPath('/api/v1/admin/backup')} download>
              {words.download}
            </a>
            <br />
            <span className="note">{words.downloadNote}</span>
          </p>
        )}
        {list.length === 0 ? (
          <p>{words.empty}</p>
        ) : (
          // A region a keyboard can scroll, where the table is wider than the pane.
          <div className="admin-table" role="region" aria-label={words.caption} tabIndex={0}>
            <table>
              <caption>{words.caption}</caption>
              <thead>
                <tr>
                  <th scope="col">{words.name}</th>
                  <th scope="col">{words.kind}</th>
                  <th scope="col">{words.taken}</th>
                  <th scope="col">{words.size}</th>
                  <th scope="col">{words.migration}</th>
                  {backups.data.copiedToHost && <th scope="col">{words.onHost}</th>}
                </tr>
              </thead>
              <tbody>
                {list.map((backup) => (
                  <tr key={backup.name}>
                    <th scope="row">{backup.name}</th>
                    <td>{words.kinds[backup.kind]}</td>
                    <td>{copy.admin.time(backup.takenAt)}</td>
                    <td>{copy.admin.bytes(backup.bytes)}</td>
                    <td>{backup.migration ?? ''}</td>
                    {backups.data.copiedToHost && <td>{backup.copied ? copy.admin.yes : copy.admin.no}</td>}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </>
    );
  }
  return <AdminFrame title={words.title}>{body}</AdminFrame>;
}
