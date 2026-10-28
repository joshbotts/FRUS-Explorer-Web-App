// S17d's done-when (docs/PLAN.md): Playwright searches the researcher's notes, summaries and tags,
// by keyboard, on Chromium with no axe violations: Search in's chips, My Tags with its counts, the
// Tags token, and a row's tags. Against the image, with the synthetic export imported (three
// documents: frus1961-63v06's d1 and d2, and frus1894Nicaragua's d1), and the single user's store,
// which starts with no notes, summaries of their own or tags. The test writes its own through the
// API, and leaves the store with none, since the suite runs twice on one store.
import { axeCheck } from './axe';
import { treatiesResults } from './expected';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { removeNotesAndSummaries, send } from './notes';

const documentPath = (volume: string, document: string) => `api/v1/me/volumes/${volume}/documents/${document}`;

test('searches the researcher’s notes, summaries and tags, as Search in and My Tags choose them, by keyboard alone', async ({ page }) => {
  await page.goto('search');
  const tag = (await send(page, 'POST', 'api/v1/me/tags', { name: 'Berlin' })) as { id: string };
  await send(page, 'PUT', `${documentPath('frus1961-63v06', 'd1')}/tags`, { tagIds: [tag.id] });
  await send(page, 'POST', `${documentPath('frus1961-63v06', 'd1')}/notes`, {
    bodyText: 'A zanzibar cable',
    runs: null,
    userTagIds: [],
    projectIds: [],
    selectedSummaryIds: [],
  });
  const summary = (await send(page, 'POST', `${documentPath('frus1961-63v06', 'd2')}/summaries`, {
    responseText: 'A quixotic proposal.',
  })) as { id: string };
  try {
    // The note's word, the summary's and the corpus's, each in its document; d1's row carries its tag.
    await page.goto('search?keywords=zanzibar+OR+quixotic+OR+canal');
    const results = page.getByRole('list', { name: 'Results' });
    const titles = results.getByRole('heading');
    await expect(titles).toHaveCount(3);
    await expect(page.getByRole('list', { name: 'Your tags' })).toHaveCount(1);
    await expect(page.getByRole('list', { name: 'Your tags' }).getByRole('listitem')).toHaveText(['◆ Berlin']);
    await axeCheck(page);

    // Search in: Notes off leaves the note's document out, Summaries off the summary's, and with all
    // three off there is nowhere to search, as the Mac's window says.
    const searchIn = page.getByRole('group', { name: 'Search in' });
    const chip = (name: string) => searchIn.getByRole('button', { name, exact: true });
    await tabTo(page, chip('Notes'));
    await page.keyboard.press('Enter');
    await expect(chip('Notes')).toHaveAttribute('aria-pressed', 'false');
    await expect(chip('Notes')).toBeFocused();
    await expect(page).toHaveURL(/[?&]includeNotes=false(&|$)/);
    await expect(titles).toHaveCount(2);
    await expect(page.getByRole('list', { name: 'Your tags' })).toHaveCount(0);
    await tabTo(page, chip('Summaries'));
    await page.keyboard.press('Space');
    await expect(titles).toHaveCount(1);
    await expect(titles).toHaveText(['No. 1. Mr. Baker to Mr. Gresham']);
    await page.keyboard.press('Shift+Tab');
    await page.keyboard.press('Shift+Tab');
    await expect(chip('Documents')).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page.getByRole('alert')).toHaveText('Enable at least one of Documents, Notes, or Summaries to search.');
    await axeCheck(page);
    // Each on again, from Documents, which has the focus, along the row.
    for (const [index, name] of ['Documents', 'Notes', 'Summaries'].entries()) {
      if (index > 0) await page.keyboard.press('Tab');
      await expect(chip(name)).toBeFocused();
      await page.keyboard.press('Enter');
      await expect(chip(name)).toHaveAttribute('aria-pressed', 'true');
    }
    await expect(page).not.toHaveURL(/include(DocumentText|Notes|Summaries)=/);
    await expect(titles).toHaveCount(3);

    // My Tags: opened, its tag counted over the results; switched on, it filters them, and shows as
    // a token, which clears it and gives the search box the focus.
    const myTags = page.locator('details.my-tags > summary');
    await tabTo(page, myTags);
    await page.keyboard.press('Enter');
    const berlin = page.getByRole('checkbox', { name: 'Berlin: 1 documents in your current results' });
    await expect(berlin).toBeVisible();
    await expect(page.getByText('Counts are documents in your current results carrying that tag.')).toBeVisible();
    await axeCheck(page);
    await tabTo(page, berlin);
    await page.keyboard.press('Space');
    await expect(berlin).toBeChecked();
    await expect(page).toHaveURL(new RegExp(`[?&]userTagIds=${tag.id}(&|$)`));
    await expect(titles).toHaveText([treatiesResults[0]!]);
    await expect(myTags).toHaveText('My Tags 1 selected');
    const token = page.getByRole('button', { name: 'Tags Berlin, clear this filter' });
    await expect(token).toBeVisible();
    await axeCheck(page);
    await tabTo(page, token);
    await page.keyboard.press('Enter');
    await expect(token).toHaveCount(0);
    await expect(page.getByRole('searchbox')).toBeFocused();
    await expect(titles).toHaveCount(3);
  } finally {
    await removeNotesAndSummaries(page);
    await send(page, 'DELETE', `api/v1/me/summaries/${summary.id}`);
  }
});
