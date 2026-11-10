// Project Home's focus subjects and their editor (PLAN's S25c), as the app's `ProjectHomeView` and
// `ProjectFocusSubjectsEditor` show them, over a stubbed server; and the editor's rules, mirrored in
// focusSubjectRules.ts, which ProjectHistoryParityTests holds to the app's source.
import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { FocusSubject, FocusSubjectList, ProjectHome } from '../api/research';
import { me, sent } from '../test/notes';
import { preferences } from '../test/research';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { chosenSubjects, filteredSubjects, showsSuggestions, subjectKind, subjectReach, toggledSubjects } from './focusSubjectRules';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const grain = 'A0000000-0000-4000-8000-000000000001';

/** Sixty subjects, in the vocabulary's order, by category, subcategory and name. */
const vocabulary: FocusSubject[] = Array.from({ length: 60 }, (_, index) => ({
  ref: `s${String(index).padStart(2, '0')}`,
  name: index === 7 ? 'Cuban missile crisis' : index === 52 ? 'Outer space' : `Subject ${index}`,
  category: index < 30 ? 'Arms Control' : 'Warfare',
  subcategory: index === 41 ? 'Nuclear Weapons' : 'General',
  volumeCount: index === 3 ? 1 : index + 1,
}));
const list: FocusSubjectList = { total: vocabulary.length, items: vocabulary };
const subject = (ref: string) => vocabulary.find((item) => item.ref === ref)!;

const base: ProjectHome = {
  project: { id: grain, name: 'Grain', defaultSubjectTagIds: [] },
  isActive: true,
  counts: { collections: 0, notes: 0, documentsVisited: 0, searches: 0 },
  coverage: [],
  focusSubjects: [],
  focusSuggestions: [subject('s52'), subject('s07'), subject('s03')],
  hasTags: false,
  focusTags: [],
  leads: [],
  recentVisits: [],
  recentNotes: [],
  recentSearches: [],
  isEmpty: true,
};

/** Project Home as the server answers it for `refs`: its subjects in the vocabulary's order, its suggestions without them. */
function homeFor(refs: string[]): ProjectHome {
  return {
    ...base,
    project: { ...base.project, defaultSubjectTagIds: refs },
    focusSubjects: vocabulary.filter((item) => refs.includes(item.ref)),
    focusSuggestions: base.focusSuggestions!.filter((item) => !refs.includes(item.ref)),
  };
}

/**
 * A server that keeps the project's subjects as each PATCH sets them, with `patch` to answer one
 * otherwise, and `home` to hold Project Home's answer back.
 */
function serving(initial: string[], patch?: (refs: string[], count: number) => unknown, home?: () => Promise<void> | void) {
  let refs = initial;
  const bodies: string[][] = [];
  const fetch = stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/projects': { total: 1, items: [base.project] },
    '/api/v1/me/preferences': preferences,
    '/api/v1/me/focus-subjects': list,
    [`/api/v1/me/projects/${grain}/home`]: async () => {
      const answer = homeFor(refs);
      await home?.();
      return answer;
    },
    [`PATCH /api/v1/me/projects/${grain}`]: async (_: URL, init?: RequestInit) => {
      const given = sent(init).body.defaultSubjectTagIds as string[];
      bodies.push(given);
      const answer = patch ? await patch(given, bodies.length) : undefined;
      if (answer instanceof ProblemAnswer) return answer;
      refs = given;
      return { ...base.project, defaultSubjectTagIds: refs };
    },
  });
  return { fetch, bodies, refs: () => refs };
}

async function openEditor() {
  const user = userEvent.setup();
  renderAt(`/projects/${grain}`);
  const section = within(await screen.findByRole('region', { name: 'Focus subjects' }));
  await user.click(section.getByRole('button', { name: /^(Add|Edit)/ }));
  const dialog = within(await screen.findByRole('dialog', { name: 'Focus Subjects' }));
  await dialog.findByRole('searchbox', { name: 'Search subjects' });
  return { user, dialog };
}

const group = (dialog: ReturnType<typeof within>, name: string) => within(dialog.getByRole('group', { name }));

/** The subjects a section's switches name, in its order. */
const names = (section: ReturnType<typeof within>) =>
  section.getAllByRole('checkbox').map((box: HTMLElement) => document.getElementById(box.getAttribute('aria-labelledby') ?? '')?.textContent);

describe('the editor’s rules', () => {
  it('keeps the vocabulary’s order for the subjects chosen, and leaves out a ref it does not name', () => {
    expect(chosenSubjects(vocabulary, ['s52', 'gone', 's07']).map((item) => item.ref)).toEqual(['s07', 's52']);
  });

  it('shows the suggestions only while the search field holds nothing at all, and there are some', () => {
    expect(showsSuggestions('', [subject('s01')])).toBe(true);
    expect(showsSuggestions(' ', [subject('s01')])).toBe(false);
    expect(showsSuggestions('', [])).toBe(false);
  });

  it('lists the first fifty while nothing is searched for, and else what the name, category or subcategory holds, whatever the case', () => {
    expect(filteredSubjects(vocabulary, '').map((item) => item.ref)).toEqual(vocabulary.slice(0, 50).map((item) => item.ref));
    expect(filteredSubjects(vocabulary, ' \t').length).toBe(50);
    expect(filteredSubjects(vocabulary, '  CUBAN ').map((item) => item.ref)).toEqual(['s07']);
    expect(filteredSubjects(vocabulary, 'warfare').length).toBe(30);
    expect(filteredSubjects(vocabulary, 'nuclear').map((item) => item.ref)).toEqual(['s41']);
    expect(filteredSubjects(vocabulary, 'zanzibar')).toEqual([]);
  });

  it('writes a row’s captions as the app’s do', () => {
    expect(subjectKind(subject('s41'))).toBe('Warfare · Nuclear Weapons');
    expect(subjectReach(subject('s03'))).toBe('1 volume');
    expect(subjectReach({ volumeCount: 1204 })).toBe('1,204 volumes');
  });

  it('takes a ref out where the list holds it, and puts it at the end otherwise', () => {
    expect(toggledSubjects(['a', 'b', 'c'], 'b')).toEqual(['a', 'c']);
    expect(toggledSubjects(['a', 'c'], 'b')).toEqual(['a', 'c', 'b']);
  });
});

describe('Project Home’s focus subjects', () => {
  it('shows the subjects chosen, in the vocabulary’s order, with Edit, and the app’s sentence and Add for none', async () => {
    serving(['s52', 's07']);
    renderAt(`/projects/${grain}`);
    const section = within(await screen.findByRole('region', { name: 'Focus subjects' }));
    expect(section.getAllByRole('listitem').map((item) => item.textContent)).toEqual(['Cuban missile crisis', 'Outer space']);
    expect(section.getByRole('button', { name: 'Edit' })).toBeTruthy();
    cleanup();
    serving([]);
    renderAt(`/projects/${grain}`);
    const empty = within(await screen.findByRole('region', { name: 'Focus subjects' }));
    expect(empty.getByText('Choose subjects to focus discovery on the volumes they define.')).toBeTruthy();
    expect(empty.getByRole('button', { name: 'Add' })).toBeTruthy();
  });

  it('leaves the section out on a server with no vocabulary, as the app does without its file', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/preferences': preferences,
      [`/api/v1/me/projects/${grain}/home`]: { ...base, focusSubjects: undefined, focusSuggestions: undefined } });
    renderAt(`/projects/${grain}`);
    expect(await screen.findByRole('heading', { level: 1, name: 'Grain' })).toBeTruthy();
    expect(screen.queryByRole('region', { name: 'Focus subjects' })).toBeNull();
  });

  it('puts a lead’s line under it, its document’s opening text, and none where the server gives none', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/preferences': preferences,
      [`/api/v1/me/projects/${grain}/home`]: {
        ...base,
        leads: [
          { id: 'L1', volumeId: 'frus1961-63v06', documentId: 'd1', title: 'Lead one', isNew: false, relatedCount: 1, isEditorialNote: false,
            snippet: 'The ambassador was negotiating treaties with the minister.' },
          { id: 'L2', volumeId: 'frus1961-63v06', documentId: 'd3', title: 'Lead two', isNew: false, relatedCount: 1, isEditorialNote: false },
        ],
      } });
    renderAt(`/projects/${grain}`);
    const leads = within(await screen.findByRole('region', { name: 'Suggested Next' }));
    const [first, second] = leads.getAllByRole('listitem');
    expect(within(first!).getByText('The ambassador was negotiating treaties with the minister.')).toBeTruthy();
    expect(second!.querySelector('.lead-snippet')).toBeNull();
  });
});

describe('the focus subjects’ editor', () => {
  it('lists Suggested from your volumes and All subjects, with the app’s words, and no Focus subjects for none', async () => {
    serving([]);
    const { dialog } = await openEditor();
    expect(dialog.queryByRole('group', { name: 'Focus subjects' })).toBeNull();
    const suggested = group(dialog, 'Suggested from your volumes');
    expect(names(suggested)).toEqual(['Outer space', 'Cuban missile crisis', 'Subject 3']);
    expect(suggested.getByText('Subjects that recur across the volumes you’ve already collected, annotated, or opened in this project.')).toBeTruthy();
    const all = group(dialog, 'All subjects');
    expect(all.getAllByRole('checkbox')).toHaveLength(50);
    const third = all.getByRole('checkbox', { name: 'Subject 3' });
    expect(third.getAttribute('aria-describedby')?.split(' ').map((id) => document.getElementById(id)?.textContent)).toEqual([
      'Arms Control · General',
      '1 volume',
    ]);
  });

  it('chooses a suggestion by keyboard, saving the whole list, the row moving up and the focus going to the next', async () => {
    const { bodies, refs } = serving(['s07']);
    const { user, dialog } = await openEditor();
    const suggested = group(dialog, 'Suggested from your volumes');
    const outer = suggested.getByRole('checkbox', { name: 'Outer space' });
    outer.focus();
    await user.keyboard(' ');
    await waitFor(() => expect(bodies).toEqual([['s07', 's52']]));
    expect(refs()).toEqual(['s07', 's52']);
    // In Focus subjects now, in the vocabulary's order, and no longer a suggestion.
    await waitFor(() => expect(group(dialog, 'Focus subjects').getAllByRole('checkbox').map((box) => (box as HTMLInputElement).checked)).toEqual([true, true]));
    expect(group(dialog, 'Suggested from your volumes').queryByRole('checkbox', { name: 'Outer space' })).toBeNull();
    expect(document.activeElement).toBe(group(dialog, 'Suggested from your volumes').getByRole('checkbox', { name: 'Subject 3' }));
    expect(dialog.getByRole('status').textContent).toBe('Outer space added to Focus subjects');
    // And on Project Home, in the vocabulary's order, the focus back on Edit after Escape, as the browser sends it.
    fireEvent(screen.getByRole('dialog', { name: 'Focus Subjects' }), new Event('cancel', { cancelable: true }));
    const section = within(await screen.findByRole('region', { name: 'Focus subjects' }));
    await waitFor(() => expect(section.getAllByRole('listitem').map((item) => item.textContent)).toEqual(['Cuban missile crisis', 'Outer space']));
    expect(document.activeElement).toBe(section.getByRole('button', { name: 'Edit' }));
  });

  it('takes a subject out of Focus subjects, the focus going on to the row in its place, or to the search field from the last', async () => {
    const { bodies } = serving(['s07', 's41']);
    const { user, dialog } = await openEditor();
    const chosen = group(dialog, 'Focus subjects');
    await user.click(chosen.getByRole('checkbox', { name: 'Cuban missile crisis' }));
    await waitFor(() => expect(bodies).toEqual([['s41']]));
    expect(document.activeElement).toBe(group(dialog, 'Focus subjects').getByRole('checkbox', { name: 'Subject 41' }));
    await user.keyboard(' ');
    await waitFor(() => expect(bodies).toEqual([['s41'], []]));
    expect(dialog.queryByRole('group', { name: 'Focus subjects' })).toBeNull();
    expect(document.activeElement).toBe(dialog.getByRole('searchbox', { name: 'Search subjects' }));
  });

  it('hands the focus from the last row of a section to the row now last', async () => {
    serving(['s07', 's41', 's52']);
    const { user, dialog } = await openEditor();
    expect(names(group(dialog, 'Focus subjects'))).toEqual(['Cuban missile crisis', 'Subject 41', 'Outer space']);
    await user.click(group(dialog, 'Focus subjects').getByRole('checkbox', { name: 'Outer space' }));
    await waitFor(() => expect(names(group(dialog, 'Focus subjects'))).toEqual(['Cuban missile crisis', 'Subject 41']));
    expect(document.activeElement).toBe(group(dialog, 'Focus subjects').getByRole('checkbox', { name: 'Subject 41' }));
  });

  it('builds a toggle on the server’s last answer, before Project Home is read again', async () => {
    let held = false;
    let release: () => void = () => {};
    const { bodies } = serving([], undefined, () => (held ? new Promise<void>((resolve) => (release = resolve)) : undefined));
    const { user, dialog } = await openEditor();
    held = true;
    await user.click(group(dialog, 'All subjects').getByRole('checkbox', { name: 'Subject 1' }));
    await waitFor(() => expect(bodies).toEqual([['s01']]));
    // The save is answered, and Project Home, read again, has not answered yet.
    await new Promise((resolve) => setTimeout(resolve, 20));
    await user.click(group(dialog, 'All subjects').getByRole('checkbox', { name: 'Subject 2' }));
    await waitFor(() => expect(bodies).toEqual([['s01'], ['s01', 's02']]));
    held = false;
    release();
    await waitFor(() => expect(names(group(dialog, 'Focus subjects'))).toEqual(['Subject 1', 'Subject 2']));
  });

  it('searches the name, category and subcategory, hiding the suggestions, and says when nothing matches', async () => {
    serving([]);
    const { user, dialog } = await openEditor();
    const search = dialog.getByRole('searchbox', { name: 'Search subjects' });
    await user.type(search, 'NUCLEAR');
    expect(dialog.queryByRole('group', { name: 'Suggested from your volumes' })).toBeNull();
    expect(names(group(dialog, 'All subjects'))).toEqual(['Subject 41']);
    await user.clear(search);
    await user.type(search, 'zanzibar');
    expect(group(dialog, 'All subjects').getByText('No subjects match.')).toBeTruthy();
    // A space alone hides the suggestions, as the app's empty search text alone shows them, and lists the first fifty.
    await user.clear(search);
    await user.type(search, ' ');
    expect(dialog.queryByRole('group', { name: 'Suggested from your volumes' })).toBeNull();
    expect(group(dialog, 'All subjects').getAllByRole('checkbox')).toHaveLength(50);
  });

  it('saves toggles one at a time, the newest list whole, so the server ends with what the rows show', async () => {
    let release: () => void = () => {};
    const first = new Promise<void>((resolve) => (release = resolve));
    const { bodies, refs } = serving([], async (_, count) => {
      if (count === 1) await first;
    });
    const { user, dialog } = await openEditor();
    const all = group(dialog, 'All subjects');
    await user.click(all.getByRole('checkbox', { name: 'Subject 1' }));
    await waitFor(() => expect(bodies).toEqual([['s01']]));
    await user.click(all.getByRole('checkbox', { name: 'Subject 2' }));
    await user.click(all.getByRole('checkbox', { name: 'Subject 1' }));
    // Shown at once, and nothing else sent while the first is under way.
    expect((all.getByRole('checkbox', { name: 'Subject 2' }) as HTMLInputElement).checked).toBe(true);
    expect((all.getByRole('checkbox', { name: 'Subject 1' }) as HTMLInputElement).checked).toBe(false);
    expect(bodies).toEqual([['s01']]);
    release();
    await waitFor(() => expect(bodies).toEqual([['s01'], ['s02']]));
    expect(refs()).toEqual(['s02']);
    await waitFor(() => expect((group(dialog, 'All subjects').getByRole('checkbox', { name: 'Subject 2' }) as HTMLInputElement).checked).toBe(true));
  });

  it('puts the rows back as the server holds them when it refuses a save, and says why', async () => {
    serving(['s07'], () => new ProblemAnswer(404, 'SUBJECT_NOT_FOUND', 'The subject vocabulary has no subject with the ref s05.'));
    const { user, dialog } = await openEditor();
    await user.click(group(dialog, 'All subjects').getByRole('checkbox', { name: 'Subject 5' }));
    expect(await dialog.findByRole('alert')).toBeTruthy();
    expect(dialog.getByText('The subject vocabulary has no subject with the ref s05.')).toBeTruthy();
    await waitFor(() => expect((group(dialog, 'All subjects').getByRole('checkbox', { name: 'Subject 5' }) as HTMLInputElement).checked).toBe(false));
    expect(group(dialog, 'Focus subjects').getAllByRole('checkbox')).toHaveLength(1);
    // Opened again, the editor starts with no refusal.
    await user.click(dialog.getByRole('button', { name: 'Done' }));
    const section = within(screen.getByRole('region', { name: 'Focus subjects' }));
    await user.click(section.getByRole('button', { name: 'Edit' }));
    const again = within(await screen.findByRole('dialog', { name: 'Focus Subjects' }));
    expect(again.queryByRole('alert')).toBeNull();
  });

  it('says a refusal that comes once the editor has closed in the section, and keeps the focus in the editor when a row goes back', async () => {
    let release: () => void = () => {};
    serving(['s07'], async () => {
      await new Promise<void>((resolve) => (release = resolve));
      return new ProblemAnswer(409, 'STORE_DAMAGED', 'The project could not be read.');
    });
    const { user, dialog } = await openEditor();
    // Subject 41 joins Focus subjects, and the focus moves onto it there, while the save waits.
    await user.click(group(dialog, 'All subjects').getByRole('checkbox', { name: 'Subject 41' }));
    group(dialog, 'Focus subjects').getByRole('checkbox', { name: 'Subject 41' }).focus();
    release();
    // Put back, the row goes, and the focus goes to the search field, not to the page behind.
    await waitFor(() => expect(group(dialog, 'Focus subjects').queryByRole('checkbox', { name: 'Subject 41' })).toBeNull());
    expect(document.activeElement).toBe(dialog.getByRole('searchbox', { name: 'Search subjects' }));
    // And a refusal after Done is said in the section.
    await user.click(group(dialog, 'All subjects').getByRole('checkbox', { name: 'Subject 42' }));
    await user.click(dialog.getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    release();
    const section = within(screen.getByRole('region', { name: 'Focus subjects' }));
    expect((await section.findByRole('alert')).textContent).toBe('The project could not be read.');
  });

  it('says the subjects are unavailable when the server cannot give them', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/preferences': preferences,
      [`/api/v1/me/projects/${grain}/home`]: base,
      '/api/v1/me/focus-subjects': new ProblemAnswer(503, 'SUBJECTS_UNAVAILABLE', 'volume-subject-profiles-index.json does not decode.') });
    const user = userEvent.setup();
    renderAt(`/projects/${grain}`);
    await user.click(await screen.findByRole('button', { name: 'Add' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Focus Subjects' }));
    expect(await dialog.findByRole('heading', { name: 'Subjects Unavailable' })).toBeTruthy();
    expect(dialog.getByText('The subject index could not be loaded.')).toBeTruthy();
    await user.click(dialog.getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  });
});
