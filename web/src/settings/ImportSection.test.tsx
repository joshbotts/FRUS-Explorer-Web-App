import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ImportStatus, ImportTypeCount, ResearchImportReport, ResearchType } from '../api/types';
import { me } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { reportOrder } from './ImportSection';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const version7: ResearchType[] = [
  'ProjectLeadEntry',
  'SavedSearch',
  'WorkingCorpus',
  'CustomVolumeScope',
  'AnnotationReview',
  'SyncedPreferences',
  'PersonClusterOverride',
  'DocumentClassificationOverride',
];

/** A version-6 report: its types counted, the eight 7 added not carried. */
function report(changes: Partial<Record<ResearchType, Partial<ImportTypeCount>>> = {}, fields: Partial<ResearchImportReport> = {}): ResearchImportReport {
  const types = reportOrder.map((type) => ({
    type,
    carried: !version7.includes(type),
    inFile: 0,
    added: 0,
    replaced: 0,
    kept: 0,
    setAside: 0,
    repeated: 0,
    ...changes[type],
  }));
  return {
    formatVersion: 6,
    exportedAt: '2026-10-25T02:38:23.000Z',
    types,
    formattedNotes: 0,
    formattingKept: 0,
    headnoteDrafts: 0,
    summariesWithoutAuthorship: 0,
    inertEntries: 0,
    unlinkedCollections: [],
    searchableDocuments: 0,
    ...fields,
  };
}

function status(state: ImportStatus['state'], extra: Partial<ImportStatus> = {}): ImportStatus {
  return { id: 3, state, formatVersion: 6, report: null, problem: null, ...extra };
}

const file = () => new File(['{"formatVersion": 6}'], 'frus-research-export.json', { type: 'application/json' });

describe('Settings ▸ Data’s import', () => {
  it('sends the chosen export as it is, follows its job, and shows what came in, was replaced or was kept, in the export sheet’s order and words', async () => {
    const done = report(
      {
        ResearchNote: { inFile: 22, added: 16, repeated: 6 },
        UserTag: { inFile: 21, added: 20, kept: 1 },
        DocumentHighlight: { inFile: 8, added: 7, replaced: 1 },
        GeneratedSummary: { inFile: 6592, added: 6592 },
      },
      { headnoteDrafts: 3, inertEntries: 35, unlinkedCollections: [{ id: 'C1', name: 'Every covert action' }, { id: 'C2', name: ' ' }] },
    );
    const statuses = [status('queued'), status('running'), status('succeeded', { report: done })];
    let notesListed = 0;
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/notes': () => ({ total: notesListed++, items: [] }),
      'POST /api/v1/me/import': status('queued'),
      '/api/v1/me/import/3': () => statuses.shift() ?? status('succeeded', { report: done }),
    });
    const user = userEvent.setup();
    renderAt('/settings/data');
    const section = await screen.findByRole('region', { name: 'Import a JSON Export' });
    const button = within(section).getByRole('button', { name: 'Import' });
    expect(button.hasAttribute('disabled')).toBe(true);
    const chosen = file();
    await user.upload(within(section).getByLabelText('Export file'), chosen);
    await user.click(button);

    const post = fetch.mock.calls.find(([, init]) => init?.method === 'POST');
    expect(post?.[0]).toBe('/api/v1/me/import');
    expect(post?.[1]?.body).toBe(chosen);
    expect(post?.[1]?.headers).toEqual({ Accept: 'application/json', 'X-CSRF-Token': 'token-1', 'Content-Type': 'application/json' });
    await within(section).findByText('frus-research-export.json waits for the server’s other work…');
    expect(within(section).getByRole('status').textContent).toBe('frus-research-export.json waits for the server’s other work…');
    expect(within(section).getByLabelText('Export file').hasAttribute('disabled')).toBe(true);
    await within(section).findByText('Importing frus-research-export.json…', undefined, { timeout: 3_000 });
    await within(section).findByText('Imported frus-research-export.json', undefined, { timeout: 3_000 });

    expect(within(section).getByText('A version-6 export, written on October 25, 2026.')).toBeTruthy();
    const table = within(section).getByRole('table', { name: 'What the export held, and what became of it' });
    const rows = within(table)
      .getAllByRole('row')
      .map((row) => [...row.querySelectorAll('th, td')].map((cell) => cell.textContent));
    expect(rows[0]).toEqual(['Records', 'In the file', 'Came in', 'Replaced', 'Kept']);
    expect(rows.slice(1).map((row) => row[0])).toEqual([
      'Research Notes',
      'Tags',
      'Tag Assignments',
      'Highlights',
      'Collections',
      'Collection Entries',
      'Custom Prompts',
      'Projects',
      'Archives Visits',
      'Archives Visit Documents',
      'Archives Visit Targets',
      'Documents Visited',
      'Searches Executed',
      'Collections Exported',
      'Generated Summaries',
    ]);
    expect(rows[1]).toEqual(['Research Notes', '22', '16', '0', '0']);
    expect(rows[4]).toEqual(['Highlights', '8', '7', '1', '0']);
    expect(rows[15]).toEqual(['Generated Summaries', '6,592', '6,592', '0', '0']);
    expect(
      within(section)
        .getAllByRole('listitem')
        .map((item) => item.textContent),
    ).toEqual([
      'Replaced: you had an older copy here. Kept: you had a copy as new or newer.',
      'A version-6 export carries no Saved Searches, Working Corpora, Volume Scopes, Classification Corrections, Person Corrections, Reviewed Changes, Suggested Next Leads, and Synced Settings.',
      '6 of the research notes came twice in the file: each is kept once, the newer copy.',
      '3 summaries are collections’ headnote drafts, which no list of a document’s summaries shows.',
      '35 collection entries have no document. A version-6 export does not say what they were, section headings, note blocks or apparatus blocks, so they are kept as entries this server does not show.',
      'These smart collections keep their link to a saved search this export does not carry:Every covert action: The linked saved search could not be found. It may have been deleted.Untitled Collection: The linked saved search could not be found. It may have been deleted.',
      'Every covert action: The linked saved search could not be found. It may have been deleted.',
      'Untitled Collection: The linked saved search could not be found. It may have been deleted.',
    ]);
    // What it brought is read again: the export's count of notes among it.
    await waitFor(() => expect(notesListed).toBeGreaterThan(1));
    expect(button.hasAttribute('disabled')).toBe(false);
  });

  it('says why a file was refused, keeps nothing of it, and lets another be chosen', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/notes': { total: 0, items: [] },
      'POST /api/v1/me/import': new ProblemAnswer(400, 'UNSUPPORTED_FORMAT_VERSION', 'This export is format version 8, and this server reads versions 1 to 7.'),
    });
    const user = userEvent.setup();
    renderAt('/settings/data');
    const section = await screen.findByRole('region', { name: 'Import a JSON Export' });
    await user.upload(within(section).getByLabelText('Export file'), file());
    await user.click(within(section).getByRole('button', { name: 'Import' }));
    expect((await within(section).findByRole('alert')).textContent).toBe(
      'frus-research-export.json could not be imported. Nothing of it was kept. This export is format version 8, and this server reads versions 1 to 7.',
    );
    expect(within(section).getByRole('button', { name: 'Import' }).hasAttribute('disabled')).toBe(false);
    expect(within(section).queryByRole('table')).toBeNull();
  });

  it('says why a job failed', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/notes': { total: 0, items: [] },
      'POST /api/v1/me/import': status('running'),
      '/api/v1/me/import/3': status('failed', { problem: { code: 'INVALID_EXPORT', detail: 'This export could not be read: notes is missing.' } }),
    });
    const user = userEvent.setup();
    renderAt('/settings/data');
    const section = await screen.findByRole('region', { name: 'Import a JSON Export' });
    await user.upload(within(section).getByLabelText('Export file'), file());
    await user.click(within(section).getByRole('button', { name: 'Import' }));
    expect((await within(section).findByRole('alert', undefined, { timeout: 3_000 })).textContent).toBe(
      'frus-research-export.json could not be imported. Nothing of it was kept. This export could not be read: notes is missing.',
    );
  });

  it('is not offered by a server that keeps no user data', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userData: false } });
    renderAt('/settings/data');
    await screen.findByText('This server keeps no tags or other research data of yours: it is read-only.');
    expect(screen.queryByRole('region', { name: 'Import a JSON Export' })).toBeNull();
  });
});
