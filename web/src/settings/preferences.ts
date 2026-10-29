// The viewer's conveniences, kept in this browser: appearance, the reader's text size and reading
// width, the citation style, which of the Research rail's sections are open, and whether the note
// editor shows formatting. Storage can be missing or refuse, so every read and write may fail
// quietly.
import { useEffect, useSyncExternalStore } from 'react';
import type { ReadingWidth, TextSize } from '../api/endpoints';
import type { CitationStyleName } from '../api/types';

export type Appearance = 'system' | 'light' | 'dark';

// This page's choices, which every component reading a preference shares. Storage is written
// too when it can be, so the choices outlast the page; when it refuses, they last as long as it.
const chosen = new Map<string, string>();
const listeners = new Set<() => void>();

function read(key: string): string | null {
  if (chosen.has(key)) return chosen.get(key) ?? null;
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function write(key: string, value: string): void {
  chosen.set(key, value);
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // A private window or blocked storage keeps the choice for this page only.
  }
  for (const listener of listeners) listener();
}

function subscribeToChoices(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

/** Forgets this page's choices, for tests. */
export function resetPreferences(): void {
  chosen.clear();
}

function usePreference<T extends string>(key: string, allowed: readonly T[], fallback: T): [T, (value: T) => void] {
  const stored = useSyncExternalStore(subscribeToChoices, () => read(key), () => null);
  const value = allowed.includes(stored as T) ? (stored as T) : fallback;
  return [value, (next: T) => write(key, next)];
}

export const useAppearance = () => usePreference<Appearance>('frus.appearance', ['system', 'light', 'dark'], 'system');
export const useTextSize = () =>
  usePreference<TextSize>('frus.textSize', ['small', 'medium', 'large', 'extraLarge'], 'medium');
/** Standard by default, as the app's Reading Width is on every device. */
export const useReadingWidth = () =>
  usePreference<ReadingWidth>('frus.readingWidth', ['narrow', 'standard', 'wide'], 'standard');
export const useCitationStyle = () =>
  usePreference<CitationStyleName>('frus.citationStyle', ['historyAtState', 'chicago', 'turabian'], 'historyAtState');

/** Closed until it is opened, and then as it was left, as the app's rail keeps its Tags section. */
export const useTagsSectionOpen = () => usePreference<'open' | 'closed'>('frus.research.tags', ['open', 'closed'], 'closed');
/** The Highlights section, the web's own, kept as the Tags section is. */
export const useHighlightsSectionOpen = () =>
  usePreference<'open' | 'closed'>('frus.research.highlights', ['open', 'closed'], 'closed');
/** Open until it is closed, as the app's rail keeps its Summary section. */
export const useSummarySectionOpen = () => usePreference<'open' | 'closed'>('frus.research.summary', ['open', 'closed'], 'open');
/** Closed until it is opened, and then as it was left, as the app's rail keeps its Collections section (S18d). */
export const useCollectionsSectionOpen = () =>
  usePreference<'open' | 'closed'>('frus.research.collections', ['open', 'closed'], 'closed');
/** Open until it is closed, as the app's rail keeps its Notes section. */
export const useNotesSectionOpen = () => usePreference<'open' | 'closed'>('frus.research.notes', ['open', 'closed'], 'open');
/**
 * Whether the note editor shows formatting, on until it is turned off, in this browser, as the app's
 * Formatting switch is kept on each device under the same key.
 */
export const useNoteEditorRichText = () => usePreference<'true' | 'false'>('frus.notes.editor.richText', ['true', 'false'], 'true');

const darkQuery = '(prefers-color-scheme: dark)';

function subscribe(onChange: () => void): () => void {
  const list = window.matchMedia?.(darkQuery);
  list?.addEventListener('change', onChange);
  return () => list?.removeEventListener('change', onChange);
}

/** The scheme the app and the reader's page show: the viewer's choice, or the system's. */
export function useResolvedScheme(appearance: Appearance): 'light' | 'dark' {
  const systemDark = useSyncExternalStore(subscribe, () => window.matchMedia?.(darkQuery).matches ?? false, () => false);
  const scheme = appearance === 'system' ? (systemDark ? 'dark' : 'light') : appearance;
  useEffect(() => {
    document.documentElement.dataset.theme = scheme;
  }, [scheme]);
  return scheme;
}
