// Settings ▸ Data (PLAN's S15d), the web's own pane, laid out as the app's export sheet in Data &
// Recovery is: from S16d its Contents, Include AI-Generated Summaries and Export as JSON
// (ExportSection); then the app's Markdown export of every research note, one file each with a
// citation and a link back to its document, here as one ZIP that the browser saves, since a page
// cannot share loose files as the app does. Its count is the server's list of the user's notes, read
// as the pane opens, as Contents' counts are. From S16c it also imports a Mac JSON export and shows
// its report (ImportSection). From S17f, after the notes, the app's method appendix, Export Query Log as
// a Method Appendix, the kit's Markdown table and CSV of every search the trail holds, each its own
// link, since a browser saves one file at a time; or the app's line while no search is recorded.
import { useQuery } from '@tanstack/react-query';
import { errorMessage } from '../api/client';
import { servedPath } from '../api/base';
import { appendixPath } from '../api/research';
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
        <MethodAppendix searches={contents.data?.types.find((type) => type.type === 'SearchHistoryEntry')?.count} />
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

/** The method appendix's two files, once the trail holds a search, as the app's row offers them. */
function MethodAppendix({ searches }: { searches: number | undefined }) {
  if (searches === undefined) return null;
  return (
    <section className="method-appendix" aria-label={copy.dataSettings.appendixAction}>
      {searches === 0 ? (
        <p>{copy.dataSettings.appendixEmpty}</p>
      ) : (
        <>
          <p>{copy.dataSettings.appendixAction}</p>
          <ul className="downloads">
            <li>
              <a className="button" href={servedPath(appendixPath('markdown'))} download="frus-query-log.md">
                {copy.dataSettings.appendixMarkdown}
              </a>
            </li>
            <li>
              <a className="button" href={servedPath(appendixPath('csv'))} download="frus-query-log.csv">
                {copy.dataSettings.appendixCSV}
              </a>
            </li>
          </ul>
        </>
      )}
      <p className="note">{copy.dataSettings.appendixFooter}</p>
    </section>
  );
}
