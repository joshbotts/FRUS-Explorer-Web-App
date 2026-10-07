// The reader (SPEC, Reader rendering and Reader and Research rail): the document's header and
// toolbar, the server's page in a sandboxed frame, the Cite rail beside it, and what the page's
// links lead to: another document or a note in one, or a card for a person, a term or an
// unresolved reference.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type ReactNode, useEffect, useEffectEvent, useRef, useState, useSyncExternalStore } from 'react';
import { ApiError } from '../api/client';
import { documentQuery, linkQuery, readerPageURL, type TextSize, volumesQuery } from '../api/endpoints';
import type { ReaderLinkTarget } from '../api/types';
import { CitePanel } from '../cite/CitePanel';
import { copy } from '../copy';
import type { ReaderSearch } from '../router';
import { useTextSize } from '../settings/preferences';
import { useScheme } from '../shell/AppShell';
import { useHeadingReady } from '../shell/headingFocus';
import { plainTitle, useDocumentTitle } from '../shell/useDocumentTitle';
import { LinkCard } from './LinkCard';
import { readerMessage } from './readerMessages';

const route = getRouteApi('/doc/$volumeId/$documentId');

/** Below this width the rail is a sheet over the text (SPEC, Shell and navigation). */
const narrowQuery = '(max-width: 899.98px)';

function subscribeToWidth(onChange: () => void): () => void {
  const list = window.matchMedia?.(narrowQuery);
  list?.addEventListener('change', onChange);
  return () => list?.removeEventListener('change', onChange);
}

/** Fetches the page before the frame loads it, so an error is a notice, never raw JSON in the frame. */
async function checkPage(url: string, signal: AbortSignal): Promise<true> {
  const response = await fetch(url, { signal });
  if (!response.ok) throw await ApiError.from(response);
  return true;
}

export function ReaderScreen() {
  const { volumeId, documentId } = route.useParams();
  const { rail, note } = route.useSearch();
  const navigate = route.useNavigate();
  const queryClient = useQueryClient();
  const citeToggle = useRef<HTMLButtonElement>(null);
  const scheme = useScheme();
  const [textSize, setTextSize] = useTextSize();
  const narrow = useSyncExternalStore(subscribeToWidth, () => window.matchMedia?.(narrowQuery).matches ?? false, () => false);
  // The reader works without an index, so metadata that fails leaves the id and the volume's title.
  const detail = useQuery(documentQuery(volumeId, documentId));
  const volumes = useQuery(volumesQuery);
  const pageURL = readerPageURL(volumeId, documentId, scheme, textSize);
  const frameURL = note ? `${pageURL}#${note}` : pageURL;
  // Checked once per page: a refocused tab, or a server briefly away, leaves an open document open.
  const page = useQuery({
    queryKey: ['page', pageURL],
    queryFn: ({ signal }) => checkPage(pageURL, signal),
    retry: false,
    staleTime: Infinity,
  });
  const frame = useRef<HTMLIFrameElement>(null);
  const body = useRef<HTMLDivElement>(null);
  // A notice and a card belong to the document they were shown for: another document, reached by
  // any route, Back and Forward among them, starts without them.
  const documentKey = `${volumeId}/${documentId}`;
  const [notice, setNotice] = useState<ReactNode>(null);
  const [card, setCard] = useState<ReaderLinkTarget | null>(null);
  const [shownKey, setShownKey] = useState(documentKey);
  if (shownKey !== documentKey) {
    setShownKey(documentKey);
    setNotice(null);
    setCard(null);
  }
  // Cite takes focus when the reader opens it, not when a page loads with it open.
  const [focusRail, setFocusRail] = useState(false);
  const sheet = rail === 'cite' && narrow;

  /** Acts on a link from the page, as the app does: the server says where it leads. */
  async function follow(href: string) {
    let target: ReaderLinkTarget;
    try {
      target = await queryClient.fetchQuery(linkQuery(volumeId, documentId, href));
    } catch (error) {
      setNotice(error instanceof ApiError ? error.message : String(error));
      return;
    }
    const say = (content: ReactNode) => setNotice(content);
    switch (target.kind) {
      case 'person':
      case 'gloss':
        setCard(target);
        return;
      case 'brokenReference':
        if (target.brokenReference) setCard(target);
        else say(copy.reader.linkBrokenUnknown);
        return;
      case 'document': {
        const destination = target.destination;
        if (!destination) return;
        if (target.inPlace) {
          // A note in this document is shown in place, as the app does: no navigation, so the
          // frame keeps its history and Back still leaves the document.
          setNotice(null);
          if (destination.footnoteElementId) reveal(destination.footnoteElementId);
        } else if (!target.volume) {
          say(copy.reader.linkUnknownVolume);
        } else if (!target.volume.teiAvailable) {
          say(
            <>
              {copy.reader.linkNotOnServer(plainTitle(target.volume.title))}{' '}
              <a href={destination.canonicalURL} target="_blank" rel="noopener noreferrer">
                {copy.reader.openOnline}
              </a>
            </>,
          );
        } else {
          // A cross-reference goes forward, so Back returns to the document it was in.
          void navigate({
            to: '/doc/$volumeId/$documentId',
            params: { volumeId: destination.volumeId, documentId: destination.documentId },
            search: { rail, note: destination.footnoteElementId },
          });
        }
        return;
      }
      case 'page':
        say(copy.reader.linkPageLater);
        return;
      case 'external':
        say(
          <>
            {copy.reader.linkExternal}{' '}
            <a href={target.url} target="_blank" rel="noopener noreferrer">
              {target.url}
            </a>
          </>,
        );
        return;
      case 'unresolved':
        say(copy.reader.linkUnresolved);
        return;
    }
  }

  // The listener follows a link with the document shown when the link arrives.
  const onLink = useEffectEvent((href: string) => void follow(href));
  useEffect(() => {
    function onMessage(event: MessageEvent) {
      const message = readerMessage(event, frame.current?.contentWindow);
      if (message?.kind === 'link') onLink(message.href);
    }
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, []);

  /** Asks the page to scroll to an element and take focus there, where the next Tab continues. */
  function reveal(id: string) {
    frame.current?.focus();
    frame.current?.contentWindow?.postMessage({ source: 'frus-app', kind: 'reveal', id }, '*');
  }

  /** A card closed: focus goes back into the frame, and the page refocuses the link it came from. */
  function closeCard() {
    setCard(null);
    frame.current?.focus();
    frame.current?.contentWindow?.postMessage({ source: 'frus-app', kind: 'restoreFocus' }, '*');
  }

  // When the sheet comes to cover the text while focus is in it, as when a window narrows with the
  // rail open, the text is set aside and focus goes to the sheet, rather than to nowhere.
  useEffect(() => {
    if (!sheet) return;
    const active = document.activeElement;
    if (!active || active === document.body || body.current?.contains(active)) document.getElementById('cite-heading')?.focus();
  }, [sheet]);

  /**
   * Opens or closes the rail, in place of the history entry, so Back leaves the document; closing
   * it hands focus back to the toggle.
   */
  function setRail(open: boolean) {
    setFocusRail(open);
    const search = (previous: ReaderSearch): ReaderSearch => ({ ...previous, rail: open ? 'cite' : undefined });
    void navigate({ search, replace: true }).then(() => {
      if (!open) citeToggle.current?.focus();
    });
  }

  const entry = detail.data?.document;
  const header = entry?.header || documentId;
  const volumeTitle = volumes.data?.items.find((volume) => volume.volumeId === volumeId)?.title ?? volumeId;
  useDocumentTitle(header);
  useHeadingReady(!detail.isPending);
  const previous = detail.data?.previous?.readable === false ? undefined : detail.data?.previous;
  const next = detail.data?.next?.readable === false ? undefined : detail.data?.next;

  return (
    <div className={rail === 'cite' ? 'reader with-rail' : 'reader'}>
      <section className="reader-main">
        <header className="document-header">
          <p className="volume">
            <Link to="/browse/$volumeId" params={{ volumeId }}>
              {plainTitle(volumeTitle)}
            </Link>
          </p>
          <h1 tabIndex={-1} data-loading={detail.isPending ? 'true' : undefined}>
            {plainTitle(header)}
          </h1>
          {entry?.dateline && <p className="dateline">{entry.dateline}</p>}
        </header>
        {/* Below 900 px the rail is a sheet over the toolbar and the text, which are set aside while it is open. */}
        <div className="reader-body" ref={body} inert={sheet}>
          <div className="toolbar" role="group" aria-label={copy.reader.toolbar}>
            {/* Previous and next turn the page in place, as the app's do; a link in the text goes forward. */}
            {previous && (
              <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId: previous.documentId }} search={{ rail }} replace>
                <span aria-hidden="true">← </span>
                {copy.reader.previous}
              </Link>
            )}
            {next && (
              <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId: next.documentId }} search={{ rail }} replace>
                {copy.reader.next}
                <span aria-hidden="true"> →</span>
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
            {notice}
          </p>
          {page.data ? (
            // A new frame for each page: changing a frame's address would add entries to the
            // browser's history inside it, which Back would walk before leaving the document.
            <iframe
              key={frameURL}
              ref={frame}
              className="reader-frame"
              title={copy.reader.frameTitle(plainTitle(header))}
              src={frameURL}
              sandbox="allow-scripts"
              referrerPolicy="no-referrer"
              // A link to a note lands on it: the fragment scrolls the page there, and focus goes to
              // the note, so the next Tab continues from it.
              onLoad={() => {
                if (note) reveal(note);
              }}
            />
          ) : page.isError ? (
            <p className="error" role="alert">
              {page.error instanceof ApiError ? page.error.message : String(page.error)}
            </p>
          ) : (
            <p role="status">{copy.reader.loading}</p>
          )}
        </div>
      </section>
      {rail === 'cite' && (
        <CitePanel volumeId={volumeId} documentId={documentId} autoFocus={focusRail} onClose={() => setRail(false)} />
      )}
      {card && <LinkCard target={card} onClose={closeCard} />}
    </div>
  );
}
