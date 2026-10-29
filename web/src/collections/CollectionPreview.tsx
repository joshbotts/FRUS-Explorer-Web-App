// The live preview beside Contents (PLAN's S18e), the app's `CollectionPreviewView`: the HTML export's
// page, which the server builds for this frame, sandboxed, its links opening tabs of their own; the
// page's policy runs no script of its own, and the sandbox allows scripts, as the reader's frame does,
// only so that the browser's own tools reach it. The frame is sent to the page again a second after
// the collection last changed, once the changes sent are answered, and at once for the first page and
// for Render All; the page it holds stays while the next is built, under a spinner. It shows the first
// 20 documents until Render All, which the editor keeps; a bar names the volumes the server's folder
// lacks, whose documents the page shows as citations; and the app's caption says what the preview
// is. A smart collection waits for its saved search to be resolved here.
import { useEffect, useRef, useState } from 'react';
import { previewDocumentCap, previewURL, whenAnswered, type CollectionDetail } from '../api/collections';
import { copy } from '../copy';
import { previewSettleMilliseconds, showsCapBar } from './exportRules';

const words = copy.collectionPreview;

export function CollectionPreview({ detail, renderAll, onRenderAll }: { detail: CollectionDetail; renderAll: boolean; onRenderAll: () => void }) {
  const frame = useRef<HTMLIFrameElement>(null);
  // Whether the frame holds a page yet, and whether it is on its way to the next.
  const [shown, setShown] = useState(false);
  const [building, setBuilding] = useState(false);
  // The page is built again whenever anything the collection holds changes.
  const fingerprint = JSON.stringify(detail);
  const first = useRef(true);
  const atOnce = useRef(false);
  const smart = !detail.takesHandAddedEntries;

  useEffect(() => {
    if (smart) return;
    const wait = first.current || atOnce.current ? 0 : previewSettleMilliseconds;
    let stopped = false;
    const timer = setTimeout(() => {
      first.current = false;
      atOnce.current = false;
      void whenAnswered(detail.id).then(() => {
        if (stopped || !frame.current) return;
        setBuilding(true);
        // Set as it is, the same address too, so the frame asks for the page again.
        frame.current.src = previewURL(detail.id, renderAll);
      });
    }, wait);
    return () => {
      stopped = true;
      clearTimeout(timer);
    };
  }, [fingerprint, renderAll, detail.id, smart]);

  if (smart) {
    return (
      <section className="collection-preview" aria-label={copy.collectionEditor.preview}>
        <p className="note">{words.smart}</p>
      </section>
    );
  }

  const missing = detail.volumesNotHeld.length;
  return (
    <section className="collection-preview" aria-label={copy.collectionEditor.preview}>
      {missing > 0 && (
        <div className="preview-bar">
          <p>{words.missingVolumes(missing)}</p>
          <p className="note">{words.missingVolumesNote}</p>
        </div>
      )}
      {showsCapBar(detail, renderAll) && (
        <div className="preview-bar">
          <p>{words.capNotice(previewDocumentCap, detail.documentCount)}</p>
          <button
            type="button"
            onClick={() => {
              atOnce.current = true;
              onRenderAll();
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
            if (!frame.current?.getAttribute('src')) return;
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
