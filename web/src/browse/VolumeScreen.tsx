// A volume (SPEC, Browse): its title, publication and editors, how many of its documents this
// server indexes, and its sections; or, when neither the index nor the TEI gives its sections, the
// index's reading order.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { ApiError } from '../api/client';
import { readingOrderQuery, volumeQuery, volumesQuery } from '../api/endpoints';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { plainTitle, useDocumentTitle } from '../shell/useDocumentTitle';
import { Breadcrumb } from './Breadcrumb';
import { SectionTree } from './SectionTree';

const route = getRouteApi('/browse/$volumeId');

export function VolumeScreen() {
  const { volumeId } = route.useParams();
  const volume = useQuery(volumeQuery(volumeId));
  const queryClient = useQueryClient();
  const data = volume.data;
  // The catalogue, when it has been read, already names the volume.
  const listed = queryClient.getQueryData(volumesQuery.queryKey)?.items.find((item) => item.volumeId === volumeId);
  const title = data?.title ?? listed?.title ?? volumeId;
  useDocumentTitle(title);
  useHeadingReady(!volume.isPending || listed !== undefined);

  return (
    <section className="screen browse-volume">
      <Breadcrumb crumbs={[{ label: copy.browse.title }]} current={title} />
      <h1 tabIndex={-1} data-loading={volume.isPending && !listed ? 'true' : undefined}>
        {plainTitle(title)}
      </h1>
      {volume.isError && (
        <p className="error" role="alert">
          {volume.error instanceof ApiError ? volume.error.message : String(volume.error)}
        </p>
      )}
      {data && (
        <>
          <div className="volume-meta">
            {data.publicationDate && <p>{copy.browse.published(data.publicationDate)}</p>}
            {data.editors.length > 0 && <p>{data.editors.join(', ')}</p>}
            {data.generalEditor && <p>{copy.browse.generalEditor(data.generalEditor)}</p>}
            {data.status === 'partiallyPublished' && <p>{copy.browse.partiallyPublished}</p>}
            {data.status === 'planned' && <p>{copy.browse.planned}</p>}
          </div>
          {data.documentCount !== undefined && (
            <p className="count">{copy.browse.documentCoverage(data.indexedDocumentCount ?? 0, data.documentCount)}</p>
          )}
          {!data.teiAvailable && <p className="note">{copy.browse.noTEI}</p>}
          {data.structure ? (
            <>
              <h2>{copy.browse.sections}</h2>
              <SectionTree volumeId={volumeId} sections={data.structure} />
            </>
          ) : data.indexed ? (
            <ReadingOrder volumeId={volumeId} />
          ) : (
            <p>{copy.browse.noContents}</p>
          )}
        </>
      )}
      {volume.isPending && <p role="status">{copy.browse.loading}</p>}
    </section>
  );
}

/** The index's reading order, for a volume whose sections neither the index nor the TEI gives. */
function ReadingOrder({ volumeId }: { volumeId: string }) {
  const order = useQuery(readingOrderQuery(volumeId));
  if (order.isError) {
    return (
      <p className="error" role="alert">
        {order.error instanceof ApiError ? order.error.message : String(order.error)}
      </p>
    );
  }
  if (!order.data) return <p role="status">{copy.browse.loading}</p>;
  return (
    <>
      <h2>{copy.browse.documents(order.data.total)}</h2>
      <ol className="document-list">
        {order.data.items.map((item) => (
          <li key={item.documentId}>
            <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId: item.documentId }}>
              {item.header}
            </Link>
            {item.dateline && <p className="meta">{item.dateline}</p>}
          </li>
        ))}
      </ol>
    </>
  );
}
