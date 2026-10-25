// Citation Lookup's form, kept for the tab's session, as the app's window keeps its own while it is
// open: a document opened from a result, and Back, find the form and its results as they were, and
// so does a reload, from the tab's session storage. What the Parsed Fields hold is the kit's
// (`CitationLookupFields`), which the server derives: this keeps what the server last derived from
// the paste, the reader's edits over it, and when to ask again, as the app's form asks
// `refreshed(forPaste:mode:parser:)` whenever the paste or the mode changes.
import { useSyncExternalStore } from 'react';
import type { CitationFields, CitationLookupMode } from '../api/types';
import type { CitationFormRequest } from '../api/endpoints';

export const emptyFields: CitationFields = { subseries: '', volumeNumber: '', partNumber: '', documentNumber: '', pageNumber: '' };

export const fieldNames: (keyof CitationFields)[] = ['subseries', 'volumeNumber', 'partNumber', 'documentNumber', 'pageNumber'];

export interface LookupState {
  mode: CitationLookupMode;
  /** The paste's text, which Batch edits too, as the app's form has one text for both. */
  text: string;
  /** The text the Parsed Fields were last derived from, the kit's `derivedFrom`. */
  derivedFrom: string;
  /** What the server derived from that text, as it last answered. */
  derived: CitationFields;
  /** The reader's edits of the Parsed Fields since, which stand over what the paste yields. */
  edits: Partial<CitationFields>;
  /** The last lookup Look Up ran in Paste Citation or Structured Entry. */
  lookup?: CitationFormRequest;
  /** The last block Look Up ran in Batch. */
  batch?: string;
  /** Batch's Needs work first, on by default, as the app's table sorts worst first. */
  needsWorkFirst: boolean;
}

const initial: LookupState = { mode: 'paste', text: '', derivedFrom: '', derived: emptyFields, edits: {}, needsWorkFirst: true };

const storageKey = 'frus.citationLookup';

/** The state the tab's session kept, when it kept one this build can read. */
export function restored(): LookupState {
  try {
    const kept = JSON.parse(window.sessionStorage.getItem(storageKey) ?? 'null') as Partial<LookupState> | null;
    if (!kept || typeof kept !== 'object' || !['paste', 'structured', 'batch'].includes(kept.mode as string)) return initial;
    return { ...initial, ...kept, derived: { ...emptyFields, ...kept.derived }, edits: { ...kept.edits } };
  } catch {
    return initial;
  }
}

let state: LookupState = typeof window === 'undefined' ? initial : restored();
const listeners = new Set<() => void>();

function update(next: LookupState) {
  state = next;
  try {
    window.sessionStorage.setItem(storageKey, JSON.stringify(state));
  } catch {
    // A browser that keeps no session storage keeps the form until the page goes.
  }
  for (const listener of listeners) listener();
}

/** The form, rendered again whenever it changes. */
export function useLookupState(): LookupState {
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    () => state,
  );
}

export function lookupState(): LookupState {
  return state;
}

/** The Parsed Fields the form shows: what the paste yielded, with the reader's edits over it. */
export function shownFields(form: LookupState): CitationFields {
  return { ...form.derived, ...form.edits };
}

/**
 * The paste's text changed: in Paste Citation every field is the text's alone again, as each paste
 * re-derives the app's fields from scratch; in Batch, which never reads the fields, they stay. Until
 * the server has derived them, the fields are empty, never the last paste's: a field typed in, or a
 * lookup in Structured Entry, meanwhile starts from nothing rather than from another citation.
 */
export function setText(text: string) {
  const derive = state.mode === 'paste';
  update({ ...state, text, ...(derive ? { derivedFrom: text, derived: emptyFields, edits: {} } : {}) });
}

/**
 * The mode changed: entering Paste Citation derives the fields again when Batch has changed the text
 * since, and a return from Structured Entry, the text unchanged, keeps what the reader typed there.
 */
export function setMode(mode: CitationLookupMode) {
  const derive = mode === 'paste' && state.text !== state.derivedFrom;
  update({ ...state, mode, ...(derive ? { derivedFrom: state.text, derived: emptyFields, edits: {} } : {}) });
}

export function setField(name: keyof CitationFields, value: string) {
  update({ ...state, edits: { ...state.edits, [name]: value } });
}

/** What the server derived from `text`, kept while the fields are still that text's. */
export function setDerived(text: string, fields: CitationFields) {
  if (text !== state.derivedFrom || fieldNames.every((name) => state.derived[name] === fields[name])) return;
  update({ ...state, derived: fields });
}

export function setNeedsWorkFirst(on: boolean) {
  update({ ...state, needsWorkFirst: on });
}

/** Look Up in Paste Citation or Structured Entry: the request it ran. */
export function setLookup(lookup: CitationFormRequest) {
  update({ ...state, lookup });
}

/** Look Up in Batch: the block it ran. */
export function setBatch(text: string) {
  update({ ...state, batch: text });
}

/**
 * What the form asks of the kit in its mode, as Look Up would hand it over: in Paste Citation the
 * text and the reader's edits, the rest derived from the text by the server; in Structured Entry the
 * fields shown; in Batch the block.
 */
export function formRequest(form: LookupState): CitationFormRequest {
  switch (form.mode) {
    case 'paste':
      return { mode: 'paste', text: form.text, fields: form.edits };
    case 'structured':
      return { mode: 'structured', fields: shownFields(form) };
    case 'batch':
      return { mode: 'batch', text: form.text };
  }
}

/** The form as the tab's session kept it, read again as a new page of the tab reads it. */
export function restoreLookupState() {
  state = restored();
  for (const listener of listeners) listener();
}

/** For tests: the form as a new tab opens it, or, `keepingSession`, as it is before a page reads the session's. */
export function resetLookupState({ keepingSession = false }: { keepingSession?: boolean } = {}) {
  if (!keepingSession) {
    try {
      window.sessionStorage.removeItem(storageKey);
    } catch {
      // Nothing kept.
    }
  }
  state = initial;
  for (const listener of listeners) listener();
}
