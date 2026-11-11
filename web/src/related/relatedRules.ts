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

/** A weight as Swift writes a `Double`: a whole number with `.0`, as the app's stored form has it. */
function weightToken(weight: number): string {
  return Number.isInteger(weight) ? weight.toFixed(1) : String(weight);
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
    .map((id) => `${id}:${weightToken(weights[id] ?? axes.find((axis) => axis.id === id)!.weight)}`)
    .join(',');
}

/**
 * Each axis's weight in a tuning of the app's stored form, an axis it leaves out at its default, as the
 * kit's `AxisWeights(rawValue:)` fills it: what the sliders show of the tuning a list was asked for,
 * before the server answers with it.
 */
export function decodedWeights(raw: string, axes: readonly RelatedAxis[]): Record<string, number> {
  const given = new Map<string, number>();
  for (const pair of raw.split(',')) {
    const [id, value] = pair.split(':');
    const weight = Number(value);
    if (id && value !== undefined && value !== '' && Number.isFinite(weight)) given.set(id, weight);
  }
  return Object.fromEntries(axes.map((axis) => [axis.id, given.get(axis.id) ?? axis.defaultWeight]));
}

/** A weight as the app's row shows it, to one decimal place. */
export function weightText(weight: number): string {
  return weight.toFixed(1);
}
