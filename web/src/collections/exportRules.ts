// The lines of the app's preview and export sheet the browser app mirrors (PLAN's S18e), held to the
// app's source by FRUSParityTests' CollectionExportParityTests: the sheet's sentence of what an export
// carries (`Collection.compositionSummarySentence`), the bar the preview shows past its cap
// (`CollectionPreviewView.capBar`'s condition) and the time the preview waits for edits to settle; and
// from S18f the grid's formats for a smart collection (`ExportFormat.gridFormats(smartCollection:)`).
import { exportFormats, previewDocumentCap, type CollectionDetail, type ExportFormat } from '../api/collections';
import { copy } from '../copy';

const words = copy.collectionExport;

/**
 * `Collection.compositionSummarySentence`: the default body depth, then what the composition turns on,
 * in its order, joined as the app's `ListFormatter` joins them in US English.
 */
export function compositionSentence(detail: CollectionDetail): string {
  const lead = words.lead[detail.defaultBodyDepth] ?? words.lead.full!;
  const included: string[] = [];
  if (detail.defaultIncludeHeadnote) included.push(words.included.headnotes);
  if (detail.includeNotes) included.push(words.included.notes);
  if (detail.includeFootnotes) included.push(words.included.footnotes);
  if (detail.includeSourceNote) included.push(words.included.sourceNotes);
  if (detail.applyHighlights) included.push(words.included.highlights);
  if (detail.includeWordCloud) included.push(words.included.wordCloud);
  if (included.length === 0) return `${lead}.`;
  return words.withIncluded(lead, new Intl.ListFormat('en-US', { style: 'long', type: 'conjunction' }).format(included));
}

/**
 * `CollectionPreviewView`'s cap bar: shown until Render All, for more documents than the preview resolves,
 * a smart collection's its results' count.
 */
export function showsCapBar(documentCount: number, renderAll: boolean): boolean {
  return !renderAll && documentCount > previewDocumentCap;
}

/**
 * `ExportFormat.gridFormats(smartCollection:)`: the grid in the app's order, the native file dropped for a
 * smart collection, whose documents no file carries.
 */
export function gridFormats(smartCollection: boolean): readonly ExportFormat[] {
  return smartCollection ? exportFormats.filter((format) => format !== 'fruscollection') : exportFormats;
}

/** `CollectionPreviewView.refresh()`'s debounce: how long edits settle before the page is built again. */
export const previewSettleMilliseconds = 1_000;
