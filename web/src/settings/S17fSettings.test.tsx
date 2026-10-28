// Settings ▸ Projects, Research Sessions with its Session Log, Reading, and Data's method appendix
// (PLAN's S17f), each in the app's words, over a stubbed server.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { SessionLog } from '../api/research';
import type { ProjectList } from '../api/types';
import { preferences } from '../test/research';
import { exportContents, me, sent } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { activityText, sessionLength, summaryText } from './SessionsSettings';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const grain = 'A0000000-0000-4000-8000-000000000001';
const berlin = 'A0000000-0000-4000-8000-000000000002';
const projects: ProjectList = {
  total: 2,
  items: [
    { id: berlin, name: 'Berlin', researchQuestion: 'How did the wall go up?', tally: 'Nothing filed yet' },
    { id: grain, name: 'Grain', tally: '1 note' },
  ],
  activeProjectId: grain,
};

const log: SessionLog = {
  sessions: [
    {
      id: 'S1',
      startedAt: '2026-10-23T23:40:00.000Z',
      endedAt: '2026-10-23T23:50:00.000Z',
      duration: 600,
      activityCount: 2,
      isOngoing: true,
      activities: [
        { id: 'A1', kind: 'documentOpen', timestamp: '2026-10-23T23:40:00.000Z', volumeId: 'frus1961-63v06', documentId: 'd1' },
        { id: 'A2', kind: 'search', timestamp: '2026-10-23T23:50:00.000Z', query: 'wheat', resultCount: 1 },
      ],
    },
  ],
  loadedActivities: 2,
  totalActivities: 2,
  pageLimit: 1000,
  hasMore: false,
  summary: { sessionCount: 1, isSessionCountExact: true, eventCount: 3, lastSessionStart: '2026-10-23T23:40:00.000Z' },
};

describe('Settings ▸ Projects', () => {
  it('lists the projects in the reader’s own order with their tallies, chooses the active one, and moves one', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/projects': projects,
      '/api/v1/me/preferences': preferences,
      '/api/v1/me/tags': { total: 1, items: [{ id: 'T1', name: 'Wheat' }] },
      '/api/v1/me/volume-scopes': { total: 0, items: [] },
      'PUT /api/v1/me/active-project': (_: URL, init?: RequestInit) => ({ projectId: sent(init).body.projectId ?? undefined }),
      'PATCH /api/v1/me/preferences': (_: URL, init?: RequestInit) => ({ ...preferences, ...sent(init).body }),
    });
    const user = userEvent.setup();
    renderAt('/settings/projects');
    expect(await screen.findByRole('heading', { level: 1, name: 'Projects' })).toBeTruthy();
    const list = within(await screen.findByRole('region', { name: 'All Projects' }));
    const rows = list.getAllByRole('button').filter((button) => button.classList.contains('settings-row'));
    expect(rows.map((row) => row.textContent)).toEqual(['BerlinNothing filed yetHow did the wall go up?›', 'Grain1 note · active›']);
    expect(screen.getByText('The active project scopes the notes, collections, history, and searches you see. Global Context shows everything.')).toBeTruthy();
    expect(within(screen.getByRole('region', { name: 'Related' })).getByText('1 tag')).toBeTruthy();

    await user.selectOptions(screen.getByRole('combobox', { name: 'Active Project' }), berlin);
    await waitFor(() => expect(fetch.mock.calls.some(([url, init]) => String(url).endsWith('/active-project') && sent(init).body.projectId === berlin)).toBe(true));
    await user.click(list.getByRole('button', { name: 'Move to Top: Grain' }));
    await waitFor(() =>
      expect(fetch.mock.calls.some(([url, init]) => String(url).endsWith('/preferences') && JSON.stringify(sent(init).body) === JSON.stringify({ projectOrder: [grain, berlin] }))).toBe(true),
    );
  });

  it('makes a project with New Project…, and deletes one after asking, as the app’s editor does', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/projects': projects,
      '/api/v1/me/preferences': preferences,
      'POST /api/v1/me/projects': (_: URL, init?: RequestInit) => ({ id: 'A0000000-0000-4000-8000-000000000003', name: sent(init).body.name }),
      [`DELETE /api/v1/me/projects/${berlin}`]: null,
    });
    const user = userEvent.setup();
    renderAt('/settings/projects');
    await user.click(await screen.findByRole('button', { name: 'New Project…' }));
    const editor = within(await screen.findByRole('dialog', { name: 'New Project' }));
    expect(editor.queryByRole('button', { name: 'Delete Project' })).toBeNull();
    await user.type(editor.getByRole('textbox', { name: 'Project name' }), 'Suez');
    await user.click(editor.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(fetch.mock.calls.some(([url, init]) => String(url).endsWith('/me/projects') && init?.method === 'POST' && sent(init).body.name === 'Suez')).toBe(true));

    await user.click(await screen.findByRole('button', { name: /^Berlin/ }));
    const edit = within(await screen.findByRole('dialog', { name: 'Edit Project' }));
    expect(edit.getByText(/Merging moves everything filed here into the project you choose/)).toBeTruthy();
    await user.click(edit.getByRole('button', { name: 'Delete Project' }));
    const ask = within(await screen.findByRole('alertdialog', { name: 'Delete Project?' }));
    expect(ask.getByText('Activity records are kept but unlinked from this project.')).toBeTruthy();
    await user.click(ask.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(fetch.mock.calls.some(([url, init]) => String(url).endsWith(`/projects/${berlin}`) && init?.method === 'DELETE')).toBe(true));
  });
});

describe('Settings ▸ Research Sessions', () => {
  it('turns logging off, summarizes the trail, and deletes it after asking, naming every event', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/preferences': preferences,
      '/api/v1/me/history/sessions': log,
      'PATCH /api/v1/me/preferences': (_: URL, init?: RequestInit) => ({ ...preferences, ...sent(init).body }),
      'DELETE /api/v1/me/history': { visits: 1, searches: 2, exports: 0 },
    });
    const user = userEvent.setup();
    renderAt('/settings/sessions');
    const logging = await screen.findByRole('switch', { name: 'Log Research Sessions' });
    expect((logging as HTMLInputElement).checked).toBe(true);
    expect(screen.getByRole('link', { name: /^Session Log/ }).textContent).toContain('1 session · 3 events · last Oct 23, 2026');
    await user.click(logging);
    await waitFor(() => expect(fetch.mock.calls.some(([url, init]) => String(url).endsWith('/preferences') && sent(init).body?.researchLoggingEnabled === false)).toBe(true));
    await user.click(screen.getByRole('button', { name: 'Delete Recorded Sessions…' }));
    const ask = within(await screen.findByRole('alertdialog', { name: 'Delete Recorded Sessions?' }));
    expect(ask.getByText(/^3 events will be permanently deleted/)).toBeTruthy();
    await user.click(ask.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(fetch.mock.calls.some(([url, init]) => String(url).endsWith('/me/history') && init?.method === 'DELETE')).toBe(true));
  });

  it('draws the Session Log’s sessions and rows as the app’s', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/preferences': preferences, '/api/v1/me/history/sessions': log });
    renderAt('/settings/sessions/log');
    expect(await screen.findByRole('heading', { level: 1, name: 'Session Log' })).toBeTruthy();
    expect(await screen.findByText('October 23, 2026')).toBeTruthy();
    expect(screen.getByText(/Ongoing · 2 events/)).toBeTruthy();
    expect(activityText(log.sessions[0]!.activities[1]!)).toBe('“wheat” — 1 result');
    expect(activityText({ id: 'E', kind: 'export', timestamp: '', format: 'zotero-api', documentCount: 3 })).toBe('Exported zotero-api — 3 documents');
    expect(sessionLength({ ...log.sessions[0]!, isOngoing: false, duration: 3_725 })).toBe('1h 2m');
    expect(summaryText({ sessionCount: 0, isSessionCountExact: true, eventCount: 0 })).toBe('Nothing recorded yet');
    expect(summaryText({ sessionCount: 1000, isSessionCountExact: false, eventCount: 1, lastSessionStart: '2026-10-23T10:00:00.000Z' }, new Date('2026-10-23T12:00:00.000Z')))
      .toMatch(/^at least 1000 sessions · 1 event · last today /);
  });
});

describe('Settings ▸ Reading', () => {
  it('sets the mode documents open in and the citation style, the user’s own', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/preferences': preferences,
      'PATCH /api/v1/me/preferences': (_: URL, init?: RequestInit) => ({ ...preferences, ...sent(init).body }),
    });
    const user = userEvent.setup();
    renderAt('/settings/reading');
    const mode = (await screen.findByRole('combobox', { name: 'Open Documents In' })) as HTMLSelectElement;
    expect(mode.value).toBe('rememberLast');
    await user.selectOptions(mode, 'research');
    await user.selectOptions(screen.getByRole('combobox', { name: 'Citation Style' }), 'chicago');
    await waitFor(() => {
      const bodies = fetch.mock.calls.filter(([url, init]) => String(url).endsWith('/preferences') && init?.method === 'PATCH').map(([, init]) => sent(init).body);
      expect(bodies).toEqual([{ defaultDocumentMode: 'research' }, { citationStyle: 'chicago' }]);
    });
  });

  it('shows a choice before the server answers it, and the server’s copy again when it refuses one', async () => {
    let answer: (given: unknown) => void = () => {};
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/preferences': preferences,
      'PATCH /api/v1/me/preferences': () => new Promise((resolve) => (answer = resolve)),
    });
    const user = userEvent.setup();
    renderAt('/settings/reading');
    const style = (await screen.findByRole('combobox', { name: 'Citation Style' })) as HTMLSelectElement;
    await user.selectOptions(style, 'chicago');
    expect(style.value).toBe('chicago');
    answer(new ProblemAnswer(400, 'INVALID_PREFERENCE', 'No such style.'));
    await waitFor(() => expect(style.value).toBe('historyAtState'));
  });
});

describe('Settings ▸ Data’s method appendix', () => {
  it('offers the kit’s Markdown and CSV once a search is recorded, and the app’s line before', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/export/contents': exportContents({ SearchHistoryEntry: 4 }), '/api/v1/me/notes': { total: 0, items: [] } });
    renderAt('/settings/data');
    const markdown = await screen.findByRole('link', { name: 'Markdown table (frus-query-log.md)' });
    expect(markdown.getAttribute('href')).toMatch(/^\/api\/v1\/me\/history\/appendix\?format=markdown&timeZone=/);
    expect(screen.getByRole('link', { name: 'CSV (frus-query-log.csv)' }).getAttribute('download')).toBe('frus-query-log.csv');
    expect(screen.getByText(/^Every search you ran, in a Markdown table and a CSV\./)).toBeTruthy();
    cleanup();
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/export/contents': exportContents(), '/api/v1/me/notes': { total: 0, items: [] } });
    renderAt('/settings/data');
    expect(await screen.findByText('No searches recorded yet.')).toBeTruthy();
  });
});
