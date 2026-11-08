// The editors' annotations' words (FRUS-Explorer#1859 to #1862), put together as the app's view code
// puts them: a volume page's row from the parts the server gives (`VolumeAnnotationsPresentation`),
// what a screen reader reads for it, an absent layer's note; an era's names, when a layer became
// standard, the axis's rows and cells (`AnnotationsAxis`); and a list's title, caption, counts and marks.
// A count goes through `counted`, the one form at exactly one and the number grouped, as the app's
// `CountCopy.phrase` does, and a year never does. The parts, eras and reaches are the server's
// (Sources/FRUSLightAPI/Annotations.swift), the words copy.ts's; AnnotationsParityTests holds these
// lines to the app's.
import type {
  AbsentAnnotation,
  AbsentLayer,
  AnnotationAccessory,
  AnnotationBand,
  AnnotationDrill,
  AnnotationDrillVolume,
  AnnotationEraName,
  AnnotationLayer,
  AnnotationPart,
  AnnotationReach,
} from '../api/annotations';
import { copy } from '../copy';

const words = copy.annotations;

type Form = (count: string) => string;
type FormOf = (total: string, count: string) => string;

/** "1 document" / "1,204 documents": `one` at exactly one, `many` otherwise, the number grouped. */
export function counted(count: number, one: Form, many: Form): string {
  const grouped = count.toLocaleString('en-US');
  return count === 1 ? one(grouped) : many(grouped);
}

/** "279 of 280 documents": the form chosen by the total, the count the second argument, as the app's `then:`. */
export function countedOf(count: number, total: number, one: FormOf, many: FormOf): string {
  const grouped = total.toLocaleString('en-US');
  return total === 1 ? one(grouped, count.toLocaleString('en-US')) : many(grouped, count.toLocaleString('en-US'));
}

/** A layer's name. */
export function layerLabel(layer: AnnotationLayer): string {
  return words.layers[layer];
}

// ─── A volume's page ────────────────────────────────────────────────────────

/** One part of a row's line, in the app's words. */
export function partText(part: AnnotationPart): string {
  switch (part.kind) {
    case 'ofDocuments':
      return countedOf(part.count, part.of, words.ofDocumentsOne, words.ofDocumentsMany);
    case 'personsListed':
      return counted(part.count, words.personsListedOne, words.personsListedMany);
    case 'termsListed':
      return counted(part.count, words.termsListedOne, words.termsListedMany);
    case 'documents':
      return counted(part.count, words.documentsOne, words.documentsMany);
    case 'sourceForm':
      return words.sourceForms[part.form];
    case 'excisions':
      return counted(part.count, words.excisionsOne, words.excisionsMany);
    case 'editorialNotes':
      return counted(part.count, words.editorialNotesOne, words.editorialNotesMany);
    case 'xrefDocuments':
      return counted(part.count, words.xrefDocumentsOne, words.xrefDocumentsMany);
    case 'xrefVolumes':
      return counted(part.count, words.xrefVolumesOne, words.xrefVolumesMany);
    case 'xrefPages':
      return counted(part.count, words.xrefPagesOne, words.xrefPagesMany);
    case 'aid':
      return words.aids[part.aid] ?? part.aid;
  }
}

/** A row's line: its parts joined by the app's separator. */
export function rowDetail(parts: AnnotationPart[]): string {
  return parts.map(partText).join(words.separator);
}

/** What a screen reader reads for a row: "People tagged: 279 of 280 documents; 325 people listed." */
export function rowSpoken(layer: AnnotationLayer, parts: AnnotationPart[]): string {
  return words.rowSpoken(layerLabel(layer), rowDetail(parts).replaceAll(words.separator, '; '));
}

/** An absent row's name: its layer's, or one of the two narrower than a layer. */
export function absentLabel(id: AbsentLayer): string {
  if (id === 'referencesToDocuments') return words.referencesToDocuments;
  if (id === 'noteOnSources') return words.noteOnSources;
  return words.layers[id];
}

/** "Standard in the volumes covering 1955 on.", or empty for no onset. The year is not a count. */
export function standardFrom(era: AnnotationEraName | undefined): string {
  if (era?.firstYear === undefined) return '';
  return words.standardFrom(String(era.firstYear));
}

/** From which era the series made an absent layer standard, with, for people, where to look instead. */
export function absentNote(row: AbsentAnnotation): string {
  let note = standardFrom(row.onset);
  if (row.id === 'people') note = note === '' ? words.peopleHint : `${note} ${words.peopleHint}`;
  return note;
}

/** What a screen reader reads for an absent row: "Not in this volume: People tagged. Standard in …" */
export function absentSpoken(row: AbsentAnnotation): string {
  const lead = words.absentSpoken(absentLabel(row.id));
  const note = absentNote(row);
  return note === '' ? lead : `${lead} ${note}`;
}

/** The disclosure's title, with how many standard layers the volume lacks. */
export function absentTitle(count: number): string {
  return words.absentTitle(count.toLocaleString('en-US'));
}

// ─── The axis ───────────────────────────────────────────────────────────────

/** "288 of 553 volumes". */
export function volumesLine(count: number, total: number): string {
  return countedOf(count, total, words.ofVolumesOne, words.ofVolumesMany);
}

/** An era's name in a sentence: "1955–1968", "1981 on", or the late retrospectives'. */
export function eraName(era: AnnotationEraName): string {
  if (era.firstYear === undefined) return words.eraRetrospective;
  if (era.lastYear !== undefined) return words.eraSpan(String(era.firstYear), String(era.lastYear));
  return words.eraFrom(String(era.firstYear));
}

/** An era's label over its column or under its cell: its first year, or the retrospectives' short name. */
export function shortEraName(era: AnnotationEraName): string {
  return era.firstYear === undefined ? words.eraRetrospectiveShort : String(era.firstYear);
}

/** When the layer became standard, or, for a practice no era made standard, where it is most common. */
export function standardLine(reach: AnnotationReach): string {
  if (reach.onset) return standardFrom(reach.onset);
  if (!reach.peak) return '';
  if (reach.peak.firstYear === undefined) return words.standardNoneRetrospective;
  return words.standardNone(eraName(reach.peak));
}

/** What a screen reader reads for a layer's row: "People tagged: 288 of 553 volumes. Standard in …" */
export function spokenRow(reach: AnnotationReach): string {
  const lead = words.layerSpoken(layerLabel(reach.layer), volumesLine(reach.carrying, reach.total));
  const standard = standardLine(reach);
  return standard === '' ? lead : `${lead} ${standard}`;
}

/** What a screen reader reads for one era of a strip: "1955–1968: 114 of 114 volumes". */
export function spokenBand(era: AnnotationEraName, band: Pick<AnnotationBand, 'carrying' | 'total'>): string {
  const name = era.firstYear === undefined ? words.eraRetrospectiveTitle : eraName(era);
  return words.bandSpoken(name, volumesLine(band.carrying, band.total));
}

/** What a cell of the matrix reads, and its help: "People tagged, 1955–1968: 114 of 114 volumes". */
export function spokenCell(layer: AnnotationLayer, era: AnnotationEraName, band: AnnotationBand): string {
  return words.cellSpoken(layerLabel(layer), spokenBand(era, band));
}

/** The axis's caption: what a row counts, and what a strip shades. */
export function indexCaption(total: number): string {
  return words.indexCaption(counted(total, words.volumesOne, words.volumesMany));
}

/** A strip cell's fill: the accent, as strong as the share of the era's volumes that carry the layer, clear at none. */
export function cellFill(band: AnnotationBand): string | undefined {
  if (band.carrying === 0 || band.total === 0) return undefined;
  const share = band.carrying / band.total;
  return `${Math.round((0.15 + 0.85 * share) * 100)}%`;
}

/** What the app does with a layer, or that nothing reads it yet. */
export function appUse(layer: AnnotationLayer): string {
  const sentences: Record<string, string> = words.appUse;
  return sentences[layer] ?? words.appUse.none;
}

// ─── A layer's lists ────────────────────────────────────────────────────────

/** A list's row on its layer's page. */
export function drillRowTitle(drill: string): string {
  if (drill === 'with') return words.drillWith;
  if (drill === 'without') return words.drillWithout;
  if (drill === 'citation') return words.drillCitation;
  if (drill === 'fileNumber') return words.drillFileNumber;
  return words.aids[drill] ?? drill;
}

/** What a screen reader reads for a list's row: "Volumes with it: 288 volumes". */
export function drillSpoken(drill: string, count: number): string {
  return words.drillSpoken(drillRowTitle(drill), counted(count, words.volumesOne, words.volumesMany));
}

/** A list's title: "With: People tagged", a form's or an aid's name, or a cell's "People tagged, 1955–1968". */
export function drillTitle(drill: Pick<AnnotationDrill, 'layer' | 'drill' | 'era'>): string {
  if (drill.drill === 'with') return words.drillWithTitle(layerLabel(drill.layer));
  if (drill.drill === 'without') return words.drillWithoutTitle(layerLabel(drill.layer));
  if (drill.drill === 'era' && drill.era) return words.eraDrillTitle(layerLabel(drill.layer), eraName(drill.era));
  return drillRowTitle(drill.drill);
}

/** A list's caption: "288 of 553 volumes." or a cell's "1955–1968: 114 of 114 volumes.", then the rule it states. */
export function drillCaption(drill: AnnotationDrill): string {
  const rule = drill.rule === 'layer' ? words.rules[drill.layer] : words.rules[drill.rule];
  const count = drill.era ? spokenBand(drill.era, { carrying: drill.count, total: drill.total }) : volumesLine(drill.count, drill.total);
  return words.drillCaption(count, rule);
}

/** A volume's count in a list: "279/280", "12 notes" or "37 docs". */
export function accessoryText(accessory: AnnotationAccessory): string {
  if (accessory.kind === 'ratio') return `${accessory.count.toLocaleString('en-US')}/${accessory.of.toLocaleString('en-US')}`;
  if (accessory.kind === 'notes') return counted(accessory.count, words.notesOne, words.notesMany);
  return counted(accessory.count, words.docsOne, words.docsMany);
}

/** A volume's amber line: the list it prints that nothing links to, then that the reader came from it. */
export function volumeNote(volume: AnnotationDrillVolume): string {
  const lines: string[] = [];
  if (volume.unlinked === 'persons') lines.push(words.notePersonsUnlinked);
  if (volume.unlinked === 'terms') lines.push(words.noteTermsUnlinked);
  if (volume.from) lines.push(words.noteFrom);
  return lines.join(' ');
}
