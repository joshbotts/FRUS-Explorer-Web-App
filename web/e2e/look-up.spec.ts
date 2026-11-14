// S22e's done-when (docs/PLAN.md): Playwright looks a passage up and sends a citation to a Zotero stub, by
// keyboard on Chromium with no axe violations. On the smoke test's Standalone server, with FRUS_E2E_LOOK_UP,
// whose FRUS_SERVICES_MIRROR names its stand-in of the NARA Catalog's API and of Zotero's, and whose index holds
// the three fixture volumes. In frus1961-63v06's d3, by caret browsing, Tab into the source note in the list of
// footnotes, three words selected, Alt+F10 to the selection bar, whose footnote's verbs are Look Up in NARA and
// Note; Look Up opens the sheet, whose Detected in This Passage reads the note's Lot 66 D 204, with its bundled
// record, first; it fills the search, and Search asks NARA's stand-in through the server; Escape closes it. Then
// Cite, by keyboard, and its Send to Zotero Library, which sends d3 to Zotero's stand-in. Each step with axe. The
// keys are placeholders the spec stores and clears through the API, as Settings ▸ Keys would.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { send } from './notes';

const lookingUp = !!process.env.FRUS_E2E_LOOK_UP;

// Caret browsing, in a worker of its own. Chromium keeps only the last --blink-settings, so the switch repeats the
// hover and pointer settings Playwright's headless launch passes.
test.use({
  launchOptions: {
    args: ['--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4,caretBrowsingEnabled=true'],
  },
});

/** Stores, or with no value clears, the user's placeholder keys. */
async function keys(page: Page, value?: { nara: string; zotero: string }) {
  for (const name of ['nara', 'zotero'] as const) {
    if (value) await send(page, 'PUT', `api/v1/me/secrets/${name}`, { value: value[name] });
    else await send(page, 'DELETE', `api/v1/me/secrets/${name}`);
  }
}

test('looks a passage up and sends a citation to Zotero, by keyboard', async ({ page }) => {
  test.skip(!lookingUp, 'runs on the smoke test’s Standalone server, with FRUS_E2E_LOOK_UP and its stand-ins of NARA and Zotero');
  // Three screens, each with an axe pass.
  test.setTimeout(90_000);
  await page.goto('doc/frus1961-63v06/d3');
  await keys(page, { nara: 'stub-nara-key-e2e-not-real', zotero: 'stub-zotero-key-e2e-not-real' });
  try {
    const frame = page.frameLocator('iframe.reader-frame');
    const footnotes = frame.locator('.footnotes-section');
    await expect(footnotes.getByText(/Presidential Correspondence: Lot 66 D 204/)).toBeAttached();
    const selection = () => frame.locator('body').evaluate(() => getSelection()?.toString() ?? '');

    // Into the source note in the list of footnotes by Tab, to Khrushchev's name, then a caret and three words.
    await tabTo(page, footnotes.getByRole('link', { name: 'Khrushchev' }), 120);
    await page.keyboard.press('ArrowRight');
    for (let word = 0; word < 3; word++) await page.keyboard.press('Control+Shift+ArrowRight');
    await expect.poll(selection).not.toBe('');

    // Alt+F10: the bar a footnote's selection has, Look Up in NARA and Note, the first in focus.
    await page.keyboard.press('Alt+F10');
    const bar = page.getByRole('toolbar', { name: 'Selection' });
    await expect(bar.getByRole('button')).toHaveText(['Look Up in NARA', 'Note']);
    await expect(bar.getByRole('button', { name: 'Look Up in NARA' })).toBeFocused();
    await axeCheck(page);
    await page.keyboard.press('Enter');

    // The sheet: the selection to search, and the readings of the note, its lot first, with the bundled record.
    const sheet = page.getByRole('dialog', { name: 'Look Up in NARA Catalog' });
    await expect(sheet.getByRole('heading', { name: 'Look Up in NARA Catalog' })).toBeFocused();
    const detected = sheet.getByRole('region', { name: 'Detected in This Passage' });
    const lot = detected.getByRole('button').first();
    await expect(lot).toContainText('Lot 66 D 204');
    await expect(lot).toContainText(/NAID \d+ — from the bundled index; no API key needed/);
    await expect(sheet.getByRole('radio', { name: 'Lot file — RG 59 (State Dept.)' })).toBeChecked();
    await axeCheck(page);
    await tabTo(page, lot);
    await page.keyboard.press('Enter');
    await expect(sheet.getByRole('textbox', { name: 'Search Text' })).toHaveValue('66 D 204');

    // Search, through the server's proxy, which asks NARA's stand-in with the key it keeps.
    const search = sheet.getByRole('button', { name: 'Search', exact: true });
    await tabTo(page, search);
    await page.keyboard.press('Enter');
    const results = sheet.getByRole('region', { name: 'NARA Catalog Results' });
    await expect(results.getByText('Presidential Correspondence (stand-in)')).toBeVisible();
    await expect(results.getByRole('status')).toHaveText('1 record found.');
    await expect(results.getByRole('link', { name: 'View in NARA Catalog' })).toHaveAttribute('href', 'https://catalog.archives.gov/id/596518');
    await axeCheck(page);
    await page.keyboard.press('Escape');
    await expect(sheet).toBeHidden();

    // Cite, from the toolbar, and its Send to Zotero Library, which sends d3 to Zotero's stand-in.
    const cite = page.getByRole('group', { name: 'Document' }).getByRole('button', { name: 'Cite', exact: true });
    await tabTo(page, cite, 120, 'Shift+Tab');
    await page.keyboard.press('Enter');
    const rail = page.getByRole('complementary', { name: 'Cite' });
    await expect(rail.getByRole('heading', { name: 'Cite' })).toBeFocused();
    const zotero = rail.getByRole('button', { name: 'Send to Zotero Library' });
    await tabTo(page, zotero);
    await page.keyboard.press('Enter');
    await expect(rail.locator('.zotero-result')).toHaveText('Sent to Zotero. Added 1 document and 0 notes to Zotero. View in Zotero');
    await expect(rail.getByRole('link', { name: 'View in Zotero' })).toHaveAttribute('href', 'https://www.zotero.org/frus-stub/library');
    await expect(zotero).toBeFocused();
    await axeCheck(page);
  } finally {
    await keys(page);
  }
});
