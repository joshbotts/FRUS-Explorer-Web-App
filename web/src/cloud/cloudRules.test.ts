import { afterEach, describe, expect, it } from 'vitest';
import {
  dateRangeOf,
  dateRangeScope,
  documentScope,
  estimatedSize,
  fontSize,
  keepDensity,
  keepFontDesign,
  keepMeasure,
  palette,
  place,
  sampleFontSize,
  storedDensity,
  storedFontDesign,
  storedMeasure,
  subjectScope,
  validateCloudSearch,
  wordColor,
} from './cloudRules';

afterEach(() => window.localStorage.clear());

/** Fifty words with falling counts, as a bundled list holds them. */
const fifty = Array.from({ length: 50 }, (_, index) => ({ term: `term${String.fromCharCode(97 + (index % 26))}${index}`, count: 5000 - index * 97 }));

function box(word: ReturnType<typeof place>[number], widthFactor = 0.54) {
  let { width, height } = estimatedSize(word.term, word.fontSize, widthFactor);
  if (word.rotation) [width, height] = [height, width];
  return { left: word.x - width / 2, top: word.y - height / 2, right: word.x + width / 2, bottom: word.y + height / 2 };
}

describe('the layout (`WordCloudLayout`)', () => {
  it('sizes a count on the square-root scale between 13 and 64 points, and a list of one count at their middle', () => {
    expect(fontSize(100, 1, 100, 13, 64)).toBe(64);
    expect(fontSize(1, 1, 100, 13, 64)).toBe(13);
    expect(fontSize(25.75, 1, 100, 13, 64)).toBeCloseTo(13 + 51 * Math.sqrt(0.25), 10);
    expect(fontSize(7, 7, 7, 13, 64)).toBe(38.5);
  });

  it('estimates a word by its characters, as a reader sees them', () => {
    expect(estimatedSize('treaty', 20)).toEqual({ width: 6 * 20 * 0.54 + 8, height: 25 });
    expect(estimatedSize('détente', 10).width).toBeCloseTo(7 * 10 * 0.54 + 4, 10);
  });

  it('places the largest word level at the centre, every word inside the canvas, and none over another', () => {
    const placed = place(fifty, 900, 540);
    expect(placed.length).toBeGreaterThan(15);
    expect(placed[0]).toMatchObject({ term: fifty[0]!.term, x: 450, y: 270, rotation: 0, colorIndex: 0, fontSize: 64 });
    for (const word of placed) {
      const edges = box(word);
      expect(edges.left).toBeGreaterThanOrEqual(0);
      expect(edges.top).toBeGreaterThanOrEqual(0);
      expect(edges.right).toBeLessThanOrEqual(900);
      expect(edges.bottom).toBeLessThanOrEqual(540);
    }
    for (const [index, a] of placed.entries()) {
      for (const b of placed.slice(index + 1)) {
        const [p, q] = [box(a), box(b)];
        expect(p.left < q.right && q.left < p.right && p.top < q.bottom && q.top < p.bottom, `${a.term} and ${b.term}`).toBe(false);
      }
    }
  });

  it('turns every third word past the first quarter, by rank, and keeps the first quarter level', () => {
    const placed = place(fifty, 1200, 800);
    for (const word of placed) {
      const vertical = word.colorIndex > Math.floor(fifty.length / 4) && word.colorIndex % 3 === 1;
      expect(word.rotation).toBe(vertical ? 90 : 0);
    }
    expect(placed.some((word) => word.rotation === 90)).toBe(true);
  });

  it('is the same at the same size, and leaves out a word with no place rather than overlapping it', () => {
    expect(place(fifty, 640, 400)).toEqual(place(fifty, 640, 400));
    const small = place(fifty, 160, 120);
    expect(small.length).toBeLessThan(fifty.length);
    expect(place([], 640, 400)).toEqual([]);
    expect(place(fifty, 0, 400)).toEqual([]);
    expect(place([{ term: 'none', count: 0 }], 640, 400)).toEqual([]);
  });

  it('packs tighter or looser with the density, and estimates by the typeface', () => {
    const compact = place(fifty, 500, 320, { spacingScale: 0.72 });
    const airy = place(fifty, 500, 320, { spacingScale: 1.45 });
    expect(compact.length).toBeGreaterThanOrEqual(airy.length);
    const monospaced = place(fifty, 500, 320, { widthFactor: 0.62 });
    for (const word of monospaced) expect(box(word, 0.62).right).toBeLessThanOrEqual(500);
  });
});

describe('the colours', () => {
  it('take the app’s ten by rank, round again, and the sentiment lens’s by polarity', () => {
    expect(palette).toEqual(['blue', 'teal', 'indigo', 'purple', 'pink', 'orange', 'green', 'red', 'cyan', 'mint']);
    expect(wordColor(0, undefined, false)).toBe('blue');
    expect(wordColor(11, undefined, false)).toBe('teal');
    expect([wordColor(0, 1, true), wordColor(1, -1, true), wordColor(2, 0, true)]).toEqual(['positive', 'negative', 'none']);
  });
});

describe('this browser’s choices', () => {
  it('open on the app’s defaults and keep what is chosen under the app’s keys', () => {
    expect([storedMeasure(), storedFontDesign(), storedDensity()]).toEqual(['frequency', 'rounded', 'balanced']);
    keepMeasure('keyness');
    keepFontDesign('serif');
    keepDensity('airy');
    expect([storedMeasure(), storedFontDesign(), storedDensity()]).toEqual(['keyness', 'serif', 'airy']);
    expect(window.localStorage.getItem('frus.wordcloud.fontDesign')).toBe('serif');
    window.localStorage.setItem('frus.wordcloud.density', 'loose');
    expect(storedDensity()).toBe('balanced');
  });

  it('size the settings pane’s sample from 20 points down to 11', () => {
    expect(sampleFontSize(0, 12)).toBe(20);
    expect(sampleFontSize(11, 12)).toBe(11);
    expect(sampleFontSize(0, 1)).toBe(20);
  });
});

describe('the address', () => {
  it('keeps a scope the app’s signature names and a lens, and drops anything else', () => {
    expect(validateCloudSearch({ scope: 'corpus', lens: 'topics' })).toEqual({ scope: 'corpus', lens: 'topics' });
    expect(validateCloudSearch({ scope: 'sub:1969-76' }).scope).toBe('sub:1969-76');
    expect(validateCloudSearch({ scope: 'vol:frus1961-63v06' }).scope).toBe('vol:frus1961-63v06');
    expect(validateCloudSearch({ scope: 'doc:frus1961-63v06/d5' }).scope).toBe('doc:frus1961-63v06/d5');
    expect(validateCloudSearch({ scope: 'col:abc', lens: 'top ics' })).toEqual({ scope: undefined, lens: undefined });
    expect(validateCloudSearch({ scope: 'doc:frus1961-63v06' }).scope).toBeUndefined();
  });

  it('reads every scope the app’s `WordCloudScope(signature:)` reads, and nothing else (S29e)', () => {
    const id = '5E17F000-0000-4000-8000-0000000000A1';
    for (const scope of [`col:${id}`, `tag:${id.toLowerCase()}`, `search:${id}`, `scope:${id}`, 'subject:Economics', 'subject:Economics\u001fTrade',
      'daterange:1962-10-01..1962-10-31']) {
      expect(validateCloudSearch({ scope }).scope).toBe(scope);
    }
    for (const scope of ['col:abc', 'subject:', 'subject:\u001fTrade', 'daterange:1962-10-01', 'daterange:1962-10..1962-11', 'era:1969-76', 'everything']) {
      expect(validateCloudSearch({ scope }).scope).toBeUndefined();
    }
  });

  it('writes a sub-category’s and a range’s scopes as the app signs them, and reads a range’s days back', () => {
    expect(subjectScope('Economics', 'Trade')).toBe('subject:Economics\u001fTrade');
    expect(dateRangeScope('1962-10-01', '1962-10-31')).toBe('daterange:1962-10-01..1962-10-31');
    expect(dateRangeOf('daterange:1962-10-01..1962-10-31')).toEqual({ from: '1962-10-01', to: '1962-10-31' });
    expect(dateRangeOf('corpus')).toBeUndefined();
  });

  it('reads a document’s scope from the rail as its volume and document', () => {
    expect(documentScope('doc:frus1961-63v06/d5')).toEqual({ volumeId: 'frus1961-63v06', documentId: 'd5' });
    expect(documentScope('vol:frus1961-63v06')).toBeUndefined();
    expect(documentScope(undefined)).toBeUndefined();
  });
});
