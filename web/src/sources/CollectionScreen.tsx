// An archival collection's record (PLAN's S22d and its follow-up), at /archival-collection?id=…: the app's
// `CollectionDetailView`, every section in its order. The record's name, its FRUS-text chip, its repository, record
// group and lot, and up to six of the forms FRUS also cites it by; its NARA Catalog link, where the server's central
// files do not mark its NAID as a mis-resolution; In Your Library, the documents of this server's index that cite
// it, with their Archival Neighbors; Related Collections, each opening its own record, with its shared volumes and
// its overlap's meter; Cited Over Time, its citing volumes by coverage era, drawn as the search timeline draws its
// chart, with the kit's reading beneath and its table; Divided at NARA, the series NARA divided its lot across;
// Pointed At, Not Printed, the volumes whose footnotes point at it; Cited Across the Series, the volumes that cite
// it; and its Sub-Series, each with its neighbours when it names a class. Each capped list shows the kit's
// `CollectionRelations.previewRowCap` rows, which the server sends, until Show all, and the lists shown whole are in
// the address, as the app's Browse keeps them for its host (`CollectionDetailView.Expansions`), so Back from a citing
// volume returns them as the reader left them, while a related record opens with each at its cap. The way back is
// the web's own. From PLAN's S30d In Your Library's unit-grain add, Add the N citing documents to an Archives Visit…, its
// count on the control: every indexed document drawn from the record, fetched to the app's ceiling, opens the plan
// picker with the source alone and the record's name for a plan made from them, on a server that keeps user data.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link, useCanGoBack, useRouter } from '@tanstack/react-router';
import { type ReactNode, useEffect, useId, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { type ArchivalCollection, archivalCollectionQuery, type CoverageEra, type LotClaimant } from '../api/sources';
import { meQuery } from '../api/userData';
import { recordSeeds } from '../api/visits';
import { copy } from '../copy';
import { columnPath, niceStep, useWidth } from '../search/Readings';
import { requestHeadingFocus, useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { PlanPicker, type PlanPickerRequest } from '../visits/PlanPicker';
import { ProvenanceChip } from './Chips';
import { claimantCaption, overlapMeterWidth, overlapPercent, relatedCaption } from './sourcesRules';

const route = getRouteApi('/archival-collection');
const words = copy.archivalCollection;

/** How many aliases the overview shows (`aliasDisplayCap`). */
export const aliasDisplayCap = 6;

/** A capped list the reader has shown whole (`CollectionDetailView.Expansions`). */
export type CollectionList = 'related' | 'volumes' | 'pointers';

export const collectionLists: readonly CollectionList[] = ['related', 'volumes', 'pointers'];

export interface CollectionSearch {
  id: string;
  /** The lists shown whole. */
  all?: CollectionList[];
}

export function CollectionScreen() {
  const { id } = route.useSearch();
  // A record opened from another, a related one's or by the way back, keeps the page's path, which the shell does not
  // count as a new screen. So each record is a page of its own, drawn afresh, nothing of one kept for the next, and its
  // heading takes the focus, once the record has come, as a new screen's does.
  const shownId = useRef(id);
  useEffect(() => {
    if (shownId.current === id) return;
    shownId.current = id;
    requestHeadingFocus();
  }, [id]);
  return <CollectionPage key={id} id={id} />;
}

function CollectionPage({ id }: { id: string }) {
  // An address that names no record asks the server nothing: the record is unavailable.
  const named = id !== '';
  const collection = useQuery({ ...archivalCollectionQuery(id), enabled: named });
  const router = useRouter();
  const canGoBack = useCanGoBack();
  useDocumentTitle(collection.data?.name ?? words.title);
  useHeadingReady(!named || !collection.isPending);
  const code = collection.error instanceof ApiError ? collection.error.code : undefined;
  const missing = !named || code === 'COLLECTION_NOT_FOUND';
  const preparing = code === 'INDEX_NOT_READY';

  return (
    <div className="collection-record">
      {/* The way back, where there is one: the record is opened from several pages. */}
      {canGoBack && (
        <p className="back">
          <button type="button" className="link-button" onClick={() => router.history.back()}>
            <span aria-hidden="true">← </span>
            {words.back}
          </button>
        </p>
      )}
      <h1 tabIndex={-1} data-loading={named && collection.isPending ? 'true' : undefined}>
        {missing ? words.unavailable : words.title}
      </h1>
      {missing && <p>{words.unavailableDetail}</p>}
      {/* The record and its counts come in one answer, so the line for the counts is the page's while it comes. */}
      <p className="note" role="status">
        {preparing ? copy.archivalNeighbors.preparing : named && collection.isFetching ? words.localLoading : ''}
      </p>
      {collection.isError && !missing && !preparing && (
        <p className="error" role="alert">
          {errorMessage(collection.error)}
        </p>
      )}
      {collection.data && <Record collection={collection.data} />}
    </div>
  );
}

function Section({ title, footer, children }: { title: string; footer?: string; children: ReactNode }) {
  const id = useId();
  return (
    <section className="se-section" aria-labelledby={id}>
      <h2 id={id}>{title}</h2>
      <div className="se-body">{children}</div>
      {footer && <p className="se-footer">{footer}</p>}
    </section>
  );
}

/** A capped list's Show all, or Show fewer once it shows all. */
function ShowAll({ shown, label, toggle }: { shown: boolean; label: string; toggle: () => void }) {
  return (
    <button type="button" className="link-button" aria-expanded={shown} onClick={toggle}>
      {shown ? words.showFewer : label}
    </button>
  );
}

export function Record({ collection }: { collection: ArchivalCollection }) {
  const { all } = route.useSearch();
  const navigate = route.useNavigate();
  const shown = (list: CollectionList) => all?.includes(list) ?? false;
  // Shown whole or at the cap in place: the address changes, the page keeps its scroll and its focus.
  const toggle = (list: CollectionList) =>
    void navigate({
      search: (previous: CollectionSearch) => {
        const next = shown(list) ? (previous.all ?? []).filter((each) => each !== list) : [...(previous.all ?? []), list];
        return { ...previous, all: next.length > 0 ? next : undefined };
      },
      replace: true,
      resetScroll: false,
    });
  const cap = collection.previewRowCap;
  const volumes = shown('volumes') ? collection.volumes : collection.volumes.slice(0, cap);
  const rows: [string, string | undefined][] = [
    [words.repository, collection.repository],
    [words.recordGroup, collection.recordGroup && `RG ${collection.recordGroup}`],
    [words.lot, collection.lotFileNorm],
  ];
  return (
    <div className="se-sections">
      <Section title={words.overview}>
        <p className="se-record-title">{collection.name}</p>
        <ProvenanceChip source="frusText" />
        <dl className="se-rows">
          {rows
            .filter((row): row is [string, string] => !!row[1])
            .map(([label, value]) => (
              <div key={label}>
                <dt>{label}</dt>
                <dd>{value}</dd>
              </div>
            ))}
        </dl>
        {collection.aliases.length > 0 && (
          <div className="se-aliases">
            <p className="se-label">{words.aliases}</p>
            <ul>
              {collection.aliases.slice(0, aliasDisplayCap).map((alias) => (
                <li key={alias}>{alias}</li>
              ))}
            </ul>
            {collection.aliases.length > aliasDisplayCap && (
              <p className="se-dates">{words.aliasesMore(collection.aliases.length - aliasDisplayCap)}</p>
            )}
          </div>
        )}
      </Section>
      {collection.catalog && (
        <Section title={words.catalog}>
          <ProvenanceChip source="naraCatalog" />
          <p className="se-text">
            <a className="se-link" href={collection.catalog.url} target="_blank" rel="noopener noreferrer" title={words.catalogHelp}>
              {words.catalogOpen}
            </a>
          </p>
          {collection.catalog.naId && <p className="se-caption">{words.catalogNAID(collection.catalog.naId)}</p>}
        </Section>
      )}
      <Section title={words.local} footer={words.localFooter}>
        {collection.documentCount > 0 ? (
          <>
            <p className="se-text">{words.localCounts(collection.documentCount, collection.volumeCount)}</p>
            <Link className="se-link" to="/archival-neighbors" search={{ collection: collection.id }} title={words.neighboursHint}>
              {words.neighbours}
            </Link>
            <AddCitingToVisit collection={collection} />
          </>
        ) : (
          <p className="se-text">{words.localEmpty}</p>
        )}
      </Section>
      {collection.related && (
        <Section title={words.related} footer={words.relatedFooter}>
          {collection.related.length === 0 ? (
            <p className="se-note">{words.relatedEmpty}</p>
          ) : (
            <>
              <ul className="se-related">
                {(shown('related') ? collection.related : collection.related.slice(0, cap)).map((item) => {
                  const caption = relatedCaption(item);
                  return (
                    <li key={item.id}>
                      <Link to="/archival-collection" search={{ id: item.id }}>
                        <span className="se-related-identity">
                          <span className="se-related-name">{item.name}</span>
                          {caption && <span className="se-dates">{caption}</span>}
                        </span>
                        <span className="se-related-figures">
                          <span className="se-related-shared">{words.relatedShared(item.sharedVolumeCount)}</span>
                          {/* The meter shows the coefficient the list is ranked by; a screen reader hears it said. */}
                          <span className="se-meter" aria-hidden="true">
                            <span style={{ width: `${overlapMeterWidth(item.overlap)}px` }} />
                          </span>
                          <span className="visually-hidden">, {words.relatedOverlap(overlapPercent(item.overlap))}</span>
                        </span>
                      </Link>
                    </li>
                  );
                })}
              </ul>
              {collection.related.length > cap && (
                <ShowAll shown={shown('related')} label={words.relatedShowAll(collection.related.length)} toggle={() => toggle('related')} />
              )}
            </>
          )}
        </Section>
      )}
      {collection.timeline && (
        <Section title={words.timeline}>
          <CitedOverTime name={collection.name} eras={collection.timeline.eras} narrative={collection.timeline.narrative} />
        </Section>
      )}
      {collection.divided && (
        <Section title={words.divided} footer={words.dividedFooter(collection.divided.dividedLots)}>
          <ProvenanceChip source="naraCatalog" />
          <p className="se-text">{words.dividedIntro(collection.divided.claimants.length)}</p>
          {collection.divided.includesRecordsNAID && <p className="se-caption">{words.dividedOneOfThem}</p>}
          <ul className="se-claimants">
            {collection.divided.claimants.map((claimant, index) => (
              <Claimant key={`${claimant.naId}-${index}`} claimant={claimant} />
            ))}
          </ul>
        </Section>
      )}
      {collection.pointers && (
        <Section title={words.unprinted} footer={words.unprintedFooter}>
          <p className="se-text">{words.unprintedCounts(collection.pointers.total, collection.pointers.volumes.length)}</p>
          <ul className="se-volumes se-pointers">
            {(shown('pointers') ? collection.pointers.volumes : collection.pointers.volumes.slice(0, cap)).map((volume) => (
              <li key={volume.volumeId}>
                <span className="se-pointer-volume">
                  <Link to="/browse/$volumeId" params={{ volumeId: volume.volumeId }} title={words.volumeHint}>
                    {volume.title ?? volume.volumeId}
                  </Link>
                  <span className="se-dates">{volume.volumeId}</span>
                </span>
                <span className="se-count">{volume.count.toLocaleString('en-US')}</span>
              </li>
            ))}
          </ul>
          {collection.pointers.volumes.length > cap && (
            <ShowAll
              shown={shown('pointers')}
              label={words.showAllVolumes(collection.pointers.volumes.length)}
              toggle={() => toggle('pointers')}
            />
          )}
        </Section>
      )}
      <Section title={words.volumes(collection.volumes.length)}>
        <ul className="se-volumes">
          {volumes.map((volume) => (
            <li key={volume.volumeId}>
              <Link to="/browse/$volumeId" params={{ volumeId: volume.volumeId }} title={words.volumeHint}>
                {volume.title ?? volume.volumeId}
              </Link>
              <p className="se-dates">{volume.volumeId}</p>
            </li>
          ))}
        </ul>
        {collection.volumes.length > cap && (
          <ShowAll shown={shown('volumes')} label={words.showAllVolumes(collection.volumes.length)} toggle={() => toggle('volumes')} />
        )}
      </Section>
      {collection.children.length > 0 && (
        <Section title={words.children}>
          <ul className="se-children">
            {collection.children.map((child) => (
              <li key={child.name}>
                <p className="se-text">{child.name}</p>
                {child.volumeCount > 1 && <p className="se-dates">{words.childVolumes(child.volumeCount)}</p>}
                {child.decimalClass && (
                  <Link
                    className="se-link"
                    to="/archival-neighbors"
                    search={{ decimalClass: child.decimalClass }}
                    title={words.childNeighboursHelp}
                  >
                    {words.childNeighbours}
                  </Link>
                )}
              </li>
            ))}
          </ul>
        </Section>
      )}
    </div>
  );
}

/**
 * `fetchCitingDocumentsForPlan(expected:)`: every indexed document drawn from the record, then the picker over the whole
 * set, the source alone, its basis saying so where the fetch's ceiling cut it; none fetched, no picker, as the app's.
 */
function AddCitingToVisit({ collection }: { collection: ArchivalCollection }) {
  const me = useQuery(meQuery);
  const [fetching, setFetching] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [request, setRequest] = useState<PlanPickerRequest | null>(null);
  const button = useRef<HTMLButtonElement>(null);
  if (me.data?.userData !== true) return null;
  async function fetchSeeds() {
    if (fetching) return;
    setFetching(true);
    setFailure(null);
    try {
      const seeds = await recordSeeds(collection.id);
      if (seeds.documents.length === 0) return;
      setRequest({
        documents: seeds.documents,
        includeSource: true,
        includeExternalRefs: false,
        basis:
          seeds.totalCount > seeds.documents.length
            ? copy.visits.basisUnitPartial(seeds.documents.length, seeds.totalCount, seeds.name)
            : copy.visits.basisUnit(seeds.name),
        suggestedName: seeds.name,
      });
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setFetching(false);
    }
  }
  return (
    <>
      <button ref={button} type="button" className="link-button se-link" aria-disabled={fetching || undefined} onClick={() => void fetchSeeds()}>
        {words.addToVisit(collection.documentCount)}
      </button>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {request && (
        <PlanPicker
          request={request}
          onClose={() => {
            setRequest(null);
            requestAnimationFrame(() => button.current?.focus());
          }}
        />
      )}
    </>
  );
}

/** A series NARA divided the lot into: its title, NARA's caption and entry numbers, and its catalogue record. */
function Claimant({ claimant }: { claimant: LotClaimant }) {
  const titleId = useId();
  return (
    <li>
      <span className="se-claimant">
        <span id={titleId} className="se-text">
          {claimant.title}
        </span>
        <span className="se-dates">{claimantCaption(claimant)}</span>
        {claimant.entryNumbers && claimant.entryNumbers.length > 0 && (
          <span className="se-dates">{words.dividedEntries(claimant.entryNumbers.join(', '))}</span>
        )}
      </span>
      {/* The app's View, told which series it opens. */}
      {claimant.catalogURL && (
        <a className="se-link" href={claimant.catalogURL} target="_blank" rel="noopener noreferrer" aria-describedby={titleId}>
          {words.dividedView}
        </a>
      )}
    </li>
  );
}

const plotHeight = 120;
const axisBand = 24;
const topPad = 8;
const axisWidth = 32;

/**
 * Cited Over Time's chart, in the search timeline's idiom: a column for each coverage era, in the kit's order, each
 * its era's short label beneath, on a count axis from none. One series, so one colour and no legend; the pointer
 * reads an era's full label and count above the plot, and the table after the figure has every figure, for
 * assistive technology and the keyboard. The kit's reading of the chart is the figure's caption, which names it.
 */
function CitedOverTime({ name, eras, narrative }: { name: string; eras: CoverageEra[]; narrative: string }) {
  const [plot, width] = useWidth(480);
  const [hovered, setHovered] = useState<number | null>(null);
  const plotWidth = Math.max(width - axisWidth - 8, 80);
  const band = plotWidth / Math.max(eras.length, 1);
  const columnWidth = Math.max(1, Math.min(40, band - 2));
  const highest = Math.max(1, ...eras.map((era) => era.volumeCount));
  const yStep = Math.max(1, niceStep(highest, 3));
  const yTop = Math.ceil(highest / yStep) * yStep;
  const y = (count: number) => topPad + plotHeight - (count / yTop) * plotHeight;
  const x = (index: number) => axisWidth + index * band;
  // Every era's label where they fit, else every second or third, as a chart thins its ticks.
  const labelWidth = Math.max(...eras.map((era) => era.shortLabel.length)) * 7 + 8;
  const labelEvery = Math.max(1, Math.ceil(labelWidth / band));
  const shown = hovered === null ? undefined : eras[hovered];
  const title = words.timelineTitle(name);
  return (
    <>
      <figure className="timeline-chart era-chart">
        <p className="chart-readout" aria-hidden="true">
          {shown ? words.timelineReadout(shown.fullLabel, shown.volumeCount) : ' '}
        </p>
        <div ref={plot} className="chart-plot">
          <svg role="img" aria-label={title} width={width} height={topPad + plotHeight + axisBand} onPointerLeave={() => setHovered(null)}>
            {Array.from({ length: yTop / yStep + 1 }, (_, index) => index * yStep).map((tick) => (
              <g key={`y${tick}`}>
                <line className="chart-grid" x1={axisWidth} x2={axisWidth + plotWidth} y1={y(tick)} y2={y(tick)} />
                <text className="chart-tick" x={axisWidth - 6} y={y(tick)} dy="0.32em" textAnchor="end">
                  {tick.toLocaleString('en-US')}
                </text>
              </g>
            ))}
            {eras.map((era, index) =>
              index % labelEvery === 0 ? (
                <text key={`x${era.fullLabel}`} className="chart-tick" x={x(index) + band / 2} y={topPad + plotHeight + 16} textAnchor="middle">
                  {era.shortLabel}
                </text>
              ) : null,
            )}
            {eras.map((era, index) => {
              const top = y(era.volumeCount);
              return (
                <g key={era.fullLabel} onPointerEnter={() => setHovered(index)}>
                  {/* The hit area is the era's whole band, wider than its column. */}
                  <rect className="chart-hit" x={x(index)} y={topPad} width={band} height={plotHeight} />
                  {era.volumeCount > 0 && (
                    <path
                      className={index === hovered ? 'chart-column hovered' : 'chart-column'}
                      d={columnPath(x(index) + (band - columnWidth) / 2, top, columnWidth, topPad + plotHeight - top)}
                    />
                  )}
                </g>
              );
            })}
            <line className="chart-axis" x1={axisWidth} x2={axisWidth + plotWidth} y1={topPad + plotHeight} y2={topPad + plotHeight} />
          </svg>
        </div>
        <figcaption className="se-caption">{words.timelineCaption(narrative)}</figcaption>
      </figure>
      <details className="chart-table">
        <summary>{words.viewTable}</summary>
        <table>
          <caption className="visually-hidden">{title}</caption>
          <thead>
            <tr>
              <th scope="col">{words.timelineEra}</th>
              <th scope="col">{words.timelineVolumes}</th>
            </tr>
          </thead>
          <tbody>
            {eras.map((era) => (
              <tr key={era.fullLabel}>
                <th scope="row">{era.fullLabel}</th>
                {/* The count as the app's table writes it, `"\(volumeCount)"`. */}
                <td>{era.volumeCount}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </details>
    </>
  );
}
