// S14c's done-when (docs/PLAN.md): Playwright tags a document and deletes the tag, by keyboard, on
// Chromium, with no axe violations: the Research rail's Tags section and its picker, then
// Settings ▸ Tags, its editor and Delete Tag's confirmation. Against the image, whose user store
// starts with no tags, and which the test leaves with none.
import { axeCheck } from './axe';
import { d1Text } from './expected';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';

const d1Header = '1. Telegram From the Embassy in the Soviet Union';

test('tags a document in the Research rail and deletes the tag in Settings ▸ Tags, by keyboard alone', async ({ page }) => {
  await page.goto('doc/frus1961-63v06/d1');
  const heading = page.getByRole('heading', { level: 1 });
  await expect(heading).toHaveText(d1Header);
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();

  // The Research rail, from the reader's toolbar; its Tags section opens on Enter.
  const toggle = page.getByRole('button', { name: 'Research' });
  await tabTo(page, toggle);
  await page.keyboard.press('Enter');
  const rail = page.getByRole('complementary', { name: 'Research' });
  await expect(rail.getByRole('heading', { name: 'Research' })).toBeFocused();
  await expect(toggle).toHaveAttribute('aria-expanded', 'true');
  const section = rail.getByRole('button', { name: 'Tags', exact: true });
  await tabTo(page, section);
  await page.keyboard.press('Enter');
  await expect(section).toHaveAttribute('aria-expanded', 'true');
  const addTag = rail.getByRole('button', { name: 'Add Tag' });
  await expect(addTag).toBeVisible();
  await axeCheck(page);

  // The picker: a new tag, made and switched on, then Done.
  await tabTo(page, addTag);
  await page.keyboard.press('Enter');
  const picker = page.getByRole('dialog', { name: 'Tags — Doc 1' });
  await expect(picker).toBeVisible();
  await expect(picker.getByRole('textbox', { name: 'New tag name' })).toBeFocused();
  await page.keyboard.type('Primary source');
  await page.keyboard.press('Enter');
  const made = picker.getByRole('checkbox', { name: /^Primary source\b/ });
  await expect(made).toBeFocused();
  await expect(made).toBeChecked();
  await expect(picker.getByRole('status')).toHaveText('Tag Primary source created and selected');
  await axeCheck(page);
  await tabTo(page, picker.getByRole('button', { name: 'Done' }));
  await page.keyboard.press('Enter');
  await expect(picker).toHaveCount(0);
  const chip = rail.getByRole('button', { name: 'Remove Primary source' });
  await expect(chip).toBeVisible();
  await expect(addTag).toBeFocused();
  await expect(rail.getByRole('button', { name: 'Tags, 1 tag' })).toBeVisible();
  await axeCheck(page);

  // Escape closes the rail, and Settings is in the header.
  await page.keyboard.press('Escape');
  await expect(rail).toHaveCount(0);
  await expect(toggle).toBeFocused();
  await backTabTo(page, page.getByRole('navigation', { name: 'Main' }).getByRole('link', { name: 'Settings' }));
  await page.keyboard.press('Enter');

  // Settings ▸ Tags, where the server's tag is listed: its row opens its editor, and Delete Tag
  // asks first.
  await expect(page).toHaveURL(/\/settings\/tags$/);
  await expect(heading).toHaveText('Tags');
  await expect(heading).toBeFocused();
  const row = page.getByRole('list', { name: 'Tags' }).getByRole('button', { name: 'Primary source' });
  await expect(row).toBeVisible();
  await axeCheck(page);
  await tabTo(page, row);
  await page.keyboard.press('Enter');
  const editor = page.getByRole('dialog', { name: 'Edit Tag' });
  await expect(editor.getByRole('textbox', { name: 'Tag name' })).toBeFocused();
  await expect(editor.getByRole('textbox', { name: 'Tag name' })).toHaveValue('Primary source');
  await axeCheck(page);
  await tabTo(page, editor.getByRole('button', { name: 'Delete Tag' }));
  await page.keyboard.press('Enter');
  const confirm = page.getByRole('alertdialog', { name: 'Delete Tag?' });
  await expect(confirm.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await axeCheck(page);
  await tabTo(page, confirm.getByRole('button', { name: 'Delete', exact: true }));
  await page.keyboard.press('Enter');
  await expect(confirm).toHaveCount(0);
  await expect(editor).toHaveCount(0);
  await expect(heading).toBeFocused();
  await expect(page.getByText(/^No tags yet\. Tags are the labels you apply/)).toBeVisible();
  await axeCheck(page);

  // The document carries it no more.
  await page.goto('doc/frus1961-63v06/d1?rail=research');
  const after = page.getByRole('complementary', { name: 'Research' });
  await expect(after.getByRole('button', { name: 'Add Tag' })).toBeVisible();
  await expect(after.getByRole('button', { name: /^Remove / })).toHaveCount(0);
  await expect(after.getByRole('button', { name: 'Tags', exact: true })).toBeVisible();
});
