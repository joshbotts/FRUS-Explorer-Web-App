import { afterEach, describe, expect, it, vi } from 'vitest';
import { emptyFields, lookupState, resetLookupState, restored, setDerived, setField, setMode, setText, shownFields } from './lookupState';

afterEach(() => {
  resetLookupState();
  vi.restoreAllMocks();
});

describe('Citation Lookup’s form', () => {
  it('reads back what the tab’s session kept, and a new form for anything it cannot read', () => {
    const kept = { mode: 'batch', text: '1. FRUS.', derivedFrom: '', derived: { ...emptyFields, volumeNumber: 'VI' }, edits: { pageNumber: '2' }, batch: '1. FRUS.', needsWorkFirst: false };
    window.sessionStorage.setItem('frus.citationLookup', JSON.stringify(kept));
    expect(restored()).toEqual({ ...kept, mode: 'batch' });
    for (const unreadable of ['{', 'null', '"text"', JSON.stringify({ ...kept, mode: 'other' })]) {
      window.sessionStorage.setItem('frus.citationLookup', unreadable);
      expect(restored().mode).toBe('paste');
      expect(restored().text).toBe('');
    }
    // A field missing from an older form is empty, not missing.
    window.sessionStorage.setItem('frus.citationLookup', JSON.stringify({ mode: 'structured', derived: { subseries: '1961-63' } }));
    expect(restored().derived).toEqual({ ...emptyFields, subseries: '1961-63' });
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('blocked');
    });
    expect(restored().text).toBe('');
  });

  it('derives the fields again at each paste, as the kit’s refreshed(forPaste:mode:parser:) does, and keeps them otherwise', () => {
    setText('FRUS, vol. VI');
    setDerived('FRUS, vol. VI', { ...emptyFields, volumeNumber: 'VI' });
    setField('pageNumber', '3');
    expect(shownFields(lookupState())).toEqual({ ...emptyFields, volumeNumber: 'VI', pageNumber: '3' });
    // An answer for another text is not kept.
    setDerived('FRUS, vol. V', { ...emptyFields, volumeNumber: 'V' });
    expect(lookupState().derived.volumeNumber).toBe('VI');
    // Structured Entry and back, the text unchanged: the edit stays.
    setMode('structured');
    setMode('paste');
    expect(shownFields(lookupState()).pageNumber).toBe('3');
    // Batch changes the text: Structured Entry keeps the fields, and Paste derives them again.
    setMode('batch');
    setText('1. FRUS, vol. V');
    setMode('structured');
    expect(shownFields(lookupState())).toEqual({ ...emptyFields, volumeNumber: 'VI', pageNumber: '3' });
    setMode('paste');
    expect(lookupState().derivedFrom).toBe('1. FRUS, vol. V');
    expect(shownFields(lookupState())).toEqual(emptyFields);
    // A paste empties the fields until the kit has read it.
    setDerived('1. FRUS, vol. V', { ...emptyFields, volumeNumber: 'V' });
    setText('FRUS, vol. VII');
    expect(shownFields(lookupState())).toEqual(emptyFields);
  });
});
