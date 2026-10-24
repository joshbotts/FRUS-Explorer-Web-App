// What the notes and summaries specs share (PLAN's S15d): the user's notes, a note with its runs,
// and d1's summaries through the API, a change sent with the user's token from a page of the app,
// and a store left with no notes, summaries of one's own or tags, since the suite runs twice on one
// store.
import type { Page } from '@playwright/test';
import { expect } from './fixtures';

export const summariesPath = 'api/v1/me/volumes/frus1961-63v06/documents/d1/summaries';

/** A run of a note's text, as the server writes it: colour and link only when there is one. */
export interface Run {
  text: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  colorHex?: string;
  linkURL?: string;
}

export interface Note {
  id: string;
  volumeId: string;
  documentId: string;
  bodyText: string;
  userTagIds: string[];
  projectIds: string[];
  selectedSummaryIds: string[];
  linkedHighlightIds: string[];
  lastModified: string | null;
  runs?: Run[] | null;
  formattingKept?: boolean;
}

export interface Summary {
  id: string;
  responseText: string;
  authorship: string;
  editable: boolean;
}

/** A run with no formatting but what is given. */
/**
 * Lets the editor catch up with keys that come faster than a person types. ProseMirror reads a
 * selection made by keys on the browser's `selectionchange`, which can come after the next key, so
 * a formatting key could act on the selection before; and 20 ms after the editor takes focus it puts
 * back the selection it last read, over any made by keys in the meantime. So a test waits after the
 * editor takes focus, and after a selection, before it acts: 60 ms and two frames.
 */
export async function settle(page: Page): Promise<void> {
  await page.evaluate(
    () => new Promise<void>((done) => setTimeout(() => requestAnimationFrame(() => requestAnimationFrame(() => done())), 60)),
  );
}

export function run(text: string, format: Partial<Run> = {}): Run {
  return { text, bold: false, italic: false, underline: false, ...format };
}

async function getJSON<T>(page: Page, path: string): Promise<T> {
  const response = await page.request.get(path);
  expect(response.ok(), path).toBe(true);
  return (await response.json()) as T;
}

/** Every note of the user's, as the server lists them. */
export async function notes(page: Page): Promise<Note[]> {
  return (await getJSON<{ items: Note[] }>(page, 'api/v1/me/notes')).items;
}

/** One note, with its runs. */
export function noteWithRuns(page: Page, id: string): Promise<Note> {
  return getJSON<Note>(page, `api/v1/me/notes/${id}`);
}

/** d1's summaries, the newest first. */
export async function summaries(page: Page): Promise<Summary[]> {
  return (await getJSON<{ items: Summary[] }>(page, summariesPath)).items;
}

/** A change sent from a page of the app, with the token the server gave it; answers its JSON, if any. */
export async function send(page: Page, method: 'POST' | 'PUT' | 'DELETE', path: string, body?: unknown): Promise<unknown> {
  return page.evaluate(
    async ({ method, path, body }) => {
      const base = document.baseURI;
      const me = (await (await fetch(new URL('api/v1/me', base))).json()) as { csrfToken: string };
      const headers: Record<string, string> = { 'X-CSRF-Token': me.csrfToken, Accept: 'application/json' };
      if (body !== undefined) headers['Content-Type'] = 'application/json';
      const response = await fetch(new URL(path, base), { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
      if (!response.ok) throw new Error(`${method} ${path}: ${response.status} ${await response.text()}`);
      return response.status === 204 ? null : response.json();
    },
    { method, path, body },
  );
}

/** Leaves the store with no notes, no summary of the user's own on d1, and no tags. */
export async function removeNotesAndSummaries(page: Page): Promise<void> {
  for (const note of await notes(page)) await send(page, 'DELETE', `api/v1/me/notes/${note.id}`);
  for (const summary of await summaries(page)) if (summary.editable) await send(page, 'DELETE', `api/v1/me/summaries/${summary.id}`);
  const tags = await getJSON<{ items: { id: string }[] }>(page, 'api/v1/me/tags');
  for (const tag of tags.items) await send(page, 'DELETE', `api/v1/me/tags/${tag.id}`);
}

/** The day a note last changed, as All Notes writes it in the suite's time zone. */
export function abbreviatedDate(iso: string): string {
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' }).format(new Date(iso));
}
