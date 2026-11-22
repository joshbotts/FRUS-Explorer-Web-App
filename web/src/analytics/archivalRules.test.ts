import { describe, expect, it } from 'vitest';
import type { FlowEndpoint } from '../api/archivalAnalytics';
import type { SeriesChart } from '../api/aboutSeries';
import {
  blockFrames,
  custodianColors,
  defaultCycle,
  destinationWidth,
  diagramHeight,
  focusFrame,
  markdownRuns,
  nodeOpacity,
  partyColors,
  provenanceColors,
  provenanceOrder,
  ribbonOpacity,
  ribbonPath,
  sectorOpacity,
  sectorPath,
  seriesColors,
  seriesLegend,
  seriesSpec,
  spokeStyle,
  validateArchivalSearch,
  validateSeriesSearch,
} from './archivalRules';

function endpoint(id: string, count: number, isRemainder = false): FlowEndpoint {
  return { id, label: id, category: 'lotFile', categoryName: 'State lot files', count, isRemainder, accessibilityValue: `${count} references`, hint: '' };
}

function chart(id: string, marks: SeriesChart['marks'], series: string[] = []): SeriesChart {
  return { id, title: id, caption: '', xLabel: 'x', yLabel: 'y', legendTitle: series.length > 0 ? 'Legend' : undefined, marks, series, domain: [1861, 2026] };
}

describe('the flows diagram', () => {
  it('lays the destinations down the right-hand column, 44 points a row, as the app does', () => {
    expect(destinationWidth(1000)).toBe(340);
    expect(destinationWidth(500)).toBe(210);
    expect(destinationWidth(400)).toBeCloseTo(168);
    const frames = blockFrames([endpoint('a', 10), endpoint('b', 5)], 1000);
    expect(frames.get('a')).toEqual({ x: 660, y: 12, width: 340, height: 36 });
    expect(frames.get('b')).toEqual({ x: 660, y: 56, width: 340, height: 36 });
    expect(diagramHeight(2)).toBe(112);
    expect(diagramHeight(0)).toBe(68);
  });

  it('draws the focus block beside them, and each ribbon as thick as its share of the largest', () => {
    expect(focusFrame(2, 1000, 112)).toEqual({ x: 0, y: 12, width: 612, height: 80 });
    // Never shorter than 44 points, never narrower than 60.
    expect(focusFrame(0, 100, 68)).toEqual({ x: 0, y: 12, width: 60, height: 44 });
    const origin = { x: 0, y: 12, width: 100, height: 80 };
    const block = { x: 300, y: 12, width: 100, height: 36 };
    expect(ribbonPath(origin, block, 10, 10)).toBe('M 100 41 C 160 41 240 19 300 19 L 300 41 C 240 41 160 63 100 63 Z');
    // At least two points thick, however small its share.
    expect(ribbonPath(origin, block, 1, 1000)).toContain('M 100 51');
    expect([ribbonOpacity(true), ribbonOpacity(false)]).toEqual([0.55, 0.28]);
  });
});

describe('the network canvas', () => {
  it('draws each wedge a quarter turn from its start, deeper for the group selected', () => {
    expect(sectorPath({ x: 100, y: 100 }, 50, 0)).toBe('M 100 100 L 150 100 A 50 50 0 0 1 100 150 Z');
    expect(sectorOpacity(undefined, 'lotFile')).toBe(0.07);
    expect(sectorOpacity('lotFile', 'lotFile')).toBe(0.17);
    expect(sectorOpacity('lotFile', 'stateDepartment')).toBe(0.04);
  });

  it('draws stronger links darker and thicker, and a shown partner full', () => {
    expect(spokeStyle(1)).toEqual({ opacity: 0.65, width: 3.5 });
    expect(spokeStyle(0)).toEqual({ opacity: 0.2, width: 0.5 });
    expect([nodeOpacity(true), nodeOpacity(false)]).toEqual([1, 0.62]);
  });
});

describe('the colours', () => {
  it('are the app’s: the custodians’ tints, the provenance categories’, the parties’ and Swift Charts’ cycle', () => {
    expect(custodianColors).toEqual({ stateDepartment: '#007AFF', lotFile: '#30B0C7', presidentialLibrary: '#AF52DE', otherInstitution: '#FF9500' });
    expect(provenanceOrder).toHaveLength(11);
    expect(provenanceColors.foreignArchive).toBe(provenanceColors.centralDecimalFile);
    expect(partyColors).toEqual(['#FF3B30', '#007AFF', '#FF9500', '#8E8E93']);
    const regions = chart('trend', [], ['Europe', 'Near East', 'South & Central Asia', 'East Asia & Pacific', 'Sub-Saharan Africa', 'Western Hemisphere', 'Other / Dependencies']);
    expect(seriesColors('geography', regions)).toEqual(defaultCycle);
    expect(seriesColors('administrations', regions)).toBe(partyColors);
  });

  it('keys a figure by the series it draws alone', () => {
    const eras = chart('perYear', [{ x: '1990', y: 2, series: '1945–1990' }], ['Before 1900', '1900–1944', '1945–1990', '1991–present']);
    expect(seriesLegend('production', eras)).toEqual([{ title: 'Legend', label: '1945–1990', color: defaultCycle[2] }]);
    expect(seriesLegend('production', chart('cumulative', [{ x: '1990', y: 2 }]))).toEqual([]);
  });
});

describe('the dashboards’ charts', () => {
  it('draw a bar a year wide, a decade’s notes a decade wide, and the step line after each change', () => {
    const perYear = seriesSpec('production', chart('perYear', [{ x: '1990', y: 2, series: '1945–1990' }], ['1945–1990']), false) as {
      data: { values: { year: number; end: number }[] };
    };
    expect(perYear.data.values[0]).toMatchObject({ year: 1990, end: 1991 });
    const density = seriesSpec('sourcing', chart('density', [{ x: '1940', y: 9 }]), false) as { data: { values: { end: number }[] } };
    expect(density.data.values[0]?.end).toBe(1950);
    const lag = seriesSpec('production', { ...chart('lag', [], ['Before 1900']), steps: [{ x: '1961', y: 15 }] }, false) as {
      layer: { mark: { interpolate?: string } }[];
    };
    expect(lag.layer[1]?.mark.interpolate).toBe('step-after');
  });
});

describe('the addresses', () => {
  it('keep what fits and drop what does not', () => {
    expect(validateArchivalSearch({ mode: 'network', umbrella: 'shown', only: 'yes', volumes: ['a', '', 'b'], focus: '', threshold: '0.30' })).toEqual({
      mode: 'network',
      umbrella: 'shown',
      volumes: ['a', 'b'],
      threshold: '0.30',
    });
    expect(validateSeriesSearch({ page: 'sourcing', from: '1945', to: 'later', notes: 'on', hidden: 'lotFile,unrecognized' })).toEqual({
      page: 'sourcing',
      from: 1945,
      notes: 'on',
      hidden: 'lotFile,unrecognized',
    });
  });
});

describe('a Markdown body', () => {
  it('sets strong and emphasis as the app’s does', () => {
    expect(markdownRuns('The profile of **your** library')).toEqual([{ text: 'The profile of ' }, { text: 'your', strong: true }, { text: ' library' }]);
    expect(markdownRuns('sent you *away* to.')).toEqual([{ text: 'sent you ' }, { text: 'away', emphasis: true }, { text: ' to.' }]);
    expect(markdownRuns('plain')).toEqual([{ text: 'plain' }]);
  });
});
