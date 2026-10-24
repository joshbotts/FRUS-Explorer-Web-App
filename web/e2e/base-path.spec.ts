// S14f's done-when (docs/PLAN.md): the suite passes with the app served under a path and at the
// root, as scripts/compose-smoke --e2e runs it, at http://localhost:8080/ and then under
// http://localhost:8080/frus-explorer/. This spec checks what the others take for granted: the
// page's base is the path the suite was given, and nothing the app or the reader's frame asks for
// leaves it.
import { d1Text, treatiesResults } from './expected';
import { expect, test } from './fixtures';

test('the app, its API and the reader ask for nothing outside the path the app is served under', async ({ page, baseURL }) => {
  const base = new URL(baseURL!);
  const asked: string[] = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.origin === base.origin) asked.push(url.pathname);
  });

  await page.goto('doc/frus1961-63v06/d1');
  expect(await page.evaluate(() => document.baseURI)).toBe(base.href);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(treatiesResults[0]);
  const frame = page.locator('iframe.reader-frame');
  await expect(frame).toHaveAttribute('src', new RegExp(`^${base.pathname}api/v1/volumes/frus1961-63v06/documents/d1/html\\?`));
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();

  // The skip link stays on the page it was followed on, though the page's base is elsewhere.
  await page.keyboard.press('Tab');
  await expect(page.getByRole('link', { name: 'Skip to content' })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('main')).toBeFocused();
  await expect(page).toHaveURL(`${base.href}doc/frus1961-63v06/d1`);

  // The router writes its routes under the path, and the search asks the API there. Exact, since a
  // name is matched as a part of one, which Research holds.
  await page.getByRole('navigation').getByRole('link', { name: 'Search', exact: true }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Search' })).toBeVisible();
  const box = page.getByRole('searchbox', { name: 'Search the documents' });
  await box.fill('treaties');
  await box.press('Enter');
  await expect(page).toHaveURL(`${base.href}search?keywords=treaties`);
  await expect(page.getByRole('list', { name: 'Results' }).getByRole('listitem')).toHaveCount(2);
  // A client route reloaded is the app again.
  await page.reload();
  await expect(page.getByRole('list', { name: 'Results' }).getByRole('listitem')).toHaveCount(2);

  expect(asked.filter((path) => !path.startsWith(base.pathname))).toEqual([]);
  for (const path of ['reader/host.js', 'readyz', 'api/v1/search']) expect(asked, path).toContain(`${base.pathname}${path}`);
});
