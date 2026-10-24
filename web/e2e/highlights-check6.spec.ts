// Check 6 on the fixtures (PLAN's S15c): highlights placed by offset over each golden row's flat text,
// the kit's buildFlatText, and the text the reader's page holds between those offsets, read by the
// kit's offset engine in Chromium, equals each one's text. fixtures/highlights/samples.json is the
// Swift half, which FRUSParityTests holds to the kit at the pin. For each of the 393 rows the page is
// loaded as the server serves it, and checked: its rendering version is the kit's; the engine's flat
// text has the row's length and digest; each sample's text, read through the engine's map of the
// live page, is the sample's; the kit's selection bridge reads the kit's own range for each sample
// back to its offsets; and the kit's renderer draws one range for each, under its colour's name or
// the stale one's.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { expect, test } from './fixtures';

interface Sample {
  startOffset: number;
  endOffset: number;
  color: string;
  isStale: boolean;
  text?: string;
}

interface Row {
  volume: string;
  document: string;
  length: number;
  sha256: string;
  renderingVersion: string;
  samples: Sample[];
}

/** What the kit's three scripts leave on the reader page's window. */
interface ReaderWindow {
  FRUSOffsets: { flatText: string; charToNode: { node: Node; localOffset: number }[] } | null;
  FRUSHighlights: { render(highlights: Omit<Sample, 'text'>[]): void };
  buildRanges(start: number, end: number): Range[];
  rangeEndpointToOffset(node: Node, offset: number): number;
}

const file = JSON.parse(readFileSync(new URL('../../fixtures/highlights/samples.json', import.meta.url), 'utf8')) as {
  formatVersion: number;
  rows: Row[];
};
const volumes = [...new Set(file.rows.map((row) => row.volume))];

/** A figure's image, which the suite's TEI folder lacks: an empty PNG, so a figure row logs no 404. */
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=', 'base64');

test('the samples cover the 393 golden rows', () => {
  expect(file.formatVersion).toBe(1);
  expect(file.rows).toHaveLength(393);
});

for (const volume of volumes) {
  const rows = file.rows.filter((row) => row.volume === volume);
  test(`check 6 over ${volume}'s ${rows.length} rows`, async ({ page }) => {
    test.setTimeout(240_000);
    await page.route('**/api/v1/volumes/*/figures/**', (route) => route.fulfill({ contentType: 'image/png', body: png }));
    const differences: string[] = [];
    let highlights = 0;
    for (const row of rows) {
      const where = `${row.volume}/${row.document}`;
      const response = await page.goto(`api/v1/volumes/${row.volume}/documents/${row.document}/html`);
      expect(response?.status(), where).toBe(200);
      expect(response?.headers()['x-frus-rendering-version'], where).toBe(row.renderingVersion);
      const flat = await page.evaluate(() => (window as unknown as ReaderWindow).FRUSOffsets?.flatText ?? null);
      expect(flat, `${where}: the offset engine found the page's .frus-document`).not.toBeNull();
      if (flat === null) continue;
      if (flat.length !== row.length) differences.push(`${where}: ${flat.length} UTF-16 units, not ${row.length}`);
      if (createHash('sha256').update(flat, 'utf8').digest('hex') !== row.sha256) differences.push(`${where}: the flat text differs`);

      const read = await page.evaluate((samples) => {
        const kit = window as unknown as ReaderWindow;
        const map = kit.FRUSOffsets!.charToNode;
        // The live page's characters through the engine's map: a text node's, or a <br>'s newline.
        const text = (start: number, end: number) => {
          let out = '';
          for (let index = start; index < end; index++) {
            const { node, localOffset } = map[index];
            out += node.nodeType === Node.TEXT_NODE ? node.nodeValue![localOffset] : '\n';
          }
          return out;
        };
        const results = samples.map((sample) => {
          const [range] = kit.buildRanges(sample.startOffset, sample.endOffset);
          return {
            text: sample.text === undefined ? text(sample.startOffset, sample.endOffset) === kit.FRUSOffsets!.flatText : text(sample.startOffset, sample.endOffset),
            bridged:
              !!range &&
              kit.rangeEndpointToOffset(range.startContainer, range.startOffset) === sample.startOffset &&
              kit.rangeEndpointToOffset(range.endContainer, range.endOffset) === sample.endOffset,
          };
        });
        kit.FRUSHighlights.render(samples.map(({ startOffset, endOffset, color, isStale }) => ({ startOffset, endOffset, color, isStale })));
        const drawn: Record<string, number> = {};
        for (const name of ['frus-yellow', 'frus-green', 'frus-blue', 'frus-pink', 'frus-stale']) drawn[name] = CSS.highlights.get(name)?.size ?? 0;
        return { results, drawn };
      }, row.samples);

      const expected: Record<string, number> = { 'frus-yellow': 0, 'frus-green': 0, 'frus-blue': 0, 'frus-pink': 0, 'frus-stale': 0 };
      row.samples.forEach((sample, index) => {
        const span = `${where} ${sample.startOffset}–${sample.endOffset}`;
        const got = read.results[index];
        if (sample.text === undefined ? got.text !== true : got.text !== sample.text) {
          differences.push(`${span}: the page holds ${JSON.stringify(got.text)}, not ${JSON.stringify(sample.text ?? 'the whole flat text')}`);
        }
        if (!got.bridged) differences.push(`${span}: the selection bridge does not read the kit's range back to its offsets`);
        expected[sample.isStale ? 'frus-stale' : `frus-${sample.color}`] += 1;
      });
      if (JSON.stringify(read.drawn) !== JSON.stringify(expected)) {
        differences.push(`${where}: drawn ${JSON.stringify(read.drawn)}, not ${JSON.stringify(expected)}`);
      }
      highlights += row.samples.length;
    }
    expect(differences).toEqual([]);
    console.log(`check 6 over ${volume}: ${rows.length} rows, ${highlights} highlights, the page's text the kit's between every offset`);
  });
}
