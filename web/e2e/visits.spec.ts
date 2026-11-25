// S30c's done-when (docs/PLAN.md): Playwright makes a plan, adds a tier, sets a target's tier and note and excludes one, by
// keyboard on Chromium with no axe violations. In the main suite, over the synthetic export, whose documents carry no
// source note, a plan is made from the list, named, copied and deleted by keyboard, axe at each page. With
// FRUS_E2E_VISITS, on the smoke test's Standalone server, whose index holds the three fixture volumes, a project with
// notes on three documents of frus1961-63v06 is made through the API; then, by keyboard, New Archives Visit makes a plan
// under it, Re-seed from Project seeds it with the project's documents, which derive two lots at College Park and a note
// the server cannot place, the tiers' sheet adds a tier, a lot is given the tier and a note and the other lot excluded,
// axe at each step; and the plan, the notes and the project are deleted after, since the store outlives the run.
import type { Locator, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';

const planning = !!process.env.FRUS_E2E_VISITS;

/** Moves focus to `target` by keyboard from wherever it is: Tab forward, else Shift+Tab back. */
async function reach(page: Page, target: Locator) {
  const focused = await target.evaluate((element) => element === document.activeElement).catch(() => false);
  if (focused) return;
  try {
    await tabTo(page, target, 40);
  } catch {
    await backTabTo(page, target, 80);
  }
}

/** Opens the menu `button` opens by keyboard and chooses `item`, the arrow keys moving to it from the first. */
async function choose(page: Page, button: Locator, item: string) {
  await reach(page, button);
  await page.keyboard.press('Enter');
  const menu = page.getByRole('menu');
  await expect(menu).toBeVisible();
  const items = await menu.getByRole('menuitem').allTextContents();
  for (let steps = 0; steps < items.indexOf(item); steps++) await page.keyboard.press('ArrowDown');
  await expect(menu.getByRole('menuitem', { name: item, exact: true })).toBeFocused();
  await page.keyboard.press('Enter');
}

/** Chooses `item` from the editor's More menu, by keyboard. */
function more(page: Page, item: string) {
  return choose(page, page.getByRole('button', { name: 'More', exact: true }), item);
}

/** Confirms the question before a delete, by keyboard: Cancel first, then the destructive button after it. */
async function confirmDelete(page: Page) {
  const question = page.getByRole('alertdialog', { name: 'Delete this Archives Visit?' });
  await expect(question.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(question.getByRole('button', { name: 'Delete' })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(question).toHaveCount(0);
}

test('makes, names, copies and deletes an Archives Visit from the list by keyboard', async ({ page }) => {
  test.skip(planning, 'the Standalone server’s plan is the test below');
  test.setTimeout(60_000);
  await page.goto('visits');
  await expect(page.getByRole('heading', { level: 1, name: 'Archives Visits' })).toBeVisible();
  await axeCheck(page);
  await tabTo(page, page.getByRole('button', { name: 'New Archives Visit' }), 60);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/visits\/[0-9A-F-]{36}$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Archives Visit' })).toBeFocused();
  const name = page.getByRole('textbox', { name: 'Archive visit name' });
  await tabTo(page, name);
  await page.keyboard.type('Spec visit');
  await page.keyboard.press('Enter');
  await expect(page).toHaveTitle(/^Spec visit/);
  // The synthetic export's documents carry no source note: a plan with none seeded says how to seed one.
  await expect(page.getByRole('heading', { level: 2, name: 'No documents seeded' })).toBeVisible();
  await axeCheck(page);

  await more(page, 'Duplicate');
  await expect(page.getByRole('status').filter({ hasText: 'Duplicated as “Spec visit copy”' })).toBeVisible();
  await more(page, 'Delete');
  await confirmDelete(page);
  await expect(page).toHaveURL(/visits$/);

  // The copy, deleted from its row's menu.
  const row = page.getByRole('listitem').filter({ has: page.getByRole('link', { name: 'Spec visit copy', exact: true }) });
  await expect(row).toBeVisible();
  await expect(page.getByRole('link', { name: 'Spec visit', exact: true })).toHaveCount(0);
  await axeCheck(page);
  await choose(page, row.getByRole('button', { name: 'Actions for Spec visit copy' }), 'Delete');
  await confirmDelete(page);
  await expect(page.getByRole('link', { name: 'Spec visit copy', exact: true })).toHaveCount(0);
});

test('plans a visit by keyboard: seeds it from its project, adds a tier, sets a target’s tier and note and excludes one', async ({ page }) => {
  test.skip(!planning, 'runs on the smoke test’s Standalone server, with FRUS_E2E_VISITS');
  // Five pages' axe passes, a derivation over the index and a dozen writes.
  test.setTimeout(120_000);
  await page.goto('visits');
  await expect(page.getByRole('heading', { level: 1, name: 'Archives Visits' })).toBeVisible();
  // A project with notes on three documents, the seed Re-seed from Project gathers: d1, a note the server cannot
  // place, and d10 and d100, two lots at College Park. Making the project makes it the one the user works in.
  const made = await page.evaluate(async () => {
    const base = document.baseURI;
    const me = (await (await fetch(new URL('api/v1/me', base))).json()) as { csrfToken: string };
    const headers = { 'Content-Type': 'application/json', 'X-CSRF-Token': me.csrfToken, Accept: 'application/json' };
    const project = (await (
      await fetch(new URL('api/v1/me/projects', base), {
        method: 'POST',
        headers,
        body: JSON.stringify({ name: 'Visits spec', researchQuestion: 'What did the two leaders write to each other?' }),
      })
    ).json()) as { id: string };
    const notes: string[] = [];
    for (const document of ['d1', 'd10', 'd100']) {
      const note = (await (
        await fetch(new URL(`api/v1/me/volumes/frus1961-63v06/documents/${document}/notes`, base), {
          method: 'POST',
          headers,
          body: JSON.stringify({ bodyText: 'For the visit', runs: null, userTagIds: [], projectIds: [project.id], selectedSummaryIds: [] }),
        })
      ).json()) as { id: string };
      notes.push(note.id);
    }
    return { project: project.id, notes };
  });
  try {
    await tabTo(page, page.getByRole('button', { name: 'New Archives Visit' }), 60);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('heading', { level: 1, name: 'Archives Visit' })).toBeFocused();
    await expect(page.getByRole('heading', { level: 2, name: 'No documents seeded' })).toBeVisible();
    await axeCheck(page);

    // Re-seed from Project: the project's three documents; the topic is its question already, so nothing is asked.
    await more(page, 'Re-seed from Project');
    await expect(page.getByRole('heading', { level: 2, name: 'National Archives at College Park' })).toBeVisible();
    await expect(page.getByRole('heading', { level: 2, name: 'Confirm before you travel' })).toBeVisible();
    await expect(page.getByText('3 targets across 1 repository.')).toBeVisible();
    await axeCheck(page);

    // Priority Tiers…: Add a priority tier, which reads "Priority 1".
    await more(page, 'Priority Tiers…');
    const sheet = page.getByRole('dialog', { name: 'Priority Tiers' });
    await expect(sheet).toBeVisible();
    await reach(page, sheet.getByRole('button', { name: 'Add a priority tier' }));
    await page.keyboard.press('Enter');
    await expect(sheet.getByText('Priority 1', { exact: true })).toBeVisible();
    await expect(sheet.getByText('0 targets')).toBeVisible();
    await axeCheck(page);
    await reach(page, sheet.getByRole('button', { name: 'Done' }));
    await page.keyboard.press('Enter');
    await expect(sheet).toHaveCount(0);

    // The first lot: its tier, then its note.
    const lot = 'Files, Lot 66 D 204, RG 59, Department of State';
    const tier = page.getByRole('button', { name: `Tier of ${lot}: Set tier` });
    await reach(page, tier);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('menuitem', { name: 'Unprioritized' })).toBeFocused();
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('menuitem', { name: 'Priority 1' })).toBeFocused();
    await page.keyboard.press('Enter');
    const tiered = page.getByRole('button', { name: `Tier of ${lot}: Priority 1` });
    await expect(tiered).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(page.getByRole('button', { name: `Actions for ${lot}` })).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page.getByRole('menuitem', { name: 'Edit Note…' })).toBeFocused();
    await page.keyboard.press('Enter');
    const note = page.getByRole('dialog', { name: 'Target Note' });
    await expect(note.getByRole('textbox', { name: 'Note' })).toBeFocused();
    await page.keyboard.type('Box 4, the Vienna letters');
    await page.keyboard.press('Enter');
    await expect(note).toHaveCount(0);
    await expect(page.getByText('Box 4, the Vienna letters')).toBeVisible();
    await expect(page.getByRole('button', { name: `Actions for ${lot}` })).toBeFocused();

    // The other lot, excluded from the packet.
    const other = 'Files, Lot 77 D 163, RG 59, Department of State';
    await reach(page, page.getByRole('button', { name: `Actions for ${other}` }));
    await page.keyboard.press('Enter');
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('menuitem', { name: 'Exclude from Packet' })).toBeFocused();
    await page.keyboard.press('Enter');
    const excluded = page.getByRole('listitem').filter({ has: page.getByRole('button', { name: other, exact: true }) });
    await expect(excluded.getByText('Excluded from the exported packet')).toBeVisible();
    await expect(page.getByText('Box 4, the Vienna letters')).toBeVisible();
    await axeCheck(page);

    // The tier filter narrows the list to the tier's one target.
    await reach(page, page.getByRole('combobox', { name: 'Tier' }));
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('button', { name: other, exact: true })).toHaveCount(0);
    await expect(page.getByRole('button', { name: lot, exact: true })).toBeVisible();

    // The plan deleted, by keyboard, with what it holds.
    await more(page, 'Delete');
    await confirmDelete(page);
    await expect(page).toHaveURL(/visits$/);
  } finally {
    await page.evaluate(async ({ project, notes }) => {
      const base = document.baseURI;
      const me = (await (await fetch(new URL('api/v1/me', base))).json()) as { csrfToken: string };
      const headers = { 'X-CSRF-Token': me.csrfToken };
      for (const note of notes) await fetch(new URL(`api/v1/me/notes/${note}`, base), { method: 'DELETE', headers });
      await fetch(new URL(`api/v1/me/projects/${project}`, base), { method: 'DELETE', headers });
    }, made);
  }
});
