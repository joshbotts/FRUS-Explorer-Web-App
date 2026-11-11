// Related Documents' rules in the browser (PLAN's S23d), mirrored from the app's `RelatedDocumentsContent`
// and held to its source by `RelatedDocumentsParityTests`: a row's title, the empty list's sentence by
// scope, and the overflow line. And a tuning written as the app stores one, its departures from the
// defaults, which the server reads with the kit's `AxisWeights(rawValue:)` and gives back in the kit's
// own spelling.
import type { RelatedAxis, RelatedRow, RelatedScope } from '../api/related';
import { copy } from '../copy';

/** A row's title: its head, else the document's id (`row.record.header.isEmpty ? row.documentId : …`). */
export function rowTitle(row: Pick<RelatedRow, 'header' | 'documentId'>): string {
  return row.header === '' ? row.documentId : row.header;
}

/** The empty list's sentence: one for all volumes, and one inviting to widen a narrower scope. */
export function emptyDetail(scope: RelatedScope): string {
  return scope === 'all' ? copy.related.emptyDetail : copy.related.emptyDetailScoped;
}

/** "N more related", while more scored than the list shows (`totalBeforeLimit > rows.count`). */
export function overflowLine(totalBeforeLimit: number, shown: number): string | undefined {
  return totalBeforeLimit > shown ? copy.related.overflow(totalBeforeLimit - shown) : undefined;
}

/**
 * A tuning as the app stores one (`AxisWeights.rawValue`): each axis away from its default, as
 * `axis:weight`, sorted by the axis's stored name and joined by commas; `''` for the defaults.
 */
export function encodedWeights(weights: Readonly<Record<string, number>>, axes: readonly RelatedAxis[]): string {
  return axes
    .filter((axis) => (weights[axis.id] ?? axis.weight) !== axis.defaultWeight)
    .map((axis) => axis.id)
    .sort()
    .map((id) => `${id}:${weights[id] ?? axes.find((axis) => axis.id === id)!.weight}`)
    .join(',');
}

/** A weight as the app's row shows it, to one decimal place. */
export function weightText(weight: number): string {
  return weight.toFixed(1);
}
