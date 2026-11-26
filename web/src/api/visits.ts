// The user's Archives Visit plans (PLAN's S30c), /api/v1/me/visits: the list, a plan's editor state, and every write
// the editor makes, each answering the plan as it then stands, which the editor shows at once. From PLAN's S30d the
// ways in, an add of documents to a plan or a plan made with them, Project Home's Plan a Visit, a collection's reading
// list and a collection authority's record's citing documents; and the packet's sheet, its writes and its files.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { getFile, getJSON } from './client';
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

/**
 * Each write answers the plan as it then stands: its editor shows it at once, and the list is read again, as is its
 * packet, which reads its seeds, stored state, topic and deliverables (S30d).
 */
function changed(client: QueryClient, plan: VisitPlan): VisitPlan {
  client.setQueryData(visitQuery(plan.id).queryKey, plan);
  void client.invalidateQueries({ queryKey: ['visits'] });
  void client.invalidateQueries({ queryKey: ['visitPacket', plan.id.toUpperCase()] });
  return plan;
}

/** A write that changes the seeds a document's review lists the plans of. */
function seedsChanged(client: QueryClient) {
  void client.invalidateQueries({ queryKey: ['documentReview'] });
}

const path = (id: string, tail = '') => `/api/v1/me/visits/${segment(id)}${tail}`;

/** New Archives Visit: under the active project, its research question the topic. */
export async function createVisit(client: QueryClient, name?: string): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'POST', '/api/v1/me/visits', name === undefined ? {} : { name }))!);
}

/** The packet's four deliverables, any of which a write names. */
export type VisitDeliverables = VisitPlan['deliverables'];

export async function editVisit(
  client: QueryClient,
  id: string,
  fields: { name?: string; inquiryText?: string; deliverables?: Partial<VisitDeliverables> },
): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'PATCH', path(id), fields))!);
}

/** A document one of the ways in adds. */
export interface SeedDocument {
  volumeId: string;
  documentId: string;
}

/** What the plan picker adds: its documents, and the halves its way in presets (`PlanPickerRequest`). */
export interface SeedRequest {
  documents: SeedDocument[];
  includeSource: boolean;
  includeExternalRefs: boolean;
}

/** The picker's row: the documents added to a plan by the kit's one add, a seed's halves turned on and never off. */
export async function addSeeds(client: QueryClient, id: string, request: SeedRequest): Promise<VisitPlan> {
  const plan = changed(client, (await change<VisitPlan>(client, 'POST', path(id, '/documents'), request))!);
  seedsChanged(client);
  return plan;
}

/** The picker's New row: a plan made under the active project, named as its way in suggests, then seeded with them. */
export async function createVisitWith(client: QueryClient, request: SeedRequest, name: string): Promise<VisitPlan> {
  const plan = changed(client, (await change<VisitPlan>(client, 'POST', '/api/v1/me/visits', { name, ...request }))!);
  seedsChanged(client);
  return plan;
}

/** Project Home's Plan a Visit, before it is pressed: the project's plan, and how many documents it engages. */
export interface ProjectVisit {
  planId?: string | null;
  engagedDocuments: number;
}

export function projectVisitQuery(projectId: string) {
  return queryOptions({
    queryKey: ['projectVisit', projectId.toUpperCase()],
    queryFn: ({ signal }) => getJSON<ProjectVisit>(`/api/v1/me/projects/${segment(projectId)}/visit`, undefined, signal),
    staleTime: 0,
    retry: false,
  });
}

/** Plan a Visit: the project's plan opened, or made from its engaged documents. */
export async function planVisit(client: QueryClient, projectId: string): Promise<{ created: boolean; plan: VisitPlan }> {
  const answer = (await change<{ created: boolean; plan: VisitPlan }>(client, 'POST', `/api/v1/me/projects/${segment(projectId)}/visit`))!;
  changed(client, answer.plan);
  void client.invalidateQueries({ queryKey: ['projectVisit', projectId.toUpperCase()] });
  seedsChanged(client);
  return answer;
}

/** A collection's reading list, as Add to Archives Visit… seeds a plan from it, with the names its picker reads. */
export interface CollectionSeeds {
  documents: SeedDocument[];
  listName: string;
  suggestedName: string;
}

export async function collectionSeeds(collectionId: string): Promise<CollectionSeeds> {
  return getJSON<CollectionSeeds>(`/api/v1/me/collections/${segment(collectionId)}/visit-documents`);
}

/** A collection authority's record's citing documents in this server's index, every one below the fetch's ceiling. */
export interface RecordSeeds {
  name: string;
  totalCount: number;
  documents: SeedDocument[];
}

export async function recordSeeds(recordId: string): Promise<RecordSeeds> {
  return getJSON<RecordSeeds>('/api/v1/archival-collection/documents', new URLSearchParams({ id: recordId }));
}

/** The packet's sheet over a plan (`GET …/packet`). */
export interface VisitPacket {
  /** Why there is no packet: no index served, or no documents seeded. */
  unavailable?: 'indexUnavailable' | 'noDocuments' | null;
  /** The kit's exporter's text, the whole plan's or a repository's slice. */
  text?: string | null;
  /** The day its header's stamp prints, `yyyy-MM-dd` in UTC. */
  day: string;
  /** The repository it is scoped to; none for the whole plan. */
  repository?: string | null;
  /** The repositories it covers, which it may be scoped to and each with its draft. */
  repositories: string[];
  drafts: { repository: string; text: string }[];
  /** The plan's topic as stored. */
  topic?: string | null;
  topicPlaceholder: string;
  /** The research question of the plan's project, which the topic's caption compares the field to. */
  researchQuestion?: string | null;
  deliverables: VisitDeliverables;
  title: string;
  fileName: string;
  textFileName: string;
}

/** The packet over the plan `id`, for a repository's slice or the whole plan, and the day the sheet opened on. */
export function packetQuery(id: string, repository: string | null, day: string | null) {
  return queryOptions({
    queryKey: ['visitPacket', id.toUpperCase(), repository, day],
    queryFn: ({ signal }) => {
      const params = new URLSearchParams();
      if (repository !== null) params.set('repository', repository);
      if (day !== null) params.set('day', day);
      return getJSON<VisitPacket>(path(id, '/packet'), params, signal);
    },
    staleTime: 30_000,
    retry: false,
  });
}

/** The packet saved, as text or as PDF, for the slice and the day the sheet shows: the file, with the name the server gives. */
export async function packetFile(id: string, format: 'text' | 'pdf', packet: VisitPacket): Promise<{ blob: Blob; name: string }> {
  const params = new URLSearchParams({ format, day: packet.day });
  if (packet.repository) params.set('repository', packet.repository);
  return getFile(`${path(id, '/packet/file')}?${params.toString()}`, format === 'pdf' ? packet.fileName : packet.textFileName);
}

export async function duplicateVisit(client: QueryClient, id: string): Promise<VisitPlan> {
  return changed(client, (await change<VisitPlan>(client, 'POST', path(id, '/duplicate')))!);
}

export async function deleteVisit(client: QueryClient, id: string): Promise<void> {
  await change(client, 'DELETE', path(id));
  client.removeQueries({ queryKey: visitQuery(id).queryKey });
  void client.invalidateQueries({ queryKey: ['visits'] });
  seedsChanged(client);
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
  const plan = changed(client, (await change<VisitPlan>(client, 'DELETE', path(id, `/documents?key=${segment(key)}`)))!);
  seedsChanged(client);
  return plan;
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
