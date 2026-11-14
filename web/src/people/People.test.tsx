import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { PeopleList, PersonCorrections, PersonSheet } from '../api/people';
import type { Me } from '../api/types';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { correctionTitle, displaySections, folded, mergeQuestion, pickerRows, rowLabel } from './peopleRules';

const curator: Me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't1' };
const reader: Me = { userId: 'bob', displayName: 'bob', auth: 'header', roles: ['reader'], userData: true, csrfToken: 't2' };

const list: PeopleList = {
  version: 'v1',
  count: 3,
  sections: [
    {
      letter: 'A',
      people: [
        { rollupId: 1, name: 'Adenauer, Conrad', subtitle: 'Chancellor of the Federal Republic of Germany · 1961–1963', mentionCount: 12, volumeCount: 1, authorityId: 7, possibleDuplicate: false },
        { rollupId: 2, name: 'Adzhubei, Aleksei I.', subtitle: 'Editor in Chief of Izvestia', mentionCount: 3, volumeCount: 1, authorityId: 9, possibleDuplicate: true },
      ],
    },
    { letter: 'K', people: [{ rollupId: 3, name: 'Khrushchev, Nikita S.', subtitle: null, mentionCount: 0, volumeCount: 2, authorityId: null, possibleDuplicate: false }] },
  ],
};

const adenauer: PersonSheet = {
  version: 'v1',
  rollupId: 1,
  name: 'Adenauer, Conrad',
  description: 'Chancellor of the Federal Republic of Germany until October 1963',
  lifespan: '1876–1967',
  registerRole: null,
  reconciled: true,
  authorityId: 7,
  mentionCount: 12,
  mentions: '12 documents',
  active: '1961–1963',
  viafURL: 'https://viaf.org/viaf/12345',
  wikidataURL: 'https://www.wikidata.org/wiki/Q2492',
  candidates: [{ rollupId: 2, name: 'Adzhubei, Aleksei I.', reason: 'Same surname, overlapping years' }],
  records: [
    { volumeId: 'frus1961-63v06', ref: 'p_AK3', name: 'Adenauer, Conrad' },
    { volumeId: 'frus1969-76ve09p1', ref: 'p_AK1', name: 'Adenauer, Konrad' },
  ],
};

function server(me: Me, answers: Record<string, unknown> = {}) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/people': list,
    '/api/v1/people/1': adenauer,
    '/api/v1/annotations/people': { reach: { layer: 'people', carrying: 288, total: 553, bands: [] }, eras: [], drills: [] },
    '/api/v1/me/people/corrections': { items: [], mode: 'standalone' } satisfies PersonCorrections,
    ...answers,
  });
}

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('the People screen', () => {
  it('lists the people by letter, each a stop with its line, its count and a suggestion, filtered as one types', async () => {
    server(reader);
    renderAt('/people');
    expect(await screen.findByRole('heading', { level: 1, name: 'People' })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'People' }).getAttribute('aria-current')).toBe('page');
    expect(await screen.findByRole('heading', { level: 2, name: 'A' })).toBeTruthy();
    const row = screen.getByRole('button', { name: 'Adzhubei, Aleksei I., Editor in Chief of Izvestia, 3 mentions, Possible duplicate' });
    expect(row.getAttribute('title')).toBe('May be the same as another person — open to review');
    expect(screen.getByText(/only those volumes' people appear here/).textContent).toContain('288 of 553 volumes');
    await userEvent.type(screen.getByRole('searchbox', { name: 'Search people' }), 'khru');
    expect(screen.queryByRole('heading', { level: 2, name: 'A' })).toBeNull();
    expect(screen.getByRole('button', { name: /^Khrushchev, Nikita S\./ })).toBeTruthy();
    await userEvent.type(screen.getByRole('searchbox', { name: 'Search people' }), 'zz');
    expect(screen.getByRole('heading', { name: 'No Results for “khruzz”' })).toBeTruthy();
    // A reader corrects nothing.
    expect(screen.queryByRole('button', { name: 'Corrections' })).toBeNull();
  });

  it('opens a person’s sheet, the app’s, with no correction for a reader', async () => {
    server(reader);
    renderAt('/people');
    await userEvent.click(await screen.findByRole('button', { name: /^Adenauer, Conrad/ }));
    const sheet = await screen.findByRole('dialog', { name: 'Adenauer, Conrad' });
    expect(await within(sheet).findByText('Chancellor of the Federal Republic of Germany until October 1963')).toBeTruthy();
    expect(within(sheet).getByText('1876–1967')).toBeTruthy();
    expect(within(sheet).getByText('12 documents')).toBeTruthy();
    expect(within(sheet).getByText('1961–1963')).toBeTruthy();
    expect(within(sheet).getByText('Reconciled identity')).toBeTruthy();
    const mentions = within(sheet).getByRole('link', { name: 'Find all mentions' });
    expect(mentions.getAttribute('href')).toContain('personRollupId=1');
    expect(within(sheet).getByRole('link', { name: 'View on VIAF' }).getAttribute('href')).toBe('https://viaf.org/viaf/12345');
    expect(within(sheet).getByRole('heading', { name: 'Possibly the Same Person' })).toBeTruthy();
    expect(within(sheet).getByRole('heading', { name: 'Records in This Identity (2)' })).toBeTruthy();
    expect(within(sheet).queryByRole('button', { name: 'Merge with another person…' })).toBeNull();
    expect(within(sheet).queryByRole('button', { name: /^Separate/ })).toBeNull();
    expect(within(sheet).queryByRole('button', { name: /^Merge Adzhubei/ })).toBeNull();
  });

  it('merges two people by keyboard for a curator: the picker, the question, and the line the screen says', async () => {
    const fetch = server(curator, {
      'POST /api/v1/me/people/merges': { state: 'applied', entryId: 'E1' },
    });
    renderAt('/people');
    const row = await screen.findByRole('button', { name: /^Adenauer, Conrad/ });
    row.focus();
    await userEvent.keyboard('{Enter}');
    const sheet = await screen.findByRole('dialog', { name: 'Adenauer, Conrad' });
    const merge = await within(sheet).findByRole('button', { name: 'Merge with another person…' });
    merge.focus();
    await userEvent.keyboard('{Enter}');
    const picker = await screen.findByRole('dialog', { name: 'Merge With…' });
    const field = within(picker).getByRole('searchbox', { name: 'Search people' });
    expect(document.activeElement).toBe(field);
    expect(within(picker).queryByRole('button', { name: /^Adenauer/ })).toBeNull();
    await userEvent.keyboard('adzh');
    await userEvent.tab();
    expect(document.activeElement?.getAttribute('aria-label')).toBe('Adzhubei, Aleksei I., Editor in Chief of Izvestia');
    await userEvent.keyboard('{Enter}');
    const question = await screen.findByRole('alertdialog', { name: 'Merge these identities?' });
    expect(question.textContent).toContain('“Adzhubei, Aleksei I.” and “Adenauer, Conrad” will become a single identity.');
    expect(question.textContent).toContain('These records match different entries in the bundled name-authority data');
    expect(document.activeElement?.textContent).toBe('Cancel');
    await userEvent.tab();
    await userEvent.keyboard('{Enter}');
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Adenauer, Conrad' })).toBeNull());
    const call = fetch.mock.calls.find(([url, init]) => String(url).endsWith('/api/v1/me/people/merges') && init?.method === 'POST');
    expect(JSON.parse(String(call?.[1]?.body))).toEqual({ rollupId: 1, otherRollupId: 2, version: 'v1' });
    expect(await screen.findByText('Merged Adzhubei, Aleksei I. into Adenauer, Conrad')).toBeTruthy();
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('heading', { level: 1, name: 'People' })));
  });

  it('says so when the people were rebuilt since the page was loaded, and loads them again', async () => {
    const fetch = server(curator, {
      'POST /api/v1/me/people/separations': new ProblemAnswer(409, 'PEOPLE_CHANGED', 'The people have been rebuilt.'),
    });
    renderAt('/people');
    await userEvent.click(await screen.findByRole('button', { name: /^Adenauer, Conrad/ }));
    const sheet = await screen.findByRole('dialog', { name: 'Adenauer, Conrad' });
    await userEvent.click(await within(sheet).findByRole('button', { name: 'Separate Adenauer, Konrad into its own identity' }));
    expect(await screen.findByText('The people have been rebuilt since this page was loaded, so they have been loaded again: choose once more.')).toBeTruthy();
    const lists = fetch.mock.calls.filter(([url]) => new URL(String(url), 'http://localhost').pathname === '/api/v1/people');
    expect(lists.length).toBeGreaterThan(1);
  });

  it('lists the corrections for a curator, with Undo, and says a correction an Import server keeps for its next export', async () => {
    const corrections: PersonCorrections = {
      items: [{ id: 'C1', kind: 'merge', nameA: 'Adenauer, Conrad', nameB: 'Adzhubei, Aleksei I.', madeBy: 'Owner', madeAt: '2026-11-14T13:00:00.000Z', applied: false }],
      mode: 'import',
    };
    const fetch = server(curator, {
      '/api/v1/me/people/corrections': corrections,
      'DELETE /api/v1/me/people/corrections/C1': { state: 'nextExport', entryId: 'E2' },
    });
    renderAt('/people');
    expect(await screen.findByText(/a correction made here is kept, and the next export installed is given it/)).toBeTruthy();
    await userEvent.click(screen.getByRole('button', { name: 'Corrections' }));
    const sheet = await screen.findByRole('dialog', { name: 'Corrections' });
    expect(await within(sheet).findByText('Adenauer, Conrad and Adzhubei, Aleksei I. — merged')).toBeTruthy();
    expect(within(sheet).getByText('Applied when the next export is installed')).toBeTruthy();
    expect(within(sheet).getByText('Nov 14, 2026, by Owner')).toBeTruthy();
    await userEvent.click(within(sheet).getByRole('button', { name: 'Undo: Adenauer, Conrad and Adzhubei, Aleksei I. — merged' }));
    await waitFor(() =>
      expect(fetch.mock.calls.some(([url, init]) => String(url).endsWith('/api/v1/me/people/corrections/C1') && init?.method === 'DELETE')).toBe(true),
    );
    expect(await within(sheet).findByText(/Correction undone\. The correction is kept/)).toBeTruthy();
  });
});

describe('the People screen’s rules', () => {
  it('filters as the app’s list does, folds as its picker does, and says a row as one stop', () => {
    expect(displaySections(list, 'ADEN').map((section) => section.people.map((row) => row.rollupId))).toEqual([[1]]);
    expect(displaySections(list, '')).toBe(list.sections);
    expect(folded('Ádzhubeĩ')).toBe('adzhubei');
    expect(pickerRows(list, 1, 'adzhubei').map((row) => row.rollupId)).toEqual([2]);
    expect(pickerRows(list, 1, '').map((row) => row.rollupId)).toEqual([2, 3]);
    expect(rowLabel(list.sections[1]!.people[0]!)).toBe('Khrushchev, Nikita S.');
    expect(mergeQuestion({ name: 'B', authorityId: 1 }, { name: 'A', authorityId: 1 })).not.toContain('different entries');
    expect(mergeQuestion({ name: 'B', authorityId: null }, { name: 'A', authorityId: 1 })).not.toContain('different entries');
    expect(correctionTitle({ kind: 'split', nameA: 'Adzhubei' })).toBe('Adzhubei — separated');
  });
});
