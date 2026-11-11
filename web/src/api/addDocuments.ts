// Add Documents' Citations and Tags (PLAN's S25d), under /api/v1/me/add-documents: a paste resolved line
// by line by the kit's resolver, and the user's tags with each one's documents, the kit's union of their
// notes and tag assignments. Neither changes anything; what the sheet chooses is added by the
// collection's own `addDocuments`.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { getJSON } from './client';
import { change } from './userData';

/** A line's bucket, as the kit's resolver gives it. */
export type CitationOutcome = 'resolved' | 'ambiguous' | 'unresolved';

/** One line of a paste, with the document it names, if any, and what its row shows. */
export interface CitationLine {
  line: string;
  outcome: CitationOutcome;
  volumeId?: string;
  documentId?: string;
  /** A resolved line's correction note, or an ambiguous line's rank note. */
  note?: string;
  /** Why an unresolved line names no document. */
  reason?: string;
  /** The document's head in the served index; absent for none. */
  header?: string;
  /** The volume's title in the catalogue. */
  volumeTitle?: string;
}

export interface CitationLines {
  total: number;
  items: CitationLine[];
}

/** A tag, with how many documents its union gathers. */
export interface DiscoveryTag {
  id: string;
  name: string;
  count: number;
}

export interface DiscoveryTags {
  total: number;
  items: DiscoveryTag[];
}

/** A document a tag gathers, with what its row shows. */
export interface TaggedDocument {
  volumeId: string;
  documentId: string;
  header?: string;
  volumeTitle?: string;
}

export interface TagDocuments {
  id: string;
  name: string;
  total: number;
  items: TaggedDocument[];
}

/** Resolves each line of `text`, as the sheet's Resolve does. A POST, which changes nothing, for a long paste. */
export async function resolveCitations(client: QueryClient, text: string): Promise<CitationLines> {
  const answer = await change<CitationLines>(client, 'POST', '/api/v1/me/add-documents/citations', { text });
  return answer ?? { total: 0, items: [] };
}

/** The user's tags, each with its count, read each time the tab opens, as the app's sheet counts its rows. */
export const discoveryTagsQuery = queryOptions({
  queryKey: ['addDocumentsTags'],
  queryFn: ({ signal }) => getJSON<DiscoveryTags>('/api/v1/me/add-documents/tags', undefined, signal),
  staleTime: 0,
  retry: false,
});

/** A tag's documents, gathered once each time it is opened. */
export function tagDocumentsQuery(tagId: string) {
  return queryOptions({
    queryKey: ['addDocumentsTag', tagId],
    queryFn: ({ signal }) => getJSON<TagDocuments>(`/api/v1/me/add-documents/tags/${encodeURIComponent(tagId)}`, undefined, signal),
    staleTime: 0,
    retry: false,
  });
}
