// Add Highlighted Passages (PLAN's S18d), the app's `CollectionAddHighlightsSheet`: the user's
// highlights on the collection's documents, in the collection's order of them, the oldest first within
// one, each with its passage and its document, ticked to insert; a highlight that stored no passage is
// left out, as there is nothing to freeze. Insert adds them as excerpts at the end, in the list's order.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { addExcerpts, type CollectionDetail } from '../api/collections';
import { getJSON } from '../api/client';
import type { HighlightList } from '../api/types';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { documentKey } from './collectionRules';

export function AddHighlights({ detail, onClose }: { detail: CollectionDetail; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const highlights = useQuery({
    queryKey: ['highlights'],
    queryFn: ({ signal }) => getJSON<HighlightList>('/api/v1/me/highlights', undefined, signal),
    staleTime: 0,
    retry: false,
  });
  const [selected, setSelected] = useState<ReadonlySet<string>>(new Set());
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const words = copy.addHighlights;

  // The collection's documents in its order, each once (`orderedDocumentKeys`), and their labels.
  const order = new Map<string, number>();
  const labels = new Map<string, string>();
  for (const entry of detail.entries) {
    if (entry.kind !== 'document') continue;
    const key = documentKey(entry.volumeId, entry.documentId);
    if (!order.has(key)) order.set(key, order.size);
    if (!labels.has(key)) labels.set(key, entry.header ?? entry.documentId);
  }
  const rows = (highlights.data?.items ?? [])
    .filter((highlight) => highlight.selectedText !== '' && order.has(documentKey(highlight.volumeId, highlight.documentId)))
    .map((highlight, at) => ({ highlight, at }))
    .sort((a, b) => {
      const byDocument = order.get(documentKey(a.highlight.volumeId, a.highlight.documentId))! - order.get(documentKey(b.highlight.volumeId, b.highlight.documentId))!;
      if (byDocument !== 0) return byDocument;
      const byTime = (a.highlight.createdAt ?? '').localeCompare(b.highlight.createdAt ?? '');
      return byTime !== 0 ? byTime : a.at - b.at;
    })
    .map((row) => row.highlight);

  async function insert() {
    const ids = rows.filter((row) => selected.has(row.id)).map((row) => row.id);
    if (ids.length === 0 || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await addExcerpts(client, detail.id, { highlightIds: ids });
      closeAtOnce(onClose);
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
    }
  }

  return (
    <Modal className="add-highlights" labelledBy={headingId} initial={cancel} onCancel={onClose} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {words.title}
      </h2>
      {highlights.isError ? (
        <p className="error" role="alert">
          {errorMessage(highlights.error)}
        </p>
      ) : !highlights.data ? (
        <p role="status">{words.loading}</p>
      ) : rows.length === 0 ? (
        <div className="empty">
          <h3>{words.emptyTitle}</h3>
          <p>{words.emptyDetail}</p>
        </div>
      ) : (
        <ul className="pick-list" aria-label={words.title}>
          {rows.map((highlight) => (
            <li key={highlight.id} className="pick-row">
              <label>
                <input
                  type="checkbox"
                  checked={selected.has(highlight.id)}
                  onChange={(event) =>
                    setSelected((held) => {
                      const next = new Set(held);
                      if (event.target.checked) next.add(highlight.id);
                      else next.delete(highlight.id);
                      return next;
                    })
                  }
                />{' '}
                {highlight.colorTag in copy.highlights.colors && (
                  <span
                    className={`color-dot hl-${highlight.colorTag}`}
                    role="img"
                    aria-label={copy.highlights.colors[highlight.colorTag as keyof typeof copy.highlights.colors]}
                  />
                )}
                <span className="pick-title">{highlight.selectedText}</span>
              </label>
              <p className="meta">{labels.get(documentKey(highlight.volumeId, highlight.documentId))}</p>
            </li>
          ))}
        </ul>
      )}
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="dialog-actions">
        <button ref={cancel} type="button" onClick={onClose}>
          {words.cancel}
        </button>
        <button type="button" className="primary" aria-disabled={selected.size === 0 || busy} onClick={() => void insert()}>
          {words.insert(selected.size)}
        </button>
      </div>
    </Modal>
  );
}
