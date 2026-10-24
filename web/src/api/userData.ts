// The user's own data, under /api/v1/me (PLAN's S14c): who the server takes the browser to be, with
// the token every change carries, the user's tags, theirs and a document's, and a document's
// highlights (S15c). A change that the server refuses for its token, as after a restart, asks for a
// new one and is sent once more.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { ApiError, getJSON, sendJSON } from './client';
import type { DocumentHighlights, DocumentTags, Highlight, HighlightColor, Me, TagList, UserTag } from './types';

const segment = encodeURIComponent;

export const meQuery = queryOptions({
  queryKey: ['me'],
  queryFn: ({ signal }) => getJSON<Me>('/api/v1/me', undefined, signal),
  staleTime: Infinity,
  retry: false,
});

export const tagsQuery = queryOptions({
  queryKey: ['tags'],
  queryFn: ({ signal }) => getJSON<TagList>('/api/v1/me/tags', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

function documentTagsPath(volumeId: string, documentId: string): string {
  return `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/tags`;
}

export function documentTagsQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['documentTags', volumeId, documentId],
    queryFn: ({ signal }) => getJSON<DocumentTags>(documentTagsPath(volumeId, documentId), undefined, signal),
    staleTime: 60_000,
    retry: false,
  });
}

/** Sends a change with the user's token, and once more with a new one if the server no longer knows it. */
async function change<T>(client: QueryClient, method: 'POST' | 'PUT' | 'PATCH' | 'DELETE', path: string, body?: unknown) {
  const me = await client.ensureQueryData(meQuery);
  try {
    return await sendJSON<T>(method, path, me.csrfToken, body);
  } catch (error) {
    if (!(error instanceof ApiError && error.code === 'CSRF_TOKEN_INVALID')) throw error;
    const fresh = await client.fetchQuery({ ...meQuery, staleTime: 0 });
    return await sendJSON<T>(method, path, fresh.csrfToken, body);
  }
}

/** After a change to a tag itself, every list of tags may name it: the user's and each document's. */
function tagsChanged(client: QueryClient) {
  void client.invalidateQueries({ queryKey: ['tags'] });
  void client.invalidateQueries({ queryKey: ['documentTags'] });
}

export async function createTag(client: QueryClient, name: string): Promise<UserTag> {
  const tag = (await change<UserTag>(client, 'POST', '/api/v1/me/tags', { name }))!;
  void client.invalidateQueries({ queryKey: ['tags'] });
  return tag;
}

export async function renameTag(client: QueryClient, id: string, name: string): Promise<UserTag> {
  const tag = (await change<UserTag>(client, 'PATCH', `/api/v1/me/tags/${segment(id)}`, { name }))!;
  tagsChanged(client);
  return tag;
}

/** Deletes a tag, and with it its assignments and its id in every note and project. */
export async function deleteTag(client: QueryClient, id: string): Promise<void> {
  await change(client, 'DELETE', `/api/v1/me/tags/${segment(id)}`);
  tagsChanged(client);
}

/** Merges a tag into another, which takes its documents, notes and projects; answers the other. */
export async function mergeTag(client: QueryClient, id: string, into: string): Promise<UserTag> {
  const tag = (await change<UserTag>(client, 'POST', `/api/v1/me/tags/${segment(id)}/merge`, { into }))!;
  tagsChanged(client);
  return tag;
}

/** The tag picker's Done: the document carries exactly these tags. */
export async function setDocumentTags(client: QueryClient, volumeId: string, documentId: string, tagIds: string[]) {
  const tags = (await change<DocumentTags>(client, 'PUT', documentTagsPath(volumeId, documentId), { tagIds }))!;
  client.setQueryData(documentTagsQuery(volumeId, documentId).queryKey, tags);
  return tags;
}

/** The Research rail's ×: one tag off the document. */
export async function removeDocumentTag(client: QueryClient, volumeId: string, documentId: string, tagId: string) {
  const tags = (await change<DocumentTags>(client, 'DELETE', `${documentTagsPath(volumeId, documentId)}/${segment(tagId)}`))!;
  client.setQueryData(documentTagsQuery(volumeId, documentId).queryKey, tags);
  return tags;
}

function documentHighlightsPath(volumeId: string, documentId: string): string {
  return `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/highlights`;
}

/** A document's highlights, in the order the reader draws them, each stale or not by the kit's rule. */
export function documentHighlightsQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['documentHighlights', volumeId, documentId],
    queryFn: ({ signal }) => getJSON<DocumentHighlights>(documentHighlightsPath(volumeId, documentId), undefined, signal),
    staleTime: 60_000,
    retry: false,
  });
}

/** After a change to one of a document's highlights, its list is read again: the server says what is stale. */
function highlightsChanged(client: QueryClient, volumeId: string, documentId: string) {
  return client.invalidateQueries({ queryKey: documentHighlightsQuery(volumeId, documentId).queryKey });
}

/**
 * A colour chosen over a selection: a highlight over its offsets in the page whose rendering version
 * the request names. The server takes its text and version from the page's model, as the app's
 * reader does.
 */
export async function createHighlight(
  client: QueryClient,
  volumeId: string,
  documentId: string,
  highlight: { startOffset: number; endOffset: number; colorTag: HighlightColor; renderingVersion: string },
): Promise<Highlight> {
  const made = (await change<Highlight>(client, 'POST', documentHighlightsPath(volumeId, documentId), highlight))!;
  await highlightsChanged(client, volumeId, documentId);
  return made;
}

/** Whether the server has no such highlight: removed elsewhere, in another tab or browser. */
const gone = (error: unknown) => error instanceof ApiError && error.code === 'HIGHLIGHT_NOT_FOUND';

/** Another colour for a highlight, keeping its text, offsets and version. */
export async function recolorHighlight(client: QueryClient, highlight: Highlight, colorTag: HighlightColor): Promise<Highlight> {
  try {
    const recoloured = (await change<Highlight>(client, 'PATCH', `/api/v1/me/highlights/${segment(highlight.id)}`, { colorTag }))!;
    await highlightsChanged(client, highlight.volumeId, highlight.documentId);
    return recoloured;
  } catch (error) {
    // One removed elsewhere leaves the list, and the refusal is said.
    if (gone(error)) await highlightsChanged(client, highlight.volumeId, highlight.documentId);
    throw error;
  }
}

/** Removes a highlight, as the app's Remove Highlight does; one already removed elsewhere is removed. */
export async function deleteHighlight(client: QueryClient, highlight: Highlight): Promise<void> {
  try {
    await change(client, 'DELETE', `/api/v1/me/highlights/${segment(highlight.id)}`);
  } catch (error) {
    if (!gone(error)) throw error;
  }
  await highlightsChanged(client, highlight.volumeId, highlight.documentId);
}
