// The few rules of the app's Source Explorer views that are view code rather than the kit's, mirrored and held
// to the app's source by SourceExplorerParityTests: the published-source guidance's link table
// (`PublishedSourceLinkTable`) and its freshness (`RepositoryLink.isStale`), a bundled lot's access and use rows,
// a curated candidate's subtitle, and the provenance chip's glyph by tier (`ProvenanceChip.glyph(for:)`).

/** The page each publication family's guidance links (`PublishedSourceLinkTable.link(for:)`). */
export const publishedLinks: Record<string, string> = {
  treatySeries: 'https://guides.loc.gov/researching-treaties-and-international-agreements',
  executiveAgreementSeries: 'https://guides.loc.gov/researching-treaties-and-international-agreements',
  stateBulletin: 'https://archive.org/details/pub_department-of-state-bulletin',
  publicPapers: 'https://www.govinfo.gov/app/collection/PPP',
};

/** When the links were last confirmed (`PublishedSourceLinkTable.confirmed`): 28 August 2026, UTC. */
export const publishedLinksConfirmed = Date.UTC(2026, 7, 28);

/** How long a confirmed link stays fresh (`RepositoryLink.freshnessWindow`): about six months. */
const freshnessWindow = 180 * 24 * 60 * 60 * 1000;

/** Whether the guidance's link is past its freshness window (`RepositoryLink.isStale(asOf:)`). */
export function publishedLinkStale(now: number = Date.now()): boolean {
  return now - publishedLinksConfirmed > freshnessWindow;
}

/** The confirmed day as the app writes it, `formatted(date: .abbreviated, time: .omitted)` in US English. */
export function confirmedDay(): string {
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' }).format(
    publishedLinksConfirmed,
  );
}

/** An access or use row's value (`bundledLotSection`): the status, then its restrictions after a dash, when any. */
export function statusValue(status: string, restrictions: string[] | undefined): string {
  return restrictions && restrictions.length > 0 ? `${status} — ${restrictions.join(', ')}` : status;
}

/** A curated candidate's one-line subtitle (`curatedSeriesSubtitle`): its entry number and dates, or none. */
export function curatedSubtitle(series: { entryNumber?: string; dateRange?: string }): string | undefined {
  const parts = [series.entryNumber, series.dateRange].filter((part): part is string => !!part);
  return parts.length > 0 ? parts.join(' · ') : undefined;
}

/** The provenance chip's glyph for its source's tier (`ProvenanceChip.glyph(for:)`), drawn as a shape. */
export function provenanceGlyph(tier: 'frusOnly' | 'joined' | 'computed'): '■' | '▲' | '●' {
  switch (tier) {
    case 'frusOnly':
      return '■';
    case 'joined':
      return '▲';
    case 'computed':
      return '●';
  }
}
