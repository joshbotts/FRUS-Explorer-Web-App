// The editors' annotations' words, as the app's own tests expect them of its views
// (`VolumeAnnotationsPresentationTests`, `AnnotationsAxisTests`), from the parts and reaches the
// server gives for the same fixtures (Tests/FRUSLightServerTests/AnnotationTests.swift).
import { describe, expect, it } from 'vitest';
import type { AnnotationDrill, AnnotationEraName, AnnotationPart, AnnotationReach } from '../api/annotations';
import {
  absentNote,
  absentSpoken,
  absentTitle,
  accessoryText,
  drillCaption,
  drillSpoken,
  drillTitle,
  eraName,
  indexCaption,
  rowDetail,
  rowSpoken,
  shortEraName,
  spokenBand,
  spokenCell,
  spokenRow,
  standardFrom,
  standardLine,
  volumeNote,
  volumesLine,
} from './annotationRules';

const era1955: AnnotationEraName = { id: '1955-1968', firstYear: 1955, lastYear: 1968 };
const era1861: AnnotationEraName = { id: '1861-1898', firstYear: 1861, lastYear: 1898 };
const era1981: AnnotationEraName = { id: '1981-', firstYear: 1981 };
const retrospective: AnnotationEraName = { id: 'retrospective' };

const of = (count: number, total: number): AnnotationPart => ({ kind: 'ofDocuments', count, of: total });

describe('a volume page’s rows', () => {
  it('say their counts as the app’s rows do, joined by its middle dot', () => {
    expect(rowDetail([of(279, 280), { kind: 'personsListed', count: 325 }])).toBe('279 of 280 documents · 325 people listed');
    expect(rowDetail([of(278, 280), { kind: 'termsListed', count: 470 }])).toBe('278 of 280 documents · 470 terms listed');
    expect(rowDetail([{ kind: 'documents', count: 161 }])).toBe('161 documents');
    expect(rowDetail([of(268, 280), { kind: 'sourceForm', form: 'both' }])).toBe('268 of 280 documents · archival citations and file numbers');
    expect(rowDetail([of(6, 10), { kind: 'sourceForm', form: 'citations' }])).toBe('6 of 10 documents · archival citations (“Source: …”)');
    expect(rowDetail([{ kind: 'excisions', count: 37 }])).toBe('37 documents with redactions marked');
    expect(rowDetail([{ kind: 'editorialOmissions', count: 32 }])).toBe('32 documents with editorial omissions marked');
    expect(rowDetail([of(280, 280)])).toBe('280 of 280 documents');
    expect(rowDetail([{ kind: 'xrefDocuments', count: 131 }, { kind: 'xrefVolumes', count: 89 }])).toBe(
      '131 documents cite others in this volume · 89 documents cite other volumes',
    );
    expect(rowDetail([{ kind: 'editorialNotes', count: 12 }])).toBe('12 editorial notes');
    expect(rowDetail([{ kind: 'documents', count: 1 }])).toBe('1 document');
    expect(
      rowDetail(['preface', 'sources', 'terms', 'persons', 'note-on-covert-actions', 'index', 'errata'].map((aid) => ({ kind: 'aid', aid }) as AnnotationPart)),
    ).toBe('Preface · Sources · Abbreviations · Persons · Note on U.S. Covert Actions · Index · Errata');
    expect(rowDetail([{ kind: 'aid', aid: 'intro' }])).toBe('Introduction');
  });

  it('take the one form at exactly one, and group a count but never a year', () => {
    expect(rowDetail([{ kind: 'editorialNotes', count: 1 }])).toBe('1 editorial note');
    expect(rowDetail([{ kind: 'xrefPages', count: 1 }])).toBe('1 document cites printed pages');
    expect(rowDetail([{ kind: 'excisions', count: 1 }])).toBe('1 document with a redaction marked');
    expect(rowDetail([{ kind: 'editorialOmissions', count: 1 }])).toBe('1 document with an editorial omission marked');
    expect(rowDetail([of(1, 1)])).toBe('1 of 1 document');
    expect(rowDetail([of(1_234, 2_000)])).toBe('1,234 of 2,000 documents');
    expect(standardFrom(era1955)).toBe('Standard in the volumes covering 1955 on.');
  });

  it('are read as one sentence, the parts joined by semicolons', () => {
    expect(rowSpoken('people', [of(279, 280), { kind: 'personsListed', count: 325 }])).toBe(
      'People tagged: 279 of 280 documents; 325 people listed.',
    );
    expect(rowSpoken('editorialOmissions', [{ kind: 'editorialOmissions', count: 1 }])).toBe(
      'Marked editorial omissions: 1 document with an editorial omission marked.',
    );
  });

  it('list an absent standard layer with the era it became standard in, and for people where to look instead', () => {
    const people = { id: 'people', layer: 'people', onset: era1955 } as const;
    expect(absentNote(people)).toBe('Standard in the volumes covering 1955 on. Search the names instead.');
    expect(absentSpoken(people)).toBe(
      'Not in this volume: People tagged. Standard in the volumes covering 1955 on. Search the names instead.',
    );
    // A practice no era made standard gives no onset.
    expect(absentNote({ id: 'classification', layer: 'classification' })).toBe('');
    expect(absentSpoken({ id: 'referencesToDocuments', layer: 'crossReferences' })).toBe('Not in this volume: References to documents.');
    expect(absentSpoken({ id: 'noteOnSources', layer: 'printedAids' })).toBe('Not in this volume: Note on Sources.');
    expect(absentTitle(8)).toBe('Not in this volume (8)');
  });
});

describe('the axis', () => {
  const reach = (fields: Partial<AnnotationReach>): AnnotationReach => ({ layer: 'people', carrying: 2, total: 5, bands: [], ...fields });

  it('names an era as a span, an open end or the retrospectives, and a cell by its first year', () => {
    expect(eraName(era1861)).toBe('1861–1898');
    expect(eraName(era1981)).toBe('1981 on');
    expect(eraName(retrospective)).toBe('the late retrospectives');
    expect(shortEraName(era1955)).toBe('1955');
    expect(shortEraName(retrospective)).toBe('Retro.');
    expect(spokenBand(era1955, { carrying: 58, total: 60 })).toBe('1955–1968: 58 of 60 volumes');
    expect(spokenBand(retrospective, { carrying: 1, total: 1 })).toBe('Late retrospectives: 1 of 1 volume');
    expect(spokenCell('people', era1955, { era: '1955-1968', carrying: 114, total: 114 })).toBe('People tagged, 1955–1968: 114 of 114 volumes');
  });

  it('says when a layer became standard, or where a practice no era made standard is most common', () => {
    expect(standardLine(reach({ onset: era1955 }))).toBe('Standard in the volumes covering 1955 on.');
    expect(spokenRow(reach({ onset: era1955 }))).toBe('People tagged: 2 of 5 volumes. Standard in the volumes covering 1955 on.');
    expect(standardLine(reach({ layer: 'despatch', peak: era1861 }))).toBe('No era made it standard. It is most common in the volumes covering 1861–1898.');
    expect(standardLine(reach({ layer: 'marginalNotes', peak: retrospective }))).toBe(
      'No era made it standard. It is most common in the late retrospective volumes.',
    );
    // Redactions follow the year of publication, so they name the statute, not an era: with an onset,
    // with a peak, and even where no volume carries them.
    const statute =
      'Volumes produced after the passage of the 1991 statute include explicit editorial annotation of redactions made during the declassification process.';
    expect(standardLine(reach({ layer: 'excisions', onset: era1981 }))).toBe(statute);
    expect(standardLine(reach({ layer: 'excisions', peak: era1861 }))).toBe(statute);
    expect(standardLine(reach({ layer: 'excisions', carrying: 0 }))).toBe(statute);
    expect(spokenRow(reach({ layer: 'excisions', onset: era1981 }))).toBe(`Redactions marked as not declassified: 2 of 5 volumes. ${statute}`);
    expect(standardLine(reach({ layer: 'editorialOmissions', onset: { id: '1920-1931', firstYear: 1920, lastYear: 1931 } }))).toBe(
      'Standard in the volumes covering 1920 on.',
    );
    // A layer no volume carries says nothing of when.
    expect(standardLine(reach({ layer: 'subjects', carrying: 0 }))).toBe('');
    expect(spokenRow(reach({ layer: 'subjects', carrying: 0 }))).toBe('Subject lines: 0 of 5 volumes.');
    expect(volumesLine(288, 553)).toBe('288 of 553 volumes');
    expect(indexCaption(553).startsWith('What the editors of 553 volumes annotated, layer by layer.')).toBe(true);
  });
});

describe('a layer’s lists', () => {
  const drill = (fields: Partial<AnnotationDrill>): AnnotationDrill => ({
    layer: 'people',
    drill: 'with',
    rule: 'layer',
    count: 1,
    total: 3,
    volumes: [],
    ...fields,
  });

  it('are titled and captioned as the app’s specs are', () => {
    expect(drillTitle(drill({}))).toBe('With: People tagged');
    expect(drillTitle(drill({ drill: 'without' }))).toBe('Without: People tagged');
    expect(drillCaption(drill({}))).toBe('1 of 3 volumes. A volume counts when at least half its documents link a name to its List of Persons.');
    expect(drillTitle(drill({ layer: 'sourceNotes', drill: 'citation', rule: 'sourceForm' }))).toBe('Archival citations (“Source: …”)');
    expect(drillTitle(drill({ layer: 'printedAids', drill: 'intro', rule: 'aid' }))).toBe('Introduction');
    expect(drillCaption(drill({ layer: 'printedAids', drill: 'intro', rule: 'aid', count: 2 }))).toBe(
      '2 of 3 volumes. A volume counts when it prints this section.',
    );
    expect(drillTitle(drill({ layer: 'editorialOmissions', drill: 'without' }))).toBe('Without: Marked editorial omissions');
    expect(drillCaption(drill({ layer: 'editorialOmissions', count: 1, total: 4 }))).toBe(
      '1 of 4 volumes. A volume published from 1925 counts when one of its documents says, in brackets, what the editors left out: “[Here follows …]” or “[Omitted here is …]”.',
    );
    const cell = drill({ drill: 'era', era: era1955, count: 2, total: 3 });
    expect(drillTitle(cell)).toBe('People tagged, 1955–1968');
    expect(drillCaption(cell)).toBe(
      '1955–1968: 2 of 3 volumes. A volume counts when at least half its documents link a name to its List of Persons.',
    );
    expect(drillCaption(drill({ drill: 'era', era: retrospective, count: 1, total: 1 })).startsWith('Late retrospectives: 1 of 1 volume. ')).toBe(true);
    expect(drillTitle(drill({ drill: 'era', era: retrospective }))).toBe('People tagged, the late retrospectives');
    expect(drillSpoken('with', 288)).toBe('Volumes with it: 288 volumes');
  });

  it('give each volume its count and its marks', () => {
    expect(accessoryText({ kind: 'ratio', count: 279, of: 280 })).toBe('279/280');
    expect(accessoryText({ kind: 'ratio', count: 1_234, of: 2_000 })).toBe('1,234/2,000');
    expect(accessoryText({ kind: 'notes', count: 12 })).toBe('12 notes');
    expect(accessoryText({ kind: 'notes', count: 1 })).toBe('1 note');
    expect(accessoryText({ kind: 'docs', count: 37 })).toBe('37 docs');
    expect(volumeNote({ volumeId: 'frus1977-80v27', unlinked: 'persons' })).toBe(
      'Prints a List of Persons, but none of its documents links a name to it.',
    );
    expect(volumeNote({ volumeId: 'frus1977-80v27', unlinked: 'persons', from: true })).toBe(
      'Prints a List of Persons, but none of its documents links a name to it. You came here from this volume.',
    );
    expect(volumeNote({ volumeId: 'frus1977-80v27', unlinked: 'terms' })).toBe(
      'Prints a List of Abbreviations, but none of its documents links a term to it.',
    );
    // The 1925 gate's line, then that the reader came from the volume, as the app's lines are joined.
    const before1925 = 'Published before the 1925 order, when the editors marked an omission with a row of asterisks, not a bracketed note.';
    expect(volumeNote({ volumeId: 'frus1914', gated: 'before1925' })).toBe(before1925);
    expect(volumeNote({ volumeId: 'frus1914', gated: 'before1925', from: true })).toBe(`${before1925} You came here from this volume.`);
    expect(volumeNote({ volumeId: 'frus1969-76v17' })).toBe('');
  });
});
