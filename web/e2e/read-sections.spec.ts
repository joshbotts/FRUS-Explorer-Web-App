// The reader opens every section the app's reader opens by its id (the follow-up of S21b's follow-up):
// a table of contents' links reach the lists of sources and of persons, which the app's Browse opens as
// lists of their own and its reader shows as printed, and a chapter that prints nothing of its own but
// its heading, which the app's reader shows as that heading; each is parsed alone from the TEI, by
// keyboard alone, with no axe violations, the reader's frame scanned with the app. Browse still links to
// the reader only what the app's Read opens. Against the image, with the synthetic export imported and
// fixtures/tei mounted: the export's index does not hold frus1969-76ve09p1, so its contents come from
// its TEI, and its pages have no Previous or Next, as the app's reader has none in a volume it has not
// indexed; FRUSParityTests turn the pages of a volume the index holds through the API.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

const volume = 'frus1969-76ve09p1';

/** The contents' links this spec follows: the section's id, the link's name, and a line of its page. */
const destinations = [
  { id: 'sources', name: 'Sources', heading: 'Sources', text: 'Sources for the Foreign Relations Series' },
  { id: 'persons', name: 'Persons', heading: 'Persons', text: 'Atherton, Alfred L., Jr.' },
  { id: 'ch1', name: 'Algeria, 1973–1976', heading: 'Algeria, 1973–1976', text: 'Algeria, 1973–1976' },
];

test('a table of contents’ links open its lists and a chapter in the reader, as the app’s reader opens them, by keyboard alone', async ({ page }) => {
  // Four axe passes over pages of up to sixty links, and a walk through the contents' links each time.
  test.setTimeout(120_000);
  await page.goto(`browse/${volume}`);
  const heading = page.getByRole('heading', { level: 1 });
  await expect(heading).toHaveText(/Documents on North Africa, 1973–1976$/);

  // The volume's contents link the table of contents to the reader, as the app's Read opens it, and name
  // the lists, which the app's Browse opens as lists of their own.
  const contents = page.getByRole('link', { name: 'Contents', exact: true });
  await expect(contents).toHaveAttribute('href', new RegExp(`/doc/${volume}/toc$`));
  const tree = page.locator('.section-tree');
  for (const list of ['Sources', 'Persons']) {
    await expect(tree.getByText(list, { exact: true })).toBeVisible();
    await expect(tree.getByRole('link', { name: list, exact: true })).toHaveCount(0);
  }
  await tabTo(page, contents, 120);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(new RegExp(`/doc/${volume}/toc$`));
  await expect(heading).toHaveText('Contents');

  // Each link the contents print opens its section in the reader, headed by its parsed head, its page
  // the kit's parse of the section alone; Back returns to the contents.
  const frame = page.frameLocator('iframe.reader-frame');
  for (const destination of destinations) {
    const link = frame.locator(`a[href="frusexplorer://doc/%23${destination.id}"]`);
    await expect(link).toHaveAccessibleName(destination.name);
    await tabTo(page, link, 80);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(new RegExp(`/doc/${volume}/${destination.id}$`));
    await expect(heading).toHaveText(destination.heading);
    await expect(heading).toBeFocused();
    await expect(frame.locator('.frus-document')).toContainText(destination.text);
    await expect(page.locator('.reader-main .notice')).toHaveText('');
    await axeCheck(page);
    await page.goBack();
    await expect(page).toHaveURL(new RegExp(`/doc/${volume}/toc$`));
    await expect(heading).toHaveText('Contents');
  }
});
