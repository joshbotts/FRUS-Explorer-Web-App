// Settings ▸ Data's export (PLAN's S16d), as the app's export sheet lays it out: Contents, what an
// export carries of each kind of record, in its order and its words; Include AI-Generated Summaries,
// off by default, as the app's switch; and Export as JSON, which fetches the server's file, the Mac's
// export with the web's one key more, and saves it, saying while it is prepared and, as the app's row
// does, why it could not be. The counts come from one read of the server's, as the sheet counts from
// the read that writes its file; the file is written when it is asked for.
import { useQuery, type UseQueryResult } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { errorMessage } from '../api/client';
import type { ExportContents, ResearchType } from '../api/types';
import { fetchExport, projectsQuery } from '../api/userData';
import { copy } from '../copy';
import { saveFile } from '../shell/saveFile';

const words = copy.dataSettings;

/** The export sheet's Contents, in its order: each row the types it counts and, where it counts two, its own words. */
export const contentsRows: { types: [ResearchType, ...ResearchType[]]; label?: string }[] = [
  { types: ['ResearchNote'] },
  { types: ['UserTag', 'DocumentTagAssignment'], label: words.tagsAndAssignments },
  { types: ['DocumentHighlight'] },
  { types: ['Collection'] },
  { types: ['SummarizationPrompt'] },
  { types: ['Project'] },
  { types: ['ArchiveVisitPlan'] },
  { types: ['SavedSearch'] },
  { types: ['WorkingCorpus'] },
  { types: ['CustomVolumeScope'] },
  { types: ['DocumentClassificationOverride'] },
  { types: ['PersonClusterOverride'] },
  { types: ['AnnotationReview'] },
  { types: ['ProjectLeadEntry'] },
  { types: ['SyncedPreferences'] },
  { types: ['ReadingHistoryEntry'] },
  { types: ['SearchHistoryEntry'] },
  { types: ['ExportHistoryEntry'] },
];

/** How many records of `type` an export carries. */
export function countOf(contents: ExportContents, type: ResearchType): number {
  return contents.types.find((count) => count.type === type)?.count ?? 0;
}

export function ExportSection({ contents }: { contents: UseQueryResult<ExportContents> }) {
  const id = useId();
  const [includeSummaries, setIncludeSummaries] = useState(false);
  // Asked once the server has said it keeps user data, by answering for the export's Contents.
  const projects = useQuery({ ...projectsQuery, enabled: contents.data !== undefined });
  const [preparing, setPreparing] = useState(false);
  const [problem, setProblem] = useState<string | null>(null);

  async function exportJSON() {
    setPreparing(true);
    setProblem(null);
    try {
      // Under the project the user works in (S17f), which the file's header names.
      const file = await fetchExport(includeSummaries, projects.data?.activeProjectId);
      saveFile(file.blob, file.name);
    } catch (error) {
      setProblem(errorMessage(error));
    } finally {
      setPreparing(false);
    }
  }

  return (
    <>
      <section className="export-contents" aria-labelledby={`${id}-contents`}>
        <h2 id={`${id}-contents`}>{words.contents}</h2>
        {contents.isError ? (
          <p className="error" role="alert">
            {errorMessage(contents.error)}
          </p>
        ) : !contents.data ? (
          <p role="status">{words.preparing}</p>
        ) : (
          <table aria-labelledby={`${id}-contents`}>
            <tbody>
              {contentsRows.map((row) => (
                <tr key={row.types.join()}>
                  <th scope="row">{row.label ?? words.types[row.types[0]]}</th>
                  {/* As the app's sheet writes each count, an interpolated number, which groups no digits. */}
                  <td>{String(row.types.reduce((sum, type) => sum + countOf(contents.data, type), 0))}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
      <p>
        <label>
          <input type="checkbox" checked={includeSummaries} onChange={(event) => setIncludeSummaries(event.target.checked)} />{' '}
          {words.includeSummaries}
        </label>
      </p>
      {contents.data && <p className="note">{words.includeSummariesFooter(countOf(contents.data, 'GeneratedSummary'))}</p>}
      <p className="export-json">
        <button type="button" disabled={preparing} onClick={() => void exportJSON()}>
          {words.exportJSON}
        </button>{' '}
        <span role="status">{preparing ? words.preparing : ''}</span>
      </p>
      {problem && (
        <p className="error" role="alert">
          {words.jsonError(problem)}
        </p>
      )}
      <p className="note">{words.jsonFooter}</p>
    </>
  );
}
