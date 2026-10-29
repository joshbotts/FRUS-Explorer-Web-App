// The reader (SPEC, Reader rendering and Reader and Research rail): the document's header and
// toolbar, the server's page in a sandboxed frame with the user's highlights drawn in it and the
// selection bar over it, the note editor the bar's Note opens, the rail beside it, Cite or
// Research, the second only on a server that keeps user data, and what the page's
// links lead to: another document or a note in one, the document on a printed page, a whole
// volume in Browse or, outside the catalogue, on history.state.gov, or a card for a person, a term
// or an unresolved reference. From S17f each document opened is recorded in the trail, and opens in
// the mode Settings ▸ Reading names when the link that opened it names no rail.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type ReactNode, useEffect, useEffectEvent, useRef, useState, useSyncExternalStore } from 'react';
import { ApiError } from '../api/client';
import { documentQuery, linkQuery, type ReadingWidth, readerPageURL, type TextSize, volumesQuery } from '../api/endpoints';
import type { ReaderLinkTarget } from '../api/types';
import { recordVisit } from '../api/research';
import { meQuery } from '../api/userData';
import { CitePanel } from '../cite/CitePanel';
import { copy } from '../copy';
import { NoteEditor } from '../research/NoteEditor';
import { ResearchRail } from '../research/ResearchRail';
import type { ReaderSearch } from '../router';
import { checklistStore, reviewedKey } from '../search/checklist';
import { useReadingWidth, useTextSize } from '../settings/preferences';
import { lastPanelVisible, rememberPanelVisible, useDocumentMode, useSyncedPreferences } from '../settings/syncedPreferences';
import { useScheme } from '../shell/AppShell';
import { useHeadingReady } from '../shell/headingFocus';
import { plainTitle, useDocumentTitle } from '../shell/useDocumentTitle';
import { LinkCard } from './LinkCard';
import { readerMessage } from './readerMessages';
import { useReaderHighlights } from './useReaderHighlights';

const route = getRouteApi('/doc/$volumeId/$documentId');

/** Below this width the rail is a sheet over the text (SPEC, Shell and navigation). */
const narrowQuery = '(max-width: 899.98px)';

function subscribeToWidth(onChange: () => void): () => void {
  const list = window.matchMedia?.(narrowQuery);
  list?.addEventListener('change', onChange);
  return () => list?.removeEventListener('change', onChange);
}

/**
 * Fetches the page before the frame loads it, so an error is a notice, never raw JSON in the frame;
 * gives the kit's rendering version of its text, which a highlight made in it names.
 */
async function checkPage(url: string, signal: AbortSignal): Promise<{ renderingVersion: string | null }> {
  const response = await fetch(url, { signal });
  if (!response.ok) throw await ApiError.from(response);
  return { renderingVersion: response.headers.get('X-FRUS-Rendering-Version') };
}

export function ReaderScreen() {
  const { volumeId, documentId } = route.useParams();
  const { rail, note } = route.useSearch();
  const navigate = route.useNavigate();
  const queryClient = useQueryClient();
  const citeToggle = useRef<HTMLButtonElement>(null);
  const researchToggle = useRef<HTMLButtonElement>(null);
  // The Research rail holds the user's data, which a server with FRUS_USER_DATA=off keeps none of.
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const shownRail = rail === 'research' && !keepsUserData ? undefined : rail;
  const { preferences } = useSyncedPreferences();
  const mode = useDocumentMode();
  const scheme = useScheme();
  const [textSize, setTextSize] = useTextSize();
  const [readingWidth, setReadingWidth] = useReadingWidth();
  const narrow = useSyncExternalStore(subscribeToWidth, () => window.matchMedia?.(narrowQuery).matches ?? false, () => false);
  // The reader works without an index, so metadata that fails leaves the id and the volume's title.
  const detail = useQuery(documentQuery(volumeId, documentId));
  const volumes = useQuery(volumesQuery);
  const pageURL = readerPageURL(volumeId, documentId, scheme, textSize, readingWidth);
  const frameURL = note ? `${pageURL}#${note}` : pageURL;
  // Checked each time the frame loads a page, as the frame fetches the page each time, so the version
  // a highlight names is the one the frame holds; a refocused tab, or a server briefly away, leaves an
  // open document open, and its last check with it.
  const page = useQuery({
    queryKey: ['page', pageURL],
    queryFn: ({ signal }) => checkPage(pageURL, signal),
    retry: false,
    staleTime: 0,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
  });
  const frame = useRef<HTMLIFrameElement>(null);
  const body = useRef<HTMLDivElement>(null);
  // A notice and a card belong to the document they were shown for: another document, reached by
  // any route, Back and Forward among them, starts without them.
  const documentKey = `${volumeId}/${documentId}`;
  const [notice, setNotice] = useState<ReactNode>(null);
  const [card, setCard] = useState<ReaderLinkTarget | null>(null);
  // The highlight made last, which the rail's Add Note to Highlight makes a note for until it is
  // chosen or the document changes, as the app's `HighlightCoordinator` holds it, with the document
  // it is in: one whose request comes back after a move to another is never offered there; and
  // whether the bar's Note has the editor open.
  const [pendingHighlight, setPendingHighlight] = useState<{ documentKey: string; id: string } | null>(null);
  const [composing, setComposing] = useState(false);
  const [shownKey, setShownKey] = useState(documentKey);
  if (shownKey !== documentKey) {
    setShownKey(documentKey);
    setNotice(null);
    setCard(null);
    setPendingHighlight(null);
    setComposing(false);
  }
  // Each arrival at a document, once its account has loaded, as the app's reader records a visit after
  // its load (S17f): the trail records it while Log Research Sessions is on, and while that is on a
  // document opened during Checklist Mode leaves its list (S17e), as the Mac's reading history hides it.
  // With no user data kept, it leaves the list, as before the switch.
  const visited = useRef<string | null>(null);
  const loaded = detail.isSuccess || detail.isError;
  useEffect(() => {
    if (!me.data || !loaded || visited.current === documentKey) return;
    if (keepsUserData && !preferences) return;
    visited.current = documentKey;
    if (!keepsUserData || preferences?.researchLoggingEnabled) checklistStore.opened(reviewedKey(volumeId, documentId));
    if (keepsUserData && detail.isSuccess) void recordVisit(queryClient, volumeId, documentId).catch(() => {});
  }, [me.data, loaded, documentKey, keepsUserData, preferences, detail.isSuccess, volumeId, documentId, queryClient]);
  // Open Documents In (S17f): a document a link opens with no rail named opens with the Research rail
  // in Research mode, as last left in Remember Last, and without it in Read; a rail the link names, as
  // the rail's own toggle does, wins. The rail as the reader leaves it is what Remember Last reopens.
  const arrivedMode = useRef<string | null>(null);
  useEffect(() => {
    if (!keepsUserData || !preferences) return;
    if (arrivedMode.current !== documentKey) {
      arrivedMode.current = documentKey;
      const wanted = mode === 'research' || (mode === 'rememberLast' && lastPanelVisible());
      if (rail === undefined && wanted) {
        void navigate({ search: (previous: ReaderSearch) => ({ ...previous, rail: 'research' }), replace: true });
        return;
      }
    }
    if (rail !== 'cite') rememberPanelVisible(rail === 'research');
  }, [keepsUserData, preferences, documentKey, mode, rail, navigate]);
  // A note is landed on once each time the reader arrives at it, by a link or by Back and Forward.
  // A page loaded again for another text size, reading width or appearance leaves focus on the
  // control that asked for it (WCAG 3.2.2), and the frame's URL fragment keeps the note in view.
  const arrival = `${documentKey}#${note ?? ''}`;
  const [arrivedAt, setArrivedAt] = useState(arrival);
  const [landing, setLanding] = useState(note);
  if (arrivedAt !== arrival) {
    setArrivedAt(arrival);
    setLanding(note);
  }
  // The rail takes focus when the reader opens it, not when a page loads with it open.
  const [focusRail, setFocusRail] = useState(false);
  const sheet = shownRail !== undefined && narrow;
  const highlights = useReaderHighlights({
    volumeId,
    documentId,
    enabled: keepsUserData,
    frame,
    frameURL,
    pageVersion: page.data?.renderingVersion,
    say: setNotice,
    onHighlightMade: (made) => setPendingHighlight({ documentKey: `${made.volumeId}/${made.documentId}`, id: made.id }),
    onNote: () => setComposing(true),
  });

  /** Opens a link's destination: a note of this document in place, else its document, if this server has it. */
  function open(target: ReaderLinkTarget, destination: NonNullable<ReaderLinkTarget['destination']>) {
    if (target.inPlace) {
      // A note in this document is shown in place, as the app does: no navigation, so the frame
      // keeps its history and Back still leaves the document.
      setNotice(null);
      if (destination.footnoteElementId) reveal(destination.footnoteElementId);
    } else if (!target.volume) {
      setNotice(copy.reader.linkUnknownVolume);
    } else if (!target.volume.teiAvailable) {
      setNotice(
        <>
          {copy.reader.linkNotOnServer(plainTitle(target.volume.title))}{' '}
          <a href={destination.canonicalURL} target="_blank" rel="noopener noreferrer">
            {copy.reader.openOnline}
          </a>
        </>,
      );
    } else {
      // A link goes forward, so Back returns to the document it was in.
      void navigate({
        to: '/doc/$volumeId/$documentId',
        params: { volumeId: destination.volumeId, documentId: destination.documentId },
        search: { rail, note: destination.footnoteElementId },
      });
    }
  }

  /**
   * Opens the volume a link opens where the kit's WholeVolumeLink sends it, as the server says: its
   * page in Browse, which names the page a page link was to, or, outside the catalogue, its page on
   * history.state.gov, which the notice offers.
   */
  function openVolume(target: ReaderLinkTarget, followedPage?: number) {
    if (target.wholeVolumeLink === 'browse' && target.volumeId) {
      void navigate({
        to: '/browse/$volumeId',
        params: { volumeId: target.volumeId },
        state: followedPage === undefined ? undefined : { followedPage },
      });
    } else if (target.wholeVolumeLink === 'web' && target.url) {
      setNotice(
        <>
          {copy.reader.linkUnknownVolume}{' '}
          <a href={target.url} target="_blank" rel="noopener noreferrer">
            {copy.reader.openOnline}
          </a>
        </>,
      );
    } else {
      setNotice(copy.reader.linkUnknownVolume);
    }
  }

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
      case 'page':
        // Where the kit's PageLink sends it: the document on the page, which opens as a
        // cross-reference's does, or, where none can be named without the volume, the volume, as a
        // link to the whole volume opens it. A page of a volume the index holds may name neither.
        if (target.destination) open(target, target.destination);
        else if (target.volumeId) openVolume(target, target.page);
        else say(target.volume ? copy.reader.linkPageNotPlaced(target.page ?? 0) : copy.reader.linkUnknownVolume);
        return;
      case 'document':
        if (target.destination) open(target, target.destination);
        return;
      case 'volume':
        openVolume(target);
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

  // The listener follows a link with the document shown when the link arrives, and hands the
  // page's other messages, its selection, a tap on a highlight and its keys, to the highlights.
  const onLink = useEffectEvent((href: string) => void follow(href));
  const onReaderMessage = useEffectEvent(highlights.onMessage);
  useEffect(() => {
    function onMessage(event: MessageEvent) {
      const message = readerMessage(event, frame.current?.contentWindow);
      if (message?.kind === 'link') onLink(message.href);
      else if (message) onReaderMessage(message);
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
    if (!active || active === document.body || body.current?.contains(active)) {
      document.getElementById(`${shownRail}-heading`)?.focus();
    }
  }, [sheet, shownRail]);

  /**
   * Opens a rail, Cite or Research, or closes the one open, in place of the history entry, so Back
   * leaves the document; closing it hands focus back to its toggle.
   */
  function setRail(next: ReaderSearch['rail']) {
    const toggle = rail === 'research' ? researchToggle : citeToggle;
    highlights.hideBar();
    setFocusRail(next !== undefined);
    const search = (previous: ReaderSearch): ReaderSearch => ({ ...previous, rail: next });
    void navigate({ search, replace: true }).then(() => {
      if (!next) toggle.current?.focus();
    });
  }

  const entry = detail.data?.document;
  // Named as the row that opened it, by the kit's rule for lists, as the app's reader is.
  const header = entry?.displayTitle ?? documentId;
  const volumeTitle = volumes.data?.items.find((volume) => volume.volumeId === volumeId)?.title ?? volumeId;
  useDocumentTitle(header);
  useHeadingReady(!detail.isPending);
  const previous = detail.data?.previous?.readable === false ? undefined : detail.data?.previous;
  const next = detail.data?.next?.readable === false ? undefined : detail.data?.next;

  return (
    <div className={shownRail ? 'reader with-rail' : 'reader'}>
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
            {/* Beside Text Size, as the app's Settings ▸ Display has it: how long the page's lines may grow. */}
            <label>
              {copy.reader.readingWidth}{' '}
              <select value={readingWidth} onChange={(event) => setReadingWidth(event.target.value as ReadingWidth)}>
                {(['narrow', 'standard', 'wide'] as const).map((width) => (
                  <option key={width} value={width}>
                    {copy.reader.readingWidths[width]}
                  </option>
                ))}
              </select>
            </label>
            <button
              ref={citeToggle}
              type="button"
              aria-expanded={shownRail === 'cite'}
              aria-controls={shownRail === 'cite' ? 'cite-panel' : undefined}
              onClick={() => setRail(rail === 'cite' ? undefined : 'cite')}
            >
              {copy.reader.cite}
            </button>
            {keepsUserData && (
              <button
                ref={researchToggle}
                type="button"
                aria-expanded={shownRail === 'research'}
                aria-controls={shownRail === 'research' ? 'research-panel' : undefined}
                onClick={() => setRail(rail === 'research' ? undefined : 'research')}
              >
                {copy.reader.research}
              </button>
            )}
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
              // the note, so the next Tab continues from it; once for each arrival at the note.
              onLoad={() => {
                highlights.onFrameLoad();
                if (!landing) return;
                setLanding(undefined);
                reveal(landing);
              }}
            />
          ) : page.isError ? (
            <p className="error" role="alert">
              {page.error instanceof ApiError ? page.error.message : String(page.error)}
            </p>
          ) : (
            <p role="status">{copy.reader.loading}</p>
          )}
          {highlights.elements}
        </div>
      </section>
      {shownRail === 'cite' && (
        <CitePanel volumeId={volumeId} documentId={documentId} autoFocus={focusRail} onClose={() => setRail(undefined)} />
      )}
      {shownRail === 'research' && (
        <ResearchRail
          volumeId={volumeId}
          documentId={documentId}
          documentNumber={entry?.documentNumber}
          undrawnHighlights={highlights.undrawn}
          pendingHighlightId={pendingHighlight?.documentKey === documentKey ? pendingHighlight.id : null}
          onPendingUsed={() => setPendingHighlight(null)}
          autoFocus={focusRail}
          onClose={() => setRail(undefined)}
        />
      )}
      {/* Outside the text's part of the page, which is inert while the rail is a sheet over it. */}
      {composing && keepsUserData && (
        <NoteEditor
          volumeId={volumeId}
          documentId={documentId}
          onClose={() => {
            setComposing(false);
            // Back to the text, once the dialog has gone: while it is open, the frame is inert.
            requestAnimationFrame(() => frame.current?.focus({ preventScroll: true }));
          }}
        />
      )}
      {card && <LinkCard target={card} onClose={closeCard} />}
    </div>
  );
}
