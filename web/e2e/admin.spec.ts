// S20d's done-when (docs/PLAN.md): Playwright by keyboard on Chromium with no axe violations, through
// Administration as the image's single user, an admin: the header's Admin link to Status, whose Reset the
// Index… asks first and is cancelled; Jobs, which names the import that made the index, finished; Users,
// whose Erase Research… names what the user holds and is cancelled; Backups; and Keys, where the
// instance's NARA key is set and cleared, leaving none. The header's Admin link keeps focus, as the
// header's links do, since the header stays; a pane's link takes it to the new pane's heading, since
// each pane draws the panes' list afresh. It changes nothing a later spec reads: no reset, no erasure,
// and no key left. It runs at the root and again under the path.
import type { Locator } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';
import { getJSON, send } from './notes';

interface SecretList {
  secrets: { name: string; set: boolean }[];
}

const key = 'e2e-instance-nara-4Rk8sTq';

test('walks Administration by keyboard alone, asking before each recovery action and taking none', async ({ page }) => {
  await page.goto('browse');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  const admin = page.getByRole('navigation', { name: 'Main' }).getByRole('link', { name: 'Admin', exact: true });
  await tabTo(page, admin);
  await page.keyboard.press('Enter');

  /**
   * The pane a link opened: its address and its heading, the link the current page's, and focus on the
   * heading, or with `keeps`, on the link.
   */
  async function opened(link: Locator, path: RegExp, title: string, keeps = false) {
    await expect(page).toHaveURL(path);
    const heading = page.getByRole('heading', { level: 1, name: title, exact: true });
    await expect(heading).toBeVisible();
    await expect(link).toHaveAttribute('aria-current', 'page');
    await expect(keeps ? link : heading).toBeFocused();
  }

  // Status, the first pane.
  await opened(admin, /admin\/status$/, 'Status', true);
  await expect(page.getByText('app.db, SQLite')).toBeVisible();
  await expect(page.getByText('Import: an index exported from the Mac')).toBeVisible();
  await axeCheck(page);
  const reset = page.getByRole('button', { name: 'Reset the Index…' });
  await tabTo(page, reset, 60);
  await page.keyboard.press('Enter');
  const question = page.getByRole('alertdialog', { name: 'Reset the index?' });
  await expect(question.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(question).toHaveCount(0);
  await expect(reset).toBeFocused();

  // Jobs: the import that made the index, finished.
  const panes = page.getByRole('navigation', { name: 'Administration' });
  const jobsLink = panes.getByRole('link', { name: 'Jobs', exact: true });
  await backTabTo(page, jobsLink, 60);
  await page.keyboard.press('Enter');
  await opened(jobsLink, /admin\/jobs$/, 'Jobs');
  const jobs = page.getByRole('table', { name: 'The jobs the server holds, newest first' });
  const imported = jobs.getByRole('row').filter({ has: page.getByRole('rowheader', { name: 'Index import: export.sqlite', exact: true }) });
  await expect(imported.first()).toBeVisible();
  await expect(imported.first().getByText('Finished', { exact: true })).toBeVisible();
  await axeCheck(page);

  // Users: the single user, an admin, whose Erase Research… names what they hold, and is cancelled.
  // From the heading, back into the panes' list, which comes before it.
  const usersLink = panes.getByRole('link', { name: 'Users', exact: true });
  await backTabTo(page, usersLink);
  await page.keyboard.press('Enter');
  await opened(usersLink, /admin\/users$/, 'Users');
  const users = page.getByRole('table', { name: 'The users this server holds, by name' });
  await expect(users.getByRole('rowheader', { name: 'owner', exact: true })).toBeVisible();
  await expect(page.getByText('This server has no sign-in: it has one user, owner, who holds every role.')).toBeVisible();
  await axeCheck(page);
  const erase = users.getByRole('button', { name: 'Erase Research of owner', exact: true });
  await tabTo(page, erase);
  await page.keyboard.press('Enter');
  const asking = page.getByRole('alertdialog', { name: 'Erase the research of owner?' });
  await expect(asking.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await expect(asking.getByText(/owner holds/)).toBeVisible();
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(asking).toHaveCount(0);
  await expect(erase).toBeFocused();

  // Backups.
  const backupsLink = panes.getByRole('link', { name: 'Backups', exact: true });
  await backTabTo(page, backupsLink, 60);
  await page.keyboard.press('Enter');
  await opened(backupsLink, /admin\/backups$/, 'Backups');
  await expect(page.getByText(/The server backs up its user store every day/)).toBeVisible();
  await axeCheck(page);

  // Keys: the instance's NARA key, set and cleared by keyboard, leaving none.
  await send(page, 'DELETE', 'api/v1/admin/secrets/nara');
  try {
    const keysLink = panes.getByRole('link', { name: 'Keys', exact: true });
    await backTabTo(page, keysLink);
    await page.keyboard.press('Enter');
    await opened(keysLink, /admin\/keys$/, 'Keys');
    const nara = page.getByRole('region', { name: 'NARA Catalog' });
    await expect(nara.getByText('No key stored', { exact: true })).toBeVisible();
    await axeCheck(page);
    await tabTo(page, nara.getByRole('button', { name: 'Add Key…' }));
    await page.keyboard.press('Enter');
    await expect(nara.getByLabel('NARA Catalog key')).toBeFocused();
    await page.keyboard.type(key);
    await page.keyboard.press('Enter');
    await expect(nara.getByText('Key stored', { exact: true })).toBeVisible();
    expect(await page.content()).not.toContain(key);
    const stored = await getJSON<SecretList>(page, 'api/v1/admin/secrets');
    expect(stored.secrets.find((secret) => secret.name === 'nara')?.set).toBe(true);
    const mine = await getJSON<SecretList>(page, 'api/v1/me/secrets');
    expect(mine.secrets.find((secret) => secret.name === 'nara')?.set).toBe(false);
    await tabTo(page, nara.getByRole('button', { name: 'Remove Key' }));
    await page.keyboard.press('Enter');
    const removal = page.getByRole('alertdialog', { name: 'Remove the stored key?' });
    await expect(removal.getByText('The server forgets the instance’s key: a user with no key of their own then has none.')).toBeVisible();
    await axeCheck(page);
    await tabTo(page, removal.getByRole('button', { name: 'Remove', exact: true }));
    await page.keyboard.press('Enter');
    await expect(nara.getByText('No key stored', { exact: true })).toBeVisible();
    await axeCheck(page);
  } finally {
    await send(page, 'DELETE', 'api/v1/admin/secrets/nara');
  }
});
