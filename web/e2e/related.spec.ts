// S23d's done-when (docs/PLAN.md): Playwright opens Related and refreshes the leads by keyboard on
// Chromium with no axe violations. Against the image, with the synthetic export imported. From the
// reader, Related opens the document's list; the scope and a weight change by keyboard, the weight kept
// for the next list as the app keeps its device's, and ranked though the scope's list comes while the
// weight's step rests; a row opens its document, and Back returns to the list as it was. Then a project
// with a note on a document has its leads found again by keyboard, Project Home saying so while the
// server finds them. The test removes its project, its note and the trail, and forgets the tuning.
// S26d's: the semantic axis's weight is raised by keyboard, a row it scored is marked helpful from its menu, by
// keyboard, Beyond your library follows the rows, and Settings ▸ Data lists the verdict, over the image's shards;
// the test clears its verdicts. S29g's: the keyboard reaches a row matched by meaning and reads its chip, the words it
// shares with the document, and, with the lexical axis raised by keyboard, the same words under it.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { getJSON, removeNotesAndSummaries, send } from './notes';

const name = 'Related documents test';

interface Home {
  leads: { volumeId: string; documentId: string }[];
  leadsRefresh?: { state: string };
}

async function reset(page: Page): Promise<void> {
  const list = await getJSON<{ items: { id: string; name: string }[] }>(page, 'api/v1/me/projects');
  for (const project of list.items) if (project.name === name) await send(page, 'DELETE', `api/v1/me/projects/${project.id}`);
  await send(page, 'PUT', 'api/v1/me/active-project', { projectId: null });
  await removeNotesAndSummaries(page);
  await send(page, 'DELETE', 'api/v1/me/history');
  await send(page, 'DELETE', 'api/v1/me/semantic-feedback');
  await page.evaluate(() => localStorage.removeItem('frus.related.weights'));
}

test('opens Related from the reader by keyboard, changes its scope and a weight, and refreshes the leads', async ({ page }) => {
  await page.goto('research');
  await reset(page);
  let deliver = () => {};
  const held = new Promise<void>((resolve) => {
    deliver = resolve;
  });
  try {
    await page.goto('doc/frus1961-63v06/d1');
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    const related = page.getByRole('group', { name: 'Document' }).getByRole('link', { name: 'Related', exact: true });
    await tabTo(page, related);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/related\/frus1961-63v06\/d1/);
    const heading = page.getByRole('heading', { level: 1, name: 'Related Documents' });
    await expect(heading).toBeFocused();
    // The list, or the app's sentence for none, once ranked.
    const list = page.locator('ol.related-list');
    const empty = page.getByRole('heading', { level: 2, name: 'No Related Documents' });
    await expect(list.or(empty).first()).toBeVisible();
    await expect(page.getByText('Ranking the related documents…')).toHaveCount(0);
    await axeCheck(page);

    // The scope, by keyboard: the picker is a group of radios, as the app's segmented control. This volume's
    // list is held until the weight below has stepped, as a list ranked for a scope chosen just before may
    // come under load: one that comes while a step rests leaves the step to settle and be ranked (S23d's
    // second follow-up, after this test failed so under load).
    await page.route(
      /\/api\/v1\/volumes\/frus1961-63v06\/documents\/d1\/related\?scope=volume$/,
      async (route) => {
        const response = await route.fetch();
        await held;
        await route.fulfill({ response }).catch(() => {});
      },
      { times: 1 },
    );
    const thisVolume = page.getByRole('radio', { name: 'This volume' });
    await tabTo(page, page.getByRole('radio', { checked: true }));
    await expect(page.getByRole('radio', { name: 'All volumes' })).toBeChecked();
    // The arrow keys move the choice along the group, as a segmented control's, to This volume, its first,
    // each choice shown at once.
    const scopes = await page.getByRole('radio').count();
    for (let step = 1; step < scopes; step += 1) await page.keyboard.press('ArrowLeft');
    await expect(thisVolume).toBeChecked();
    await expect(page).toHaveURL(/scope=volume/);
    await expect(thisVolume).toBeFocused();

    // A weight, by keyboard: Adjust weights opens, and Corpus proximity's slider moves up by a step.
    await tabTo(page, page.getByText('Adjust weights'));
    await page.keyboard.press('Enter');
    const proximity = page.getByRole('slider', { name: 'Corpus proximity' });
    await tabTo(page, proximity);
    await page.keyboard.press('ArrowRight');
    // This volume's list comes while the step rests.
    deliver();
    await expect(proximity).toHaveValue('0.4');
    await expect(page).toHaveURL(/weights=subseries%3A0\.4/);
    await expect.poll(() => page.evaluate(() => localStorage.getItem('frus.related.weights'))).toBe('subseries:0.4');
    // The slider kept its place, and the focus, through the new ranking.
    await expect(proximity).toBeFocused();
    // Every axis ranks since S26d, the experimental ones saying what they are where their sliders are.
    await expect(page.getByRole('slider', { name: 'Semantically similar (experimental)' })).toBeEnabled();
    await expect(page.getByText(/^Matches carry a “Semantic match” score/)).toBeVisible();
    await expect(page.getByRole('slider', { name: 'Similar wording (experimental)' })).toBeEnabled();
    await expect(page.getByRole('slider', { name: 'Cross-references' })).toBeEnabled();
    await axeCheck(page);
    const resetWeights = page.getByRole('button', { name: 'Reset to app defaults' });
    await tabTo(page, resetWeights);
    await page.keyboard.press('Enter');
    await expect(proximity).toHaveValue('0.3');
    await expect.poll(() => page.evaluate(() => localStorage.getItem('frus.related.weights'))).toBeNull();
    // The focus goes back to the weights' heading, Reset being unavailable once it has reset.
    await expect(page.getByText('Adjust weights')).toBeFocused();

    // A row opens its document, and Back returns to the list as it was. The synthetic export gives d1 no
    // document of its archival container; its rows are the semantic axis's, over the image's shards.
    if ((await list.count()) > 0) {
      const first = list.getByRole('link').first();
      const title = (await first.textContent()) ?? '';
      await tabTo(page, first);
      await page.keyboard.press('Enter');
      await expect(page).toHaveURL(/\/doc\//);
      await page.goBack();
      await expect(page.getByRole('link', { name: title, exact: true }).first()).toBeVisible();
      await expect(page.getByRole('radio', { name: 'This volume' })).toBeChecked();
    }

    // Suggested Next: a project with a note on a document, whose leads the server finds again.
    const project = (await send(page, 'POST', 'api/v1/me/projects', { name })) as { id: string };
    await send(page, 'POST', 'api/v1/me/volumes/frus1961-63v06/documents/d1/notes', {
      bodyText: 'A seed',
      runs: null,
      userTagIds: [],
      projectIds: [project.id],
      selectedSummaryIds: [],
    });
    await page.goto(`projects/${project.id}`);
    const leads = page.getByRole('region', { name: 'Suggested Next' });
    const refresh = leads.getByRole('button', { name: 'Refresh' });
    await tabTo(page, refresh);
    await page.keyboard.press('Enter');
    await expect.poll(async () => (await getJSON<Home>(page, `api/v1/me/projects/${project.id}/home`)).leadsRefresh?.state).toBe('succeeded');
    await expect(leads.getByText('Finding leads…')).toHaveCount(0);
    await expect(refresh).toBeFocused();
    await expect(refresh).toHaveAttribute('aria-disabled', 'false');
    const home = await getJSON<Home>(page, `api/v1/me/projects/${project.id}/home`);
    for (const lead of home.leads) expect(`${lead.volumeId}/${lead.documentId}`).not.toBe('frus1961-63v06/d1');
    await axeCheck(page);
  } finally {
    deliver();
    await page.unrouteAll({ behavior: 'ignoreErrors' });
    // Off Project Home first, so that no read of it meets the project deleted under it.
    await page.goto('research');
    await reset(page);
  }
});

test('raises the semantic axis’s weight and marks a match by keyboard, and Settings ▸ Data lists the verdict', async ({ page }) => {
  await page.goto('research');
  await reset(page);
  try {
    await page.goto('related/frus1961-63v06/d1');
    await expect(page.getByRole('heading', { level: 1, name: 'Related Documents' })).toBeVisible();
    await expect(page.locator('ol.related-list')).toBeVisible();
    await expect(page.getByText('Ranking the related documents…')).toHaveCount(0);

    // The semantic axis, by keyboard: Adjust weights opens, and its slider moves up a step, ranked again with it.
    await tabTo(page, page.getByText('Adjust weights'));
    await page.keyboard.press('Enter');
    const meaning = page.getByRole('slider', { name: 'Semantically similar (experimental)' });
    await tabTo(page, meaning);
    await expect(meaning).toHaveValue('0.5');
    await page.keyboard.press('ArrowRight');
    await expect(meaning).toHaveValue('0.6');
    await expect(page).toHaveURL(/weights=semanticSimilarity%3A0\.6/);
    await expect(page.getByText('Ranking the related documents…')).toHaveCount(0);
    await expect(meaning).toBeFocused();

    // A row the semantic axis scored says its match, by the words it shares with the document or, sharing none, by its
    // percentage (S29g), and carries the app's two verdicts on its menu.
    const menu = { name: /^Semantic match feedback: / };
    const row = page.locator('ol.related-list > li').filter({ has: page.getByRole('button', menu) }).first();
    const feedback = row.getByRole('button', menu);
    await expect(feedback).toBeVisible();
    await expect(row.locator('li.axis-semanticSimilarity')).toContainText('shares: ');
    await tabTo(page, feedback);
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('menuitem', { name: 'Semantic match: helpful' })).toBeFocused();
    await expect(page.getByRole('menuitem', { name: 'Semantic match: not useful' })).toBeVisible();
    await axeCheck(page);
    await page.keyboard.press('Enter');
    await expect(row.getByText('Marked helpful')).toBeVisible();
    await expect(feedback).toBeFocused();

    // Beyond your library follows the rows: the volumes this server does not serve, each opening its page in Browse.
    const beyond = page.getByRole('region', { name: 'Beyond your library' });
    await expect(beyond).toBeVisible();
    await expect(beyond.getByRole('link').first()).toHaveAttribute('href', /\/browse\/frus/);
    await axeCheck(page);

    // The verdict is the user's, kept on the server, and Settings ▸ Data lists it.
    expect(await getJSON<{ total: number; helpful: number }>(page, 'api/v1/me/semantic-feedback')).toMatchObject({ total: 1, helpful: 1 });
    await page.goto('settings/data');
    const section = page.getByRole('region', { name: 'Semantic Match Feedback' });
    await expect(section.getByText('Verdicts recorded')).toBeVisible();
    await expect(section.getByText('Marked helpful')).toBeVisible();
    await expect(section.getByRole('link', { name: 'Download Feedback File' })).toHaveAttribute('download', 'frus-semantic-feedback.json');
    await axeCheck(page);
  } finally {
    await page.goto('research');
    await reset(page);
  }
});

test('reads by keyboard what a row matched by meaning, and then by wording, shares with the document', async ({ page }) => {
  await page.goto('research');
  await reset(page);
  try {
    await page.goto('related/frus1961-63v06/d1');
    await expect(page.getByRole('heading', { level: 1, name: 'Related Documents' })).toBeVisible();
    await expect(page.locator('ol.related-list')).toBeVisible();
    await expect(page.getByText('Ranking the related documents…')).toHaveCount(0);

    // The export's second document is matched by meaning, and shares two words with the first that are no stop words,
    // "negotiating" and "treaties", which its chip names in their dictionary forms, the rarer first, since the first
    // prints neither in that form (S29g). The keyboard reaches the row's link, which its chips describe.
    const title = '2. Memorandum of Conversation';
    const row = page.locator('ol.related-list > li').filter({ has: page.getByRole('link', { name: title, exact: true }) });
    const link = row.getByRole('link', { name: title, exact: true });
    const words = /shares: (negotiate, treaty|treaty, negotiate)$/;
    await expect(row.locator('li.axis-semanticSimilarity')).toHaveText(/^Semantically similar \(experimental\) shares: /);
    await expect(row.locator('li.axis-semanticSimilarity')).toHaveText(words);
    const shared = (await row.locator('li.axis-semanticSimilarity').textContent())!.replace(/^.*shares: /, '');
    await tabTo(page, link);
    await expect(link).toBeFocused();
    await expect(link).toHaveAccessibleDescription(new RegExp(`Semantically similar \\(experimental\\) shares: ${shared}`));
    await axeCheck(page);

    // The lexical axis, by keyboard: Adjust weights opens, and its slider moves up a step, the list ranked again with it.
    await tabTo(page, page.getByText('Adjust weights'));
    await page.keyboard.press('Enter');
    const wording = page.getByRole('slider', { name: 'Similar wording (experimental)' });
    await tabTo(page, wording);
    await page.keyboard.press('ArrowRight');
    await expect(wording).toHaveValue('0.1');
    await expect(page).toHaveURL(/weights=lexicalSimilarity%3A0\.1/);
    await expect(page.getByText('Ranking the related documents…')).toHaveCount(0);
    await expect(wording).toBeFocused();

    // The row's wording is its chip's too: the same words, the one pass naming them under both axes, as the app's does.
    await expect(row.locator('li.axis-lexicalSimilarity')).toHaveText(`Similar wording (experimental) shares: ${shared}`);
    await tabTo(page, link);
    await expect(link).toBeFocused();
    await expect(link).toHaveAccessibleDescription(new RegExp(`Similar wording \\(experimental\\) shares: ${shared}`));
    await expect(link).toHaveAccessibleDescription(new RegExp(`Semantically similar \\(experimental\\) shares: ${shared}`));
    await axeCheck(page);
  } finally {
    await page.goto('research');
    await reset(page);
  }
});
