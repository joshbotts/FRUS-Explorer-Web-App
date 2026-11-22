// The few rules of the app's Source Explorer views that are view code rather than the kit's, mirrored and held
// to the app's source by SourceExplorerParityTests: the published-source guidance's link table
// (`PublishedSourceLinkTable`) and its freshness (`RepositoryLink.isStale`), a bundled lot's access and use rows,
// a curated candidate's subtitle, and the provenance chip's glyph by tier (`ProvenanceChip.glyph(for:)`); a
// collection record's related row's caption, overlap and meter, and a claiming series' caption
// (`CollectionDetailView`); and the name a Sources row's Archival Neighbors button is spoken by in its three
// states (`VolumeSourcesView.neighborsAccessibilityLabel(count:)`).
import { copy } from '../copy';

/** The page each publication family's guidance links (`PublishedSourceLinkTable.link(for:)`). */
export const publishedLinks: Record<string, string> = {
  treatySeries: 'https://guides.loc.gov/researching-treaties-and-international-agreements',
  executiveAgreementSeries: 'https://guides.loc.gov/researching-treaties-and-international-agreements',
  stateBulletin: 'https://archive.org/details/pub_department-of-state-bulletin',
  publicPapers: 'https://www.govinfo.gov/app/collection/PPP',
};

/** When the links were last confirmed (`PublishedSourceLinkTable.confirmed`): 20 November 2026, UTC. */
export const publishedLinksConfirmed = Date.UTC(2026, 10, 20);

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

/** A related collection's caption (`provenanceCaption(for:)`): its repository and record group, or none. */
export function relatedCaption(record: { repository?: string; recordGroup?: string }): string | undefined {
  const parts = [record.repository, record.recordGroup && `RG ${record.recordGroup}`].filter((part): part is string => !!part);
  return parts.length > 0 ? parts.join(' · ') : undefined;
}

/**
 * A related row's overlap as the app says it, `formatted(.percent.precision(.fractionLength(0)))` in US English:
 * a whole percent, a half rounded to the even, as Foundation rounds.
 */
export function overlapPercent(overlap: number): string {
  return overlap.toLocaleString('en-US', { style: 'percent', minimumFractionDigits: 0, maximumFractionDigits: 0, roundingMode: 'halfEven' });
}

/** The width of a related row's 56-point meter's fill (`overlapMeter`): the overlap's share of it, 2 at the least. */
export function overlapMeterWidth(overlap: number): number {
  const fraction = Math.min(Math.max(overlap, 0), 1);
  return Math.max(2, 56 * fraction);
}

/** A claiming series' caption (`claimantCaption`): its NAID, record group and dates, each NARA's own. */
export function claimantCaption(claimant: { naId: string; recordGroup?: string; dateRange?: string }): string {
  const parts = [copy.archivalCollection.dividedNAID(claimant.naId)];
  if (claimant.recordGroup) parts.push(`RG ${claimant.recordGroup}`);
  if (claimant.dateRange) parts.push(claimant.dateRange);
  return parts.join(' · ');
}

/**
 * A Sources row's Archival Neighbors button's name (`neighborsAccessibilityLabel(count:)`): for a count of none, a
 * count, and none known.
 */
export function neighboursLabel(count: number | undefined): string {
  const words = copy.volumeSources;
  if (count === 0) return words.neighboursZero;
  if (count !== undefined) return words.neighboursCount(count);
  return words.neighbours;
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
