// The Word Cloud's rules in the browser (PLAN's S24i), what the app's view decides between its data and the screen,
// mirrored under the app's names and held to its source by `WordCloudMirrorParityTests`: the spiral packing that places
// each word (`WordCloudLayout.place`), its sizes on a square-root scale and its estimate of a word's extent; the palette
// the words take by rank (`WordCloudView.palette`) and the sentiment lens's colours; the typefaces and densities the
// reader picks for this device (`WordCloudFontDesign`, `WordCloudDensity`), kept under the app's keys with the measure;
// the settings pane's sample row (`SampleTermsRow`); and the page's address.

/** A word placed on the canvas, `PlacedWord`. */
export interface PlacedWord {
  term: string;
  count: number;
  /** The word's centre. */
  x: number;
  y: number;
  fontSize: number;
  /** Its rank, which picks its colour from the palette. */
  colorIndex: number;
  /** 0, level, or 90, turned to fill a vertical gap. */
  rotation: number;
}

interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

/** `CGRect.contains(_:)`: whether `inner` lies wholly within `outer`. */
function contains(outer: Rect, inner: Rect): boolean {
  return inner.x >= outer.x && inner.y >= outer.y && inner.x + inner.width <= outer.x + outer.width && inner.y + inner.height <= outer.y + outer.height;
}

/** `CGRect.intersects(_:)`, for rectangles of positive size: whether they overlap. */
function intersects(a: Rect, b: Rect): boolean {
  return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
}

/** A term's length as Swift counts it, in characters as a reader sees them. */
function characters(term: string): number {
  if (typeof Intl !== 'undefined' && 'Segmenter' in Intl) {
    return Array.from(new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(term)).length;
  }
  return Array.from(term).length;
}

/**
 * `WordCloudLayout.fontSize`: a count's point size, on the square-root scale that makes a word's area, not its height,
 * roughly proportional to its count.
 */
export function fontSize(count: number, minCount: number, maxCount: number, minFontSize: number, maxFontSize: number): number {
  if (!(maxCount > minCount)) return (minFontSize + maxFontSize) / 2;
  const t = Math.max(0, Math.min(1, (count - minCount) / (maxCount - minCount)));
  const curve = Math.sqrt(t);
  return minFontSize + (maxFontSize - minFontSize) * curve;
}

/** `WordCloudLayout.estimatedSize`: a word's box at a point size, from an average glyph advance, with padding. */
export function estimatedSize(term: string, size: number, widthFactor = 0.54): { width: number; height: number } {
  const width = characters(term) * size * widthFactor + size * 0.4;
  const height = size * 1.25;
  return { width, height };
}

/**
 * `WordCloudLayout.place`: deterministic Archimedean-spiral packing. Words are placed largest first, from the centre
 * outward along a spiral, each at the first position where its estimated box meets neither a word placed before it nor
 * the canvas's edge; a word that finds no place is left out.
 */
export function place(
  terms: { term: string; count: number }[],
  width: number,
  height: number,
  { maxWords = 180, minFontSize = 13, maxFontSize = 64, spacingScale = 1, widthFactor = 0.54 } = {},
): PlacedWord[] {
  const words = terms.slice(0, maxWords);
  const maxCount = words[0]?.count;
  if (!(width > 0 && height > 0) || maxCount === undefined || !(maxCount > 0)) return [];
  const minCount = words[words.length - 1]?.count ?? maxCount;

  const center = { x: width / 2, y: height / 2 };
  const bounds: Rect = { x: 0, y: 0, width, height };
  const placed: PlacedWord[] = [];
  const occupied: Rect[] = [];

  for (const [rank, term] of words.entries()) {
    const size = fontSize(term.count, minCount, maxCount, minFontSize, maxFontSize);
    // Keep the largest words level, and turn every third of the rest a quarter, rank by rank.
    const vertical = rank > Math.floor(words.length / 4) && rank % 3 === 1;
    let estimate = estimatedSize(term.term, size, widthFactor);
    if (vertical) estimate = { width: estimate.height, height: estimate.width };

    // March outward along the spiral until a free slot is found, stretched to favour a wide cloud.
    let angle = 0;
    const angleStep = 0.3;
    const spiralTightness = Math.max(estimate.height, minFontSize) * 0.22 * spacingScale;
    let slot: Rect | undefined;
    while (angle < 70) {
      const radius = spiralTightness * angle;
      const point = { x: center.x + radius * Math.cos(angle) * 1.7, y: center.y + radius * Math.sin(angle) * 1 };
      const rect = { x: point.x - estimate.width / 2, y: point.y - estimate.height / 2, width: estimate.width, height: estimate.height };
      if (contains(bounds, rect) && !occupied.some((taken) => intersects(taken, rect))) {
        slot = rect;
        break;
      }
      angle += angleStep;
    }

    if (!slot) continue;
    placed.push({
      term: term.term,
      count: term.count,
      x: slot.x + slot.width / 2,
      y: slot.y + slot.height / 2,
      fontSize: size,
      colorIndex: rank,
      rotation: vertical ? 90 : 0,
    });
    // Padded so that neighbours do not touch, the gap following the density.
    const gap = -1.5 * spacingScale;
    occupied.push({ x: slot.x + gap, y: slot.y + gap, width: slot.width - 2 * gap, height: slot.height - 2 * gap });
  }
  return placed;
}

/** `WordCloudView.palette`: the app's ten system colours, which a word takes by rank; each a token in app.css. */
export const palette = ['blue', 'teal', 'indigo', 'purple', 'pink', 'orange', 'green', 'red', 'cyan', 'mint'] as const;

/** `wordColor(term:colorIndex:)`: the sentiment lens's polarity, or the palette by rank. */
export function wordColor(rank: number, polarity: number | undefined, colorsBySentiment: boolean): string {
  if (colorsBySentiment) {
    switch (polarity) {
      case 1:
        return 'positive';
      case -1:
        return 'negative';
      default:
        return 'none';
    }
  }
  return palette[rank % palette.length]!;
}

/** `WordCloudFontDesign`: the typeface the cloud is drawn in, and its average glyph advance for the layout. */
export type FontDesign = 'rounded' | 'standard' | 'serif' | 'monospaced';
export const fontDesigns: FontDesign[] = ['rounded', 'standard', 'serif', 'monospaced'];
export const widthFactors: Record<FontDesign, number> = { rounded: 0.54, standard: 0.54, serif: 0.52, monospaced: 0.62 };

/** `WordCloudDensity`: how tightly the cloud packs its words, a multiplier on the spiral and the gap. */
export type Density = 'compact' | 'balanced' | 'airy';
export const densities: Density[] = ['compact', 'balanced', 'airy'];
export const spacingScales: Record<Density, number> = { compact: 0.72, balanced: 1.0, airy: 1.45 };

/** `KeynessCloudMeasure`'s raw values: what the cloud sizes its words by. */
export type Measure = 'frequency' | 'keyness';

/** The app's keys (`WordCloudSettings.Keys`): the measure, the typeface and the density, each kept on this device. */
const keys = { measure: 'frus.wordcloud.measure', fontDesign: 'frus.wordcloud.fontDesign', density: 'frus.wordcloud.density' };

function stored(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function keep(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // Storage that refuses keeps nothing: the next page opens on the app's default.
  }
}

/** The measure this browser keeps, Frequency by default, as the app's `@AppStorage` holds it. */
export function storedMeasure(): Measure {
  return stored(keys.measure) === 'keyness' ? 'keyness' : 'frequency';
}
export function keepMeasure(measure: Measure): void {
  keep(keys.measure, measure);
}

/** The typeface this browser keeps, Rounded by default (`WordCloudSettings.fontDesign`). */
export function storedFontDesign(): FontDesign {
  const value = stored(keys.fontDesign);
  return fontDesigns.includes(value as FontDesign) ? (value as FontDesign) : 'rounded';
}
export function keepFontDesign(design: FontDesign): void {
  keep(keys.fontDesign, design);
}

/** The density this browser keeps, Balanced by default (`WordCloudSettings.density`). */
export function storedDensity(): Density {
  const value = stored(keys.density);
  return densities.includes(value as Density) ? (value as Density) : 'balanced';
}
export function keepDensity(density: Density): void {
  keep(keys.density, density);
}

/** `SampleTermsRow.fontSize(forRank:)`: the settings pane's sample, from 20 points down to 11 across its words. */
export function sampleFontSize(rank: number, count: number): number {
  if (!(count > 1)) return 20;
  const t = rank / (count - 1);
  return 20 - 9 * t;
}

/** The Word Cloud's address: the scope, by the app's signature, and the lens. */
export interface CloudSearch {
  /**
   * The app's signature (`WordCloudScope.signature`): `corpus`, `sub:<subseries>`, `vol:<volume>`, `doc:<volume>/<document>`
   * from the reader's rail, `col:`, `tag:`, `search:` or `scope:<id>` of the reader's own, `subject:<category>␟<sub-category>`
   * or `daterange:<from>..<to>`.
   */
  scope?: string;
  lens?: string;
}

const uuid = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
const day = /^\d{4}-\d{2}-\d{2}$/;

/** Whether `scope` is a signature the app's `WordCloudScope(signature:)` reads. */
export function isScopeSignature(scope: string): boolean {
  if (scope === 'corpus') return true;
  const colon = scope.indexOf(':');
  if (colon < 0) return false;
  const prefix = scope.slice(0, colon);
  const value = scope.slice(colon + 1);
  switch (prefix) {
    case 'sub':
    case 'vol':
      return value !== '';
    case 'doc':
      return /^[^/]+\/.+$/.test(value);
    case 'col':
    case 'tag':
    case 'search':
    case 'scope':
      return uuid.test(value);
    case 'subject':
      return value.split('\u001f')[0] !== '';
    case 'daterange': {
      const bounds = value.split('..');
      return bounds.length === 2 && day.test(bounds[0]!) && day.test(bounds[1]!);
    }
    default:
      return false;
  }
}

/** The address's fields, each checked; what does not fit is dropped. */
export function validateCloudSearch(raw: Record<string, unknown>): CloudSearch {
  const text = (value: unknown) => (typeof value === 'string' && value !== '' ? value : undefined);
  const scope = text(raw.scope);
  const lens = text(raw.lens);
  return {
    scope: scope && isScopeSignature(scope) ? scope : undefined,
    lens: lens && /^[a-zA-Z]+$/.test(lens) ? lens : undefined,
  };
}

/** The document of a scope from the rail, whose cloud the page shows; none for another scope. */
export function documentScope(scope: string | undefined): { volumeId: string; documentId: string } | undefined {
  const match = scope ? /^doc:([^/]+)\/(.+)$/.exec(scope) : null;
  return match ? { volumeId: match[1]!, documentId: match[2]! } : undefined;
}

/** A sub-category's scope, `subject:<category>␟<sub-category>` (`WordCloudScope.subjectCategory`). */
export function subjectScope(category: string, subcategory: string): string {
  return `subject:${category}\u001f${subcategory}`;
}

/** A range of days' scope, `daterange:<from>..<to>` (`WordCloudScope.dateRange`). */
export function dateRangeScope(from: string, to: string): string {
  return `daterange:${from}..${to}`;
}

/** The days of a range's scope; none for another scope. */
export function dateRangeOf(scope: string | undefined): { from: string; to: string } | undefined {
  const match = scope ? /^daterange:(\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2})$/.exec(scope) : null;
  return match ? { from: match[1]!, to: match[2]! } : undefined;
}
