// The review sheet (PLAN's S21f), opened from Research's Changed by an update: its sections in the app's words,
// the lines the server gives, Move Here and Confirm sent with the version the sheet judged by, Mark Reviewed, and
// Remove… asking first; by keyboard, focus kept where the user acts.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { ResearchDocument, ResearchPage } from '../api/researchPage';
import type { DocumentChange, DocumentReview } from '../api/reviews';
import { resetPreferences } from '../settings/preferences';
import { me } from '../test/notes';
import { ready, renderAt, stubServer } from '../test/renderRoute';

const page: ResearchPage = { allAnnotated: 1, hasNotes: 1, notes: 1, collections: [], tags: [], highlightColors: [], updated: 1 };

const row: ResearchDocument = {
  volumeId: 'frus1894Nicaragua',
  documentId: 'd2',
  title: 'No. 2. Mr. Gresham to Mr. Baker',
  volumeTitle: 'Nicaragua',
  noteCount: 1,
  summaryCount: 0,
  isInVisitPlan: false,
  highlights: [],
  highlightCount: 1,
  tags: [],
  collections: [],
  change: { kind: 'body', line: 'Text changed in an update — highlight positions may have moved' },
  reviewable: true,
};

const change: DocumentChange = {
  volumeId: 'frus1894Nicaragua',
  documentId: 'd2',
  line: 'The text of this document changed in a volume update. Some highlights may be misaligned.',
  changeKind: 'body',
  changedAt: '2026-11-13T12:00:00Z',
  highlightsStale: true,
  vanished: false,
  canMarkReviewed: true,
  foundInTEI: false,
};

const review: DocumentReview = {
  change,
  currentVersion: '00000000000000b2',
  changeLine: change.line!,
  highlights: [
    {
      id: 'H1',
      colorTag: 'yellow',
      selectedText: 'touching an invasion of the troops of Honduras at Cape Gracias',
      startOffset: 300,
      endOffset: 363,
      status: 'stale',
      statusLine: 'Made against an earlier version of the text — its position may have moved.',
      search: 'moved',
      searchLine: 'Found once, at a new position in the corrected text.',
      context: {
        before: 'from our consular agent at Blueflelds, Nicaragua, ',
        found: 'touching an invasion of the troops of Honduras at Cape Gracias',
        after: '; also a copy of a letter',
        start: 302,
        end: 365,
      },
      canMove: true,
      canConfirm: true,
    },
  ],
  excerpts: [
    {
      id: 'E1',
      collectionId: 'C1',
      collectionName: 'Briefing book',
      text: 'the troops of Honduras',
      finding: 'These words are still in the document as it reads now.',
      capture: 'Captured from an earlier version of the text.',
      warning: false,
    },
  ],
  others: { notes: [{ id: 'N1', title: 'Gresham’s telegram' }], tagCount: 0, collectionCount: 0, summaryCount: 0, inVisitPlan: false },
};

const documentPath = '/api/v1/me/volumes/frus1894Nicaragua/documents/d2';

function server(answers: Record<string, unknown> = {}) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/research': page,
    '/api/v1/me/research/documents': { group: 'updated', total: 1, items: [row] },
    [`${documentPath}/review`]: review,
    [`${documentPath}/change`]: change,
    ...answers,
  });
}

/** What the browser sent, by method and path, with its body. */
const sent = (fetch: ReturnType<typeof stubServer>) =>
  fetch.mock.calls
    .filter(([, init]) => init?.method && init.method !== 'GET')
    .map(([input, init]) => `${init!.method} ${new URL(String(input), 'http://localhost').pathname} ${init!.body ?? ''}`);

beforeEach(() => resetPreferences());
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('the review sheet', () => {
  it('opens from a row’s Review Changes…, with the app’s sections and the server’s lines', async () => {
    server();
    renderAt('/research?group=updated');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: `Review Changes…: ${row.title}` }));
    const sheet = await screen.findByRole('dialog', { name: row.title });
    expect(await within(sheet).findByRole('heading', { level: 3, name: 'What Changed' })).toBeTruthy();
    expect(within(sheet).getByText(change.line!)).toBeTruthy();
    expect(within(sheet).getAllByRole('heading', { level: 3 }).map((heading) => heading.textContent)).toEqual([
      'What Changed',
      'Highlights',
      'Quotations',
      'Other Annotations',
    ]);
    expect(within(sheet).getByText('Found once, at a new position in the corrected text.')).toBeTruthy();
    expect(within(sheet).getByText('These words are still in the document as it reads now.')).toBeTruthy();
    expect(within(sheet).getByText('Captured from an earlier version of the text.')).toBeTruthy();
    expect(within(sheet).getByText('1 notes')).toBeTruthy();
    expect(within(sheet).getByRole('button', { name: 'Gresham’s telegram' })).toBeTruthy();
    expect(within(sheet).getByRole('button', { name: 'Edit Tags…' })).toBeTruthy();
    // The found words in what surrounds them.
    expect(within(sheet).getByText(review.highlights[0]!.context!.found).tagName).toBe('STRONG');
  });

  it('moves a highlight by keyboard with the version it judged by, and marks the document reviewed', async () => {
    const fetch = server({
      [`POST /api/v1/me/highlights/H1/move`]: { ...review.highlights[0]!, startOffset: 302, endOffset: 365, renderingVersion: '00000000000000b2' },
      [`POST ${documentPath}/review`]: { ...change, line: undefined, changeKind: undefined, canMarkReviewed: false, highlightsStale: false },
    });
    renderAt('/research?group=updated');
    const user = userEvent.setup();
    const open = await screen.findByRole('button', { name: `Review Changes…: ${row.title}` });
    open.focus();
    await user.keyboard('{Enter}');
    const sheet = await screen.findByRole('dialog', { name: row.title });
    const move = await within(sheet).findByRole('button', { name: /^Move Here: touching an invasion/ });
    move.focus();
    await user.keyboard('{Enter}');
    await waitFor(() => expect(sent(fetch)).toContain('POST /api/v1/me/highlights/H1/move {"renderingVersion":"00000000000000b2"}'));
    expect(await within(sheet).findByText('The highlight is moved to the corrected text.')).toBeTruthy();
    const mark = within(sheet).getByRole('button', { name: 'Mark Reviewed' });
    mark.focus();
    await user.keyboard('{Enter}');
    await waitFor(() => expect(sent(fetch)).toContain(`POST ${documentPath}/review `));
    expect(await within(sheet).findByText('The document is marked reviewed.')).toBeTruthy();
    // Done closes the sheet, and focus goes back to the row's Review Changes….
    await user.click(within(sheet).getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: row.title })).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('button', { name: `Review Changes…: ${row.title}` })));
  });

  it('stays open when Mark Reviewed takes the row out of Changed by an update, and sends focus to the list’s heading once done', async () => {
    let reviewedYet = false;
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/research': () => ({ ...page, updated: reviewedYet ? 0 : 1 }),
      '/api/v1/me/research/documents': () => ({ group: 'updated', total: reviewedYet ? 0 : 1, items: reviewedYet ? [] : [row] }),
      [`${documentPath}/review`]: () => (reviewedYet ? { ...review, change: { ...change, canMarkReviewed: false } } : review),
      [`POST ${documentPath}/review`]: () => {
        reviewedYet = true;
        return { ...change, line: undefined, changeKind: undefined, canMarkReviewed: false };
      },
    });
    renderAt('/research?group=updated');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: `Review Changes…: ${row.title}` }));
    const sheet = await screen.findByRole('dialog', { name: row.title });
    await user.click(await within(sheet).findByRole('button', { name: 'Mark Reviewed' }));
    expect(await within(sheet).findByText('The document is marked reviewed.')).toBeTruthy();
    // The list has been read again, without the row, and the sheet is still open.
    await waitFor(() => expect(screen.queryByRole('button', { name: `Review Changes…: ${row.title}` })).toBeNull());
    expect(screen.getByRole('dialog', { name: row.title })).toBeTruthy();
    await user.click(within(sheet).getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('heading', { level: 2, name: 'Changed by an update' })));
  });

  it('asks before Remove… removes a highlight', async () => {
    const fetch = server({ 'DELETE /api/v1/me/highlights/H1': null });
    renderAt('/research?group=updated');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: `Review Changes…: ${row.title}` }));
    const sheet = await screen.findByRole('dialog', { name: row.title });
    await user.click(await within(sheet).findByRole('button', { name: /^Remove…: touching/ }));
    const question = await screen.findByRole('alertdialog', { name: 'Remove Highlight' });
    expect(sent(fetch)).toEqual([]);
    await user.click(within(question).getByRole('button', { name: 'Remove' }));
    await waitFor(() => expect(sent(fetch)).toContain('DELETE /api/v1/me/highlights/H1 '));
    expect(await within(sheet).findByText('The highlight is removed.')).toBeTruthy();
  });
});
