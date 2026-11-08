// The editors' annotations (FRUS-Explorer#1859 to #1862), the follow-up to the pin move to fe9325b2:
// Playwright reaches a volume page's Editors’ Annotations and Browse's axis of that name by keyboard on
// Chromium, with no axe violations. The counts are the bundled volume-annotations-index.json's, which the
// image carries with the app's other data files, as the app's own UI suites read the shipped file
// (`VolumeAnnotationsSectionTests`, `AnnotationsAxisBrowseTests`).
import { axeCheck } from './axe';
import { v06Title } from './expected';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';

const peopleRule = 'A volume counts when at least half its documents link a name to its List of Persons.';

test('opens a layer from a volume’s Editors’ Annotations, lists its volumes with that one first, and reaches the axis’s matrix and an era’s volumes, by keyboard alone', async ({
  page,
}) => {
  await page.goto('browse/frus1961-63v06');
  const heading = page.getByRole('heading', { level: 1 });
  await expect(heading).toHaveText(v06Title);
  const section = page.getByRole('region', { name: 'Editors’ Annotations' });
  await expect(section.getByRole('heading', { level: 3 })).toHaveText(['Who is named', 'Where it came from', 'How it connects']);
  const people = section.getByRole('link', { name: 'People tagged: 120 of 120 documents; 58 people listed.' });
  await expect(people).toBeVisible();
  await expect(section.getByRole('link', { name: /^Cross-references: / })).toHaveAccessibleName(
    'Cross-references: 70 documents cite others in this volume; 13 documents cite other volumes; 12 documents cite printed pages.',
  );
  await expect(section.getByRole('link', { name: /^Printed aids: / })).toContainText('Preface · Sources · Abbreviations · Persons · Index');
  // It carries every standard layer, so nothing is listed as absent.
  await expect(section.locator('details')).toHaveCount(0);
  await axeCheck(page);

  // The row opens People tagged's page, which keeps the volume it came from.
  await tabTo(page, people);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/browse\/annotations\/people\?from=frus1961-63v06$/);
  await expect(heading).toHaveText('People tagged');
  await expect(heading).toBeFocused();
  await expect(page.getByText('288 of 553 volumes', { exact: true })).toBeVisible();
  await expect(page.getByText(peopleRule, { exact: true })).toBeVisible();
  await expect(page.getByText('Standard in the volumes covering 1955 on.')).toBeVisible();
  await expect(page.getByText('1955–1968: 114 of 114 volumes')).toBeAttached();
  await axeCheck(page);

  // Volumes with it: the volume the page came from first, marked, in the rest's place in volume order.
  await tabTo(page, page.getByRole('link', { name: 'Volumes with it: 288 volumes' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/browse\/annotations\/people\/with\?from=frus1961-63v06$/);
  await expect(heading).toHaveText('With: People tagged');
  await expect(heading).toBeFocused();
  await expect(page.getByText(`288 of 553 volumes. ${peopleRule}`)).toBeVisible();
  const list = page.getByRole('list', { name: 'With: People tagged' });
  await expect(list.getByRole('listitem')).toHaveCount(288);
  const first = list.getByRole('listitem').first();
  await expect(first.getByRole('link')).toHaveText(v06Title);
  await expect(first).toContainText('frus1961-63v06 · 120/120');
  await expect(first.getByText('You came here from this volume.')).toBeVisible();
  await axeCheck(page);

  // The breadcrumb's axis: each group a matrix, a layer's row beside a cell for each era.
  await backTabTo(page, page.getByRole('navigation', { name: 'Breadcrumb' }).getByRole('link', { name: 'Editors’ Annotations' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/browse\/annotations$/);
  await expect(heading).toHaveText('Editors’ Annotations');
  await expect(heading).toBeFocused();
  const axes = page.getByRole('navigation', { name: 'Browse by' });
  await expect(axes.getByRole('link', { name: 'Editors’ Annotations' })).toHaveAttribute('aria-current', 'page');
  await expect(axes.getByRole('link', { name: 'All Volumes' })).not.toHaveAttribute('aria-current');
  const named = page.getByRole('table', { name: 'Who is named' });
  await expect(named.getByRole('columnheader')).toHaveText(['1861', '1899', '1914', '1920', '1932', '1945', '1951', '1955', '1969', '1981', 'Retro.']);
  await expect(named.getByRole('link', { name: 'People tagged: 288 of 553 volumes. Standard in the volumes covering 1955 on.' })).toBeVisible();
  await expect(page.getByRole('table', { name: 'Where it came from' })).toBeVisible();
  await expect(page.getByRole('table', { name: 'How it connects' })).toBeVisible();
  // A cell no volume of its era fills is read, and opens nothing.
  const empty = named.getByRole('link', { name: 'People tagged, 1899–1913: 0 of 20 volumes' });
  await expect(empty).toHaveAttribute('aria-disabled', 'true');
  await axeCheck(page);

  // A cell: the volumes covering 1955–1968 that tag their people.
  await tabTo(page, named.getByRole('link', { name: 'People tagged, 1955–1968: 114 of 114 volumes' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/browse\/annotations\/people\/era\/1955-1968$/);
  await expect(heading).toHaveText('People tagged, 1955–1968');
  await expect(heading).toBeFocused();
  await expect(page.getByText(`1955–1968: 114 of 114 volumes. ${peopleRule}`)).toBeVisible();
  await expect(page.getByRole('list', { name: 'People tagged, 1955–1968' }).getByRole('listitem')).toHaveCount(114);
  await axeCheck(page);
});

test('opens what a volume lacks by keyboard, and its absent row lists the volumes without the layer with that one first', async ({ page }) => {
  await page.goto('browse/frus1894Nicaragua');
  const heading = page.getByRole('heading', { level: 1 });
  const section = page.getByRole('region', { name: 'Editors’ Annotations' });
  await expect(section.getByRole('link', { name: 'Senders and recipients: 138 documents.' })).toBeVisible();
  await expect(section.getByRole('link', { name: 'Cross-references: 13 documents cite others in this volume; 2 documents cite printed pages.' })).toBeVisible();
  const summary = section.getByText('Not in this volume (7)', { exact: true });
  const absent = section.getByRole('link', {
    name: 'Not in this volume: People tagged. Standard in the volumes covering 1955 on. Search the names instead.',
  });
  // Collapsed at first.
  await expect(absent).toBeHidden();
  await tabTo(page, summary);
  await page.keyboard.press('Enter');
  await expect(absent).toBeVisible();
  await axeCheck(page);

  await tabTo(page, absent);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/browse\/annotations\/people\?from=frus1894Nicaragua$/);
  await expect(heading).toHaveText('People tagged');
  await tabTo(page, page.getByRole('link', { name: 'Volumes without it: 265 volumes' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/browse\/annotations\/people\/without\?from=frus1894Nicaragua$/);
  await expect(heading).toHaveText('Without: People tagged');
  await expect(heading).toBeFocused();
  const list = page.getByRole('list', { name: 'Without: People tagged' });
  await expect(list.getByRole('listitem').first()).toContainText('You came here from this volume.');
  // frus1977-80v27 prints a List of Persons that none of its documents links to.
  await expect(list.getByText('Prints a List of Persons, but none of its documents links a name to it.')).toHaveCount(1);
  await axeCheck(page);
});
