// The reader (SPEC, Reader rendering and Reader and Research rail): the document's header and
// toolbar, the server's page in a sandboxed frame, and the Cite rail beside it.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { useEffect, useRef, useState } from 'react';
import { ApiError } from '../api/client';
import { documentQuery, readerPageURL, type TextSize, volumesQuery } from '../api/endpoints';
import type { ReaderSearch } from '../router';
import { CitePanel } from '../cite/CitePanel';
import { copy } from '../copy';
import { useTextSize } from '../settings/preferences';
import { useScheme } from '../shell/AppShell';
import { readerMessage } from './readerMessages';

const route = getRouteApi('/doc/$volumeId/$documentId');

/** Fetches the page before the frame loads it, so an error is a notice, never raw JSON in the frame. */
async function checkPage(url: string, signal: AbortSignal): Promise<true> {
  const response = await fetch(url, { signal });
  if (!response.ok) throw await ApiError.from(response);
  return true;
}

export function ReaderScreen() {
  const { volumeId, documentId } = route.useParams();
  const { rail } = route.useSearch();
  const navigate = route.useNavigate();
  const citeToggle = useRef<HTMLButtonElement>(null);
  const scheme = useScheme();
  const [textSize, setTextSize] = useTextSize();
  // The reader works without an index, so metadata that fails leaves the id and the volume's title.
  const detail = useQuery(documentQuery(volumeId, documentId));
  const volumes = useQuery(volumesQuery);
  const pageURL = readerPageURL(volumeId, documentId, scheme, textSize);
  // Checked once per page: a refocused tab, or a server briefly away, leaves an open document open.
  const page = useQuery({
    queryKey: ['page', pageURL],
    queryFn: ({ signal }) => checkPage(pageURL, signal),
    retry: false,
    staleTime: Infinity,
  });
  const frame = useRef<HTMLIFrameElement>(null);
  // The notice belongs to the document it was shown for, so another document starts without it.
  const documentKey = `${volumeId}/${documentId}`;
  const [notice, setNotice] = useState<{ key: string; text: string } | null>(null);

  useEffect(() => {
    function onMessage(event: MessageEvent) {
      const message = readerMessage(event, frame.current?.contentWindow);
      if (message?.kind === 'link') setNotice({ key: documentKey, text: copy.reader.linksLater });
    }
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [documentKey]);

  /**
   * Opens or closes the rail, in place of the history entry, so Back leaves the document; closing
   * it hands focus back to the toggle.
   */
  function setRail(open: boolean) {
    const search = (previous: ReaderSearch): ReaderSearch => ({ ...previous, rail: open ? 'cite' : undefined });
    void navigate({ search, replace: true }).then(() => {
      if (!open) citeToggle.current?.focus();
    });
  }

  const document = detail.data?.document;
  const header = document?.header || documentId;
  const volumeTitle = volumes.data?.items.find((volume) => volume.volumeId === volumeId)?.title ?? volumeId;

  return (
    <div className={rail === 'cite' ? 'reader with-rail' : 'reader'}>
      <section className="reader-main">
        <header className="document-header">
          <p className="volume">{volumeTitle}</p>
          <h1 tabIndex={-1}>{header}</h1>
          {document?.dateline && <p className="dateline">{document.dateline}</p>}
        </header>
        <div className="toolbar" role="toolbar" aria-label={copy.reader.toolbar}>
          {detail.data?.previous && (
            <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId: detail.data.previous.documentId }} search={{ rail }}>
              ← {copy.reader.previous}
            </Link>
          )}
          {detail.data?.next && (
            <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId: detail.data.next.documentId }} search={{ rail }}>
              {copy.reader.next} →
            </Link>
          )}
          {detail.data?.canonicalURL && (
            <a href={detail.data.canonicalURL} target="_blank" rel="noopener noreferrer">
              {copy.reader.openOnline}
            </a>
          )}
          <label>
            {copy.reader.textSize}{' '}
            <select value={textSize} onChange={(event) => setTextSize(event.target.value as TextSize)}>
              {(['small', 'medium', 'large', 'extraLarge'] as const).map((size) => (
                <option key={size} value={size}>
                  {copy.reader.textSizes[size]}
                </option>
              ))}
            </select>
          </label>
          <button
            ref={citeToggle}
            type="button"
            aria-expanded={rail === 'cite'}
            aria-controls={rail === 'cite' ? 'cite-panel' : undefined}
            onClick={() => setRail(rail !== 'cite')}
          >
            {copy.reader.cite}
          </button>
        </div>
        <p className="notice" role="status">
          {notice?.key === documentKey ? notice.text : ''}
        </p>
        {page.data ? (
          <iframe
            ref={frame}
            className="reader-frame"
            title={copy.reader.frameTitle(header)}
            src={pageURL}
            sandbox="allow-scripts"
            referrerPolicy="no-referrer"
          />
        ) : page.isError ? (
          <p className="error" role="alert">
            {page.error instanceof ApiError ? page.error.message : String(page.error)}
          </p>
        ) : (
          <p role="status">{copy.reader.loading}</p>
        )}
      </section>
      {rail === 'cite' && <CitePanel volumeId={volumeId} documentId={documentId} onClose={() => setRail(false)} />}
    </div>
  );
}
