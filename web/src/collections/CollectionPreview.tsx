// The live preview beside Contents (PLAN's S18e), the app's `CollectionPreviewView`: the HTML export's
// page, which the server builds for this frame, sandboxed, its links opening tabs of their own; the
// page's policy runs no script of its own, and the sandbox allows scripts, as the reader's frame does,
// only so that the browser's own tools reach it. The frame is sent to the page again a second after
// the collection last changed, once the changes sent are answered and only if nothing has changed
// since, and at once for the first page and for Render All, each time in the frame's own place in the
// browser's history, so Back leaves the editor; the page it holds stays while the next is built,
// under a spinner. It shows the first 20 documents until Render All, which the editor keeps; a bar
// names the volumes the server's folder lacks, whose documents the page shows as citations; and the
// app's caption says what the preview is. A smart collection's page is its saved search's results,
// which the server caps as the app's preview does, and the bar counts them, as the app's counts the
// results it fetched (S18f); no volume is named as missing for it, as the app names none.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { collectionQuery, previewDocumentCap, previewURL, smartResultsQuery, whenAnswered, type CollectionDetail } from '../api/collections';
import { copy } from '../copy';
import { previewSettleMilliseconds, showsCapBar } from './exportRules';

const words = copy.collectionPreview;

export function CollectionPreview({ detail, renderAll, onRenderAll }: { detail: CollectionDetail; renderAll: boolean; onRenderAll: () => void }) {
  const client = useQueryClient();
  const region = useRef<HTMLElement>(null);
  const frame = useRef<HTMLIFrameElement>(null);
  // Whether the frame has been sent to a page, holds one yet, and is on its way to the next.
  const asked = useRef(false);
  const [shown, setShown] = useState(false);
  const [building, setBuilding] = useState(false);
  const [said, setSaid] = useState<string | null>(null);
  // The page is built again whenever anything the collection holds changes.
  const fingerprint = JSON.stringify(detail);
  const first = useRef(true);
  const atOnce = useRef(false);
  const smart = !detail.takesHandAddedEntries;
  const results = useQuery({ ...smartResultsQuery(detail.id), enabled: smart });
  const documentCount = smart ? (results.data?.total ?? 0) : detail.documentCount;

  useEffect(() => {
    const wait = first.current || atOnce.current ? 0 : previewSettleMilliseconds;
    let stopped = false;
    const timer = setTimeout(() => {
      first.current = false;
      atOnce.current = false;
      void whenAnswered(detail.id).then(() => {
        // An answer unlike what was shown is drawn first, and this effect runs again for it.
        const held = client.getQueryData(collectionQuery(detail.id).queryKey);
        if (stopped || !frame.current || (held !== undefined && JSON.stringify(held) !== fingerprint)) return;
        asked.current = true;
        setBuilding(true);
        // In the frame's own place in the history, so that Back leaves the editor, not the page.
        const address = previewURL(detail.id, renderAll);
        if (frame.current.contentWindow) frame.current.contentWindow.location.replace(address);
        else frame.current.src = address;
      });
    }, wait);
    return () => {
      stopped = true;
      clearTimeout(timer);
    };
  }, [fingerprint, renderAll, detail.id, client]);

  const missing = smart ? 0 : detail.volumesNotHeld.length;
  return (
    <section ref={region} className="collection-preview" aria-label={copy.collectionEditor.preview} tabIndex={-1}>
      <p className="visually-hidden" role="status">
        {said}
      </p>
      {missing > 0 && (
        <div className="preview-bar">
          <p>{words.missingVolumes(missing)}</p>
          <p className="note">{words.missingVolumesNote}</p>
        </div>
      )}
      {showsCapBar(documentCount, renderAll) && (
        <div className="preview-bar">
          <p>{words.capNotice(previewDocumentCap, documentCount)}</p>
          <button
            type="button"
            onClick={() => {
              atOnce.current = true;
              onRenderAll();
              // The bar goes with its button: focus goes to the preview, which says what it now shows.
              requestAnimationFrame(() => region.current?.focus());
              setSaid(words.renderingAll(documentCount));
            }}
          >
            {words.renderAll}
          </button>
        </div>
      )}
      <div className="preview-surface" aria-busy={building}>
        <iframe
          ref={frame}
          className="preview-frame"
          title={words.frameTitle}
          sandbox="allow-scripts allow-popups allow-popups-to-escape-sandbox"
          onLoad={() => {
            // The frame's first, empty document loads too; only a page asked for counts.
            if (!asked.current) return;
            setShown(true);
            setBuilding(false);
          }}
        />
        {!shown && (
          <p className="preview-loading" role="status">
            {words.loading}
          </p>
        )}
        {shown && building && <span className="preview-spinner" aria-hidden="true" />}
      </div>
      <p className="preview-caption">{words.fidelityNote}</p>
    </section>
  );
}
