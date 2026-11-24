// Semantic Analytics (PLAN's S28b), at /analytics/semantic, which the Mac's Analytics menu lists after Archival
// Analytics: the bundled semantic map, its 314,616 documents each where the layout put it, coloured by region in the
// app's palette on its dark ground and drawn by the web's own WebGL2 renderer, with pan and zoom by pointer and
// keyboard and a fit to the whole (SemanticMap.tsx); and beside it the map's regions in a table, largest first, as the
// app's regions table ranks them, with the summary the app's accessibility list opens with. A browser without WebGL2
// has the table and a sentence, and fetches no points; one whose WebGL2 fails as the map is made has the table and a
// sentence of its own, the reason in the console. Every point and region is the server's, from the bundled map.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { errorMessage } from '../api/client';
import { bytesPerPoint, type SemanticMapRegions, semanticMapPointsQuery, semanticMapRegionsQuery } from '../api/semanticMap';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { Empty } from './CorpusAnalyticsScreen';
import { DataTable } from './PersonAnalyticsScreen';
import { SemanticMap } from './SemanticMap';
import { supportsWebGL2 } from './semanticMapRenderer';

const words = copy.semanticAnalytics;

/** The regions' table: largest first, ties by id, as the app's regions table and its labels rank them. */
export function regionRows(answer: SemanticMapRegions): string[][] {
  return [...answer.regions]
    .sort((a, b) => b.documentCount - a.documentCount || a.id - b.id)
    .map((region) => [String(region.id), region.terms.join(' '), region.documentCount.toLocaleString('en-US')]);
}

export function SemanticAnalyticsScreen() {
  useDocumentTitle(words.title);
  const regions = useQuery(semanticMapRegionsQuery);
  useHeadingReady(!regions.isPending);
  const [webGL2] = useState(supportsWebGL2);
  const [failure, setFailure] = useState<string | undefined>(undefined);
  const drawable = webGL2 && failure === undefined;
  function unavailable(reason: string) {
    console.warn(`Semantic map: ${reason}`);
    setFailure(reason);
  }
  const points = useQuery({ ...semanticMapPointsQuery, enabled: drawable && regions.isSuccess });
  const answer = regions.data;
  const whole = answer !== undefined && points.data !== undefined && points.data.byteLength === answer.documentCount * bytesPerPoint;

  return (
    <div className="analytics-page semantic-analytics">
      <h1 tabIndex={-1} data-loading={regions.isPending ? 'true' : undefined}>
        {words.title}
      </h1>
      {regions.error ? (
        <Empty title={words.unavailableTitle} detail={errorMessage(regions.error)} />
      ) : !answer ? (
        <p className="analytics-loading" role="status">
          {words.loading}
        </p>
      ) : (
        <div className="semantic-layout">
          <div className="semantic-map-column">
            {!drawable ? (
              <p className="semantic-map-unavailable">{webGL2 ? words.failed : words.noWebGL2}</p>
            ) : points.error ? (
              <Empty title={words.unavailableTitle} detail={errorMessage(points.error)} />
            ) : !points.data ? (
              <p className="analytics-loading" role="status">
                {words.loading}
              </p>
            ) : !whole ? (
              <Empty title={words.unavailableTitle} detail={words.unreadable} />
            ) : (
              <SemanticMap points={points.data} gridExtent={answer.gridExtent} onUnavailable={unavailable} />
            )}
          </div>
          <div className="semantic-regions">
            <p className="semantic-regions-summary">
              {words.summary(answer.regions.length, answer.documentCount - answer.unclusteredCount, answer.unclusteredCount)}
            </p>
            <DataTable
              table={{
                title: words.table,
                columns: [words.columns.region, words.columns.terms, words.columns.documents],
                rows: regionRows(answer),
              }}
            />
          </div>
        </div>
      )}
    </div>
  );
}
