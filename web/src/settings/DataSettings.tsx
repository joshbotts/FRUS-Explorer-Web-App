// Settings ▸ Data (PLAN's S15d), the web's own pane, laid out as the app's export sheet in Data &
// Recovery is: from S16d its Contents, Include AI-Generated Summaries and Export as JSON
// (ExportSection); then the app's Markdown export of every research note, one file each with a
// citation and a link back to its document, here as one ZIP that the browser saves, since a page
// cannot share loose files as the app does. Its count is the server's list of the user's notes, read
// as the pane opens, as Contents' counts are. From S16c it also imports a Mac JSON export and shows
// its report (ImportSection).
import { useQuery } from '@tanstack/react-query';
import { errorMessage } from '../api/client';
import { servedPath } from '../api/base';
import { exportContentsQuery, meQuery, notesExportPath, notesQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { ExportSection } from './ExportSection';
import { ImportSection } from './ImportSection';
import { SettingsPanes } from './SettingsPanes';

export function DataSettingsScreen() {
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const contents = useQuery({ ...exportContentsQuery, enabled: keepsUserData });
  const notes = useQuery({ ...notesQuery, staleTime: 0, enabled: keepsUserData });
  useDocumentTitle(copy.dataSettings.title);
  useHeadingReady(!me.isPending);

  let body;
  if (me.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(me.error)}
      </p>
    );
  } else if (me.data && !keepsUserData) {
    body = <p>{copy.settings.userDataOff}</p>;
  } else {
    const total = notes.data?.total;
    body = (
      <>
        <ExportSection contents={contents} />
        {notes.isError ? (
          <p className="error" role="alert">
            {errorMessage(notes.error)}
          </p>
        ) : total === undefined ? (
          <p role="status">{copy.dataSettings.preparing}</p>
        ) : total === 0 ? (
          <p>{copy.dataSettings.empty}</p>
        ) : (
          <p>
            {/* The server names the file, FRUSResearchNotes.zip, and the browser saves it. */}
            <a className="button" href={servedPath(notesExportPath)} download>
              {copy.dataSettings.exportMarkdown(total)}
            </a>
          </p>
        )}
        <p className="note">{copy.dataSettings.footer}</p>
        {keepsUserData && <ImportSection />}
      </>
    );
  }

  return (
    <div className="settings">
      <SettingsPanes />
      <section className="settings-pane">
        <h1 tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
          {copy.dataSettings.title}
        </h1>
        {body}
      </section>
    </div>
  );
}
