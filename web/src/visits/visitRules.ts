// The Archives Visit editor's own rules (PLAN's S30c), the app's view's (`ArchiveVisitEditorView`), mirrored and held to
// its source by ArchiveVisitMirrorParityTests: the Targets list's four filters and what clears them, the claims' line,
// which never sums its two counts, the line where no target derives, and the citation's italics. The server gives the
// sections in the app's order, each section's targets by tier then label, with the kit's words; the filters narrow them
// here, as the app's view narrows the derivation it holds. From PLAN's S30d the packet sheet's topic rules, the kit's
// (`TripPacketTopicSentence`), and the plan picker's banner and search (`PlanPickerSheet`).
import type { VisitPlan, VisitPlanItem, VisitSection, VisitTarget } from '../api/visits';
import { copy } from '../copy';

/** The tier filter's three shapes: every target, those with no tier, or one tier's. */
export type TierFilter = { kind: 'all' } | { kind: 'unprioritized' } | { kind: 'tier'; id: string };
/** The claim filter: every target, or those with documents drawn from it, or footnotes pointing at it. */
export type ClaimFilter = 'all' | 'drawnFrom' | 'pointedAt';

export interface TargetFilters {
  /** A section's heading, or none for every repository. */
  repository: string | null;
  tier: TierFilter;
  claim: ClaimFilter;
  includedOnly: boolean;
}

export const noFilters: TargetFilters = { repository: null, tier: { kind: 'all' }, claim: 'all', includedOnly: false };

/** Whether a target passes the filters (`visibleTargets`), its section's heading `heading`. */
export function passes(target: VisitTarget, heading: string, filters: TargetFilters): boolean {
  if (filters.repository !== null && heading !== filters.repository) return false;
  switch (filters.tier.kind) {
    case 'all':
      break;
    case 'unprioritized':
      if (target.tierId != null) return false;
      break;
    case 'tier':
      if (target.tierId !== filters.tier.id) return false;
      break;
  }
  switch (filters.claim) {
    case 'all':
      break;
    case 'drawnFrom':
      if (target.drawnFromCount === 0) return false;
      break;
    case 'pointedAt':
      if (target.pointedAtCount === 0) return false;
      break;
  }
  if (filters.includedOnly && target.excluded) return false;
  return true;
}

/** The sections drawn under the filters: each with the targets that pass, in the order given, and none left empty. */
export function visibleSections(plan: VisitPlan, filters: TargetFilters): VisitSection[] {
  return plan.sections
    .map((section) => ({ ...section, targets: section.targets.filter((target) => passes(target, section.heading, filters)) }))
    .filter((section) => section.targets.length > 0);
}

/** Whether any filter narrows the list (`hasActiveFilters`). */
export function hasActiveFilters(filters: TargetFilters): boolean {
  return filters.repository !== null || filters.tier.kind !== 'all' || filters.claim !== 'all' || filters.includedOnly;
}

/**
 * The filters with the stale ones reset, as the app's view resets them after each derivation: a tier the plan no longer
 * has, or a repository no section is headed by, would empty the list while the controls read as unfiltered.
 */
export function freshFilters(filters: TargetFilters, plan: VisitPlan): TargetFilters {
  let fresh = filters;
  if (fresh.tier.kind === 'tier') {
    const id = fresh.tier.id;
    if (!plan.tiers.some((tier) => tier.id === id)) fresh = { ...fresh, tier: { kind: 'all' } };
  }
  if (fresh.repository !== null && !plan.sections.some((section) => section.heading === fresh.repository)) {
    fresh = { ...fresh, repository: null };
  }
  return fresh;
}

/** The row's claims (`claimCountsLine`): two clauses, never one total. */
export function claimCountsLine(target: VisitTarget): string {
  const parts: string[] = [];
  if (target.drawnFromCount > 0) parts.push(copy.visits.drawnFromCount(target.drawnFromCount));
  if (target.pointedAtCount > 0) parts.push(copy.visits.pointedAtCount(target.pointedAtCount));
  return parts.join(' · ');
}

/** Which half is missing when the seeds derive no target (`noTargetsExplanation`). */
export function noTargetsExplanation(plan: VisitPlan): string {
  const anyOn = plan.documents.some((seed) => seed.includeSource || seed.includeExternalRefs);
  return anyOn ? copy.visits.noTargets : copy.visits.allOff;
}

/** A tier's name for a target's control: its tier's, or Set tier for an Unprioritized one. */
export function tierName(plan: VisitPlan, tierId: string | null | undefined): string | undefined {
  return tierId == null ? undefined : plan.tiers.find((tier) => tier.id === tierId)?.displayName;
}

/**
 * A citation's runs, as the app's `AttributedString(markdownBody:)` reads the kit's formatter's: the series' title in
 * underscores, emphasis.
 */
export function citationRuns(text: string): { text: string; emphasis?: boolean }[] {
  const runs: { text: string; emphasis?: boolean }[] = [];
  let last = 0;
  for (const match of text.matchAll(/_([^_]+)_/g)) {
    if (match.index > last) runs.push({ text: text.slice(last, match.index) });
    runs.push({ text: match[1] ?? '', emphasis: true });
    last = match.index + match[0].length;
  }
  if (last < text.length) runs.push({ text: text.slice(last) });
  return runs;
}

/** The text of a citation's runs, its marks gone, for an accessible name. */
export function citationText(text: string): string {
  return citationRuns(text)
    .map((run) => run.text)
    .join('');
}

/** `TripPacketTopicSentence.written`: the text as written when it holds anything but white space, else none. */
export function writtenTopic(text: string | null | undefined): string | null {
  return text != null && text.trim() !== '' ? text : null;
}

/** `sameText`: two topics that say the same thing, both written and equal once the white space around them is set aside. */
export function sameTopicText(first: string | null | undefined, second: string | null | undefined): boolean {
  const a = writtenTopic(first);
  const b = writtenTopic(second);
  return a !== null && b !== null && a.trim() === b.trim();
}

/** `showsSeededCaption(draft:researchQuestion:)`: the caption says "Seeded…" only while the field still reads the question. */
export function showsSeededCaption(draft: string, researchQuestion: string | null | undefined): boolean {
  return sameTopicText(draft, researchQuestion);
}

/** `isUncommitted(draft:edited:)`: the field holds an edit the plan has not taken, which Done writes before it closes. */
export function topicIsUncommitted(draft: string, edited: string | null | undefined): boolean {
  return writtenTopic(draft) !== writtenTopic(edited);
}

/** The picker's banner (`bannerText`): what is being added, under which claims, from where. */
export function pickerBanner(count: number, includeSource: boolean, includeExternalRefs: boolean, basis: string): string {
  const documents = copy.visits.documents(count);
  const contribution =
    includeSource && includeExternalRefs
      ? copy.visits.pickerAddingBoth(documents)
      : includeSource
        ? copy.visits.pickerAddingSource(documents)
        : copy.visits.pickerAddingRefs(documents);
  return `${contribution} — ${basis}`;
}

/** The picker's search (`filtered`): a plan whose name as its row shows it holds the text, whatever its case. */
export function planMatches(plan: VisitPlanItem, search: string): boolean {
  return search === '' || plan.displayName.toLocaleLowerCase('en-US').includes(search.toLocaleLowerCase('en-US'));
}
