// The frame around every screen: a skip link, the header with navigation and appearance, the
// readiness banner, the screen, and the footer.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, Outlet, useRouter } from '@tanstack/react-router';
import { createContext, useContext, useEffect, useRef } from 'react';
import { readinessQuery } from '../api/endpoints';
import { copy } from '../copy';
import { type Appearance, useAppearance, useResolvedScheme } from '../settings/preferences';
import { requestHeadingFocus } from './headingFocus';

const SchemeContext = createContext<'light' | 'dark'>('light');

/** The scheme the app shows, for the reader's page to match. */
export const useScheme = () => useContext(SchemeContext);

export function AppShell() {
  const [appearance, setAppearance] = useAppearance();
  const scheme = useResolvedScheme(appearance);
  const router = useRouter();

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
      <a className="skip-link" href="#main">
        {copy.app.skipToContent}
      </a>
      <header className="app-header">
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
        </nav>
        <label className="appearance">
          {copy.appearance.label}{' '}
          <select value={appearance} onChange={(event) => setAppearance(event.target.value as Appearance)}>
            <option value="system">{copy.appearance.system}</option>
            <option value="light">{copy.appearance.light}</option>
            <option value="dark">{copy.appearance.dark}</option>
          </select>
        </label>
      </header>
      <ReadinessBanner />
      <main id="main" tabIndex={-1}>
        <Outlet />
      </main>
      <footer className="app-footer">
        <p>{copy.app.footer}</p>
      </footer>
    </SchemeContext.Provider>
  );
}

/** While no index is served, says which step the server is at; the reader works meanwhile. */
function ReadinessBanner() {
  const readiness = useQuery(readinessQuery);
  const queryClient = useQueryClient();
  const ready = readiness.data?.ready;
  const wasReady = useRef(ready);

  // When an index becomes ready, what was asked before it is asked again: searches, citations,
  // documents, and what Browse shows of what the server indexes.
  useEffect(() => {
    if (ready && wasReady.current === false) {
      for (const key of ['search', 'citation', 'document', 'volumes', 'volume', 'section', 'readingOrder']) {
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
