// The editors' annotations (FRUS-Explorer#1859 to #1862): a volume page's Editors’ Annotations and
// Browse's axis of that name, as the server answers them from the bundled volume-annotations-index.json
// (Sources/FRUSLightAPI/Annotations.swift). The server gives the counts and the parts; the words are
// copy.ts's, put together by browse/annotationRules.ts. The file is the server's build's, so an answer
// never goes stale.
import { queryOptions } from '@tanstack/react-query';
import { getJSON } from './client';
import { retryServerFaults } from './endpoints';
import { formEncode } from './form';

/** The fifteen layers, in the order a volume's page and the axis show them (`AnnotationLayer`). */
export const annotationLayers = [
  'people',
  'abbreviations',
  'correspondents',
  'subjects',
  'participants',
  'sourceNotes',
  'classification',
  'excisions',
  'despatch',
  'numbered',
  'crossReferences',
  'editorialNotes',
  'footnotes',
  'marginalNotes',
  'printedAids',
] as const;

export type AnnotationLayer = (typeof annotationLayers)[number];

/** The kit's `AnnotationCategory.Family`: the three groups a volume's page shows the layers in. */
export type AnnotationFamily = 'named' | 'provenance' | 'connects';

/** Whether `id` names a layer. */
export function isAnnotationLayer(id: string): id is AnnotationLayer {
  return (annotationLayers as readonly string[]).includes(id);
}

/** An era, by the kit's raw value, with its first year and its last where it has them. */
export interface AnnotationEraName {
  /** "1955-1968", "1981-" or "retrospective". */
  id: string;
  /** Absent for the late retrospectives. */
  firstYear?: number;
  /** Absent for the band with an open end, and for the late retrospectives. */
  lastYear?: number;
}

/** A part of a volume page's row, which the browser app words. */
export type AnnotationPart =
  | { kind: 'ofDocuments'; count: number; of: number }
  | {
      kind: 'personsListed' | 'termsListed' | 'documents' | 'excisions' | 'editorialNotes' | 'xrefDocuments' | 'xrefVolumes' | 'xrefPages';
      count: number;
    }
  | { kind: 'sourceForm'; form: 'citations' | 'fileNumbers' | 'both' }
  | { kind: 'aid'; aid: string };

/** A standard layer a volume's page lists as absent: a layer, or one of the two narrower than one. */
export type AbsentLayer =
  | 'people'
  | 'abbreviations'
  | 'sourceNotes'
  | 'classification'
  | 'numbered'
  | 'referencesToDocuments'
  | 'editorialNotes'
  | 'noteOnSources';

/** A row of a volume's section: a layer the volume carries, and its line's parts. */
export interface AnnotationRow {
  layer: AnnotationLayer;
  parts: AnnotationPart[];
}

/** A standard layer the volume lacks, the layer whose page its row opens, and the era from which it was standard. */
export interface AbsentAnnotation {
  id: AbsentLayer;
  layer: AnnotationLayer;
  onset?: AnnotationEraName;
}

/** GET /api/v1/volumes/{v}/annotations: a volume page's Editors’ Annotations. */
export interface VolumeAnnotationsSection {
  volumeId: string;
  groups: { family: AnnotationFamily; rows: AnnotationRow[] }[];
  absent: AbsentAnnotation[];
}

/** One era's share of a layer. */
export interface AnnotationBand {
  /** The era's id. */
  era: string;
  carrying: number;
  total: number;
}

/** A layer's reach across the file's volumes. */
export interface AnnotationReach {
  layer: AnnotationLayer;
  carrying: number;
  total: number;
  /** In strip order: earliest first, the late retrospectives last. */
  bands: AnnotationBand[];
  /** The first era from which the series made it standard. */
  onset?: AnnotationEraName;
  /** For a practice no era made standard, the era where it is most common. */
  peak?: AnnotationEraName;
}

/** GET /api/v1/annotations: the axis. */
export interface AnnotationsAxis {
  total: number;
  /** In strip order, the matrix's columns. */
  eras: AnnotationEraName[];
  groups: { family: AnnotationFamily; layers: AnnotationReach[] }[];
}

/** GET /api/v1/annotations/{layer}: a layer's page. */
export interface AnnotationLayerPage {
  reach: AnnotationReach;
  eras: AnnotationEraName[];
  /** `with`, `without`, `citation`, `fileNumber`, or an aid's id, with how many volumes each lists. */
  drills: { id: string; count: number }[];
}

/** A volume's count in a list: its documents of all, its editorial notes, or its documents. */
export type AnnotationAccessory = { kind: 'ratio'; count: number; of: number } | { kind: 'notes' | 'docs'; count: number };

/** One volume of a drill's list. */
export interface AnnotationDrillVolume {
  volumeId: string;
  accessory?: AnnotationAccessory;
  /** The list the volume prints that none of its documents links to. */
  unlinked?: 'persons' | 'terms';
  /** The volume whose page opened the layer's. */
  from?: boolean;
}

/** A drill's or a cell's list of volumes. */
export interface AnnotationDrill {
  layer: AnnotationLayer;
  /** The drill's id, or `era` for a cell of the matrix. */
  drill: string;
  era?: AnnotationEraName;
  /** The rule its caption states. */
  rule: 'layer' | 'sourceForm' | 'aid';
  count: number;
  /** The file's volumes, or a cell's era's. */
  total: number;
  volumes: AnnotationDrillVolume[];
}

const segment = encodeURIComponent;

export const annotationsAxisQuery = queryOptions({
  queryKey: ['annotations'],
  queryFn: ({ signal }) => getJSON<AnnotationsAxis>('/api/v1/annotations', undefined, signal),
  staleTime: Infinity,
  retry: retryServerFaults,
});

export function annotationLayerQuery(layer: string) {
  return queryOptions({
    queryKey: ['annotations', layer],
    queryFn: ({ signal }) => getJSON<AnnotationLayerPage>(`/api/v1/annotations/${segment(layer)}`, undefined, signal),
    staleTime: Infinity,
    retry: retryServerFaults,
  });
}

/** A drill of a layer's page, with `from`, the volume whose page opened it, first. */
export function annotationDrillQuery(layer: string, drill: string, from?: string) {
  return queryOptions({
    queryKey: ['annotations', layer, 'drills', drill, from ?? null],
    queryFn: ({ signal }) =>
      getJSON<AnnotationDrill>(`/api/v1/annotations/${segment(layer)}/drills/${segment(drill)}`, from ? formEncode({ from }) : undefined, signal),
    staleTime: Infinity,
    retry: retryServerFaults,
  });
}

/** A cell of the matrix: the era's volumes that carry the layer. */
export function annotationEraQuery(layer: string, era: string) {
  return queryOptions({
    queryKey: ['annotations', layer, 'eras', era],
    queryFn: ({ signal }) => getJSON<AnnotationDrill>(`/api/v1/annotations/${segment(layer)}/eras/${segment(era)}`, undefined, signal),
    staleTime: Infinity,
    retry: retryServerFaults,
  });
}

export function volumeAnnotationsQuery(volumeId: string) {
  return queryOptions({
    queryKey: ['annotations', 'volume', volumeId],
    queryFn: ({ signal }) => getJSON<VolumeAnnotationsSection>(`/api/v1/volumes/${segment(volumeId)}/annotations`, undefined, signal),
    staleTime: Infinity,
    retry: retryServerFaults,
  });
}
