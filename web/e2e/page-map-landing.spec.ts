// The page-map landing (joshbotts/FRUS-Explorer#1784, #1778): a page link into a volume this server
// does not hold goes where the app's readers send it, as the kit's PageLink decides from the bundled
// page map: to the document the map names on the page, or, where it names none, to the volume, as a
// link to the whole volume opens it, in Browse, which names the page. Against the image, with the
// synthetic export imported and fixtures/tei mounted: frus1889 and frus1961-63v14 are neither.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

test('a page link into a volume this server does not hold lands on the document the page map names, by keyboard alone', async ({ page }) => {
  // frus1894Nicaragua d15's one link, to page 469 of the 1889 volume, where the map names d173.
  await page.goto('/doc/frus1894Nicaragua/d15');
  const frame = page.frameLocator('iframe.reader-frame');
  const link = frame.getByRole('link', { name: 'Foreign Relations for that year, page 469' });
  await expect(link).toBeVisible();
  await tabTo(page, link);
  await page.keyboard.press('Enter');
  // It opens as a link to that document does: this server has neither its TEI nor its index, so the
  // notice offers the document's page on history.state.gov.
  const notice = page.getByRole('status').filter({ hasText: 'isn’t on this server' });
  await expect(notice).toContainText(
    'The linked document is in “Papers Relating to the Foreign Relations of the United States, Transmitted to Congress',
  );
  await expect(notice.getByRole('link', { name: 'Open on history.state.gov' })).toHaveAttribute(
    'href',
    'https://history.state.gov/historicaldocuments/frus1889/d173',
  );
  await expect(page).toHaveURL(/\/doc\/frus1894Nicaragua\/d15$/);
  await axeCheck(page);
});

test('a page link the page map names no document on opens the volume in Browse, and that visit names the page', async ({ page }) => {
  // d42 cites pages 859–862 of Volume XIV, a range across documents, which the map lists no
  // document for; the link names its first page.
  await page.goto('/doc/frus1961-63v06/d42');
  await page.frameLocator('iframe.reader-frame').getByRole('link', { name: 'vol. XIV, pp. 859' }).first().click();
  await expect(page).toHaveURL(/\/browse\/frus1961-63v14$/);
  const heading = page.getByRole('heading', { level: 1 });
  await expect(heading).toHaveText('Foreign Relations of the United States, 1961–1963, Volume XIV, Berlin Crisis, 1961–1962');
  await expect(heading).toBeFocused();
  const followed = page.getByText('You followed a link to page 859 of this volume, which isn’t on this server.');
  await expect(followed).toBeVisible();
  await expect(page.getByText('Its TEI isn’t on this server, so its documents can’t be read here.')).toBeVisible();
  await axeCheck(page);

  // Back returns to the document; Forward to the same visit, which still names the page, as a
  // reload of it would.
  await page.goBack();
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d42$/);
  await page.goForward();
  await expect(page).toHaveURL(/\/browse\/frus1961-63v14$/);
  await expect(followed).toBeVisible();

  // A later visit, from the catalogue, names none.
  await page.goto('/browse');
  await page.getByRole('searchbox', { name: 'Title or volume number' }).fill('Berlin Crisis');
  await page.getByRole('list', { name: 'All Volumes' }).getByRole('link', { name: /Volume XIV, Berlin Crisis/ }).click();
  await expect(page).toHaveURL(/\/browse\/frus1961-63v14$/);
  await expect(page.getByText('Its TEI isn’t on this server, so its documents can’t be read here.')).toBeVisible();
  await expect(page.getByText(/You followed a link/)).toHaveCount(0);
});
