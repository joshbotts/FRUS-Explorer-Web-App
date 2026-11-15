// Corpus Analytics' and Chronology's rules in the browser (PLAN's S24f): the palette, the year fields' bounds, the
// axis menu's sections, the scope menu's choices, the addresses, and the charts drawn from the server's series.
import { describe, expect, it } from 'vitest';
import type { AnalyticsContext, AnalyticsPlate, ChronologyAnswer, CorpusAnswer } from '../api/analytics';
import { corpusParams } from '../api/analytics';
import type { VolumeScope } from '../api/searchSets';
import {
  addressScope,
  axisSections,
  breakdownSpec,
  chartPalette,
  chronologySpec,
  clampEnd,
  clampStart,
  corpusSpec,
  figureSpec,
  otherGray,
  scopeFields,
  scopeGroups,
  scopeValue,
  seriesColor,
  stackedPeriodSpec,
  validateChronologySearch,
  validateCorpusSearch,
  wrapped,
} from './analyticsRules';

function answer(fields: Partial<CorpusAnswer> = {}): CorpusAnswer {
  return {
    term: 'cold',
    axis: 'byYear',
    axisLabel: 'By Year',
    state: 'chart',
    heading: '"cold" — by Year',
    figureTitle: '"cold" — By Year',
    valueAxisLabel: 'Documents',
    periodLabel: 'Year',
    measure: { chosen: 'documents', effective: 'documents', applies: true, available: true },
    values: { chosen: 'raw', applies: true, enabled: true, isNormalized: false },
    years: { start: 1960, end: 1965, isCustom: true, applies: true },
    scope: { label: 'Whole corpus' },
    colors: 8,
    segments: [
      { period: 1962, seriesKey: 'frus1961-63v06', count: 3, plotted: 3 },
      { period: 1961, seriesKey: 'frus1961-63v06', count: 2, plotted: 2 },
      { period: 1962, seriesKey: '__other__', count: 1, plotted: 1 },
      { period: 1963, seriesKey: 'frus1961-63v06', count: 4 },
    ],
    series: [
      { key: 'frus1961-63v06', title: 'Kennedy-Khrushchev · 1961-63 v06', total: 5, totalLabel: '5 docs', isOther: false },
      { key: '__other__', title: 'Other volumes', total: 1, totalLabel: '1 docs', isOther: true },
    ],
    fit: [
      { period: 1961, value: 2 },
      { period: 1962, value: 4 },
    ],
    points: [],
    bars: [],
    matchedDocumentCount: 6,
    table: { title: '"cold" — By Year', columns: ['Term', 'Year', 'Matching documents'], rows: [['cold', '1961', '2']] },
    ...fields,
  };
}

const context: AnalyticsContext = {
  floorYear: 1861,
  corpusMaxYear: 1992,
  earliestYear: 1776,
  chronologyFrom: '1991-12-31',
  chronologyTo: '1992-12-31',
  presets: [{ label: 'Abraham Lincoln (1861–1865)', start: 1861, end: 1865 }],
  colorCounts: [6, 7, 8, 9, 10, 11, 12],
  defaultColors: 8,
  indexedVolumeCount: 3,
  subseries: [
    { name: '1894', volumes: [{ id: 'frus1894Nicaragua', title: 'Affairs in Nicaragua' }] },
    { name: '1961-63', volumes: [{ id: 'frus1961-63v06', title: 'Kennedy-Khrushchev Exchanges' }] },
  ],
  topics: [
    {
      label: 'Arms Control',
      items: [
        { subcategory: 'Nuclear Testing', label: 'Nuclear Testing (1 of 2 indexed)', indexed: 1, total: 2 },
        { subcategory: 'Chemical', label: 'Chemical — none indexed yet', indexed: 0, total: 4 },
      ],
    },
  ],
};

describe('the palette', () => {
  it('is the app’s twelve system colours, the folded Other grey', () => {
    expect(chartPalette).toHaveLength(12);
    expect(seriesColor('frus1961-63v06', 0)).toBe('#007AFF');
    expect(seriesColor('x', 13)).toBe(chartPalette[1]);
    expect(seriesColor('__other__', 0)).toBe(otherGray);
  });
});

describe('the year fields', () => {
  it('clamp a start into 1776 to the end, an end into the start to the corpus’s last year', () => {
    expect(clampStart(1700, 1950, 1776)).toBe(1776);
    expect(clampStart(1960, 1950, 1776)).toBe(1950);
    expect(clampEnd(1940, 1950, 1992)).toBe(1950);
    expect(clampEnd(2020, 1950, 1992)).toBe(1992);
  });
});

describe('the axis menu', () => {
  it('has the app’s two sections, the date-based axes over time', () => {
    const sections = axisSections();
    expect(sections.map((section) => section.label)).toEqual(['Over time', 'Broken down by']);
    expect(sections[0]?.axes).toEqual(['byDecade', 'byYear', 'byMonth', 'byDay']);
    expect(sections[1]?.axes).toEqual(['bySubseries', 'byVolume']);
  });
});

describe('the scope menu', () => {
  const scopes: VolumeScope[] = [
    { id: 'B', name: 'Berlin', volumeIds: ['frus1961-63v06', 'frus1958-60v08'], indexedVolumeIds: ['frus1961-63v06'], cataloguedCount: 2 } as VolumeScope,
    { id: 'A', name: 'Asia', volumeIds: ['frus1964-68v01'], cataloguedCount: 1 } as VolumeScope,
  ];

  it('offers the whole corpus, the subseries, each subseries’s volumes, the user’s scopes and the topics', () => {
    const groups = scopeGroups(context, scopes);
    expect(groups.map((group) => group.label)).toEqual([
      '',
      'By Subseries',
      'By Volume — 1894',
      'By Volume — 1961-63',
      'My Volume Scopes',
      'By Detected Topic — Arms Control',
    ]);
    // The user's scopes by name, one with indexed members chosen by them, one with none disabled.
    const custom = groups[4]?.options ?? [];
    expect(custom.map((option) => option.label)).toEqual(['Asia — none indexed yet', 'Berlin (1 of 2 indexed)']);
    expect(custom[0]?.disabled).toBe(true);
    expect(custom[1]?.scope).toEqual({ kind: 'volumes', volumeIds: ['frus1961-63v06'], label: 'Berlin' });
    // A topic none of whose volumes is indexed is disabled, as the app's menu disables it.
    expect(groups[5]?.options.map((option) => option.disabled ?? false)).toEqual([false, true]);
  });

  it('leaves out My Volume Scopes without scopes, and finds a scope again by its value', () => {
    expect(scopeGroups(context, undefined).some((group) => group.label === 'My Volume Scopes')).toBe(false);
    const scope = { kind: 'topic' as const, category: 'Arms Control', subcategory: 'Nuclear Testing' };
    expect(scopeGroups(context, undefined).flatMap((group) => group.options).find((option) => option.value === scopeValue(scope))?.scope).toEqual(scope);
    expect(scopeValue(undefined)).toBe('whole');
  });
});

describe('the addresses', () => {
  it('keep what fits and drop the rest', () => {
    expect(validateCorpusSearch({ term: 'cold', axis: 'byWeek', measure: 'occurrences', values: 'percent', from: '1950', to: 'x', colors: '13' }))
      .toMatchObject({ term: 'cold', axis: undefined, measure: 'occurrences', values: undefined, from: 1950, to: undefined, colors: undefined });
    expect(validateChronologySearch({ from: '1969-01-01', to: '1969-12-31', order: 'newest', chart: 'hidden', colors: '6' }))
      .toEqual({ from: '1969-01-01', to: '1969-12-31', order: 'newest', colors: 6, series: undefined, chart: 'hidden' });
    expect(validateChronologySearch({ from: '1969-01-01' })).toMatchObject({ from: undefined, to: undefined });
    // The term as the server takes it, its spaces trimmed, and none for spaces alone.
    expect(validateCorpusSearch({ term: ' cold war ' }).term).toBe('cold war');
    expect(validateCorpusSearch({ term: '   ' }).term).toBeUndefined();
  });

  it('carry a scope both ways, and as the routes read it', () => {
    const scope = { kind: 'volumes' as const, volumeIds: ['a', 'b'], label: 'Mine' };
    expect(addressScope({ ...scopeFields(scope) })).toEqual(scope);
    expect(scopeFields(undefined)).toEqual({ subseries: undefined, volume: undefined, topic: undefined, subtopic: undefined, volumes: undefined, scopeLabel: undefined });
    const params = corpusParams({ term: 'cold war', axis: 'byYear', measure: 'documents', values: 'raw', from: 1950, scope });
    expect(params.toString()).toBe('term=cold+war&axis=byYear&measure=documents&values=raw&from=1950&volumes=a&volumes=b&scopeLabel=Mine');
  });
});

describe('the charts', () => {
  it('stack By Year’s segments in the legend’s order, leave out a period with no share, and centre the fit line', () => {
    const spec = stackedPeriodSpec(answer(), { fitLine: true, dark: false }) as { layer: { data: { values: Record<string, unknown>[] } }[] };
    const bars = spec.layer[0]?.data.values ?? [];
    expect(bars).toEqual([
      expect.objectContaining({ start: 1961, end: 1962, y0: 0, y1: 2, series: 'frus1961-63v06' }),
      expect.objectContaining({ start: 1962, end: 1963, y0: 0, y1: 3, series: 'frus1961-63v06' }),
      expect.objectContaining({ start: 1962, end: 1963, y0: 3, y1: 4, series: '__other__', volume: 'Other volumes' }),
    ]);
    expect(spec.layer[1]?.data.values).toEqual([
      { x: 1961.5, y: 2 },
      { x: 1962.5, y: 4 },
    ]);
    const unfitted = stackedPeriodSpec(answer(), { fitLine: false, dark: false }) as { layer: unknown[] };
    expect(unfitted.layer).toHaveLength(1);
  });

  it('draw a decade ten years wide, and a share with a per cent sign', () => {
    const spec = corpusSpec(answer({ axis: 'byDecade', values: { chosen: 'percentOfDocuments', applies: true, enabled: true, isNormalized: true },
      segments: [{ period: 1960, seriesKey: 'frus1961-63v06', count: 3, plotted: 12.5 }] }), { fitLine: false, dark: false }) as {
      layer: { data: { values: Record<string, unknown>[] }; encoding: { y: { axis: Record<string, unknown> } } }[];
    };
    expect(spec.layer[0]?.data.values[0]).toMatchObject({ start: 1960, end: 1970, y1: 12.5 });
    expect(spec.layer[0]?.encoding.y.axis).toEqual({ labelExpr: "datum.label + '%'" });
  });

  it('draw a breakdown’s bars in the server’s order, each with its index for its drill', () => {
    const spec = breakdownSpec(answer({ axis: 'bySubseries', bars: [{ label: '1961-63', count: 4, volumeIds: ['frus1961-63v06'] }, { label: '1894', count: 1, volumeIds: [] }] }), { dark: false }) as {
      data: { values: unknown[] }; height: number;
    };
    expect(spec.data.values).toEqual([{ label: '1961-63', count: 4, index: 0 }, { label: '1894', count: 1, index: 1 }]);
    expect(spec.height).toBe(240);
  });

  it('draw Chronology’s buckets stacked by volume over the range rounded out', () => {
    const chronology = {
      granularity: 'month',
      domainFrom: '1962-01-01',
      domainTo: '1962-03-31',
      buckets: [{ key: '1962-02', label: 'February 1962', date: '1962-02-01', segments: [{ seriesKey: 'v', count: 2 }], total: 2 }],
      series: [{ key: 'v', title: 'V', total: 2, totalPhrase: '2 documents', isOther: false }],
    } as ChronologyAnswer;
    const spec = chronologySpec(chronology, { dark: false }) as { data: { values: Record<string, unknown>[] }; encoding: { x: { timeUnit: string; scale: { domain: unknown[] } } } };
    expect(spec.data.values).toEqual([{ date: '1962-02-01', bucket: '1962-02', label: 'February 1962', series: 'v', volume: 'V', count: 2, order: 0 }]);
    expect(spec.encoding.x.timeUnit).toBe('utcyearmonth');
    expect(spec.encoding.x.scale.domain).toEqual([
      { year: 1962, month: 1, date: 1, utc: true },
      { year: 1962, month: 3, date: 31, hours: 23, minutes: 59, seconds: 59, utc: true },
    ]);
  });
});

describe('the exported figure', () => {
  it('wraps a caption line at spaces', () => {
    expect(wrapped('one two three four', 9)).toEqual(['one two', 'three', 'four']);
    expect(wrapped('', 9)).toEqual(['']);
  });

  it('carries the plate’s title and facts above the chart and its other lines below', () => {
    const plate: AnalyticsPlate = {
      fileName: 'FRUS-Analytics-cold-By-Year-2026-11-14',
      lines: [
        { role: 'title', text: '"cold" — By Year' },
        { role: 'facts', text: 'Whole corpus · 1861–1992 · Raw count · FRUS Explorer Light 0.1 · Nov 14, 2026' },
        { role: 'caveat', text: 'Corpus: counts cover only the 3 volumes indexed on this device.' },
        { role: 'attribution', text: 'Public domain.' },
        { role: 'dataPointer', text: 'The underlying numbers are available as a CSV export.' },
      ],
    };
    const spec = figureSpec(corpusSpec(answer(), { fitLine: true, dark: false }), plate, [{ title: 'V', label: 'V  5 docs', color: '#007AFF' }]) as {
      title: { text: string; subtitle: string[] };
      vconcat: { data?: { values: { text?: string }[] } }[];
    };
    expect(spec.title).toMatchObject({ text: '"cold" — By Year', subtitle: [plate.lines[1]?.text] });
    expect(spec.vconcat).toHaveLength(3);
    expect(spec.vconcat[2]?.data?.values.map((row) => row.text)).toEqual([plate.lines[2]?.text, plate.lines[3]?.text, plate.lines[4]?.text]);
  });
});
