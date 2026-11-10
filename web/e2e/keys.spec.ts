// S20c's done-when (docs/PLAN.md): Playwright sets and clears a key by keyboard on Chromium, with no axe
// violations, in Settings ▸ Keys: Add Key… for the NARA Catalog, typed into a field that shows none of
// it and saved with Return, after which the pane and the server say only that it is stored; then
// Remove Key and its question. Against the image's single user, whom the test leaves with no keys, as it
// found them; it runs at the root and again under the path.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { getJSON, send } from './notes';

interface SecretList {
  secrets: { name: string; set: boolean; updatedAt?: string }[];
}

const key = 'e2e-nara-key-7Hq2vXw9';

test('sets and clears the NARA Catalog key in Settings ▸ Keys, by keyboard alone', async ({ page }) => {
  await page.goto('settings/keys');
  const heading = page.getByRole('heading', { level: 1, name: 'Keys' });
  await expect(heading).toBeVisible();
  // As the test found it, whatever an earlier run left.
  await send(page, 'DELETE', 'api/v1/me/secrets/nara');
  await page.reload();
  try {
    const nara = page.getByRole('region', { name: 'NARA Catalog' });
    await expect(nara.getByText('No key stored', { exact: true })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Settings' }).getByRole('link', { name: 'Keys' })).toHaveAttribute('aria-current', 'page');
    await axeCheck(page);

    // Add Key… opens the field, focused, which shows none of what is typed; Return saves.
    const add = nara.getByRole('button', { name: 'Add Key…' });
    await tabTo(page, add);
    await page.keyboard.press('Enter');
    // A password field, which has no role of its own: found by its label.
    const field = nara.getByLabel('NARA Catalog key');
    await expect(field).toBeFocused();
    await expect(field).toHaveAttribute('type', 'password');
    await axeCheck(page);
    await page.keyboard.type(key);
    await page.keyboard.press('Enter');

    await expect(nara.getByText('Key stored', { exact: true })).toBeVisible();
    await expect(nara.getByRole('status')).toHaveText('Saved');
    const replace = nara.getByRole('button', { name: 'Replace Key…' });
    await expect(replace).toBeFocused();
    await expect(nara.getByLabel('NARA Catalog key')).toHaveCount(0);
    expect(await page.content()).not.toContain(key);
    const stored = await getJSON<SecretList>(page, 'api/v1/me/secrets');
    expect(stored.secrets.find((secret) => secret.name === 'nara')?.set).toBe(true);
    expect(JSON.stringify(stored)).not.toContain(key);
    await axeCheck(page);

    // Remove Key asks first, its Cancel focused; Remove clears it.
    const remove = nara.getByRole('button', { name: 'Remove Key' });
    await tabTo(page, remove);
    await page.keyboard.press('Enter');
    const question = page.getByRole('alertdialog', { name: 'Remove the stored key?' });
    await expect(question.getByRole('button', { name: 'Cancel' })).toBeFocused();
    await axeCheck(page);
    await tabTo(page, question.getByRole('button', { name: 'Remove', exact: true }));
    await page.keyboard.press('Enter');
    await expect(question).toHaveCount(0);
    await expect(nara.getByText('No key stored', { exact: true })).toBeVisible();
    await expect(nara.getByRole('status')).toHaveText('Removed');
    await expect(nara.getByRole('button', { name: 'Add Key…' })).toBeFocused();
    const cleared = await getJSON<SecretList>(page, 'api/v1/me/secrets');
    expect(cleared.secrets.find((secret) => secret.name === 'nara')?.set).toBe(false);
    await axeCheck(page);
  } finally {
    await send(page, 'DELETE', 'api/v1/me/secrets/nara');
  }
});
