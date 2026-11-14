import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { PeopleList, PersonCorrections, PersonSheet, SubjectVolumes } from '../api/people';
import type { Me } from '../api/types';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import {
  correctionTitle,
  displaySections,
  folded,
  mergeQuestion,
  pickerRows,
  roleEraLine,
  rowLabel,
  subjectChipValue,
  subjectVolumesHeader,
} from './peopleRules';

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
  subjects: [],
  viafURL: 'https://viaf.org/viaf/12345',
  wikidataURL: 'https://www.wikidata.org/wiki/Q2492',
  career: [],
  candidates: [{ rollupId: 2, name: 'Adzhubei, Aleksei I.', reason: 'Same surname, overlapping years' }],
  records: [
    { volumeId: 'frus1961-63v06', ref: 'p_AK3', name: 'Adenauer, Conrad' },
    { volumeId: 'frus1969-76ve09p1', ref: 'p_AK1', name: 'Adenauer, Konrad' },
  ],
};

/** A sheet with Subjects and Career, a person the register knows, and one chip's pivot. */
const thompsonRow = { rollupId: 7, name: 'Thompson, Llewellyn E.', subtitle: 'Ambassador to the Soviet Union', mentionCount: 40, volumeCount: 1, authorityId: 70, possibleDuplicate: false };
const thompson: PersonSheet = {
  version: 'v1',
  rollupId: 7,
  name: 'Thompson, Llewellyn E.',
  description: 'Ambassador to the Soviet Union',
  lifespan: '1904–1972',
  registerRole: 'Foreign Service officer',
  reconciled: true,
  authorityId: 70,
  mentionCount: 40,
  mentions: '40 documents',
  active: '1961–1963',
  subjects: [
    { ref: 'berlin-crisis', name: 'Berlin Crisis', category: 'Crises', volumeCount: 1 },
    { ref: 'arms-control', name: 'Arms Control', category: 'Arms Control and Disarmament', volumeCount: 2 },
  ],
  viafURL: null,
  wikidataURL: null,
  career: [
    { title: 'Ambassador Extraordinary and Plenipotentiary — Soviet Union', dates: '1957-07-16 – 1962-07-27', note: null },
    { title: 'Ambassador-at-Large', dates: null, note: 'Left post' },
  ],
  candidates: [],
  records: [],
};
const berlin: SubjectVolumes = {
  ref: 'berlin-crisis',
  volumes: [
    { volumeId: 'frus1958-60v08', title: 'Foreign Relations of the United States, 1958–1960, Volume VIII, Berlin Crisis, 1958–1959' },
    { volumeId: 'frus1961-63v14', title: null },
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
    // No subject ranked and no post in the register: neither section, as the app's sheet draws neither.
    expect(within(sheet).queryByRole('region', { name: 'Subjects' })).toBeNull();
    expect(within(sheet).queryByRole('region', { name: 'Career' })).toBeNull();
  });

  it('draws Subjects and Career as the app’s sheet does, and a chip opens the volumes covering its subject, by keyboard', async () => {
    server(reader, {
      '/api/v1/people': { version: 'v1', count: 1, sections: [{ letter: 'T', people: [thompsonRow] }] } satisfies PeopleList,
      '/api/v1/people/7': thompson,
      '/api/v1/subjects/berlin-crisis/volumes': berlin,
    });
    renderAt('/people');
    await userEvent.click(await screen.findByRole('button', { name: /^Thompson, Llewellyn E\./ }));
    const sheet = await screen.findByRole('dialog', { name: 'Thompson, Llewellyn E.' });
    // The lifespan line and the register's role under the register's chip, the volumes' words under their own.
    expect(await within(sheet).findByText('1904–1972')).toBeTruthy();
    expect(within(sheet).getByText('Foreign Service officer')).toBeTruthy();
    expect(within(sheet).getAllByRole('img', { name: 'Source: the FRUS volumes only.' })).toHaveLength(1);
    expect(within(sheet).getAllByRole('img', { name: /^Source: FRUS joined to the Office of the Historian's working data on people/ })).toHaveLength(2);
    // The app's order: Mentions and Active, Subjects, the links, Career.
    const headings = within(sheet).getAllByRole('heading', { level: 3 }).map((heading) => heading.textContent);
    expect(headings).toEqual(['Subjects', 'Career']);
    const subjects = within(sheet).getByRole('region', { name: 'Subjects' });
    const career = within(sheet).getByRole('region', { name: 'Career' });
    const active = within(sheet).getByText('Active');
    const mentions = within(sheet).getByRole('link', { name: 'Find all mentions' });
    const follows = (first: Node, then: Node) => Boolean(first.compareDocumentPosition(then) & Node.DOCUMENT_POSITION_FOLLOWING);
    expect(follows(active, subjects) && follows(subjects, mentions) && follows(mentions, career)).toBe(true);
    // Each chip its subject's name, said with its category and count and the hint, in the server's order.
    const chips = within(subjects).getAllByRole('button');
    expect(chips.map((chip) => chip.textContent)).toEqual(['Berlin Crisis', 'Arms Control']);
    const described = (chip: HTMLElement) =>
      (chip.getAttribute('aria-describedby') ?? '').split(' ').map((id) => document.getElementById(id)?.textContent).join(' ');
    expect(described(chips[0]!)).toBe('Crises, in 1 volume mentioning this person Shows other volumes covering this subject');
    expect(described(chips[1]!)).toBe('Arms Control and Disarmament, in 2 volumes mentioning this person Shows other volumes covering this subject');
    expect(chips[0]!.getAttribute('title')).toBe('Subject of volumes where this person is mentioned — click to see all volumes covering it');
    expect(within(subjects).getByText(/^Volume-level: subjects characteristic of the volumes/)).toBeTruthy();
    // Career's posts in order, each its title, its dates where the register has them and its note, over its sentence.
    expect(within(career).getAllByRole('listitem').map((post) => post.textContent)).toEqual([
      'Ambassador Extraordinary and Plenipotentiary — Soviet Union 1957-07-16 – 1962-07-27',
      'Ambassador-at-Large Left post',
    ]);
    expect(within(career).getByText('From the Department’s Principal Officers and Chiefs of Mission register.')).toBeTruthy();

    // The first chip by keyboard: its pivot lists the volumes covering it, each a link to its page, by its title or id.
    chips[0]!.focus();
    await userEvent.keyboard('{Enter}');
    const pivot = await screen.findByRole('dialog', { name: 'Berlin Crisis' });
    await waitFor(() => expect(document.activeElement).toBe(within(pivot).getByRole('heading', { level: 2, name: 'Berlin Crisis' })));
    expect(await within(pivot).findByRole('heading', { name: '2 volumes cover this subject' })).toBeTruthy();
    // Done beside the title, before the rows, as the app's toolbar keeps it.
    const done = within(pivot).getByRole('button', { name: 'Done' });
    expect(Boolean(done.compareDocumentPosition(within(pivot).getAllByRole('link')[0]!) & Node.DOCUMENT_POSITION_FOLLOWING)).toBe(true);
    const rows = within(pivot).getAllByRole('link');
    expect(rows.map((row) => row.getAttribute('href'))).toEqual(['/browse/frus1958-60v08', '/browse/frus1961-63v14']);
    expect(rows.map((row) => row.textContent)).toEqual([
      'Foreign Relations of the United States, 1958–1960, Volume VIII, Berlin Crisis, 1958–1959 frus1958-60v08',
      'frus1961-63v14 frus1961-63v14',
    ]);
    expect(rows[0]!.getAttribute('title')).toBe('Opens this volume in the browser');
    // Done, and focus is back on the chip.
    done.focus();
    await userEvent.keyboard('{Enter}');
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Berlin Crisis' })).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(chips[0]));
  });

  it('says a subject no volume carries as the app’s pivot does, and closes on Escape', async () => {
    server(reader, {
      '/api/v1/people': { version: 'v1', count: 1, sections: [{ letter: 'T', people: [thompsonRow] }] } satisfies PeopleList,
      '/api/v1/people/7': thompson,
      '/api/v1/subjects/arms-control/volumes': { ref: 'arms-control', volumes: [] } satisfies SubjectVolumes,
    });
    renderAt('/people');
    await userEvent.click(await screen.findByRole('button', { name: /^Thompson, Llewellyn E\./ }));
    const sheet = await screen.findByRole('dialog', { name: 'Thompson, Llewellyn E.' });
    await userEvent.click(await within(sheet).findByRole('button', { name: 'Arms Control' }));
    const pivot = await screen.findByRole('dialog', { name: 'Arms Control' });
    expect(await within(pivot).findByRole('heading', { name: 'No volumes' })).toBeTruthy();
    expect(within(pivot).getByText('No volume in the series carries documents on this subject.')).toBeTruthy();
    expect(within(pivot).queryByRole('link')).toBeNull();
    fireEvent(pivot, new Event('cancel', { cancelable: true }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Arms Control' })).toBeNull());
    expect(screen.getByRole('dialog', { name: 'Thompson, Llewellyn E.' })).toBeTruthy();
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

  it('sends no correction from a sheet of another rollup than the list its ids came from', async () => {
    const fetch = server(curator, { '/api/v1/people/1': { ...adenauer, version: 'v2' } });
    renderAt('/people');
    await userEvent.click(await screen.findByRole('button', { name: /^Adenauer, Conrad/ }));
    const sheet = await screen.findByRole('dialog', { name: 'Adenauer, Conrad' });
    await userEvent.click(await within(sheet).findByRole('button', { name: 'Separate Adenauer, Konrad into its own identity' }));
    expect(await screen.findByText('The people have been rebuilt since this page was loaded, so they have been loaded again: choose once more.')).toBeTruthy();
    expect(fetch.mock.calls.some(([url]) => String(url).endsWith('/api/v1/me/people/separations'))).toBe(false);
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
    expect(await within(sheet).findByText('Correction undone. The next export this server installs is given the change.')).toBeTruthy();
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

  it('says a chip’s value and its pivot’s count in the one form at exactly one, grouped, as the kit’s CountCopy does', () => {
    const subject = { ref: 'warfare', name: 'Warfare', category: 'Warfare', volumeCount: 1 };
    expect(subjectChipValue(subject)).toBe('Warfare, in 1 volume mentioning this person');
    expect(subjectChipValue({ ...subject, volumeCount: 2 })).toBe('Warfare, in 2 volumes mentioning this person');
    expect(subjectVolumesHeader(1)).toBe('1 volume covers this subject');
    expect(subjectVolumesHeader(69)).toBe('69 volumes cover this subject');
    expect(subjectVolumesHeader(0)).toBe('0 volumes cover this subject');
    expect(subjectVolumesHeader(1204)).toBe('1,204 volumes cover this subject');
    expect(subjectChipValue({ ...subject, volumeCount: 1204 })).toBe('Warfare, in 1,204 volumes mentioning this person');
  });

  it('gives the merge picker the role and era alone, as the app’s picker shows them', () => {
    const row = list.sections[0]!.people[0]!;
    expect(roleEraLine(row)).toBe('Chancellor of the Federal Republic of Germany · 1961–1963');
    expect(roleEraLine({ ...row, subtitle: 'Ambassador · 1961–1963 · 2 volumes', volumeCount: 2 })).toBe('Ambassador · 1961–1963');
    expect(roleEraLine({ ...row, subtitle: '3 volumes', volumeCount: 3 })).toBeNull();
    expect(roleEraLine({ ...row, subtitle: null, volumeCount: 1 })).toBeNull();
  });
});
