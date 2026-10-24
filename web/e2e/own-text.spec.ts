// S13a's done-when (docs/PLAN.md): Playwright browses to a section's own text by keyboard on Chromium,
// with no axe violations. Against the image, with the synthetic export's --own-text rows imported and
// fixtures/own-text/frus1969-76v01.xml mounted beside fixtures/tei.
import type { Locator } from '@playwright/test';
import { axeCheck } from './axe';
import { ownText } from './expected';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

/** Whether `first` comes before `second` in the page. */
async function precedes(first: Locator, second: Locator): Promise<boolean> {
  const other = await second.elementHandle();
  return first.evaluate((element, node) => (element.compareDocumentPosition(node!) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0, other);
}

test('lists a section’s own text first in its section, as the app’s Browse does, and opens it in the reader, by keyboard alone', async ({
  page,
}) => {
  await page.goto(`browse/${ownText.volumeId}`);
  const heading = page.getByRole('heading', { level: 1 });
  await expect(heading).toHaveText(ownText.volumeTitle);
  await axeCheck(page);

  // The conference holds only sections; its page lists its own text above them.
  await tabTo(page, page.getByRole('link', { name: ownText.conference, exact: true }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(new RegExp(`/browse/${ownText.volumeId}/comp1$`));
  await expect(heading).toHaveText(ownText.conference);
  await expect(heading).toBeFocused();
  const conference = page.getByRole('link', { name: `Read ${ownText.conference}` });
  await expect(conference).toHaveAccessibleDescription(ownText.note);
  expect(await precedes(conference, page.getByRole('heading', { name: 'Sections' }))).toBe(true);
  await axeCheck(page);

  // The first meeting: its own text, a list of those present, above its two documents.
  await tabTo(page, page.getByRole('link', { name: ownText.meeting, exact: true }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(new RegExp(`/browse/${ownText.volumeId}/ch1$`));
  await expect(heading).toHaveText(ownText.meeting);
  await expect(heading).toBeFocused();
  const meeting = page.getByRole('link', { name: `Read ${ownText.meeting}` });
  await expect(meeting).toHaveAccessibleDescription(ownText.note);
  const documents = page.getByRole('heading', { name: 'Documents (2)' });
  await expect(documents).toBeVisible();
  expect(await precedes(meeting, documents)).toBe(true);
  await axeCheck(page);

  // The row opens in the reader, which reads the meeting's own text, and nothing its documents hold.
  await tabTo(page, meeting);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(new RegExp(`/doc/${ownText.volumeId}/ch1$`));
  await expect(heading).toHaveText(ownText.meeting);
  await expect(heading).toBeFocused();
  const frame = page.frameLocator('iframe.reader-frame');
  await expect(frame.getByText(ownText.meetingText)).toBeVisible();
  await expect(frame.getByText('Agreed minutes.')).toHaveCount(0);
  await axeCheck(page);

  // The reader's order is the kit's: the conference's own text before the meeting's, and the
  // meeting's first document after it.
  await tabTo(page, page.getByRole('link', { name: 'Next' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(new RegExp(`/doc/${ownText.volumeId}/d1$`));
  await expect(heading).toHaveText(ownText.firstDocument);
  await tabTo(page, page.getByRole('link', { name: 'Previous' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(new RegExp(`/doc/${ownText.volumeId}/ch1$`));
  await tabTo(page, page.getByRole('link', { name: 'Previous' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(new RegExp(`/doc/${ownText.volumeId}/comp1$`));
  await expect(heading).toHaveText(ownText.conference);
  await expect(frame.getByText(ownText.conferenceText)).toBeVisible();

  // Previous and Next turn the page in place, so Back leaves the reader for the meeting's page.
  await page.goBack();
  await expect(page).toHaveURL(new RegExp(`/browse/${ownText.volumeId}/ch1$`));
  await expect(page.getByRole('link', { name: `Read ${ownText.meeting}` })).toBeVisible();
});
