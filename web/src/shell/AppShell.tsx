// The frame around every screen: a skip link, the header with navigation, the project picker (PLAN's
// S17f) and appearance, the "Working on:" line over Browse and Search, the readiness banner, the
// screen, and the footer. Behind a proxy that signs people in (PLAN's S14e),
// the header names the user and the footer says that the instance's operator can read what it
// keeps for them, as SPEC's Privacy asks.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, Outlet, useRouter } from '@tanstack/react-router';
import { createContext, type MouseEvent, useContext, useEffect, useRef } from 'react';
import { readinessQuery } from '../api/endpoints';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { type Appearance, useAppearance, useResolvedScheme } from '../settings/preferences';
import { requestHeadingFocus } from './headingFocus';
import { ProjectPicker, WorkingOn } from './ProjectPicker';

const SchemeContext = createContext<'light' | 'dark'>('light');

/** The scheme the app shows, for the reader's page to match. */
export const useScheme = () => useContext(SchemeContext);

export function AppShell() {
  const [appearance, setAppearance] = useAppearance();
  const scheme = useResolvedScheme(appearance);
  const router = useRouter();
  // Signed in, through the proxy: a server with no sign-in has one user, its operator.
  const me = useQuery(meQuery);
  const signedIn = me.data && me.data.auth !== 'none' ? me.data : undefined;
  const keepsUserData = me.data?.userData === true;

  // A new screen takes focus at its heading, so a screen reader announces where it arrived. The
  // router says when the new screen has rendered; a new search on the same screen keeps its focus,
  // and a page just loaded starts at its top, where Skip to content is the first stop.
  useEffect(
    () =>
      router.subscribe('onRendered', (event) => {
        if (event.pathChanged && event.fromLocation) requestHeadingFocus();
      }),
    [router],
  );

  return (
    <SchemeContext.Provider value={scheme}>
      {/* Against the page's <base>, #main names the app's first page, so the link moves focus itself. */}
      <a className="skip-link" href="#main" onClick={skipToMain}>
        {copy.app.skipToContent}
      </a>
      {/* Named, as its footer is, since a collection's preview frames the kit's page, whose own header and
          footer are a banner and a page's footer too, and two of a kind need names to be told apart (S18e). */}
      <header className="app-header" aria-label={copy.app.name}>
        <Link to="/search" className="brand">
          {copy.app.name}
        </Link>
        <nav aria-label={copy.app.navigation}>
          <Link to="/browse" activeProps={{ 'aria-current': 'page' }}>
            {copy.app.browse}
          </Link>
          <Link to="/search" activeProps={{ 'aria-current': 'page' }}>
            {copy.app.search}
          </Link>
          {/* Between Search and Settings, as the app's tabs order them. */}
          <Link to="/research" activeProps={{ 'aria-current': 'page' }}>
            {copy.app.research}
          </Link>
          {/* From S18d, the app's Collections tab, on a server that keeps user data. */}
          {keepsUserData && (
            <Link to="/collections" activeProps={{ 'aria-current': 'page' }}>
              {copy.app.collections}
            </Link>
          )}
          <Link to="/settings" activeProps={{ 'aria-current': 'page' }}>
            {copy.app.settings}
          </Link>
        </nav>
        <ProjectPicker />
        <label className="appearance">
          {copy.appearance.label}{' '}
          <select value={appearance} onChange={(event) => setAppearance(event.target.value as Appearance)}>
            <option value="system">{copy.appearance.system}</option>
            <option value="light">{copy.appearance.light}</option>
            <option value="dark">{copy.appearance.dark}</option>
          </select>
        </label>
        {signedIn && <p className="signed-in">{copy.app.signedInAs(signedIn.displayName)}</p>}
      </header>
      <WorkingOn />
      <ReadinessBanner />
      <main id="main" tabIndex={-1}>
        <Outlet />
      </main>
      <footer className="app-footer" aria-label={copy.app.footerLabel}>
        <p>{copy.app.footer}</p>
        {signedIn && <p>{copy.app.operatorReads}</p>}
      </footer>
    </SchemeContext.Provider>
  );
}

function skipToMain(event: MouseEvent<HTMLAnchorElement>) {
  event.preventDefault();
  document.getElementById('main')?.focus();
}

/** While no index is served, says which step the server is at; the reader works meanwhile. */
function ReadinessBanner() {
  const readiness = useQuery(readinessQuery);
  const queryClient = useQueryClient();
  const ready = readiness.data?.ready;
  const wasReady = useRef(ready);

  // When an index becomes ready, what was asked before it is asked again: searches and their
  // readings, citations and Citation Lookup's answers, documents, and what Browse shows of what the
  // server indexes.
  useEffect(() => {
    if (ready && wasReady.current === false) {
      for (const key of ['search', 'facets', 'inspect', 'timeline', 'concordance', 'citation', 'citationLookup', 'citationBatch', 'document', 'volumes', 'volume', 'section', 'readingOrder']) {
        void queryClient.invalidateQueries({ queryKey: [key] });
      }
    }
    wasReady.current = ready;
  }, [ready, queryClient]);

  if (!readiness.data || readiness.data.ready) return null;
  return (
    <p className="banner" role="status">
      {copy.readiness.notReady} {readiness.data.detail}
    </p>
  );
}
