// Browse's Editors’ Annotations (FRUS-Explorer#1861, #1862), as the app's `AnnotationsIndexView`,
// `AnnotationCategoryView` and the lists they open show it: every layer in the three groups a volume's
// page uses, each with how many volumes carry it and its eras as the app's regular-width matrix draws
// them, a cell opening its era's volumes that carry the layer; a layer's page, with what the editors did,
// when it became standard, its eras, what the app does with it and its lists; and a list, its volumes
// with each one's count and its marks, the volume whose page opened the layer's first. The app's links
// to People and Archives are not drawn: this server has neither screen yet.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type CSSProperties, useId } from 'react';
import {
  type AnnotationBand,
  type AnnotationDrill,
  type AnnotationEraName,
  type AnnotationLayer,
  type AnnotationsAxis,
  annotationDrillQuery,
  annotationEraQuery,
  annotationLayerQuery,
  annotationsAxisQuery,
  isAnnotationLayer,
} from '../api/annotations';
import { ApiError, errorMessage } from '../api/client';
import { volumesQuery } from '../api/endpoints';
import type { Volume } from '../api/types';
import { copy } from '../copy';
import { Badge } from '../shell/Badge';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import {
  accessoryText,
  appUse,
  cellFill,
  drillCaption,
  drillRowTitle,
  drillSpoken,
  drillTitle,
  indexCaption,
  layerLabel,
  shortEraName,
  spokenBand,
  spokenCell,
  spokenRow,
  standardLine,
  volumeNote,
  volumesLine,
} from './annotationRules';
import { Breadcrumb } from './Breadcrumb';
import { BrowseAxes } from './BrowseAxes';

const words = copy.annotations;

export interface AnnotationSearch {
  /** The volume whose page opened the layer's, which its lists mark and put first. */
  from?: string;
}

/** Every field is returned, undefined when dropped, so the router's raw value cannot stand in for it. */
export function validateAnnotationSearch(raw: Record<string, unknown>): AnnotationSearch {
  return { from: typeof raw.from === 'string' && raw.from !== '' ? raw.from : undefined };
}

/** What a page says when the server could not answer: the app's words for a file it cannot read, else the problem. */
function AnnotationsProblem({ error }: { error: unknown }) {
  if (error instanceof ApiError && error.code === 'ANNOTATIONS_UNAVAILABLE') {
    return (
      <div className="empty">
        <h2>{words.unavailableTitle}</h2>
        <p>{words.unavailableDetail}</p>
        <p className="note">{error.message}</p>
      </div>
    );
  }
  return (
    <p className="error" role="alert">
      {errorMessage(error)}
    </p>
  );
}

/** A cell's fill, as the app's strip shades it, set where the stylesheet reads it. */
function fillStyle(band: AnnotationBand): CSSProperties | undefined {
  const fill = cellFill(band);
  return fill ? ({ '--fill': fill } as CSSProperties) : undefined;
}

// ─── The axis ───────────────────────────────────────────────────────────────

export function AnnotationsAxisScreen() {
  const axis = useQuery(annotationsAxisQuery);
  useDocumentTitle(words.title);
  useHeadingReady(true);
  return (
    <section className="screen browse annotations">
      <h1 tabIndex={-1}>{words.title}</h1>
      <BrowseAxes current="annotations" />
      {axis.isError ? (
        <AnnotationsProblem error={axis.error} />
      ) : !axis.data ? (
        <p role="status">{copy.browse.loading}</p>
      ) : (
        <>
          <p className="note">{indexCaption(axis.data.total)}</p>
          {axis.data.groups.map((group) => (
            <AnnotationsMatrix key={group.family} group={group} eras={axis.data.eras} />
          ))}
        </>
      )}
    </section>
  );
}

/**
 * A group of the axis as the app's regular-width matrix draws it: the eras' first years over the cells'
 * columns, and each layer's row its name, which opens its page, beside a cell per era, which opens that
 * era's volumes that carry the layer. A cell no volume of its era fills is drawn, read and disabled.
 */
function AnnotationsMatrix({ group, eras }: { group: AnnotationsAxis['groups'][number]; eras: AnnotationEraName[] }) {
  const headingId = useId();
  const named = new Map(eras.map((era) => [era.id, era]));
  return (
    <section className="annotations-group" aria-labelledby={headingId}>
      <h2 id={headingId}>{words.families[group.family]}</h2>
      <div className="annotations-matrix-scroll">
        <table className="annotations-matrix" aria-labelledby={headingId}>
          <thead>
            <tr>
              <td />
              {eras.map((era) => (
                <th key={era.id} scope="col" className={era.firstYear === undefined ? 'retrospective' : undefined}>
                  {shortEraName(era)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {group.layers.map((reach) => (
              <tr key={reach.layer}>
                <th scope="row">
                  <Link to="/browse/annotations/$layer" params={{ layer: reach.layer }} aria-label={spokenRow(reach)} title={words.rowHelp}>
                    <span className="annotation-label">{layerLabel(reach.layer)}</span>
                    <span className="annotation-detail">{volumesLine(reach.carrying, reach.total)}</span>
                  </Link>
                </th>
                {reach.bands.map((band) => {
                  const era = named.get(band.era) ?? { id: band.era };
                  const spoken = spokenCell(reach.layer, era, band);
                  return (
                    <td key={band.era} className={era.firstYear === undefined ? 'retrospective' : undefined}>
                      {band.carrying === 0 ? (
                        <a className="era-cell" role="link" aria-disabled="true" aria-label={spoken} title={spoken} />
                      ) : (
                        <Link
                          className="era-cell"
                          to="/browse/annotations/$layer/era/$era"
                          params={{ layer: reach.layer, era: band.era }}
                          aria-label={spoken}
                          title={spoken}
                          style={fillStyle(band)}
                        />
                      )}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

// ─── A layer's page ─────────────────────────────────────────────────────────

const layerRoute = getRouteApi('/browse/annotations/$layer');

export function AnnotationLayerScreen() {
  const { layer } = layerRoute.useParams();
  const { from } = layerRoute.useSearch();
  const page = useQuery(annotationLayerQuery(layer));
  const known = isAnnotationLayer(layer);
  const title = known ? layerLabel(layer) : layer;
  useDocumentTitle(title);
  useHeadingReady(true);
  const data = page.data;
  return (
    <section className="screen browse annotation-layer">
      <Breadcrumb crumbs={[{ label: words.title, axis: 'annotations' }]} current={title} />
      <h1 tabIndex={-1}>{title}</h1>
      {page.isError ? (
        <AnnotationsProblem error={page.error} />
      ) : !data || !known ? (
        <p role="status">{copy.browse.loading}</p>
      ) : (
        <>
          <div className="annotation-reach">
            <p className="reach">{volumesLine(data.reach.carrying, data.reach.total)}</p>
            <p className="note">{words.rules[layer]}</p>
          </div>
          <h2>{words.practiceHeader}</h2>
          <p>{words.practices[layer]}</p>
          <h2>{words.erasHeader}</h2>
          {standardLine(data.reach) && <p>{standardLine(data.reach)}</p>}
          <EraStrip bands={data.reach.bands} eras={data.eras} />
          <h2>{words.appHeader}</h2>
          <p>{appUse(layer)}</p>
          <h2>{words.volumesHeader}</h2>
          <ul className="annotation-drills">
            {data.drills.map((drill) => (
              <li key={drill.id}>
                <Link
                  to="/browse/annotations/$layer/$drill"
                  params={{ layer, drill: drill.id }}
                  search={{ from }}
                  aria-label={drillSpoken(drill.id, drill.count)}
                >
                  <span className="annotation-label">{drillRowTitle(drill.id)}</span>
                  <span className="count">{drill.count.toLocaleString('en-US')}</span>
                </Link>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
}

/** A layer's eras at full size, earliest first and the late retrospectives last, each naming its era and reading its count. */
function EraStrip({ bands, eras }: { bands: AnnotationBand[]; eras: AnnotationEraName[] }) {
  const named = new Map(eras.map((era) => [era.id, era]));
  return (
    <ul className="era-strip">
      {bands.map((band) => {
        const era = named.get(band.era) ?? { id: band.era };
        return (
          <li key={band.era} className={era.firstYear === undefined ? 'retrospective' : undefined}>
            <span className="era-cell" style={fillStyle(band)} aria-hidden="true" />
            <span className="era-name" aria-hidden="true">
              {shortEraName(era)}
            </span>
            <span className="visually-hidden">{spokenBand(era, band)}</span>
          </li>
        );
      })}
    </ul>
  );
}

// ─── A list ─────────────────────────────────────────────────────────────────

const drillRoute = getRouteApi('/browse/annotations/$layer/$drill');

export function AnnotationDrillScreen() {
  const { layer, drill } = drillRoute.useParams();
  const { from } = drillRoute.useSearch();
  const list = useQuery(annotationDrillQuery(layer, drill, from));
  return <AnnotationList layer={layer} from={from} list={list.data} error={list.isError ? list.error : undefined} />;
}

const eraRoute = getRouteApi('/browse/annotations/$layer/era/$era');

export function AnnotationEraScreen() {
  const { layer, era } = eraRoute.useParams();
  const list = useQuery(annotationEraQuery(layer, era));
  return <AnnotationList layer={layer} list={list.data} error={list.isError ? list.error : undefined} />;
}

/**
 * A list's volumes, as the app's `VolumeListView` shows a spec: the caption above the rows, and each
 * volume the catalogue lists by its title, with its count and, in amber, its marks. A volume the
 * catalogue does not list is left out, never invented.
 */
function AnnotationList({ layer, from, list, error }: { layer: string; from?: string; list?: AnnotationDrill; error?: unknown }) {
  const volumes = useQuery(volumesQuery);
  const known = isAnnotationLayer(layer);
  const title = list ? drillTitle(list) : known ? layerLabel(layer) : layer;
  useDocumentTitle(title);
  useHeadingReady(list !== undefined || error !== undefined);
  const catalogue = new Map((volumes.data?.items ?? []).map((volume) => [volume.volumeId, volume]));
  const crumbs = [
    { label: words.title, axis: 'annotations' as const },
    ...(known ? [{ label: layerLabel(layer as AnnotationLayer), axis: 'annotations' as const, layer, from }] : []),
  ];
  return (
    <section className="screen browse annotation-list">
      <Breadcrumb crumbs={crumbs} current={title} />
      <h1 tabIndex={-1} data-loading={!list && !error ? 'true' : undefined}>
        {title}
      </h1>
      {error !== undefined ? (
        <AnnotationsProblem error={error} />
      ) : volumes.isError ? (
        <AnnotationsProblem error={volumes.error} />
      ) : !list || !volumes.data ? (
        <p role="status">{copy.browse.loading}</p>
      ) : (
        <>
          <p className="note">{drillCaption(list)}</p>
          <ul className="volume-list" aria-label={title}>
            {list.volumes.map((entry) => {
              const volume: Volume | undefined = catalogue.get(entry.volumeId);
              if (!volume) return null;
              const note = volumeNote(entry);
              return (
                <li key={entry.volumeId} className="volume-row">
                  <Link to="/browse/$volumeId" params={{ volumeId: entry.volumeId }}>
                    {volume.title}
                  </Link>
                  <p className="meta">
                    {entry.volumeId}
                    {entry.accessory && <> · {accessoryText(entry.accessory)}</>}
                    {volume.indexed && <Badge>{copy.browse.indexed}</Badge>}
                    {volume.teiAvailable && <Badge>{copy.browse.teiHere}</Badge>}
                  </p>
                  {note && <p className="annotation-note">{note}</p>}
                </li>
              );
            })}
          </ul>
        </>
      )}
    </section>
  );
}
