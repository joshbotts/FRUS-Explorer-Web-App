// Settings ▸ Data's import of a Mac JSON export (PLAN's S16c), the web's own, since the app imports
// none: the file chosen is sent as it is to POST /api/v1/me/import, whose job the pane follows until
// it is done. Its report says, for each kind of record, how many the file held and how many came in,
// replaced an older copy or left a copy as new or newer as it was, in the order and the words of the
// app's export sheet; then what the import made of what an older file does not say.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useId, useState } from 'react';
import { errorMessage } from '../api/client';
import type { ImportTypeCount, ResearchImportReport, ResearchType } from '../api/types';
import { importStatusQuery, researchImported, startImport } from '../api/userData';
import { copy } from '../copy';

/**
 * The export sheet's Contents, in its order, with the parts it counts in one row beside it: tags and
 * their assignments, a collection's entries, a visit's documents and targets; and the summaries its
 * switch adds, last.
 */
export const reportOrder: ResearchType[] = [
  'ResearchNote',
  'UserTag',
  'DocumentTagAssignment',
  'DocumentHighlight',
  'Collection',
  'CollectionEntry',
  'SummarizationPrompt',
  'Project',
  'ArchiveVisitPlan',
  'ArchiveVisitDocument',
  'ArchiveVisitTarget',
  'SavedSearch',
  'WorkingCorpus',
  'CustomVolumeScope',
  'DocumentClassificationOverride',
  'PersonClusterOverride',
  'AnnotationReview',
  'ProjectLeadEntry',
  'SyncedPreferences',
  'ReadingHistoryEntry',
  'SearchHistoryEntry',
  'ExportHistoryEntry',
  'GeneratedSummary',
];

const words = copy.dataSettings;
const number = (value: number) => value.toLocaleString('en-US');

export function ImportSection() {
  const client = useQueryClient();
  const inputId = useId();
  const [file, setFile] = useState<File | null>(null);
  const [started, setStarted] = useState<{ id: number; name: string } | null>(null);
  const [sending, setSending] = useState<string | null>(null);
  const [refusal, setRefusal] = useState<{ name: string; detail: string } | null>(null);
  const status = useQuery({ ...importStatusQuery(started?.id ?? 0), enabled: started !== null });
  const state = started ? status.data?.state : undefined;
  const running = sending !== null || state === 'queued' || state === 'running' || (started !== null && status.isPending);

  // What an import brought is in every list of the user's.
  useEffect(() => {
    if (state === 'succeeded') researchImported(client);
  }, [state, client]);

  async function start() {
    if (!file) return;
    setRefusal(null);
    setStarted(null);
    setSending(file.name);
    try {
      const begun = await startImport(client, file);
      client.setQueryData(importStatusQuery(begun.id).queryKey, begun);
      setStarted({ id: begun.id, name: file.name });
    } catch (error) {
      setRefusal({ name: file.name, detail: errorMessage(error) });
    } finally {
      setSending(null);
    }
  }

  let line: string | null = null;
  if (sending !== null) line = words.importRunning(sending);
  else if (started && state === 'queued') line = words.importQueued(started.name);
  else if (started && (state === 'running' || status.isPending)) line = words.importRunning(started.name);
  else if (started && state === 'succeeded') line = words.importDone(started.name);
  const failure =
    refusal ??
    (started && state === 'failed' ? { name: started.name, detail: status.data?.problem?.detail ?? '' } : null) ??
    (started && status.isError ? { name: started.name, detail: errorMessage(status.error) } : null);

  return (
    <section className="import" aria-labelledby={`${inputId}-title`}>
      <h2 id={`${inputId}-title`}>{words.importTitle}</h2>
      <p>{words.importLead}</p>
      <div className="import-controls">
        <label htmlFor={inputId}>{words.importFile}</label>
        <input
          id={inputId}
          type="file"
          accept="application/json,.json"
          disabled={running}
          onChange={(event) => setFile(event.currentTarget.files?.[0] ?? null)}
        />
        <button type="button" disabled={!file || running} onClick={() => void start()}>
          {words.importAction}
        </button>
      </div>
      <p role="status">{line}</p>
      {failure && (
        <p className="error" role="alert">
          {words.importFailed(failure.name)} {failure.detail}
        </p>
      )}
      {started && state === 'succeeded' && status.data?.report && <Report report={status.data.report} />}
    </section>
  );
}

/** The date an export was written, as the app's lists write a day. */
function day(iso: string): string {
  return new Intl.DateTimeFormat('en-US', { dateStyle: 'long', timeZone: 'UTC' }).format(new Date(iso));
}

function Report({ report }: { report: ResearchImportReport }) {
  const byType = new Map(report.types.map((count) => [count.type, count]));
  const counts = reportOrder.map((type) => byType.get(type)).filter((count): count is ImportTypeCount => count !== undefined);
  const carried = counts.filter((count) => count.carried);
  const missing = counts.filter((count) => !count.carried).map((count) => words.types[count.type]);
  const settingsSetAside = byType.get('SyncedPreferences')?.setAside ?? 0;
  const correctionsSetAside = (byType.get('PersonClusterOverride')?.setAside ?? 0) + (byType.get('DocumentClassificationOverride')?.setAside ?? 0);
  const list = new Intl.ListFormat('en-US', { type: 'conjunction' });
  return (
    <div className="import-report">
      <p>{words.importWritten(report.formatVersion, day(report.exportedAt))}</p>
      <table>
        <caption>{words.reportCaption}</caption>
        <thead>
          <tr>
            <th scope="col">{words.reportType}</th>
            <th scope="col">{words.reportInFile}</th>
            <th scope="col">{words.reportAdded}</th>
            <th scope="col">{words.reportReplaced}</th>
            <th scope="col">{words.reportKept}</th>
          </tr>
        </thead>
        <tbody>
          {carried.map((count) => (
            <tr key={count.type}>
              <th scope="row">{words.types[count.type]}</th>
              <td>{number(count.inFile)}</td>
              <td>{number(count.added)}</td>
              <td>{number(count.replaced)}</td>
              <td>{number(count.kept)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <ul className="import-notes">
        <li>{words.reportKeptNote}</li>
        {missing.length > 0 && <li>{words.notCarried(report.formatVersion, list.format(missing))}</li>}
        {carried
          .filter((count) => count.repeated > 0)
          .map((count) => (
            <li key={`repeated-${count.type}`}>{words.repeated(count.repeated, words.types[count.type])}</li>
          ))}
        {settingsSetAside > 0 && <li>{words.setAsideSettings(settingsSetAside)}</li>}
        {correctionsSetAside > 0 && <li>{words.setAsideCorrections(correctionsSetAside)}</li>}
        {report.formattingKept > 0 && <li>{words.formattingKept(report.formattingKept)}</li>}
        {report.headnoteDrafts > 0 && <li>{words.headnoteDrafts(report.headnoteDrafts)}</li>}
        {report.summariesWithoutAuthorship > 0 && <li>{words.withoutAuthorship(report.summariesWithoutAuthorship)}</li>}
        {report.inertEntries > 0 && <li>{words.inertEntries(report.inertEntries)}</li>}
        {report.unlinkedCollections.length > 0 && (
          <li>
            {words.unlinkedLead}
            <ul>
              {report.unlinkedCollections.map((collection) => (
                <li key={collection.id}>
                  {collection.name.trim() || words.untitledCollection}: {words.missingSearch}
                </li>
              ))}
            </ul>
          </li>
        )}
      </ul>
    </div>
  );
}
