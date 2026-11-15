// Person and Cross-Reference Analytics' rules in the browser (PLAN's S24g): the two pages' addresses, the charts drawn by
// Vega-Lite from the server's series as the app's Swift Charts draw them, and what the app's canvases decide that the
// server's answer leaves to the page, each mirrored from the app's source and held to it by the mirror test: the
// co-mention network's layout (`PersonCoMentionGraphViewModel.runPhysics` and `rerunLayout`), its discs and edges, the
// comparison's colours in the order its people were added (`color(forRollupId:)`), and the heat matrix's shading
// (`heatColor(for:)`). The series, their words and tables are the kit's, computed on the server.
import type { CrossReferenceAnswer } from '../api/crossReferenceAnalytics';
import type { NetworkAnswer, PersonAnswer } from '../api/personAnalytics';
import { type ChartSpec, chartPalette, config } from './analyticsRules';

// ─── The addresses ──────────────────────────────────────────────────────────

/** The scope's fields, as Corpus Analytics' address names them. */
export interface ScopeSearch {
  subseries?: string;
  volume?: string;
  topic?: string;
  subtopic?: string;
  volumes?: string[];
  scopeLabel?: string;
}

/** Person Analytics' address: the mode, the years, the scope, the people compared, the decade switch, the values and the
 *  network's focus. */
export interface PeopleSearch extends ScopeSearch {
  mode?: 'network';
  from?: number;
  to?: number;
  people?: number[];
  decade?: 'on';
  values?: 'percentOfDocuments';
  focus?: number;
}

/** Cross-Reference Analytics' address: the years, the scope and the out-degree overlay. */
export interface CrossReferenceSearch extends ScopeSearch {
  from?: number;
  to?: number;
  outDegree?: 'on';
}

function text(value: unknown): string | undefined {
  const single = Array.isArray(value) ? value[0] : value;
  return typeof single === 'string' && single !== '' ? single : typeof single === 'number' ? String(single) : undefined;
}

function year(value: unknown): number | undefined {
  const raw = text(value);
  return raw !== undefined && /^\d{4}$/.test(raw) ? Number(raw) : undefined;
}

function list(value: unknown): string[] {
  return (Array.isArray(value) ? value : value === undefined ? [] : [value])
    .map((each) => (typeof each === 'number' ? String(each) : each))
    .filter((each): each is string => typeof each === 'string' && each !== '');
}

function rollupId(value: unknown): number | undefined {
  const raw = text(value);
  return raw !== undefined && /^\d{1,15}$/.test(raw) ? Number(raw) : undefined;
}

function scopeSearch(raw: Record<string, unknown>): ScopeSearch {
  const volumes = list(raw.volumes);
  return {
    subseries: text(raw.subseries),
    volume: text(raw.volume),
    topic: text(raw.topic),
    subtopic: text(raw.subtopic),
    volumes: volumes.length > 0 ? volumes : undefined,
    scopeLabel: text(raw.scopeLabel),
  };
}

/** The address's fields, each checked; what does not fit is dropped, and the comparison keeps its first five, once each. */
export function validatePeopleSearch(raw: Record<string, unknown>): PeopleSearch {
  const people = [...new Set(list(raw.people).map(rollupId).filter((id): id is number => id !== undefined))].slice(0, maxComparisonPeople);
  return {
    ...scopeSearch(raw),
    mode: text(raw.mode) === 'network' ? 'network' : undefined,
    from: year(raw.from),
    to: year(raw.to),
    people: people.length > 0 ? people : undefined,
    decade: text(raw.decade) === 'on' ? 'on' : undefined,
    values: text(raw.values) === 'percentOfDocuments' ? 'percentOfDocuments' : undefined,
    focus: rollupId(raw.focus),
  };
}

export function validateCrossReferenceSearch(raw: Record<string, unknown>): CrossReferenceSearch {
  return {
    ...scopeSearch(raw),
    from: year(raw.from),
    to: year(raw.to),
    outDegree: text(raw.outDegree) === 'on' ? 'on' : undefined,
  };
}

/** The comparison's cap, the app's `maxComparisonPeople`. */
export const maxComparisonPeople = 5;
/** The search results the add field and the focus search show (`searchResults.prefix(6)`). */
export const shownMatches = 6;

/** A person's colour, by their place in the comparison (`color(forRollupId:)`, `ChartSeriesPalette.color(at:)`). */
export function personColor(people: { rollupId: number }[], rollupId: number): string {
  const index = Math.max(0, people.findIndex((person) => person.rollupId === rollupId));
  return chartPalette[index % chartPalette.length] ?? '#007AFF';
}

// ─── The charts ─────────────────────────────────────────────────────────────

const schema = 'https://vega.github.io/schema/vega-lite/v6.json';

function ink(dark: boolean) {
  return dark ? '#64a8ff' : '#007AFF';
}

function faint(dark: boolean) {
  return dark ? '#bbbbbb' : '#6e6e73';
}

/** A ranking as horizontal bars, the first at the top, each labelled with its count (`rankingChartBody`, `CrossReferenceRankingChart`). */
function rankingBars(
  rows: { key: string; label: string; count: number; index: number }[],
  titles: { y: string; x: string },
  description: string,
  dark: boolean,
  clickable: boolean,
): ChartSpec {
  return {
    $schema: schema,
    description,
    width: 'container',
    height: Math.max(240, rows.length * 30 + 40),
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(dark),
    data: { values: rows },
    encoding: {
      y: { field: 'label', type: 'nominal', sort: null, title: titles.y, axis: { labelLimit: 260 } },
      x: { field: 'count', type: 'quantitative', title: titles.x },
    },
    layer: [
      { mark: { type: 'bar', color: ink(dark), cursor: clickable ? 'pointer' : 'default', tooltip: true } },
      { mark: { type: 'text', align: 'left', dx: 4, color: faint(dark) }, encoding: { text: { field: 'count', type: 'quantitative', format: ',d' } } },
    ],
  };
}

/** Most-Mentioned People: each person's mentions in dated documents, keyed by the chart's own label for them. */
export function personRankingSpec(answer: PersonAnswer, labels: { person: string; mentions: string; description: string }, dark: boolean): ChartSpec {
  return rankingBars(
    answer.ranking.rows.map((row, index) => ({ key: String(row.rollupId), label: row.axisLabel, count: row.mentions, index })),
    { y: labels.person, x: labels.mentions },
    labels.description,
    dark,
    true,
  );
}

/** Mention Trajectories: a line and its points for each person compared, coloured in the order they were added, over the
 *  years asked (`trajectoryChart`). */
export function trajectorySpec(answer: PersonAnswer, labels: { person: string; description: string }, dark: boolean): ChartSpec {
  const comparison = answer.comparison;
  const percent = comparison.isNormalized;
  const values = comparison.points.map((point) => ({ ...point, plotted: percent ? point.value * 100 : point.value }));
  return {
    $schema: schema,
    description: labels.description,
    width: 'container',
    height: 300,
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(dark),
    data: { values },
    mark: { type: 'line', point: true, tooltip: true },
    encoding: {
      x: {
        field: 'period',
        type: 'quantitative',
        title: comparison.xAxisLabel,
        scale: { domain: [answer.years.start, answer.years.end], nice: false },
        axis: { format: 'd' },
      },
      y: {
        field: 'plotted',
        type: 'quantitative',
        title: comparison.valueAxisLabel,
        axis: percent ? { labelExpr: "format(datum.value, '.3~') + '%'" } : { format: ',d' },
      },
      color: {
        field: 'name',
        type: 'nominal',
        title: labels.person,
        scale: {
          domain: comparison.people.map((person) => person.name),
          range: comparison.people.map((person) => personColor(comparison.people, person.rollupId)),
        },
      },
      shape: { field: 'name', type: 'nominal', title: labels.person, scale: { domain: comparison.people.map((person) => person.name) } },
      detail: { field: 'rollupId', type: 'nominal' },
    },
  };
}

/** Relationship Dynamics: the dated documents tagging both people, a bar a year or a decade (`relationshipChart`). */
export function relationshipSpec(answer: PersonAnswer, description: string, dark: boolean): ChartSpec {
  const relationship = answer.relationship;
  const decade = answer.comparison.byDecade;
  const width = decade ? 10 : 1;
  return {
    $schema: schema,
    description,
    width: 'container',
    height: 220,
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(dark),
    data: { values: (relationship?.points ?? []).map((point) => ({ ...point, end: point.period + width })) },
    mark: { type: 'bar', color: ink(dark), tooltip: true },
    encoding: {
      x: {
        field: 'period',
        type: 'quantitative',
        title: relationship?.xAxisLabel,
        scale: { domain: [answer.years.start, answer.years.end + 1], nice: false },
        axis: { format: 'd' },
      },
      x2: { field: 'end' },
      y: { field: 'coMentions', type: 'quantitative', title: relationship?.valueAxisLabel, axis: { format: ',d', tickMinStep: 1 } },
    },
  };
}

/** Most-Referenced Documents: each document's inbound citations, labelled as its row is, told apart where two read alike. */
export function referenceRankingSpec(answer: CrossReferenceAnswer, labels: { document: string; inDegree: string; description: string }, dark: boolean): ChartSpec {
  return rankingBars(
    answer.ranking.rows.map((row, index) => ({
      key: `${row.document.volumeId}/${row.document.documentId}`,
      label: row.axisLabel,
      count: row.inDegree,
      index,
    })),
    { y: labels.document, x: labels.inDegree },
    labels.description,
    dark,
    true,
  );
}

/** Citation Degree Distribution: how many documents have each inbound count, beside each outbound count while the overlay
 *  is shown, in the buckets' order (`distributionChart`). */
export function distributionSpec(
  answer: CrossReferenceAnswer,
  labels: { degree: string; documents: string; direction: string; inDegree: string; outDegree: string; description: string },
  dark: boolean,
): ChartSpec {
  const distribution = answer.distribution;
  const order = distribution.inDegree.map((bucket) => bucket.label);
  for (const bucket of distribution.outDegree) if (!order.includes(bucket.label)) order.push(bucket.label);
  const values = [
    ...distribution.inDegree.map((bucket) => ({ ...bucket, direction: labels.inDegree })),
    ...(distribution.showsOutDegree ? distribution.outDegree.map((bucket) => ({ ...bucket, direction: labels.outDegree })) : []),
  ];
  return {
    $schema: schema,
    description: labels.description,
    width: 'container',
    height: 260,
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(dark),
    data: { values },
    mark: { type: 'bar', tooltip: true },
    encoding: {
      x: { field: 'label', type: 'ordinal', sort: order, title: labels.degree, axis: { labelAngle: 0 } },
      xOffset: { field: 'direction', type: 'nominal', sort: [labels.inDegree, labels.outDegree] },
      y: { field: 'documentCount', type: 'quantitative', title: labels.documents, axis: { format: ',d' } },
      color: {
        field: 'direction',
        type: 'nominal',
        title: labels.direction,
        scale: { domain: [labels.inDegree, labels.outDegree], range: [ink(dark), dark ? '#ffb340' : '#FF9500'] },
        legend: distribution.showsOutDegree ? { orient: 'top' } : null,
      },
    },
  };
}

/**
 * A heat cell's shade (`heatColor(for:)`): none for no references, else the accent at 15% to 95% of its strength by its
 * share of the matrix's largest count.
 */
export function heatOpacity(count: number, maxCount: number): number {
  if (count <= 0 || maxCount <= 0) return 0;
  return 0.15 + 0.8 * (count / maxCount);
}

/** The legend's five swatches (`matrixLegend`). */
export const heatLegendSteps = [0.15, 0.35, 0.55, 0.75, 0.95];

/** Volume Citation Heat Matrix: a cell for each pair, rows citing columns, shaded by count, a diagonal cell greyed. */
export function matrixSpec(answer: CrossReferenceAnswer, labels: { citing: string; cited: string; references: string; description: string }, dark: boolean, counts = false): ChartSpec {
  const matrix = answer.matrix;
  const rowLabel = (volume: (typeof matrix.volumes)[number]) => (volume.topic ? `${volume.topic} · ${volume.tag}` : volume.tag);
  const values = matrix.volumes.flatMap((source, row) =>
    matrix.volumes.map((target, column) => {
      const cell = matrix.rows[row]?.[column];
      const count = cell?.count ?? 0;
      return {
        source: rowLabel(source),
        target: target.code,
        count,
        shade: source.id === target.id ? 0 : heatOpacity(count, matrix.maxCount),
        diagonal: source.id === target.id,
        help: cell?.help ?? '',
      };
    }),
  );
  const size = 34;
  return {
    $schema: schema,
    description: labels.description,
    width: matrix.volumes.length * (size + 1),
    height: matrix.volumes.length * (size + 1),
    config: config(dark),
    data: { values },
    encoding: {
      x: { field: 'target', type: 'ordinal', sort: matrix.volumes.map((v) => v.code), title: labels.cited, axis: { orient: 'top', labelAngle: -45, labelLimit: 120 } },
      y: { field: 'source', type: 'ordinal', sort: matrix.volumes.map(rowLabel), title: labels.citing, axis: { labelLimit: 260 } },
    },
    layer: [
      {
        mark: { type: 'rect', cornerRadius: 2, tooltip: { content: 'data' }, stroke: dark ? '#1c1c1e' : '#ffffff', strokeWidth: 1 },
        encoding: {
          color: { condition: { test: 'datum.diagonal', value: dark ? '#3a3a3c' : '#e5e5ea' }, value: ink(dark) },
          opacity: { condition: { test: 'datum.diagonal || datum.count > 0', field: 'shade', type: 'quantitative', scale: null }, value: 0.06 },
          tooltip: [{ field: 'help', type: 'nominal', title: labels.references }],
        },
      },
      ...(counts
        ? [{
            transform: [{ filter: 'datum.count > 0 && !datum.diagonal' }],
            mark: { type: 'text', fontSize: 11, color: '#000000', opacity: 0.85 },
            encoding: { text: { field: 'count', type: 'quantitative', format: ',d' } },
          }]
        : []),
    ],
  };
}

// ─── The co-mention network ─────────────────────────────────────────────────

export interface NetworkPoint {
  x: number;
  y: number;
}

/** How many passes the app's animated layout publishes before it rests, each of twenty iterations (`layoutSteps`). */
export const layoutSteps = 15;

/**
 * The app's spring-repulsion layout with the focus pinned at the canvas's centre (`runPhysics`): a spring along every
 * edge, a repulsion between every pair, damped, each partner kept 48 points inside the canvas.
 */
export function runPhysics(
  ids: number[],
  centralId: number,
  edges: { a: number; b: number }[],
  positions: Map<number, NetworkPoint>,
  size: { width: number; height: number },
  iterations: number,
): Map<number, NetworkPoint> {
  const kS = 0.008;
  const restLength = 150;
  const kR = 6_000;
  const damping = 0.82;
  const pad = 48;
  const center = { x: size.width / 2, y: size.height / 2 };
  const pos = new Map([...positions].map(([id, point]) => [id, { ...point }]));
  const vel = new Map(ids.map((id) => [id, { dx: 0, dy: 0 }]));
  for (let step = 0; step < iterations; step += 1) {
    const forces = new Map(ids.map((id) => [id, { dx: 0, dy: 0 }]));
    // Attractive spring along every edge.
    for (const edge of edges) {
      const ps = pos.get(edge.a);
      const pt = pos.get(edge.b);
      if (!ps || !pt) continue;
      const dx = pt.x - ps.x;
      const dy = pt.y - ps.y;
      const d = Math.max(Math.hypot(dx, dy), 1);
      const f = kS * (d - restLength);
      const ux = dx / d;
      const uy = dy / d;
      const fa = forces.get(edge.a);
      const fb = forces.get(edge.b);
      if (fa) {
        fa.dx += ux * f;
        fa.dy += uy * f;
      }
      if (fb) {
        fb.dx -= ux * f;
        fb.dy -= uy * f;
      }
    }
    // Repulsion between every node pair.
    for (let i = 0; i < ids.length; i += 1) {
      for (let j = i + 1; j < ids.length; j += 1) {
        const idI = ids[i];
        const idJ = ids[j];
        if (idI === undefined || idJ === undefined) continue;
        const pa = pos.get(idI);
        const pb = pos.get(idJ);
        if (!pa || !pb) continue;
        const dx = pa.x - pb.x;
        const dy = pa.y - pb.y;
        const d = Math.max(Math.hypot(dx, dy), 1);
        const f = kR / (d * d);
        const ux = dx / d;
        const uy = dy / d;
        const fi = forces.get(idI);
        const fj = forces.get(idJ);
        if (fi) {
          fi.dx += ux * f;
          fi.dy += uy * f;
        }
        if (fj) {
          fj.dx -= ux * f;
          fj.dy -= uy * f;
        }
      }
    }
    for (const id of ids) {
      if (id === centralId) {
        pos.set(id, { ...center });
        vel.set(id, { dx: 0, dy: 0 });
        continue;
      }
      const v = vel.get(id);
      const p = pos.get(id);
      const f = forces.get(id);
      if (!v || !p || !f) continue;
      v.dx = (v.dx + f.dx) * damping;
      v.dy = (v.dy + f.dy) * damping;
      p.x = Math.max(pad, Math.min(size.width - pad, p.x + v.dx));
      p.y = Math.max(pad, Math.min(size.height - pad, p.y + v.dy));
    }
  }
  return pos;
}

/**
 * The network's settled places (`rerunLayout`): the focus at the centre and its partners on a circle of 35% of the
 * canvas's shorter side, then the physics: three hundred iterations at once under Reduce Motion or for three nodes or
 * fewer, else the animated layout's fifteen passes of twenty, each starting at rest, whose last pass is where it settles.
 */
export function networkLayout(
  answer: NetworkAnswer,
  size: { width: number; height: number },
  reducedMotion: boolean,
): Map<number, NetworkPoint> {
  const focus = answer.focus.rollupId;
  const ids = [focus, ...answer.nodes.filter((node) => !node.isFocus).map((node) => node.rollupId)];
  const cx = size.width / 2;
  const cy = size.height / 2;
  if (ids.length <= 1) return new Map([[focus, { x: cx, y: cy }]]);
  const r = Math.min(size.width, size.height) * 0.35;
  let current = new Map<number, NetworkPoint>([[focus, { x: cx, y: cy }]]);
  const partners = ids.filter((id) => id !== focus);
  partners.forEach((id, i) => {
    const angle = (2 * Math.PI * i) / partners.length;
    current.set(id, { x: cx + r * Math.cos(angle), y: cy + r * Math.sin(angle) });
  });
  if (reducedMotion || ids.length <= 3) return runPhysics(ids, focus, answer.edges, current, size, 300);
  for (let step = 0; step < layoutSteps; step += 1) current = runPhysics(ids, focus, answer.edges, current, size, 20);
  return current;
}

/** The focus's disc radius (`focusRadius`). */
export const focusRadius = 26;

/** A node's disc radius (`nodeRadius(for:)`): the focus's 26, a partner's 12 to 22 by its shared documents with the focus,
 *  3 more while it is the one shown. */
export function nodeRadius(answer: NetworkAnswer, rollupId: number, displayed?: number): number {
  if (rollupId === answer.focus.rollupId) return focusRadius;
  const partners = answer.nodes.filter((node) => !node.isFocus);
  const maxShared = Math.max(1, ...partners.map((node) => node.sharedWithFocus));
  const shared = partners.find((node) => node.rollupId === rollupId)?.sharedWithFocus ?? 0;
  const base = 12 + 10 * (shared / maxShared);
  return displayed === rollupId ? base + 3 : base;
}

/** An edge's weight, its shared documents over the network's largest (`maxEdgeWeight`), and its line's width and opacity
 *  (`drawEdge`). */
export function edgeStyle(answer: NetworkAnswer, sharedDocuments: number): { width: number; opacity: number } {
  const maxWeight = Math.max(1, ...answer.edges.map((edge) => edge.sharedDocuments));
  const weight = sharedDocuments / maxWeight;
  return { width: 0.5 + weight * 3.5, opacity: 0.2 + weight * 0.5 };
}
