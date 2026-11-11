import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdminJob, AdminStatus, AdminUser, ResearchHoldings } from '../api/admin';
import type { Me } from '../api/types';
import { me } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const reader: Me = { ...me, userId: 'bob', displayName: 'bob', auth: 'local', roles: ['reader'] };
const alice: Me = { ...me, userId: 'alice', displayName: 'Alice', auth: 'local' };

const status: AdminStatus = {
  version: '0.1.0',
  mode: 'import',
  auth: 'local',
  userData: true,
  startedAt: '2026-11-10T20:00:00.000Z',
  supportedIndexVersion: 74,
  readiness: { ready: true, step: 'ready', detail: 'Serving 2,113 documents from 3 volumes, index version 74' },
  index: { documents: 2113, volumes: 3, indexVersion: 74, ftsSchemaVersion: 4, exportedAt: '2026-11-10T12:00:00Z', appVersion: '1.0', appBuild: '1812' },
  catalogueVolumes: 553,
  store: { kind: 'sqlite', migration: 6, latestMigration: 6 },
  backups: { daily: 2, kept: 7, hour: '03:00', timeZone: 'America/New_York', copiedToHost: true },
  keys: { keyFileId: '9f3a6c0d51e27b48', stored: 1 },
  jobs: { queued: 0 },
};

const job = (fields: Partial<AdminJob> & Pick<AdminJob, 'id' | 'state'>): AdminJob => ({
  kind: 'indexImport',
  queuedAt: '2026-11-10T20:00:00.000Z',
  cancellable: fields.state === 'queued' || fields.state === 'running',
  ...fields,
});

const user = (fields: Partial<AdminUser> & Pick<AdminUser, 'id'>): AdminUser => ({
  displayName: fields.id,
  role: 'reader',
  hasPassword: true,
  ...fields,
});

const sent = (fetch: ReturnType<typeof stubServer>, method: string, path: string) =>
  fetch.mock.calls.filter(([url, init]) => init?.method === method && String(url).endsWith(path));

describe('Administration', () => {
  it('is an admin’s, linked from the header, with its five panes', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': alice, '/api/v1/admin/status': status });
    const { router } = renderAt('/admin');
    expect(await screen.findByRole('heading', { level: 1, name: 'Status' })).toBeTruthy();
    expect(await screen.findByText('3 of the catalogue’s 553 volumes, 2,113 documents')).toBeTruthy();
    expect(router.state.location.pathname).toBe('/admin/status');
    const header = screen.getByRole('navigation', { name: 'Main' });
    expect(within(header).getByRole('link', { name: 'Admin' }).getAttribute('aria-current')).toBe('page');
    const panes = screen.getByRole('navigation', { name: 'Administration' });
    expect(within(panes).getAllByRole('link').map((link) => link.textContent)).toEqual(['Status', 'Jobs', 'Users', 'Backups', 'Keys']);
    expect(screen.getByText('6, this build’s')).toBeTruthy();
    expect(screen.getByText('9f3a6c0d51e27b48')).toBeTruthy();
    expect(screen.getByText('No job is running.')).toBeTruthy();
  });

  it('shows a reader no link and nothing of it', async () => {
    const fetch = stubServer({ '/readyz': ready, '/api/v1/me': reader });
    renderAt('/admin/users');
    expect(await screen.findByText('Administration is for admins, and your account does not hold the role.')).toBeTruthy();
    expect(within(screen.getByRole('navigation', { name: 'Main' })).queryByRole('link', { name: 'Admin' })).toBeNull();
    expect(fetch.mock.calls.some(([url]) => String(url).includes('/api/v1/admin/'))).toBe(false);
  });

  it('resets the index after a question, as a job', async () => {
    const queued = job({ id: 'J1', kind: 'indexReset', state: 'queued', requestedBy: 'alice' });
    const fetch = stubServer({ '/readyz': ready, '/api/v1/me': alice, '/api/v1/admin/status': status, 'POST /api/v1/admin/index/reset': queued });
    renderAt('/admin/status');
    const reset = await screen.findByRole('button', { name: 'Reset the Index…' });
    await userEvent.click(reset);
    const dialog = await screen.findByRole('alertdialog', { name: 'Reset the index?' });
    expect(within(dialog).getByRole('button', { name: 'Cancel' })).toBe(document.activeElement);
    await userEvent.click(within(dialog).getByRole('button', { name: 'Reset' }));
    expect(await screen.findByText('The reset is queued as a job: Jobs follows it.', { exact: false })).toBeTruthy();
    expect(sent(fetch, 'POST', '/api/v1/admin/index/reset')).toHaveLength(1);
    expect(screen.queryByRole('alertdialog')).toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Reset the Index…' }));
  });

  it('lists the jobs and cancels one after a question', async () => {
    let jobs: AdminJob[] = [
      job({ id: 'J2', state: 'running', subject: 'export.sqlite', progress: 'Copying export.sqlite', fraction: 0.5, startedAt: '2026-11-10T20:00:01.000Z' }),
      job({ id: 'J1', kind: 'researchImport', state: 'failed', requestedBy: 'bob', error: 'INVALID_EXPORT: the export’s records could not be read.' }),
    ];
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/jobs': () => ({ jobs }),
      'POST /api/v1/admin/jobs/J2/cancel': () => {
        jobs = [{ ...jobs[0]!, cancelRequestedBy: 'alice', cancelRequestedAt: '2026-11-10T20:00:02.000Z' }, jobs[1]!];
        return jobs[0];
      },
    });
    renderAt('/admin/jobs');
    const table = await screen.findByRole('table', { name: 'The jobs the server holds, newest first' });
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows.map((row) => within(row).getByRole('rowheader').textContent)).toEqual(['Index import: export.sqlite', 'Research import']);
    expect(within(rows[0]!).getByText('Running')).toBeTruthy();
    expect(within(rows[0]!).getByRole('progressbar', { name: 'Copying export.sqlite' })).toBeTruthy();
    expect(within(rows[0]!).getByText('The server')).toBeTruthy();
    expect(within(rows[1]!).getByText('INVALID_EXPORT: the export’s records could not be read.')).toBeTruthy();
    expect(within(rows[1]!).queryByRole('button')).toBeNull();
    await userEvent.click(within(rows[0]!).getByRole('button', { name: 'Cancel Index import: export.sqlite' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'Cancel this job?' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'Cancel Job' }));
    // The row's Cancel… goes with the cancel, so focus goes to the row.
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    await waitFor(() => expect(screen.getByText('Stopping at its next step', { exact: false })).toBeTruthy());
    expect(screen.getAllByRole('status').some((line) => line.textContent === 'Index import: export.sqlite stops before its next step.')).toBe(true);
    expect(document.activeElement).toBe(within(table).getByRole('rowheader', { name: 'Index import: export.sqlite' }));
    expect(within(table).queryByRole('button', { name: 'Cancel Index import: export.sqlite' })).toBeNull();
    expect(sent(fetch, 'POST', '/api/v1/admin/jobs/J2/cancel')).toHaveLength(1);
  });

  it('manages the accounts under local accounts, and says why a change was refused', async () => {
    let users: AdminUser[] = [user({ id: 'alice', role: 'admin', lastSignInAt: '2026-11-10T20:00:00.000Z' }), user({ id: 'bob' })];
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/users': () => ({ auth: 'local', users }),
      'POST /api/v1/admin/users': (_url: URL, init?: RequestInit) => {
        const body = JSON.parse(String(init?.body)) as { name: string; role: AdminUser['role'] };
        const made = user({ id: body.name, role: body.role });
        users = [...users, made];
        return made;
      },
      'PATCH /api/v1/admin/users/alice': new ProblemAnswer(409, 'LAST_ADMIN', 'alice is the last admin who can sign in: make another account an admin first.'),
      'PATCH /api/v1/admin/users/bob': (_url: URL, init?: RequestInit) => {
        const body = JSON.parse(String(init?.body)) as { disabled?: boolean };
        users = users.map((one) => (one.id === 'bob' ? { ...one, disabledAt: body.disabled ? '2026-11-10T20:00:00.000Z' : undefined } : one));
        return users[1];
      },
    });
    renderAt('/admin/users');
    const table = await screen.findByRole('table', { name: 'The users this server holds, by name' });
    expect(within(table).getAllByRole('rowheader').map((cell) => cell.textContent)).toEqual(['alice', 'bob']);
    const role = within(table).getByRole('combobox', { name: 'Role of alice' }) as HTMLSelectElement;
    await userEvent.selectOptions(role, 'reader');
    expect(sent(fetch, 'PATCH', '/api/v1/admin/users/alice')).toHaveLength(0);
    const setRole = within(table).getByRole('button', { name: 'Set Role of alice' });
    await userEvent.click(setRole);
    await waitFor(() =>
      expect(screen.getAllByRole('alert').some((line) => line.textContent === 'alice is the last admin who can sign in: make another account an admin first.')).toBe(
        true,
      ),
    );
    expect(sent(fetch, 'PATCH', '/api/v1/admin/users/alice')).toHaveLength(1);
    await waitFor(() => expect(role.value).toBe('admin'));
    expect(document.activeElement).toBe(setRole);

    await userEvent.click(within(table).getByRole('button', { name: 'Disable bob' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'Disable bob?' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'Disable' }));
    expect(await screen.findByRole('button', { name: 'Enable bob' })).toBe(document.activeElement);
    expect(JSON.parse(String(sent(fetch, 'PATCH', '/api/v1/admin/users/bob')[0]?.[1]?.body))).toEqual({ disabled: true });

    const add = screen.getByRole('region', { name: 'Add an Account' });
    await userEvent.type(within(add).getByLabelText('Name'), 'carol');
    await userEvent.selectOptions(within(add).getByLabelText('Role'), 'curator');
    await userEvent.type(within(add).getByLabelText('Password'), 'correct horse battery staple');
    await userEvent.type(within(add).getByLabelText('Password again'), 'correct horse battery stable');
    await userEvent.click(within(add).getByRole('button', { name: 'Add Account' }));
    expect(within(add).getByRole('alert').textContent).toBe('The two passwords differ.');
    expect(sent(fetch, 'POST', '/api/v1/admin/users')).toHaveLength(0);
    const again = within(add).getByLabelText('Password again') as HTMLInputElement;
    expect(again.value).toBe('');
    expect(document.activeElement).toBe(again);
    await userEvent.type(again, 'correct horse battery staple');
    await userEvent.click(within(add).getByRole('button', { name: 'Add Account' }));
    expect(await screen.findByText('Made carol’s account.')).toBeTruthy();
    expect(JSON.parse(String(sent(fetch, 'POST', '/api/v1/admin/users')[0]?.[1]?.body))).toEqual({
      name: 'carol',
      role: 'curator',
      password: 'correct horse battery staple',
    });
    expect((within(add).getByLabelText('Password') as HTMLInputElement).value).toBe('');
  });

  it('erases a user’s research after a question that names what they hold, counting again when it changed', async () => {
    const counted = (notes: number): ResearchHoldings => ({
      userId: 'bob',
      holdings: [
        { type: 'ResearchNote', table: 'notes', count: notes },
        { type: 'UserTag', table: 'tags', count: 2 },
        { type: 'StoredKey', table: 'secrets', count: 1 },
      ],
      total: notes + 3,
    });
    let notes = 3;
    let tries = 0;
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/users': { auth: 'local', users: [user({ id: 'alice', role: 'admin' }), user({ id: 'bob' })] },
      '/api/v1/admin/users/bob/research': () => counted(notes),
      'POST /api/v1/admin/users/bob/research/erase': () => {
        tries += 1;
        if (tries === 1) {
          notes = 4;
          return new ProblemAnswer(409, 'RESEARCH_CHANGED', 'changed');
        }
        return counted(notes);
      },
    });
    renderAt('/admin/users');
    await userEvent.click(await screen.findByRole('button', { name: 'Erase Research of bob' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'Erase the research of bob?' });
    expect(await within(dialog).findByText('3 Research Notes')).toBeTruthy();
    expect(within(dialog).getByText('2 Tags')).toBeTruthy();
    expect(within(dialog).getByText('1 Stored Keys')).toBeTruthy();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Erase' }));
    expect(await within(dialog).findByText('What they hold changed since it was counted, so nothing was erased. Here is what they hold now.')).toBeTruthy();
    expect(await within(dialog).findByText('4 Research Notes')).toBeTruthy();
    expect(document.activeElement).toBe(within(dialog).getByRole('button', { name: 'Erase' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Erase' }));
    expect(await screen.findByText('Erased 7 records of bob’s research.')).toBeTruthy();
    const bodies = sent(fetch, 'POST', '/api/v1/admin/users/bob/research/erase').map(([, init]) => JSON.parse(String(init?.body)) as unknown);
    expect(bodies).toEqual([{ expected: { notes: 3, tags: 2, secrets: 1 } }, { expected: { notes: 4, tags: 2, secrets: 1 } }]);
    expect(screen.getByRole('button', { name: 'Erase Research of bob' })).toBe(document.activeElement);
  });

  it('lists the backups with a link to the newest', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/status': status,
      '/api/v1/admin/backups': {
        backedUp: true,
        copiedToHost: true,
        backups: [
          { name: 'app-20261110T080000Z.db', kind: 'daily', takenAt: '2026-11-10T08:00:00Z', bytes: 2_097_152, migration: 6, copied: true },
          { name: 'app-20261110T070000Z-before-migration-6.db', kind: 'beforeMigration', takenAt: '2026-11-10T07:00:00Z', bytes: 1_024, migration: 5, copied: false },
        ],
      },
    });
    renderAt('/admin/backups');
    const link = await screen.findByRole('link', { name: 'Download the Newest Backup' });
    expect(link.getAttribute('href')).toBe('/api/v1/admin/backup');
    const table = screen.getByRole('table', { name: 'The backups and copies the server keeps, newest first' });
    expect(within(table).getAllByRole('row')[1]!.textContent).toContain('Daily');
    expect(within(table).getAllByRole('row')[2]!.textContent).toContain('Before a migration');
    expect(await screen.findByText(/every day at 03:00, America\/New_York/)).toBeTruthy();
  });

  it('keeps the instance’s NARA key with the Keys section', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/secrets': { secrets: [{ name: 'nara', set: false }] },
      'PUT /api/v1/admin/secrets/nara': { name: 'nara', set: true, updatedAt: '2026-11-10T20:00:00.000Z' },
    });
    renderAt('/admin/keys');
    const nara = await screen.findByRole('region', { name: 'NARA Catalog' });
    await userEvent.click(within(nara).getByRole('button', { name: 'Add Key…' }));
    await userEvent.type(within(nara).getByLabelText('NARA Catalog key'), 'P9NiFoyLeZu2bZNvvuQPDWsd{Enter}');
    expect(await within(nara).findByText('Key stored', { exact: true })).toBeTruthy();
    expect(sent(fetch, 'PUT', '/api/v1/admin/secrets/nara')).toHaveLength(1);
    expect(sent(fetch, 'PUT', '/api/v1/me/secrets/nara')).toHaveLength(0);
  });
});
