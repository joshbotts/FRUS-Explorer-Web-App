// What Archival Analytics and About the Series (PLAN's S24h) draw in the browser: the colours the app's charts take, the
// Vega-Lite specifications of their charts, the flows diagram's geometry, the network canvas's drawing rules, and the
// pages' addresses. The geometry and the colours are the app's views' (`ArchivalFlowsView`, `ArchivalNetworkView`, the
// four dashboards), mirrored and held to the app's source by `ArchivalAndSeriesMirrorParityTests`; every number they
// draw is the server's, the kit's.
import type { CollectionsAnswer, FlowEndpoint, LibraryAnswer } from '../api/archivalAnalytics';
import type { SeriesChart, SeriesDashboard } from '../api/aboutSeries';
import { type ChartSpec, config } from './analyticsRules';

// ─── The colours ────────────────────────────────────────────────────────────

/** The system colours the app's charts name, as their light appearance draws them. */
const system = {
  blue: '#007AFF',
  green: '#34C759',
  orange: '#FF9500',
  purple: '#AF52DE',
  red: '#FF3B30',
  teal: '#30B0C7',
  yellow: '#FFCC00',
  brown: '#A2845E',
  gray: '#8E8E93',
};

/** Swift Charts' own cycle, which a chart given a domain and no range colours its series by: blue, green, orange,
 *  purple, red, teal, yellow, then blue again. */
export const defaultCycle = [system.blue, system.green, system.orange, system.purple, system.red, system.teal, system.yellow];

/** The custodians' tints (`ArchivalRepositoryCategory.color`): State blue, lot files teal, libraries purple, others orange. */
export const custodianColors: Record<string, string> = {
  stateDepartment: system.blue,
  lotFile: system.teal,
  presidentialLibrary: system.purple,
  otherInstitution: system.orange,
};

/** The custodians in the app's order (`ArchivalRepositoryCategory.ordered`). */
export const custodianOrder = ['stateDepartment', 'lotFile', 'presidentialLibrary', 'otherInstitution'];

/** The provenance categories' colours (`SourceProvenanceCategory.chartColor`), in `ordered`'s order. */
export const provenanceColors: Record<string, string> = {
  centralDecimalFile: system.blue,
  subjectNumericFile: system.brown,
  centralForeignPolicyFile: system.green,
  lotFile: system.orange,
  presidentialLibrary: system.purple,
  naraCollection: system.red,
  intelligence: system.teal,
  namedFileSeries: system.yellow,
  foreignArchive: system.blue,
  previouslyPublished: system.green,
  unrecognized: system.orange,
};

export const provenanceOrder = [
  'centralDecimalFile', 'subjectNumericFile', 'centralForeignPolicyFile', 'lotFile', 'presidentialLibrary', 'naraCollection',
  'intelligence', 'namedFileSeries', 'foreignArchive', 'previouslyPublished', 'unrecognized',
];

/** The parties' colours (`PoliticalParty.color`), in `ordered`'s order: Republican, Democratic, National Union, Other. */
export const partyColors = [system.red, system.blue, system.orange, system.gray];

/** The colour of each of a chart's series, in its legend's order. */
export function seriesColors(dashboard: SeriesDashboard, chart: SeriesChart): string[] {
  if (dashboard === 'sourcing') return provenanceOrder.map((key) => provenanceColors[key] ?? system.gray);
  if (dashboard === 'administrations') return partyColors;
  return chart.series.map((_, index) => defaultCycle[index % defaultCycle.length] ?? system.blue);
}

/** A chart's own ink, the accent the app's single-series charts draw in. */
function accent(dark: boolean) {
  return dark ? '#64a8ff' : system.blue;
}

const schema = 'https://vega.github.io/schema/vega-lite/v6.json';

// ─── Archival Analytics' charts ─────────────────────────────────────────────

/** The Collections ranking (`rankingChart`): a bar a unit, coloured by its custodian, its value beside it, 26 points a row. */
export function rankingSpec(answer: CollectionsAnswer, dark: boolean, custodianNames: Record<string, string>): ChartSpec {
  const rows = answer.ranking.rows;
  const domain = custodianOrder.map((key) => custodianNames[key] ?? key);
  return {
    $schema: schema,
    width: 'container',
    height: rows.length * 26 + 60,
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(dark),
    data: { values: rows.map((row) => ({ id: row.id, label: row.label, value: row.value, custodian: row.categoryName })) },
    encoding: {
      y: { field: 'label', type: 'nominal', sort: null, title: null, axis: { labelLimit: 300 } },
      x: { field: 'value', type: 'quantitative', title: answer.ranking.axisLabel },
    },
    layer: [
      {
        mark: { type: 'bar', cursor: 'pointer' },
        encoding: {
          color: {
            field: 'custodian', type: 'nominal', title: null,
            scale: { domain, range: custodianOrder.map((key) => custodianColors[key]) },
            legend: { orient: 'bottom', direction: 'horizontal' },
          },
        },
      },
      { mark: { type: 'text', align: 'left', dx: 4, color: dark ? '#bbbbbb' : '#6e6e73' }, encoding: { text: { field: 'value', type: 'quantitative' } } },
    ],
  };
}

/** Your Library's composition (`libraryCompositionChart`): one bar of every source note, divided by kind of collection. */
export function compositionSpec(composition: LibraryAnswer['composition'], dark: boolean): ChartSpec {
  return {
    $schema: schema,
    width: 'container',
    height: 40,
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(dark),
    data: { values: composition.items.map((item, index) => ({ ...item, key: composition.legendTitle, index })) },
    mark: { type: 'bar' },
    encoding: {
      x: { field: 'documents', type: 'quantitative', stack: 'zero', title: composition.axisLabel },
      y: { field: 'key', type: 'nominal', axis: null },
      color: provenanceColor(composition.legendTitle, composition.items.map((item) => item.category), composition.items.map((item) => item.categoryName)),
      order: { field: 'index', type: 'quantitative' },
    },
  };
}

/** Your Library's eras (the bands card): each era's source notes stacked by kind of collection. */
export function bandsSpec(bands: LibraryAnswer['bands'], dark: boolean): ChartSpec {
  const order = [...new Set(bands.items.map((item) => item.band))];
  return {
    $schema: schema,
    width: 'container',
    height: 260,
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(dark),
    data: { values: bands.items },
    mark: { type: 'bar' },
    encoding: {
      x: { field: 'band', type: 'nominal', sort: order, title: bands.xLabel, axis: { labelAngle: 0 } },
      y: { field: 'documents', type: 'quantitative', stack: 'zero', title: bands.yLabel },
      color: provenanceColor(bands.legendTitle, bands.items.map((item) => item.category), bands.items.map((item) => item.categoryName)),
    },
  };
}

/** A colour encoding by provenance category, its names in the categories' order with their colours. */
function provenanceColor(title: string, keys: string[], names: string[]) {
  const named = new Map(keys.map((key, index) => [key, names[index] ?? key]));
  const shown = provenanceOrder.filter((key) => named.has(key));
  return {
    field: 'categoryName', type: 'nominal', title,
    scale: { domain: shown.map((key) => named.get(key)), range: shown.map((key) => provenanceColors[key]) },
    legend: { orient: 'bottom', direction: 'horizontal', columns: 3 },
  };
}

// ─── About the Series' charts ───────────────────────────────────────────────

/** A year axis with no grouping, as `SeriesChartKind.yearAxisFormat` writes it. */
const yearAxis = (title: string) => ({ title, format: 'd', labelOverlap: true });

/** A chart of a dashboard, as its card draws it, from the server's marks. */
export function seriesSpec(dashboard: SeriesDashboard, chart: SeriesChart, dark: boolean): ChartSpec {
  const colors = seriesColors(dashboard, chart);
  const color = (legend: boolean) => ({
    field: 'series', type: 'nominal', title: chart.legendTitle ?? null,
    scale: { domain: chart.series, range: colors.slice(0, chart.series.length) },
    legend: legend ? { orient: 'bottom', direction: 'horizontal', columns: 3 } : null,
  });
  const numeric = chart.marks.map((mark, index) => ({ ...mark, year: Number(mark.x), index }));
  const domain = chart.domain && chart.domain.length === 2 ? chart.domain : undefined;
  const base = { $schema: schema, width: 'container', autosize: { type: 'fit-x', contains: 'padding' }, config: config(dark) };
  const key = `${dashboard}.${chart.id}`;
  switch (key) {
    case 'production.lag':
      // `PointMark`s coloured by coverage era, and the target's dashed step line, stepping at each change.
      return {
        ...base,
        height: 260,
        layer: [
          {
            data: { values: numeric },
            mark: { type: 'point', filled: true, size: 20 },
            encoding: {
              x: { field: 'year', type: 'quantitative', scale: { domain, zero: false }, axis: yearAxis(chart.xLabel) },
              y: { field: 'y', type: 'quantitative', title: chart.yLabel },
              color: color(true),
            },
          },
          {
            data: { values: (chart.steps ?? []).map((step) => ({ year: Number(step.x), y: step.y })) },
            mark: { type: 'line', interpolate: 'step-after', strokeDash: [4, 4], strokeWidth: 1.5, color: dark ? '#bbbbbb' : '#6e6e73' },
            encoding: { x: { field: 'year', type: 'quantitative' }, y: { field: 'y', type: 'quantitative' } },
          },
        ],
      };
    case 'production.perYear':
    case 'sourcing.density':
      // Bars a year wide, stacked by era (`BarMark` over a fixed domain), or a decade's notes.
      return {
        ...base,
        height: 240,
        data: { values: numeric.map((mark) => ({ ...mark, end: mark.year + (key === 'sourcing.density' ? 10 : 1) })) },
        mark: { type: 'bar', ...(key === 'sourcing.density' ? { color: accent(dark) } : {}) },
        encoding: {
          x: { field: 'year', type: 'quantitative', scale: { domain, zero: false }, axis: yearAxis(chart.xLabel) },
          x2: { field: 'end' },
          y: { field: 'y', type: 'quantitative', stack: 'zero', title: chart.yLabel },
          ...(key === 'production.perYear' ? { color: color(true) } : {}),
        },
      };
    case 'production.cumulative':
      return {
        ...base,
        height: 240,
        data: { values: numeric },
        encoding: {
          x: { field: 'year', type: 'quantitative', scale: { domain, zero: false }, axis: yearAxis(chart.xLabel) },
          y: { field: 'y', type: 'quantitative', title: chart.yLabel },
        },
        layer: [
          { mark: { type: 'area', color: accent(dark), opacity: 0.25 } },
          { mark: { type: 'line', color: accent(dark) } },
        ],
      };
    case 'geography.trend':
    case 'sourcing.mix':
      // Each decade's shares stacked to 100%, by region or by provenance (`AreaMark`).
      return {
        ...base,
        height: key === 'sourcing.mix' ? 300 : 280,
        data: { values: numeric.map((mark) => ({ ...mark, order: chart.series.indexOf(mark.series ?? '') })) },
        mark: { type: 'area' },
        encoding: {
          x: { field: 'year', type: 'quantitative', scale: { domain, zero: false }, axis: yearAxis(chart.xLabel) },
          y: { field: 'y', type: 'quantitative', stack: 'zero', scale: { domain: [0, 1] }, axis: { format: '.0%', title: chart.yLabel } },
          color: color(true),
          order: { field: 'order', type: 'quantitative' },
        },
      };
    case 'geography.totals':
    case 'sourcing.composition':
    case 'administrations.documents':
    case 'administrations.perYear':
      // A bar a region, a kind of collection or an administration, in the server's order, its label turned upright.
      return {
        ...base,
        height: key.startsWith('administrations') ? 320 : key === 'sourcing.composition' ? 300 : 260,
        data: { values: chart.marks },
        mark: { type: 'bar' },
        encoding: {
          x: { field: 'x', type: 'nominal', sort: null, title: chart.xLabel, axis: { labelAngle: -90, labelLimit: 160 } },
          y: { field: 'y', type: 'quantitative', title: chart.yLabel },
          color: color(key !== 'sourcing.composition'),
        },
      };
    default:
      // The most-covered countries: horizontal bars in the accent, 24 points a row.
      return {
        ...base,
        height: Math.max(chart.marks.length, 1) * 24 + 40,
        data: { values: chart.marks },
        mark: { type: 'bar', color: accent(dark) },
        encoding: {
          y: { field: 'x', type: 'nominal', sort: null, title: null, axis: { labelLimit: 220 } },
          x: { field: 'y', type: 'quantitative', title: chart.xLabel },
        },
      };
  }
}

/** A figure's legend: the series a chart colours, each with its colour, as the plate's key draws it. */
export function seriesLegend(dashboard: SeriesDashboard, chart: SeriesChart): { title: string; label: string; color: string }[] {
  if (!chart.legendTitle || chart.series.length === 0) return [];
  const colors = seriesColors(dashboard, chart);
  const shown = new Set(chart.marks.map((mark) => mark.series));
  return chart.series
    .map((name, index) => ({ title: chart.legendTitle ?? '', label: name, color: colors[index] ?? system.gray }))
    .filter((entry) => shown.has(entry.label));
}

// ─── The flows diagram (`ArchivalFlowsView`) ─────────────────────────────────

export interface Frame {
  x: number;
  y: number;
  width: number;
  height: number;
}

/** The destinations' column: between a third and 42% of the width, at most 260 points (`destinationWidth(for:)`). */
export function destinationWidth(width: number): number {
  return Math.max(Math.min(width * 0.42, 260), width * 0.34);
}

/** The diagram's height: a row of 44 points an endpoint, and 24 more (`diagramHeight`). */
export function diagramHeight(endpoints: number): number {
  return Math.max(endpoints, 1) * 44 + 24;
}

/** Each endpoint's block, a row of 44 points down the right-hand column (`blockFrames`). */
export function blockFrames(endpoints: FlowEndpoint[], width: number): Map<string, Frame> {
  const column = destinationWidth(width);
  const rowHeight = 44;
  const frames = new Map<string, Frame>();
  endpoints.forEach((endpoint, index) => {
    frames.set(endpoint.id, { x: width - column, y: index * rowHeight + 12, width: column, height: rowHeight - 8 });
  });
  return frames;
}

/** The focus's block, down the left-hand side (`focusFrame`). */
export function focusFrame(endpoints: number, width: number, height: number): Frame {
  const blockWidth = Math.max(width - destinationWidth(width) - 48, 60);
  const blockHeight = Math.min(endpoints * 44, height - 24);
  return { x: 0, y: 12, width: blockWidth, height: Math.max(blockHeight - 8, 44) };
}

/** A ribbon from the focus to an endpoint, as thick as its share of the largest (`ribbonCanvas`). */
export function ribbonPath(origin: Frame, frame: Frame, count: number, maxCount: number): string {
  const thickness = Math.max(2, (count / maxCount) * 22);
  const startY = origin.y + origin.height / 2;
  const endY = frame.y + frame.height / 2;
  const fromX = origin.x + origin.width;
  const toX = frame.x;
  return [
    `M ${fromX} ${startY - thickness / 2}`,
    `C ${fromX + 60} ${startY - thickness / 2} ${toX - 60} ${endY - thickness / 2} ${toX} ${endY - thickness / 2}`,
    `L ${toX} ${endY + thickness / 2}`,
    `C ${toX - 60} ${endY + thickness / 2} ${fromX + 60} ${startY + thickness / 2} ${fromX} ${startY + thickness / 2}`,
    'Z',
  ].join(' ');
}

/** A ribbon's opacity: deeper for the hand-off selected. */
export function ribbonOpacity(isSelected: boolean): number {
  return isSelected ? 0.55 : 0.28;
}

// ─── The network canvas (`ArchivalNetworkView`) ─────────────────────────────

/** A wedge of the canvas, a quarter turn from `start` degrees clockwise from east, as an SVG path. */
export function sectorPath(center: { x: number; y: number }, radius: number, start: number): string {
  const point = (degrees: number) => {
    const radians = (degrees * Math.PI) / 180;
    return `${center.x + Math.cos(radians) * radius} ${center.y + Math.sin(radians) * radius}`;
  };
  return `M ${center.x} ${center.y} L ${point(start)} A ${radius} ${radius} 0 0 1 ${point(start + 90)} Z`;
}

/** A wedge's fill opacity: deeper for the group selected, fainter for the others while one is, 7% with none. */
export function sectorOpacity(selected: string | undefined, category: string): number {
  if (selected === undefined) return 0.07;
  return selected === category ? 0.17 : 0.04;
}

/** A spoke from the focus to a partner: stronger links darker and thicker (`drawSpokes`). */
export function spokeStyle(relativeStrength: number): { opacity: number; width: number } {
  return { opacity: 0.2 + relativeStrength * 0.45, width: 0.5 + relativeStrength * 3 };
}

/** A partner's disc: its custodian's colour at 62%, full when shown (`drawNodes`). */
export function nodeOpacity(isSelected: boolean): number {
  return isSelected ? 1 : 0.62;
}

// ─── The addresses ──────────────────────────────────────────────────────────

export interface ArchivalSearch {
  mode?: string;
  band?: string;
  lens?: string;
  weight?: string;
  umbrella?: 'shown';
  subseries?: string;
  volume?: string;
  topic?: string;
  subtopic?: string;
  volumes?: string[];
  scopeLabel?: string;
  administration?: string;
  focus?: string;
  trail?: string;
  measure?: string;
  expansion?: string;
  threshold?: string;
  group?: string;
  only?: 'on';
  layer?: string;
  flowFocus?: string;
  direction?: string;
}

const text = (value: unknown) => (typeof value === 'string' && value !== '' ? value : undefined);

export function validateArchivalSearch(raw: Record<string, unknown>): ArchivalSearch {
  const search: ArchivalSearch = {};
  for (const key of ['mode', 'band', 'lens', 'weight', 'subseries', 'volume', 'topic', 'subtopic', 'scopeLabel', 'administration',
    'focus', 'trail', 'measure', 'expansion', 'threshold', 'group', 'layer', 'flowFocus', 'direction'] as const) {
    const value = text(raw[key]);
    if (value !== undefined) search[key] = value;
  }
  // A scope of volumes, each named in the address, as Corpus Analytics' is.
  const volumes = (Array.isArray(raw.volumes) ? raw.volumes : raw.volumes === undefined ? [] : [raw.volumes])
    .filter((value): value is string => typeof value === 'string' && value !== '');
  if (volumes.length > 0) search.volumes = volumes;
  if (raw.umbrella === 'shown') search.umbrella = 'shown';
  if (raw.only === 'on') search.only = 'on';
  return search;
}

export interface SeriesSearch {
  page?: string;
  from?: number;
  to?: number;
  subseries?: string;
  topic?: string;
  subtopic?: string;
  volumes?: string;
  scopeLabel?: string;
  hidden?: string;
  notes?: 'on';
  administration?: string;
}

const year = (value: unknown) => {
  const number = typeof value === 'number' ? value : typeof value === 'string' && /^\d{4}$/.test(value) ? Number(value) : NaN;
  return Number.isInteger(number) && number >= 1776 && number <= 2100 ? number : undefined;
};

export function validateSeriesSearch(raw: Record<string, unknown>): SeriesSearch {
  const search: SeriesSearch = {};
  for (const key of ['page', 'subseries', 'topic', 'subtopic', 'volumes', 'scopeLabel', 'hidden', 'administration'] as const) {
    const value = text(raw[key]);
    if (value !== undefined) search[key] = value;
  }
  const from = year(raw.from);
  const to = year(raw.to);
  if (from !== undefined) search.from = from;
  if (to !== undefined) search.to = to;
  if (raw.notes === 'on') search.notes = 'on';
  return search;
}

// ─── Markdown bodies ────────────────────────────────────────────────────────

/** A Markdown body's runs, as the app's `AttributedString(markdownBody:)` sets them: `**strong**` and `*emphasis*`. */
export function markdownRuns(body: string): { text: string; strong?: boolean; emphasis?: boolean }[] {
  const runs: { text: string; strong?: boolean; emphasis?: boolean }[] = [];
  const pattern = /\*\*([^*]+)\*\*|\*([^*]+)\*/g;
  let last = 0;
  for (const match of body.matchAll(pattern)) {
    if (match.index > last) runs.push({ text: body.slice(last, match.index) });
    if (match[1] !== undefined) runs.push({ text: match[1], strong: true });
    else if (match[2] !== undefined) runs.push({ text: match[2], emphasis: true });
    last = match.index + match[0].length;
  }
  if (last < body.length) runs.push({ text: body.slice(last) });
  return runs;
}
