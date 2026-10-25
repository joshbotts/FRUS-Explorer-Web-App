// Settings ▸ Data's export (PLAN's S16d), as the app's export sheet lays it out: Contents, what an
// export carries of each kind of record, in its order and its words; Include AI-Generated Summaries,
// off by default, as the app's switch; and Export as JSON, which saves the server's file, the Mac's
// export with the web's one key more. The counts come from one read of the server's, as the sheet
// counts from the read that writes its file; the file is written when it is asked for.
import type { UseQueryResult } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { servedPath } from '../api/base';
import { errorMessage } from '../api/client';
import type { ExportContents, ResearchType } from '../api/types';
import { exportPath } from '../api/userData';
import { copy } from '../copy';

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

const number = (value: number) => value.toLocaleString('en-US');

export function ExportSection({ contents }: { contents: UseQueryResult<ExportContents> }) {
  const id = useId();
  const [includeSummaries, setIncludeSummaries] = useState(false);
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
                  <td>{number(row.types.reduce((sum, type) => sum + countOf(contents.data, type), 0))}</td>
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
      <p>
        {/* The server names the file, frus-research-export.json, and the browser saves it. */}
        <a className="button" href={servedPath(exportPath(includeSummaries))} download>
          {words.exportJSON}
        </a>
      </p>
      <p className="note">{words.jsonFooter}</p>
    </>
  );
}
