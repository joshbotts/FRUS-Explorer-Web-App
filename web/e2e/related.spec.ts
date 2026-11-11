// S23d's done-when (docs/PLAN.md): Playwright opens Related and refreshes the leads by keyboard on
// Chromium with no axe violations. Against the image, with the synthetic export imported. From the
// reader, Related opens the document's list; the scope and a weight change by keyboard, the weight kept
// for the next list as the app keeps its device's; a row opens its document, and Back returns to the
// list as it was. Then a project with a note on a document has its leads found again by keyboard, Project
// Home saying so while the server finds them. The test removes its project, its note and the trail, and
// forgets the tuning.
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
  await page.evaluate(() => localStorage.removeItem('frus.related.weights'));
}

test('opens Related from the reader by keyboard, changes its scope and a weight, and refreshes the leads', async ({ page }) => {
  await page.goto('research');
  await reset(page);
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

    // The scope, by keyboard: the picker is a group of radios, as the app's segmented control.
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
    await expect(proximity).toHaveValue('0.4');
    await expect(page).toHaveURL(/weights=subseries%3A0\.4/);
    await expect.poll(() => page.evaluate(() => localStorage.getItem('frus.related.weights'))).toBe('subseries:0.4');
    // The slider kept its place, and the focus, through the new ranking.
    await expect(proximity).toBeFocused();
    await expect(page.getByRole('slider', { name: 'Cross-references' })).toBeDisabled();
    await expect(page.getByText('This server does not rank by cross-references yet.')).toBeVisible();
    await axeCheck(page);
    const resetWeights = page.getByRole('button', { name: 'Reset to app defaults' });
    await tabTo(page, resetWeights);
    await page.keyboard.press('Enter');
    await expect(proximity).toHaveValue('0.3');
    await expect.poll(() => page.evaluate(() => localStorage.getItem('frus.related.weights'))).toBeNull();
    // The focus goes back to the weights' heading, Reset being unavailable once it has reset.
    await expect(page.getByText('Adjust weights')).toBeFocused();

    // A row opens its document, and Back returns to the list as it was. The synthetic export gives d1 no
    // document of its archival container, so its list is empty there; the rows are the unit tests'.
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
    await reset(page);
  }
});
