// Whether the server under test offers PDF (PLAN's S25a): its PDF service answers, as it does once the
// Compose smoke test has started the `pdf` profile, or not, as without it. The export sheet's specs hold
// either way: PDF first and chosen as the sheet opens while the server offers it, as the app's sheet
// opens on PDF, and HTML first and chosen while it does not.
import type { Page } from '@playwright/test';
import { getJSON } from './notes';

/** Whether the server makes PDFs now, as `GET /api/v1/pdf` says. */
export async function offersPdf(page: Page): Promise<boolean> {
  return (await getJSON<{ available: boolean }>(page, 'api/v1/pdf')).available;
}

/** The radio the export sheet opens on, by its name. */
export const firstFormat = (pdf: boolean): string => (pdf ? 'PDF, Formatted reader' : 'HTML, Web page');
