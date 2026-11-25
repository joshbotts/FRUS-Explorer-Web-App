import { describe, expect, it } from 'vitest';
import type { VisitPlan, VisitTarget } from '../api/visits';
import {
  citationRuns,
  citationText,
  claimCountsLine,
  freshFilters,
  hasActiveFilters,
  noFilters,
  noTargetsExplanation,
  passes,
  tierName,
  visibleSections,
} from './visitRules';

function target(fields: Partial<VisitTarget> & Pick<VisitTarget, 'key' | 'label'>): VisitTarget {
  return {
    form: 'lotFile',
    drawnFrom: [],
    drawnFromCount: 1,
    pointedAt: [],
    pointedAtCount: 0,
    substitute: false,
    accessLines: [],
    lots: [],
    excluded: false,
    ...fields,
  };
}

const first = { id: 'T1', label: 'First morning', displayName: 'First morning', order: 0, members: 1 };
const lot = target({ key: 'lot|66D204', label: 'Files, Lot 66 D 204', tierId: 'T1' });
const pointed = target({ key: 'lot|77D163', label: 'Files, Lot 77 D 163', drawnFromCount: 0, pointedAtCount: 2, excluded: true });
const raw = target({ key: 'r|Source: Current Documents', label: 'Source: Current Documents', form: 'raw' });

const plan: VisitPlan = {
  id: 'P',
  name: 'Berlin',
  displayName: 'Berlin',
  projectIds: [],
  deliverables: { includeLinks: true, includeTargets: true, includeInquiry: true, includeCitationCrib: false },
  tiers: [first],
  documentCount: 3,
  indexedDocumentCount: 3,
  served: true,
  sections: [
    { heading: 'National Archives at College Park', unplaced: false, links: [], targets: [lot, pointed] },
    { heading: 'Confirm before you travel', unplaced: true, links: [], targets: [raw] },
  ],
  storedTargets: [],
  documents: [
    { key: 'frus1961-63v06/d1', includeSource: true, includeExternalRefs: false },
    { key: 'frus1961-63v06/d10', includeSource: false, includeExternalRefs: true },
  ],
};

describe('the Targets list’s filters', () => {
  it('narrow by repository, tier, claim and inclusion, as the app’s visibleTargets does', () => {
    expect(passes(lot, 'National Archives at College Park', noFilters)).toBe(true);
    expect(passes(lot, 'National Archives at College Park', { ...noFilters, repository: 'Confirm before you travel' })).toBe(false);
    expect(passes(lot, 'x', { ...noFilters, tier: { kind: 'unprioritized' } })).toBe(false);
    expect(passes(raw, 'x', { ...noFilters, tier: { kind: 'unprioritized' } })).toBe(true);
    expect(passes(lot, 'x', { ...noFilters, tier: { kind: 'tier', id: 'T1' } })).toBe(true);
    expect(passes(raw, 'x', { ...noFilters, tier: { kind: 'tier', id: 'T1' } })).toBe(false);
    expect(passes(pointed, 'x', { ...noFilters, claim: 'drawnFrom' })).toBe(false);
    expect(passes(pointed, 'x', { ...noFilters, claim: 'pointedAt' })).toBe(true);
    expect(passes(lot, 'x', { ...noFilters, claim: 'pointedAt' })).toBe(false);
    expect(passes(pointed, 'x', { ...noFilters, includedOnly: true })).toBe(false);
  });

  it('draw only the sections with a target left, in their order', () => {
    expect(visibleSections(plan, noFilters).map((section) => section.targets.map((each) => each.key))).toEqual([
      ['lot|66D204', 'lot|77D163'],
      ['r|Source: Current Documents'],
    ]);
    expect(visibleSections(plan, { ...noFilters, claim: 'pointedAt' }).map((section) => section.heading)).toEqual([
      'National Archives at College Park',
    ]);
    expect(visibleSections(plan, { ...noFilters, claim: 'pointedAt', includedOnly: true })).toEqual([]);
  });

  it('say whether any narrows, and reset a tier or a repository the plan no longer has', () => {
    expect(hasActiveFilters(noFilters)).toBe(false);
    expect(hasActiveFilters({ ...noFilters, includedOnly: true })).toBe(true);
    const stale = { ...noFilters, tier: { kind: 'tier' as const, id: 'GONE' }, repository: 'A library' };
    expect(freshFilters(stale, plan)).toEqual(noFilters);
    const kept = { ...noFilters, tier: { kind: 'tier' as const, id: 'T1' }, repository: 'Confirm before you travel' };
    expect(freshFilters(kept, plan)).toBe(kept);
  });
});

describe('a target’s words', () => {
  it('say each claim apart, never summed, the app’s singular at one', () => {
    expect(claimCountsLine(lot)).toBe('drawn from 1 document');
    expect(claimCountsLine(pointed)).toBe('pointed at by 2 footnotes');
    expect(claimCountsLine(target({ key: 'k', label: 'l', drawnFromCount: 1200, pointedAtCount: 1 }))).toBe(
      'drawn from 1,200 documents · pointed at by 1 footnote',
    );
  });

  it('name the tier of a target, and none for Unprioritized or a tier gone', () => {
    expect(tierName(plan, 'T1')).toBe('First morning');
    expect(tierName(plan, null)).toBeUndefined();
    expect(tierName(plan, 'GONE')).toBeUndefined();
  });

  it('say which half is missing where no target derives', () => {
    expect(noTargetsExplanation(plan)).toMatch(/^No targets derive from these documents on this server/);
    const off = { ...plan, documents: plan.documents.map((seed) => ({ ...seed, includeSource: false, includeExternalRefs: false })) };
    expect(noTargetsExplanation(off)).toMatch(/^Every document’s contributions are switched off/);
  });

  it('read the formatter’s series title in italics', () => {
    const citation = '_Foreign Relations of the United States_, 1961–1963, Volume VI, Document 10.';
    expect(citationRuns(citation)).toEqual([
      { text: 'Foreign Relations of the United States', emphasis: true },
      { text: ', 1961–1963, Volume VI, Document 10.' },
    ]);
    expect(citationText(citation)).toBe('Foreign Relations of the United States, 1961–1963, Volume VI, Document 10.');
    expect(citationRuns('No marks.')).toEqual([{ text: 'No marks.' }]);
  });
});
