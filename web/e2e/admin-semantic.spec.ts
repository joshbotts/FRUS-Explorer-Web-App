// S27b's done-when (docs/PLAN.md): Playwright reads Search Model by keyboard, on Chromium with no axe violations.
// The image's own encoder embeds one query through the server's path first, so that the pane finds the real
// llama-server loaded over the model in the image: Administration's panes' Semantic link, reached by keyboard
// from Status, opens on Search Model, with the model in the image, verified, its file, size and digest, the
// engine at the pinned commit and the encoder loaded. It changes nothing a later spec reads. It runs at the
// root and again under the path.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { getJSON } from './notes';

interface Embedding {
  dimensions: number;
  vector: number[];
  tokens: number;
}

test('reads Search Model by keyboard: the model in the image and its encoder, loaded', async ({ page }) => {
  await page.goto('admin/status');
  await expect(page.getByRole('heading', { level: 1, name: 'Status', exact: true })).toBeVisible();

  // The server's own path: the query, the kit's prompt before it, through the image's llama-server.
  const embedded = await getJSON<Embedding>(page, 'api/v1/admin/semantic/embedding?query=the%20Berlin%20airlift');
  expect(embedded.dimensions).toBe(768);
  expect(Math.abs(embedded.vector.reduce((sum, value) => sum + value * value, 0) - 1)).toBeLessThan(1e-9);

  const panes = page.getByRole('navigation', { name: 'Administration' });
  const semantic = panes.getByRole('link', { name: 'Semantic', exact: true });
  await tabTo(page, semantic, 60);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/admin\/semantic$/);
  const heading = page.getByRole('heading', { level: 1, name: 'Semantic', exact: true });
  await expect(heading).toBeFocused();
  await expect(semantic).toHaveAttribute('aria-current', 'page');

  const model = page.getByRole('region', { name: 'Search Model' });
  await expect(model.getByRole('heading', { level: 2, name: 'Search Model' })).toBeVisible();
  await expect(model.getByText('In the image and verified — 310 MB on this server.', { exact: true })).toBeVisible();
  await expect(model.getByText('/usr/share/frus-light/model/embeddinggemma-2-Q8_0.gguf', { exact: true })).toBeVisible();
  await expect(model.getByText('309,855,456 bytes, the length the app publishes', { exact: true })).toBeVisible();
  await expect(model.getByText('2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135', { exact: true })).toBeVisible();
  await expect(model.getByText('llama.cpp’s llama-server, commit a0e6dc7', { exact: true })).toBeVisible();
  await expect(model.getByText(/^On, and loaded since .+, holding \d+ MB\. It stops at .+ unless another search comes, 3 minutes after the last/)).toBeVisible();
  // Nothing to download or remove: the model is the image's.
  await expect(model.getByRole('button')).toHaveCount(0);
  await axeCheck(page);
});
