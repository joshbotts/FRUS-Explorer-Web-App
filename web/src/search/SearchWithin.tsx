// Search Within These Results and the fallback (S27e), as the app draws them: the row that names a held list in the
// Search by group's place (`SearchLayerBaseRow`), with Swap once a layer has run and its close button; what a layer that
// found nothing shows, with its ways on (`SearchLayerEmptyState`); and the Semantic matches (experimental) under a
// keyword search that found nothing (`SemanticSearchFallbackView`), each hit a document the server holds, which opens, or
// one of a volume it does not serve, as a search by meaning lists those apart. The sentences that count are the kit's,
// from the server.
import { useQuery } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { useId } from 'react';
import { ApiError } from '../api/client';
import { fallbackQuery, type FallbackHit, type HeldListSummary, type LayerSummary } from '../api/searchWithin';
import { copy } from '../copy';
import { Badge } from '../shell/Badge';
import { plainTitle } from '../shell/useDocumentTitle';
import type { SearchState } from './searchState';

/**
 * The row that names the held list, in the Search by group's place, as the app's takes the Keywords | Meaning control's:
 * the field runs the other engine inside the list, and the control has nothing to choose. "Within 100 closest matches to
 * “…”", what the list held that a layer leaves out, Swap once a layer has run inside it, and the close button, which shows
 * the list again as it was.
 */
export function HeldListRow({
  summary,
  swap,
  canSwap,
  onSwap,
  onLeave,
}: {
  /** The held list, as the server says it; absent while it is asked for. */
  summary: HeldListSummary | undefined;
  /** The layer on screen and the list, swapped, where a layer has run and both have words. */
  swap: LayerSummary['swap'];
  /** Whether Swap acts now: not while a search runs. */
  canSwap: boolean;
  onSwap: () => void;
  onLeave: () => void;
}) {
  return (
    <section className="held-list" aria-label={summary?.accessibilityLabel ?? copy.searchLayer.held}>
      <span className="held-glyph" aria-hidden="true">
        {summary?.kind === 'meaning' ? '✦' : '⌕'}
      </span>
      <div className="held-text">
        <p>{summary?.rowDescription ?? copy.searchLayer.held}</p>
        {summary?.leftOutDescription && <p className="caption">{summary.leftOutDescription}</p>}
      </div>
      {swap && (
        <button type="button" aria-label={copy.searchLayer.swapLabel} title={swap.help} disabled={!canSwap} onClick={onSwap}>
          <span aria-hidden="true">⇄ </span>
          {copy.searchLayer.swap}
        </button>
      )}
      <button type="button" className="held-leave" aria-label={copy.searchLayer.leave} title={copy.searchLayer.leaveHelp} onClick={onLeave}>
        <span aria-hidden="true">✕</span>
      </button>
    </section>
  );
}

/**
 * What a layer that found nothing shows in its rows' place, as the app's does: the header's sentence, which says what it
 * looked in, the command that searches the whole library for words found nowhere in a Meaning list, and the way back.
 * Neither the keyword zero-state nor the fallback shows inside a held list (the app's rule 7).
 */
export function LayerEmpty({
  empty,
  onSearchLibrary,
  onBack,
}: {
  empty: NonNullable<LayerSummary['empty']>;
  onSearchLibrary: () => void;
  onBack: () => void;
}) {
  return (
    <div className="empty layer-empty">
      <h3>{empty.statement}</h3>
      {empty.searchLibraryTitle && (
        <button type="button" className="prominent" onClick={onSearchLibrary}>
          {empty.searchLibraryTitle}
        </button>
      )}
      <button type="button" onClick={onBack}>
        {empty.backTitle}
      </button>
    </div>
  );
}

/**
 * The Semantic matches (experimental) under a keyword search that found nothing, as the app mounts them beneath the
 * account of the terms that found nothing: the nearest by meaning across the whole series, with the kit's caption, which
 * says the filters are not applied, each hit with its chip.
 */
export function MeaningFallback({ state }: { state: SearchState }) {
  const headingId = useId();
  const fallback = useQuery(fallbackQuery(state, true));
  if (fallback.isPending && fallback.fetchStatus === 'idle') return null;
  return (
    <section className="meaning-fallback" aria-labelledby={headingId} aria-busy={fallback.isFetching}>
      <h3 id={headingId}>
        <span className="meaning-glyph" aria-hidden="true">
          ✦{' '}
        </span>
        {fallback.data && fallback.data.hits.length === 0 ? copy.meaningFallback.emptyTitle : copy.meaningFallback.title}
      </h3>
      {fallback.isError ? (
        <p className="note" role="status">
          {fallback.error instanceof ApiError && fallback.error.code === 'QUERY_TOO_LONG' ? copy.meaningFallback.tooLong : copy.meaningFallback.failed}
        </p>
      ) : !fallback.data ? (
        <p className="note" role="status">
          {copy.meaningFallback.searching}
        </p>
      ) : fallback.data.hits.length === 0 ? (
        <p className="caption">{fallback.data.emptyStatement}</p>
      ) : (
        <>
          <p className="caption">{fallback.data.caption}</p>
          <ul aria-label={copy.meaningFallback.title}>
            {fallback.data.hits.map((hit) => (
              <FallbackRow key={`${hit.volumeId}/${hit.documentId}`} hit={hit} />
            ))}
          </ul>
        </>
      )}
    </section>
  );
}

function FallbackRow({ hit }: { hit: FallbackHit }) {
  if (!hit.opens) {
    // A volume this server does not serve: its document's id, the volume's page in Browse, as a search by meaning lists it.
    return (
      <li>
        <Link to="/browse/$volumeId" params={{ volumeId: hit.volumeId }}>
          {copy.meaningSearch.beyondDocument(hit.documentId, plainTitle(hit.volumeTitle))}
        </Link>
        <p className="note">{copy.meaningSearch.beyondNotServed}</p>
        <p className="semantic-chip">{hit.chip}</p>
      </li>
    );
  }
  return (
    <li>
      <Link to="/doc/$volumeId/$documentId" params={{ volumeId: hit.volumeId, documentId: hit.documentId }}>
        {hit.displayTitle}
      </Link>
      <p className="meta">
        {hit.dateline && <>{hit.dateline} · </>}
        {plainTitle(hit.volumeTitle)}
        {hit.isEditorialNote && <Badge>{copy.search.editorialNote}</Badge>}
      </p>
      <p className="semantic-chip">{hit.chip}</p>
    </li>
  );
}
