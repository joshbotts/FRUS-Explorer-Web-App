// S21b's follow-up: the reader opens a volume's back-of-volume index, which it parses alone, as the app's
// Read Index does, from where the app offers it, the volume's contents, and an index's "See" reference
// lands on its entry in the same page (FRUS-Explorer#1875), by keyboard alone, with no axe violations,
// the reader's frame scanned with the app. Against the image, with the synthetic export imported and
// fixtures/tei mounted: frus1961-63v06's index holds eight "See" references, among them "Cuba (see also
// Cuban missile crisis)", whose entry is a few dozen lines further on.
import { axeCheck } from './axe';
import { v06Title } from './expected';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

const volume = 'frus1961-63v06';

test('opens a volume’s index from its contents and follows a “See” reference to its entry, by keyboard alone', async ({ page }) => {
  // About 120 links come before the reference: the index's page numbers and names, after the toolbar.
  test.setTimeout(90_000);
  await page.goto(`browse/${volume}`);
  const heading = page.getByRole('heading', { level: 1 });
  await expect(heading).toHaveText(v06Title);

  // The volume's contents list the index under its back matter, and the reader opens it, as the app's
  // Read Index does; the lists of persons and sources, which the app opens as lists of their own, are
  // named only.
  const index = page.getByRole('link', { name: 'Index', exact: true });
  await expect(index).toHaveAttribute('href', new RegExp(`/doc/${volume}/index$`));
  await expect(page.getByRole('link', { name: 'Contents', exact: true })).toHaveAttribute('href', new RegExp(`/doc/${volume}/toc$`));
  await expect(page.getByRole('link', { name: 'Persons', exact: true })).toHaveCount(0);
  await axeCheck(page);
  await tabTo(page, index, 80);
  await page.keyboard.press('Enter');

  // The reader: the index, headed by its parsed head, its entries the kit's, each an item with an id.
  await expect(page).toHaveURL(new RegExp(`/doc/${volume}/index$`));
  await expect(heading).toHaveText('Index');
  await expect(heading).toBeFocused();
  const frame = page.frameLocator('iframe.reader-frame');
  const entry = frame.locator('#ix-in1');
  await expect(entry).toContainText('Cuban missile crisis:');
  await axeCheck(page);

  // The "See also" in Cuba's entry: Enter on it, and the page lands on the entry it names, in place.
  const see = frame.getByRole('link', { name: 'Cuban missile crisis', exact: true });
  await tabTo(page, see, 200);
  await page.keyboard.press('Enter');
  await expect(entry).toBeFocused();
  await expect(entry).toBeInViewport();
  await expect(page).toHaveURL(new RegExp(`/doc/${volume}/index$`));
  await expect(page.locator('.reader-main .notice')).toHaveText('');
  // The next Tab goes on from the entry: to its first page number.
  await page.keyboard.press('Tab');
  await expect(entry.getByRole('link').first()).toBeFocused();
  await axeCheck(page);
});
