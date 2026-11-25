// Browse's Clusters axis (PLAN's S28d), as the Mac's Browse lists and opens it (`ClustersIndexView`,
// `ClusterDocumentsView`) over the kit's `ClustersAxis` (S28a), which the server runs over the semantic map's reading
// (S28c): the map's regions, largest first, each its four terms, its count and its eras' histogram, under the kit's
// caption; and a region opened, its count in the series, its eras, what this server holds of its members and the app's
// sentence of what a cluster is, See on the semantic map and Save as Working Corpus, and its documents, the first 500 in
// volume order, a section a volume, 500 more at each "Show more", those of a volume the server holds opening in the
// reader and the rest named, never a dead end. A region's id means something only in its layout, so its address carries
// the layout's identity, which the map's link carries too, and a link from another layout is refused.
import { useInfiniteQuery, useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { memo, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import {
  clusterDocumentsQuery,
  clusterSections,
  clustersIndexQuery,
  saveClusterCorpus,
  type ClusterDocuments,
  type ClusterEraBar,
} from '../api/clusters';
import type { WorkingCorpusDetail } from '../api/searchSets';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { BrowseAxes } from './BrowseAxes';
import { Breadcrumb } from './Breadcrumb';

/** A cluster's address: the layout its id was minted in, which the server holds it to. */
export interface ClusterSearch {
  layout?: string;
}

export function validateClusterSearch(raw: Record<string, unknown>): ClusterSearch {
  const layout = Array.isArray(raw.layout) ? raw.layout[0] : raw.layout;
  return typeof layout === 'string' && layout !== '' ? { layout } : {};
}

/** The tallest bar and the shortest, in pixels, as the app's histogram draws them (`ClusterEraHistogramView`). */
const tallest = 18;
const shortest = 2;

/** A bar's height: its count against the row's largest, never under the shortest, an empty era the shortest. */
export function barHeight(count: number, peak: number): number {
  if (peak <= 0 || count <= 0) return shortest;
  return Math.max(shortest, (tallest * count) / peak);
}

/** The row's eras' histogram, a bar an era and the two largest accented: decorative, the row's name says its count. */
function EraHistogram({ bars }: { bars: readonly ClusterEraBar[] }) {
  const peak = Math.max(0, ...bars.map((bar) => bar.count));
  return (
    <span className="cluster-histogram" aria-hidden="true">
      {bars.map((bar, index) => (
        <span key={bar.era ?? `pooled-${index}`} className={bar.isPeak ? 'cluster-bar peak' : 'cluster-bar'} style={{ height: `${barHeight(bar.count, peak)}px` }} />
      ))}
    </span>
  );
}

/**
 * Why there is no list or no region, as the app's unavailable view says it: the server's sentence for the map's files,
 * the app's for a region it cannot load, and the web's for a link from another layout. A region's page says
 * Clusters Unavailable in its heading; the index says it here.
 */
function ClustersProblem({ error, drill = false }: { error: unknown; drill?: boolean }) {
  const code = error instanceof ApiError ? error.code : undefined;
  return (
    <div className="empty" role="alert">
      {!drill && <h2>{copy.clusters.unavailableTitle}</h2>}
      {code === 'LAYOUT_CHANGED' ? (
        <p>
          {copy.clusters.otherLayout} <Link to="/browse/clusters">{copy.clusters.title}</Link>
        </p>
      ) : code === 'CLUSTER_NOT_FOUND' || (drill && code !== 'CLUSTERS_UNAVAILABLE') ? (
        <p>{copy.clusters.drillUnavailable}</p>
      ) : (
        <p>{errorMessage(error)}</p>
      )}
    </div>
  );
}

export function ClustersScreen() {
  const index = useQuery(clustersIndexQuery);
  useDocumentTitle(copy.clusters.title);
  useHeadingReady(!index.isPending);
  const data = index.data;
  return (
    <section className="screen browse clusters">
      <h1 tabIndex={-1}>{copy.clusters.title}</h1>
      <BrowseAxes current="clusters" />
      {index.isError ? (
        <ClustersProblem error={index.error} />
      ) : !data ? (
        <p role="status">{copy.clusters.loading}</p>
      ) : (
        <>
          <p className="note">{copy.clusters.caption(data.clusterCount, data.unclusteredCount, data.documentCount)}</p>
          <ul className="volume-list cluster-list" aria-label={copy.clusters.title}>
            {data.clusters.map((cluster) => (
              <li key={cluster.id} className="volume-row cluster-row">
                <Link
                  to="/browse/clusters/$clusterId"
                  params={{ clusterId: String(cluster.id) }}
                  search={{ layout: data.layoutIdentity }}
                  className="cluster-link"
                  title={copy.clusters.rowHelp}
                  aria-label={copy.clusters.rowLabel(cluster.label, cluster.documentCount)}
                >
                  <span className="cluster-text">
                    <span className="cluster-label">{cluster.label}</span>
                    <span className="meta">{copy.clusters.rowCount(cluster.documentCount)}</span>
                  </span>
                  <EraHistogram bars={cluster.eras} />
                </Link>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
}

const clusterRoute = getRouteApi('/browse/clusters/$clusterId');

export function ClusterScreen() {
  const { clusterId } = clusterRoute.useParams();
  const { layout } = clusterRoute.useSearch();
  // A region of its own: what one region showed, its pages and its save, is never another's.
  return <ClusterDrill key={`${clusterId}|${layout ?? ''}`} clusterId={clusterId} layout={layout} />;
}

/** The id of a volume's section heading. */
function sectionHeading(volumeId: string): string {
  return `cluster-volume-${volumeId}`;
}

/** The id of a listed document's row, its link where the server holds its volume, which the keyboard can be sent to. */
function documentRow(volumeId: string, documentId: string): string {
  return `cluster-document-${volumeId}-${documentId}`;
}

/**
 * The row of the first document the last page listed, in the order the list draws them: in the volume a page boundary
 * split, the first of its documents the pages before had not listed, or else the first of the first volume it added.
 */
export function firstNewlyListed(pages: readonly ClusterDocuments[]): string | undefined {
  const last = pages.at(-1);
  if (!last) return undefined;
  const before = new Map(clusterSections(pages.slice(0, -1)).map((section) => [section.volumeId, new Set(section.documents.map((each) => each.documentId))]));
  for (const section of last.sections) {
    const listed = before.get(section.volumeId);
    const added = section.documents.find((each) => !listed?.has(each.documentId));
    if (added) return documentRow(section.volumeId, added.documentId);
  }
  return undefined;
}

function ClusterDrill({ clusterId, layout }: { clusterId: string; layout: string | undefined }) {
  const client = useQueryClient();
  const me = useQuery(meQuery);
  const pages = useInfiniteQuery(clusterDocumentsQuery(clusterId, layout));
  const loaded = pages.data?.pages;
  const first = loaded?.[0];
  const last = loaded?.at(-1);
  // A first page that fails, or any page of another layout than the address names or the first was listed in, which
  // would list another region's documents under this one's name, is no list; a later page that fails otherwise keeps the
  // pages before it, and says so by its button.
  const layoutChanged = pages.error instanceof ApiError && pages.error.code === 'LAYOUT_CHANGED';
  const failed = (pages.isError && loaded === undefined) || layoutChanged;
  const title = failed ? copy.clusters.unavailableTitle : (first?.label ?? copy.clusters.title);
  useDocumentTitle(title);
  useHeadingReady(!pages.isPending);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState<{ line: string; warns: boolean } | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const more = useRef<HTMLButtonElement>(null);
  // Whether "Show more" had the keyboard when it was pressed, so that the last page, which takes the button away, can
  // send the keyboard to the first document it listed rather than leave it on the page.
  const keepFocus = useRef(false);

  // Before the browser paints: the button is gone, so the keyboard is on the page, unless the reader moved it meanwhile.
  useLayoutEffect(() => {
    if (!keepFocus.current || pages.isFetchingNextPage || !loaded) return;
    keepFocus.current = false;
    const final = loaded.at(-1);
    if (!final || final.after === 0 || final.shown < final.total) return;
    const active = document.activeElement;
    if (active !== null && active !== document.body) return;
    const row = firstNewlyListed(loaded);
    if (row !== undefined) document.getElementById(row)?.focus();
  }, [loaded, pages.isFetchingNextPage]);

  // Pages listed against different states of the served index, as when it indexes a volume between two of them, are
  // listed again from the first, as the app's drill reloads its rows when the count of indexed volumes changes.
  const { refetch, isFetching, isError } = pages;
  const mixed = loaded !== undefined && loaded.some((page) => page.indexedVolumes !== loaded[0]?.indexedVolumes);
  useEffect(() => {
    if (mixed && !isFetching && !isError) void refetch();
  }, [mixed, isFetching, isError, refetch]);

  function showMore() {
    if (!pages.hasNextPage || pages.isFetchingNextPage) return;
    keepFocus.current = more.current !== null && more.current === document.activeElement;
    void pages.fetchNextPage();
  }

  async function save(region: ClusterDocuments) {
    if (saving) return;
    setSaving(true);
    // Emptied first, so that a second save's line, the same words within a minute, is said again.
    setSaved(null);
    setFailure(null);
    try {
      const corpus = await saveClusterCorpus(client, region.id, region.layoutIdentity);
      const truncated = corpus.wasTruncatedAtCapture === true && corpus.totalMatchCountAtCapture !== undefined;
      setSaved({
        line: truncated
          ? copy.clusters.savedTruncated(corpus.name, corpus.documentCount, corpus.totalMatchCountAtCapture ?? corpus.documentCount)
          : copy.clusters.saved(corpus.name),
        warns: truncated,
      });
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setSaving(false);
    }
  }

  const sections = loaded ? clusterSections(loaded) : [];
  return (
    <section className="screen browse cluster">
      <Breadcrumb crumbs={[{ label: copy.clusters.title, axis: 'clusters' }]} current={title} />
      <h1 tabIndex={-1} data-loading={pages.isPending ? 'true' : undefined}>
        {title}
      </h1>
      {failed ? (
        <ClustersProblem error={pages.error} drill />
      ) : !first || !last ? (
        <p role="status">{copy.clusters.loading}</p>
      ) : (
        <>
          <dl className="cluster-facts">
            <div>
              <dt>{copy.clusters.countLabel}</dt>
              <dd>{first.documentCount.toLocaleString('en-US')}</dd>
            </div>
            {first.eraRows.map((row) => (
              <div key={row.label}>
                <dt>{row.label}</dt>
                <dd>{row.count}</dd>
              </div>
            ))}
          </dl>
          {first.coverage && first.total > 0 && (
            // Once, at the top, in the resolver's words; the list below never blocks.
            <p className={first.coverage.isComplete ? 'count' : 'count warning'}>
              {copy.corpora.coverage(first.coverage.indexedCount, first.coverage.totalCount)}
            </p>
          )}
          <p className="note">{copy.clusters.footer}</p>
          <div className="manage">
            <Link to="/analytics/semantic" search={{ region: first.id, layout: first.layoutIdentity }}>
              {copy.clusters.seeOnMap}
            </Link>
            {me.data?.userData === true && (
              <button type="button" disabled={first.total === 0} aria-disabled={saving ? 'true' : undefined} onClick={() => void save(first)}>
                {copy.clusters.saveCorpus}
              </button>
            )}
          </div>
          {me.data?.userData === true && (
            // A live region from the first, so that the confirmation is said when it comes.
            <p className={saved?.warns ? 'note warning' : 'note'} role="status">
              {saved?.line ?? ''}
            </p>
          )}
          {failure && (
            <p className="error" role="alert">
              {failure}
            </p>
          )}
          {sections.map((section) => (
            <ClusterVolume key={section.volumeId} section={section} />
          ))}
          {pages.hasNextPage && (
            <div className="show-more">
              <button ref={more} type="button" aria-disabled={pages.isFetchingNextPage ? 'true' : undefined} onClick={showMore}>
                {copy.clusters.showMore}
              </button>
              <p className="note" role="status">
                {copy.clusters.paging(last.shown, last.total)}
              </p>
              {pages.isFetchNextPageError && (
                <p className="error" role="alert">
                  {errorMessage(pages.error)}
                </p>
              )}
            </div>
          )}
        </>
      )}
    </section>
  );
}

/**
 * One volume's members, as the corpora's drill lists a volume's (`CorporaAxis`): a volume this server holds opens each in
 * the reader, its title and day from the index, and another's are named. A section a page did not change is the same
 * object, so it is not drawn again.
 */
const ClusterVolume = memo(function ClusterVolume({ section }: { section: WorkingCorpusDetail['sections'][number] }) {
  const heading = sectionHeading(section.volumeId);
  // A section, not a landmark: a long list would make dozens, and two of the catalogue's volumes share a title.
  return (
    <section className="corpus-volume">
      <h2 id={heading} tabIndex={-1}>
        {section.title ?? section.volumeId}
      </h2>
      <ol className="document-list">
        {section.documents.map((document) =>
          section.indexed ? (
            <li key={document.documentId}>
              <Link
                id={documentRow(document.volumeId, document.documentId)}
                to="/doc/$volumeId/$documentId"
                params={{ volumeId: document.volumeId, documentId: document.documentId }}
              >
                {document.displayTitle ?? document.documentId}
              </Link>
              {document.dateISO && <p className="meta">{document.dateISO}</p>}
            </li>
          ) : (
            <li key={document.documentId} id={documentRow(document.volumeId, document.documentId)} tabIndex={-1} className="not-indexed">
              <span>
                {document.volumeId} · {document.documentId}
              </span>
              <p className="meta">{copy.clusters.notIndexed}</p>
            </li>
          ),
        )}
      </ol>
    </section>
  );
});
