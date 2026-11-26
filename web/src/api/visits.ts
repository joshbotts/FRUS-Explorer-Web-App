// The user's Archives Visit plans (PLAN's S30c), /api/v1/me/visits: the list, a plan's editor state, and every write
// the editor makes, each answering the plan as it then stands, which the editor shows at once.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { getJSON } from './client';
import { change } from './userData';

const segment = encodeURIComponent;

export interface VisitPlanItem {
  id: string;
  /** As stored; empty for an untitled plan. */
  name: string;
  displayName: string;
  lastModified?: string | null;
  documentCount: number;
  indexedDocumentCount: number;
  /** "6 targets · 3 repositories", the kit's, for a plan with documents over a served index. */
  summary?: string | null;
}

export interface VisitPlanList {
  total: number;
  items: VisitPlanItem[];
}

export interface VisitTier {
  id: string;
  label?: string | null;
  displayName: string;
  order: number;
  members: number;
}

export interface VisitLink {
  label: string;
  url: string;
}

export interface VisitDrawnFrom {
  volumeId: string;
  documentId: string;
  /** The citation, its series' title in Markdown's italics. */
  citation: string;
  sourceNote: string;
}

export interface VisitPointedAt {
  volumeId: string;
  documentId: string;
  /** The citation and the footnote the volume printed, in Markdown's italics. */
  line: string;
  rawText: string;
  inherited: boolean;
}

export interface VisitLot {
  title: string;
  recordsLine?: string | null;
  accessLines: string[];
}

export interface VisitTarget {
  key: string;
  label: string;
  form: string;
  recordsLine?: string | null;
  drawnFrom: VisitDrawnFrom[];
  drawnFromCount: number;
  pointedAt: VisitPointedAt[];
  pointedAtCount: number;
  substitute: boolean;
  accessLines: string[];
  lots: VisitLot[];
  tierId?: string | null;
  excluded: boolean;
  note?: string | null;
}

export interface VisitSection {
  heading: string;
  unplaced: boolean;
  links: VisitLink[];
  targets: VisitTarget[];
}

export interface VisitStoredTarget {
  key: string;
  label: string;
  kind: 'orphan' | 'superseded';
  tierId?: string | null;
  note?: string | null;
  partOf?: string | null;
  excludedWhenOwn: boolean;
}

export interface VisitSeed {
  key: string;
  volumeId?: string | null;
  documentId?: string | null;
  header?: string | null;
  volumeTitle?: string | null;
  hasSourceNote?: boolean | null;
  referenceCount?: number | null;
  includeSource: boolean;
  includeExternalRefs: boolean;
}

export interface VisitPlan {
  id: string;
  name: string;
  displayName: string;
  inquiryText?: string | null;
  projectIds: string[];
  /** The project Re-seed from Project reads, while the user holds it. */
  project?: { id: string; name: string } | null;
  createdAt?: string | null;
  lastModified?: string | null;
  deliverables: { includeLinks: boolean; includeTargets: boolean; includeInquiry: boolean; includeCitationCrib: boolean };
  tiers: VisitTier[];
  documentCount: number;
  indexedDocumentCount: number;
  served: boolean;
  summary?: string | null;
  sections: VisitSection[];
  storedTargets: VisitStoredTarget[];
  documents: VisitSeed[];
  sparsity?: { withReferences: number; indexed: number } | null;
}

export interface VisitReseed {
  topic: 'unchanged' | 'filled' | 'needsConfirmation';
  question?: string | null;
  current?: string | null;
  added: number;
  plan: VisitPlan;
}

export const visitsQuery = queryOptions({
  queryKey: ['visits'],
  queryFn: ({ signal }) => getJSON<VisitPlanList>('/api/v1/me/visits', undefined, signal),
  staleTime: 30_000,
  retry: false,
});

/** One of the user's plans, by its id in any letter case, as its editor reads it. */
export function visitQuery(id: string) {
  return queryOptions({
    queryKey: ['visit', id.toUpperCase()],
    queryFn: ({ signal }) => getJSON<VisitPlan>(`/api/v1/me/visits/${segment(id)}`, undefined, signal),
    staleTime: 30_000,
    retry: false,
  });
}

/** Each write answers the plan as it then stands: its editor shows it at once, and the list is read again. */
function changed(client: QueryClient, plan: VisitPlan): VisitPlan {
  client.setQueryData(visitQuery(plan.id).queryKey, plan);
  void client.invalidateQueries({ queryKey: ['visits'] });
  return plan;
}

const path = (id: string, tail = '') => `/api/v1/me/visits/${segment(id)}${tail}`;

/** New Archives Visit: under the active project, its research question the topic. */
export async function createVisit(client: QueryClient, name?: string): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'POST', '/api/v1/me/visits', name === undefined ? {} : { name }))!);
}

export async function editVisit(client: QueryClient, id: string, fields: { name?: string; inquiryText?: string }): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'PATCH', path(id), fields))!);
}

export async function duplicateVisit(client: QueryClient, id: string): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'POST', path(id, '/duplicate')))!);
}

export async function deleteVisit(client: QueryClient, id: string): Promise<void> {
  await change(client, 'DELETE', path(id));
  client.removeQueries({ queryKey: visitQuery(id).queryKey });
  void client.invalidateQueries({ queryKey: ['visits'] });
}

export async function reseedVisit(client: QueryClient, id: string): Promise<VisitReseed> {
  const answer = (await change<VisitReseed>(client, 'POST', path(id, '/reseed')))!;
  changed(client, answer.plan);
  return answer;
}

/** A target's tier (null for Unprioritized), exclusion or note: one of the three. */
export async function writeTarget(
  client: QueryClient,
  id: string,
  key: string,
  write: { tierId: string | null } | { included: boolean } | { note: string },
): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'PATCH', path(id, '/targets'), { key, ...write }))!);
}

export async function removeStoredTarget(client: QueryClient, id: string, key: string): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'DELETE', path(id, `/targets?key=${segment(key)}`)))!);
}

export async function writeSeed(
  client: QueryClient,
  id: string,
  key: string,
  write: { includeSource: boolean } | { includeExternalRefs: boolean },
): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'PATCH', path(id, '/documents'), { key, ...write }))!);
}

export async function removeSeed(client: QueryClient, id: string, key: string): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'DELETE', path(id, `/documents?key=${segment(key)}`)))!);
}

export async function addTier(client: QueryClient, id: string): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'POST', path(id, '/tiers')))!);
}

export async function relabelTier(client: QueryClient, id: string, tierId: string, label: string): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'PATCH', path(id, `/tiers/${segment(tierId)}`), { label }))!);
}

export async function moveTier(client: QueryClient, id: string, tierId: string, by: number): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'POST', path(id, `/tiers/${segment(tierId)}/move`), { by }))!);
}

export async function deleteTier(client: QueryClient, id: string, tierId: string): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'DELETE', path(id, `/tiers/${segment(tierId)}`)))!);
}
