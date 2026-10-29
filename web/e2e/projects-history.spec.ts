// S17f's done-when (docs/PLAN.md, the same as S11c's, with the appendix the kit writes for the recorded
// trail): Playwright uses projects, Project Home, the history and its switch, the method appendix and
// the synced preferences, by keyboard where the app's own flows are, on Chromium with no axe
// violations. Against the image, with the synthetic export imported (frus1961-63v06's d1 and d2, and
// frus1894Nicaragua's d1), and the single user's store, which may hold the projects import.spec.ts
// brings. Each test removes what it made: its project, the trail, and its preferences set back.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { treatiesResults } from './expected';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { getJSON, send } from './notes';

interface Projects {
  items: { id: string; name: string; researchQuestion?: string }[];
  activeProjectId?: string;
}

/** Removes the projects named `name`, those a test made, and returns the user to Global Context. */
async function removeProjects(page: Page, name: string): Promise<void> {
  const list = await getJSON<Projects>(page, 'api/v1/me/projects');
  for (const project of list.items) if (project.name === name) await send(page, 'DELETE', `api/v1/me/projects/${project.id}`);
  await send(page, 'PUT', 'api/v1/me/active-project', { projectId: null });
}

/** Sets back what the tests set: the trail, and the preferences a user who has set nothing has. */
async function reset(page: Page): Promise<void> {
  await send(page, 'DELETE', 'api/v1/me/history');
  await send(page, 'PATCH', 'api/v1/me/preferences', {
    citationStyle: '',
    defaultDocumentMode: '',
    researchLoggingEnabled: true,
    tagOrder: [],
    projectOrder: [],
  });
}

test('makes a project, works in it, and sees its Project Home and history fill, by keyboard', async ({ page }) => {
  await page.goto('settings/projects');
  await reset(page);
  try {
    // New Project…, named and asked, saved with Return: it is the project the user works in.
    const projects = page.getByRole('heading', { level: 1, name: 'Projects' });
    await expect(projects).toBeVisible();
    const add = page.getByRole('button', { name: 'New Project…' });
    await tabTo(page, add);
    await page.keyboard.press('Enter');
    const editor = page.getByRole('dialog', { name: 'New Project' });
    await expect(editor.getByRole('textbox', { name: 'Project name' })).toBeFocused();
    await axeCheck(page);
    await page.keyboard.type('Grain diplomacy');
    await page.keyboard.press('Tab');
    await page.keyboard.type('How did treaties follow the grain?');
    await tabTo(page, editor.getByRole('button', { name: 'Save' }));
    await page.keyboard.press('Enter');
    await expect(editor).toHaveCount(0);
    await expect(add).toBeFocused();
    const picker = page.getByRole('combobox', { name: 'Switch project context' });
    await expect(picker.locator('option:checked')).toHaveText('Grain diplomacy');
    await expect(page.getByRole('combobox', { name: 'Active Project' }).locator('option:checked')).toHaveText('Grain diplomacy');
    await axeCheck(page);

    // Searched and read under it: "Working on:" over Search, and the trail records both.
    await page.goto('search?keywords=treaties');
    await expect(page.getByRole('list', { name: 'Results' }).getByRole('heading')).toHaveText(treatiesResults);
    await expect(page.getByText('How did treaties follow the grain?')).toBeVisible();
    await page.getByRole('link', { name: treatiesResults[0] }).click();
    await expect(page.getByRole('heading', { level: 1, name: treatiesResults[0] })).toBeVisible();

    // Project Home: its question, its tiles, and Recent Activity.
    await page.getByRole('link', { name: 'Project Home' }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Grain diplomacy' })).toBeVisible();
    const question = page.getByRole('textbox', { name: 'Research question' });
    await expect(question).toHaveValue('How did treaties follow the grain?');
    const recent = page.getByRole('region', { name: 'Recent Activity' });
    await expect(recent.getByRole('link', { name: treatiesResults[0] })).toBeVisible();
    await expect(recent.getByText('treaties', { exact: true })).toBeVisible();
    await expect(page.getByRole('listitem').filter({ hasText: 'Documents Visited' })).toContainText('1');
    await axeCheck(page);
    // The question, saved as it is typed.
    await question.fill('How did treaties follow the wheat?');
    await page.keyboard.press('Tab');
    await expect
      .poll(async () => (await getJSON<Projects>(page, 'api/v1/me/projects')).items.find((item) => item.name === 'Grain diplomacy')?.researchQuestion)
      .toBe('How did treaties follow the wheat?');

    // The History screen, from All Notes' Research navigation: the visit and the search, filtered, and a
    // row deleted.
    await page.goto('research/notes');
    await tabTo(page, page.getByRole('navigation', { name: 'Research', exact: true }).getByRole('link', { name: 'History' }));
    await page.keyboard.press('Enter');
    await expect(page.getByRole('heading', { level: 1, name: 'History' })).toBeFocused();
    const visited = page.getByRole('region', { name: 'Documents Visited' });
    await expect(visited.getByRole('link', { name: treatiesResults[0] })).toBeVisible();
    const searched = page.getByRole('region', { name: 'Searches Executed' });
    await expect(searched.getByRole('link', { name: 'treaties' })).toBeVisible();
    await expect(searched.getByText(/^2 results/)).toBeVisible();
    await axeCheck(page);
    await tabTo(page, page.getByRole('searchbox', { name: 'Search history' }));
    await page.keyboard.type('frus1961');
    await expect(searched.getByText('No Matches')).toBeVisible();
    await page.keyboard.press('ControlOrMeta+a');
    await page.keyboard.press('Backspace');
    const remove = searched.getByRole('button', { name: 'Delete treaties' });
    await tabTo(page, remove);
    await page.keyboard.press('Enter');
    await expect(searched.getByText('No Searches Executed')).toBeVisible();
    await axeCheck(page);
  } finally {
    await removeProjects(page, 'Grain diplomacy');
    await reset(page);
  }
});

test('stops the trail with Log Research Sessions, reads the Session Log, and deletes the trail', async ({ page }) => {
  await page.goto('settings/sessions');
  await reset(page);
  try {
    // A visit recorded while the switch is on.
    await page.goto('doc/frus1961-63v06/d2');
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Memorandum');
    await page.goto('settings/sessions');
    const logging = page.getByRole('switch', { name: 'Log Research Sessions' });
    await expect(logging).toBeChecked();
    await expect(page.getByRole('link', { name: /^Session Log/ })).toContainText('1 session · 1 event');
    await axeCheck(page);
    await tabTo(page, logging);
    await page.keyboard.press('Space');
    await expect(logging).not.toBeChecked();
    await expect.poll(async () => (await getJSON<{ researchLoggingEnabled: boolean }>(page, 'api/v1/me/preferences')).researchLoggingEnabled).toBe(false);

    // Off, nothing new is recorded, and the History screen says so.
    await page.goto('doc/frus1961-63v06/d1');
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Telegram');
    await page.goto('research/history');
    const visited = page.getByRole('region', { name: 'Documents Visited' });
    await expect(visited.getByText(/Research logging is off/)).toBeVisible();
    await expect(visited.getByRole('link')).toHaveCount(1);
    await axeCheck(page);

    // The Session Log, its one session opened.
    await page.goto('settings/sessions/log');
    const session = page.locator('details').first();
    await expect(session).toContainText('1 event');
    await session.locator('summary').click();
    await expect(session.getByText(treatiesResults[1])).toBeVisible();
    await axeCheck(page);

    // Delete Recorded Sessions…, asked first, naming the events.
    await page.goto('settings/sessions');
    const deleteAll = page.getByRole('button', { name: 'Delete Recorded Sessions…' });
    await tabTo(page, deleteAll);
    await page.keyboard.press('Enter');
    const ask = page.getByRole('alertdialog', { name: 'Delete Recorded Sessions?' });
    await expect(ask.getByText(/^1 event will be permanently deleted/)).toBeVisible();
    await axeCheck(page);
    await ask.getByRole('button', { name: 'Delete' }).click();
    await expect(ask).toHaveCount(0);
    await expect(page.getByRole('link', { name: /^Session Log/ })).toContainText('Nothing recorded yet');
    await expect(deleteAll).toBeDisabled();
  } finally {
    await reset(page);
  }
});

test('exports the method appendix the kit writes for the searches recorded', async ({ page }) => {
  await page.goto('settings/data');
  await reset(page);
  try {
    await page.goto('search?keywords=treaties');
    await expect(page.getByRole('list', { name: 'Results' }).getByRole('heading')).toHaveText(treatiesResults);
    await page.goto('search?keywords=zanzibar');
    // The second run recorded, which found nothing.
    await expect.poll(async () => (await getJSON<{ totalSearches: number }>(page, 'api/v1/me/history')).totalSearches).toBe(2);
    await page.goto('settings/data');
    const markdown = page.getByRole('link', { name: 'Markdown table (frus-query-log.md)' });
    await expect(markdown).toBeVisible();
    await axeCheck(page);
    const [file] = await Promise.all([page.waitForEvent('download'), markdown.click()]);
    expect(file.suggestedFilename()).toBe('frus-query-log.md');
    const text = await (await file.createReadStream()).toArray().then((chunks) => Buffer.concat(chunks).toString('utf8'));
    expect(text).toContain('# Query log — method appendix');
    expect(text).toMatch(/\| treaties \| 2 \| \d+ \|/);
    expect(text).toContain('One of these searches returned nothing.');
    const [csv] = await Promise.all([page.waitForEvent('download'), page.getByRole('link', { name: 'CSV (frus-query-log.csv)' }).click()]);
    const rows = await (await csv.createReadStream()).toArray().then((chunks) => Buffer.concat(chunks).toString('utf8'));
    expect(rows).toContain('executed_at,query,count_basis,match_count,loaded_count,fetch_limit');
    // An exact count's match and loaded, and no fetch limit, which the kit writes for a floor alone.
    expect(rows).toMatch(/"zanzibar",exact,0,0,,,\d+,/);
  } finally {
    await reset(page);
  }
});

test('keeps the citation style and the mode documents open in, the user’s own', async ({ page }) => {
  await page.goto('settings/reading');
  await reset(page);
  try {
    const mode = page.getByRole('combobox', { name: 'Open Documents In' });
    await tabTo(page, mode);
    await mode.selectOption('research');
    await page.getByRole('combobox', { name: 'Citation Style' }).selectOption('chicago');
    await expect.poll(async () => (await getJSON<{ citationStyle: string; defaultDocumentMode: string }>(page, 'api/v1/me/preferences')).citationStyle).toBe('chicago');
    await axeCheck(page);

    // A document opened from a list opens with the Research rail; Cite opens in Chicago.
    await page.goto('search?keywords=treaties');
    await page.getByRole('list', { name: 'Results' }).getByRole('link', { name: treatiesResults[1] }).click();
    await expect(page).toHaveURL(/[?&]rail=research/);
    await expect(page.getByRole('complementary', { name: 'Research' })).toBeVisible();
    await page.getByRole('button', { name: 'Cite' }).click();
    await expect(page.getByRole('radio', { name: 'Chicago' })).toBeChecked();
    await axeCheck(page);
  } finally {
    await reset(page);
  }
});
