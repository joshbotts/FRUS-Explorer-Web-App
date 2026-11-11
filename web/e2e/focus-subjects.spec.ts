// S25c's done-when (docs/PLAN.md): Playwright chooses focus subjects in the editor by keyboard and finds
// them on Project Home after a reload, on Chromium with no axe violations. Against the image, with the
// synthetic export imported and the app's bundled subject vocabulary. The project is made for the test,
// and a visit under it to frus1961-63v06's d1 gives the editor its suggestions, from that volume's
// subjects; the test removes the project and the trail, and sets back the preferences.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';
import { getJSON, send } from './notes';

interface Subject {
  ref: string;
  name: string;
}

interface Home {
  project: { id: string; defaultSubjectTagIds: string[] };
  focusSubjects?: Subject[];
  focusSuggestions?: Subject[];
}

const name = 'Focus subjects test';

/** Removes the test's project, the trail it recorded and the preferences it set, and returns the user to Global Context. */
async function reset(page: Page): Promise<void> {
  const list = await getJSON<{ items: { id: string; name: string }[] }>(page, 'api/v1/me/projects');
  for (const project of list.items) if (project.name === name) await send(page, 'DELETE', `api/v1/me/projects/${project.id}`);
  await send(page, 'PUT', 'api/v1/me/active-project', { projectId: null });
  await send(page, 'DELETE', 'api/v1/me/history');
  await send(page, 'PATCH', 'api/v1/me/preferences', { researchLoggingEnabled: true });
}

test('chooses focus subjects in the editor by keyboard, and finds them on Project Home after a reload', async ({ page }) => {
  await page.goto('research');
  await reset(page);
  try {
    // A project to work in, which has read one document.
    const project = (await send(page, 'POST', 'api/v1/me/projects', { name })) as { id: string };
    await send(page, 'POST', 'api/v1/me/history/documents', { volumeId: 'frus1961-63v06', documentId: 'd1' });
    const before = await getJSON<Home>(page, `api/v1/me/projects/${project.id}/home`);
    const suggested = before.focusSuggestions ?? [];
    expect(before.focusSubjects, 'the image has the vocabulary').toEqual([]);
    expect(suggested.length, 'the visit’s volume suggests subjects').toBe(8);
    const vocabulary = (await getJSON<{ items: Subject[] }>(page, 'api/v1/me/focus-subjects')).items;
    // A subject the volume does not suggest, which the search finds.
    const searched = vocabulary.find((subject) => !suggested.some((item) => item.ref === subject.ref) && subject.name.length > 6)!;

    await page.goto(`projects/${project.id}`);
    const section = page.getByRole('region', { name: 'Focus subjects' });
    await expect(section.getByText('Choose subjects to focus discovery on the volumes they define.')).toBeVisible();
    await axeCheck(page);
    const add = section.getByRole('button', { name: 'Add' });
    await tabTo(page, add);
    await page.keyboard.press('Enter');
    const editor = page.getByRole('dialog', { name: 'Focus Subjects' });
    await expect(editor.getByRole('heading', { name: 'Focus Subjects' })).toBeFocused();
    const suggestions = editor.getByRole('group', { name: 'Suggested from your volumes' });
    await expect(suggestions.getByRole('checkbox')).toHaveCount(8);
    await axeCheck(page);

    // The first suggestion, chosen with Space: it moves to Focus subjects, and the focus to the next.
    const first = suggestions.getByRole('checkbox', { name: suggested[0].name, exact: true });
    await tabTo(page, first);
    await page.keyboard.press('Space');
    const chosen = editor.getByRole('group', { name: 'Focus subjects' });
    await expect(chosen.getByRole('checkbox', { name: suggested[0].name, exact: true })).toBeChecked();
    await expect(suggestions.getByRole('checkbox', { name: suggested[1].name, exact: true })).toBeFocused();
    await expect(editor.getByRole('status')).toHaveText(`${suggested[0].name} added to Focus subjects`);

    // Another, found by the search, which hides the suggestions.
    const search = editor.getByRole('searchbox', { name: 'Search subjects' });
    await backTabTo(page, search);
    await page.keyboard.type(searched.name.toUpperCase());
    await expect(suggestions).toHaveCount(0);
    const found = editor.getByRole('group', { name: 'All subjects' }).getByRole('checkbox', { name: searched.name, exact: true });
    await tabTo(page, found);
    await page.keyboard.press('Space');
    await expect(found).toBeChecked();
    await axeCheck(page);
    await expect
      .poll(async () => (await getJSON<Home>(page, `api/v1/me/projects/${project.id}/home`)).project.defaultSubjectTagIds)
      .toEqual([suggested[0].ref, searched.ref]);

    // Done, and the focus is back on the section's Edit; the chips are in the vocabulary's order.
    await backTabTo(page, editor.getByRole('button', { name: 'Done' }));
    await page.keyboard.press('Enter');
    await expect(editor).toHaveCount(0);
    const edit = section.getByRole('button', { name: 'Edit' });
    await expect(edit).toBeFocused();
    const order = vocabulary.filter((subject) => subject.ref === suggested[0].ref || subject.ref === searched.ref).map((subject) => subject.name);
    await expect(section.getByRole('listitem')).toHaveText(order);

    // After a reload, as the server keeps them.
    await page.reload();
    await expect(page.getByRole('heading', { level: 1, name })).toBeVisible();
    await expect(section.getByRole('listitem')).toHaveText(order);
    await axeCheck(page);

    // Taken out again from the editor's Focus subjects, by keyboard.
    await tabTo(page, edit);
    await page.keyboard.press('Enter');
    const again = editor.getByRole('group', { name: 'Focus subjects' });
    await tabTo(page, again.getByRole('checkbox', { name: order[0], exact: true }));
    await page.keyboard.press('Space');
    // The focus goes on to the row now in its place, and from the last to the search field.
    await expect(again.getByRole('checkbox', { name: order[1], exact: true })).toBeFocused();
    await page.keyboard.press('Space');
    await expect(again).toHaveCount(0);
    await expect(search).toBeFocused();
    await page.keyboard.press('Escape');
    await expect(section.getByRole('button', { name: 'Add' })).toBeFocused();
    await expect(section.getByRole('listitem')).toHaveCount(0);
  } finally {
    // Off Project Home first, whose last save asks for it again, which a project deleted under it would
    // answer 404, a console error (S23d's smoke run found the race).
    await page.goto('research');
    await reset(page);
  }
});
